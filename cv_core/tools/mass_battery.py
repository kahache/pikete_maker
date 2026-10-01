"""Mass battery of the colorlab pipeline over Fashionpedia val (issue #24).

QA tool, NOT part of the package. Runs the full pipeline
(load_image -> remove_background -> skin filter -> dominant_colors ->
pick_harmony_base) over a reproducible random sample of
samples/g0/raw/test/ and computes, per photo:

- Automatic FLAGS (measurable proxies of the known bugs B1-B4):
  CRASH, BASE_IS_SKIN (B1), FG_BROKEN (B4), COLLAPSED_PALETTE,
  OVERFILTERED (B2) are KO flags. NEUTRAL_BASE is NOT a KO: since canvas
  mode (D10) a neutral base is the CORRECT outcome for a neutral outfit, so
  it is reported as its own "canvas-mode" category (see KO_FLAGS / summarize).
- Background complexity (standard deviation in LAB of the NON-fg pixels),
  to segment plain vs busy backgrounds (decision D11/F13). The threshold is
  decided in post-processing (report); here it is only measured.
- Pipeline time (excluding the QA panel render).

Outputs (gitignored): outputs/mass-battery/results.json,
outputs/mass-battery/<id>_panel.png and index.html (gallery, KO first).

Usage:
    python cv_core/tools/mass_battery.py --n 200 [--limit 5] [--gallery-only]

The automatic flags are a LOWER BOUND of the real KO rate: they detect the
known failure modes, they do not positively confirm that "the palette is the
outfit". The gallery exists so a human can calibrate that bound.

NOTE (#28): translated from tools/bateria_masiva.py. Flags, JSON keys and the
output directory are now in English, so results.json files produced by the
old script (outputs/bateria-100/, e.g. the 2026-07-07 battery-200 snapshot)
are not readable with --gallery-only: re-run the battery (seed 42) instead.
"""

from __future__ import annotations

import argparse
import json
import logging
import random
import time
import traceback
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Rectangle

from colorlab.background import remove_background
from colorlab.filters import (
    MIN_PIXELS,
    SKIN_DELTA_E,
    SKIN_LIGHTNESS_WEIGHT,
    adaptive_skin_mask,
    estimate_skin_tone,
)
from colorlab.harmony import hexstr, is_neutral, pick_harmony_base
from colorlab.image_io import load_image
from colorlab.palette import dominant_colors, srgb_to_lab
from colorlab.render import label_text_color

# --- Battery parameters (QA, issue #24) --------------------------------------

RAW_DIR = Path(__file__).resolve().parents[2] / "samples" / "g0" / "raw" / "test"
OUT_DIR = Path(__file__).resolve().parents[2] / "outputs" / "mass-battery"

# Fixed sampling seed: reproducible. N_MAX are sampled at once and smaller
# runs use the prefix, so N=100 is a strict subset of N=200.
SAMPLE_SEED = 42
N_MAX = 200

# FG_BROKEN (B4 proxy): GrabCut foreground outside this range.
FG_MIN_FRACTION = 0.05
FG_MAX_FRACTION = 0.95

# OVERFILTERED (B2 proxy): the skin filter removes more than this from the fg.
# (The filter's guardrail cuts at 0.5; 0.4 marks the real risk zone.)
OVERFILTERED_FRACTION = 0.40

# Maximum background pixel sample for the complexity metric.
BG_SAMPLE_MAX = 20_000

# Severity order to group the gallery (a photo can carry several flags; it is
# grouped by the first one in this order). CANVAS_MODE comes last: it is not a
# failure, just a category.
FLAG_ORDER = [
    "CRASH",
    "FG_BROKEN",
    "BASE_IS_SKIN",
    "COLLAPSED_PALETTE",
    "OVERFILTERED",
    "NEUTRAL_BASE",
]

# Real failure flags. NEUTRAL_BASE is deliberately NOT here: since canvas mode
# (D10) a neutral base is the correct handling of a neutral outfit, not a KO
# (#23 finding — the flag predated D10 and was inflating the apparent KO rate
# in reverse). See summarize().
KO_FLAGS = frozenset(
    {"CRASH", "FG_BROKEN", "BASE_IS_SKIN", "COLLAPSED_PALETTE", "OVERFILTERED"}
)


def summarize(results: list[dict]) -> dict:
    """Aggregate the automatic flags into KO / canvas-mode / clean.

    - KO: at least one KO_FLAGS flag (a real automatic failure proxy).
    - CANVAS: NEUTRAL_BASE and no KO flag (canvas mode D10 — a legitimate
      neutral-outfit outcome, flagged only for a human visual sanity check).
    - CLEAN: no flags at all.
    """
    ko = [r for r in results if KO_FLAGS.intersection(r["flags"])]
    canvas = [r for r in results if "NEUTRAL_BASE" in r["flags"] and r not in ko]
    clean = [r for r in results if not r["flags"]]
    return {
        "n": len(results),
        "ko": len(ko),
        "canvas": len(canvas),
        "clean": len(clean),
    }


def format_summary(results: list[dict]) -> str:
    s = summarize(results)
    n = s["n"] or 1
    return (
        f"KO (real failures): {s['ko']}/{s['n']} ({100 * s['ko'] / n:.1f}%)  ·  "
        f"canvas-mode (D10, ok): {s['canvas']} ({100 * s['canvas'] / n:.1f}%)  ·  "
        f"clean: {s['clean']} ({100 * s['clean'] / n:.1f}%)"
    )


def background_complexity(
    rgb: np.ndarray, fg_mask: np.ndarray, rng: random.Random
) -> float:
    """Total standard deviation in LAB of the background (~fg) pixels.

    sqrt(var(L) + var(a) + var(b)) over a subsample of up to BG_SAMPLE_MAX
    pixels. Plain backgrounds (studio, wall) yield low values; streets,
    graffiti, vegetation yield high ones.
    """
    bg = rgb[~fg_mask]
    if len(bg) < 100:  # no measurable background (fg ~100%)
        return float("nan")
    if len(bg) > BG_SAMPLE_MAX:
        idx = rng.sample(range(len(bg)), BG_SAMPLE_MAX)
        bg = bg[idx]
    lab = srgb_to_lab(bg.astype(float))
    return float(np.sqrt(lab.var(axis=0).sum()))


def evaluate_photo(path: Path, rng: random.Random) -> dict:
    """Runs the pipeline over one photo and returns metrics + flags."""
    res: dict = {"id": path.stem, "file": path.name, "flags": [], "error": None}
    t0 = time.perf_counter()
    try:
        img = load_image(path)
        rgb, fg = remove_background(img)
        res["fg_frac"] = float(fg.mean())

        # Replica of gather_pixels(drop_skin=True) so the removed skin
        # fraction can be measured without parsing logs.
        skin = adaptive_skin_mask(rgb, fg)
        fg_total = max(int(fg.sum()), 1)
        res["skin_frac"] = float((skin & fg).sum() / fg_total)
        pixels = rgb[fg & ~skin]
        if len(pixels) < MIN_PIXELS:
            pixels = rgb[fg]
        colors, weights = dominant_colors(pixels.astype(float))
        base = pick_harmony_base(colors, weights)
        res["time_s"] = time.perf_counter() - t0  # pure pipeline, no render

        res["palette"] = [
            {"hex": hexstr(tuple(int(x) for x in c)), "weight": float(w)}
            for c, w in zip(colors, weights, strict=True)
        ]
        res["base_hex"] = hexstr(base)
        res["colors"] = [[int(x) for x in c] for c in colors]
        res["weights"] = [float(w) for w in weights]

        # --- Automatic flags ---------------------------------------------
        if not (FG_MIN_FRACTION <= res["fg_frac"] <= FG_MAX_FRACTION):
            res["flags"].append("FG_BROKEN")
        if is_neutral(base):
            res["flags"].append("NEUTRAL_BASE")
        # BASE_IS_SKIN: the base sits at < SKIN_DELTA_E (dE with attenuated
        # L, same metric as filters.py) from the subject's sampled tone.
        tone = estimate_skin_tone(rgb, fg)
        if tone is not None:
            delta = srgb_to_lab(np.asarray(base, dtype=float)) - tone
            delta[0] *= SKIN_LIGHTNESS_WEIGHT
            res["de_base_skin"] = float(np.linalg.norm(delta))
            if res["de_base_skin"] < SKIN_DELTA_E:
                res["flags"].append("BASE_IS_SKIN")
        else:
            res["de_base_skin"] = None
        if len(colors) == 1:
            res["flags"].append("COLLAPSED_PALETTE")
        if res["skin_frac"] > OVERFILTERED_FRACTION:
            res["flags"].append("OVERFILTERED")

        res["bg_std"] = background_complexity(rgb, fg, rng)
        res["_rgb"] = rgb  # only for the panel; removed before the JSON dump
    except Exception:
        res["time_s"] = time.perf_counter() - t0
        res["flags"].insert(0, "CRASH")
        res["error"] = traceback.format_exc(limit=3)
    return res


def compact_panel(res: dict, out_path: Path) -> None:
    """QA panel: photo + palette (base highlighted) + flags. Compact on purpose."""
    fig = plt.figure(figsize=(7.2, 2.9))
    gs = fig.add_gridspec(1, 2, width_ratios=[1.0, 1.5], wspace=0.05)
    ax_img = fig.add_subplot(gs[0, 0])
    ax_img.axis("off")
    if "_rgb" in res:
        ax_img.imshow(res["_rgb"])
    else:
        ax_img.text(
            0.5, 0.5, "CRASH", ha="center", va="center", fontsize=20, color="red"
        )

    ax_pal = fig.add_subplot(gs[0, 1])
    ax_pal.set_xlim(0, 1)
    ax_pal.set_ylim(0, 1)
    ax_pal.axis("off")
    palette = res.get("palette", [])
    n = max(len(palette), 1)
    for i, entry in enumerate(palette):
        rgb = tuple(int(entry["hex"][j : j + 2], 16) for j in (1, 3, 5))
        is_base = entry["hex"] == res.get("base_hex")
        ax_pal.add_patch(
            Rectangle(
                (i / n, 0.35),
                1 / n,
                0.55,
                facecolor=np.array(rgb) / 255,
                edgecolor="red" if is_base else "0.7",
                linewidth=3 if is_base else 0.5,
            )
        )
        label = f"{entry['hex']}\n{entry['weight'] * 100:.0f}%" + (
            "\nBASE" if is_base else ""
        )
        ax_pal.text(
            (i + 0.5) / n,
            0.62,
            label,
            ha="center",
            va="center",
            fontsize=7,
            color=label_text_color(rgb),
        )
    flags = res["flags"]
    is_ko = bool(KO_FLAGS.intersection(flags))
    is_canvas = "NEUTRAL_BASE" in flags and not is_ko
    if is_ko:
        flags_line = "KO: " + ", ".join(flags)
        flags_color = "red"
    elif is_canvas:
        flags_line = "canvas mode (D10): " + ", ".join(flags)
        flags_color = "darkorange"
    else:
        flags_line = "no flags (clean)"
        flags_color = "green"
    detail = (
        f"fg={res.get('fg_frac', float('nan')) * 100:.0f}%  "
        f"skin_filtered={res.get('skin_frac', float('nan')) * 100:.0f}%  "
        f"bg_std={res.get('bg_std', float('nan')):.0f}  "
        f"t={res.get('time_s', float('nan')):.1f}s"
    )
    ax_pal.text(0.0, 0.16, flags_line, fontsize=9, color=flags_color)
    ax_pal.text(0.0, 0.02, detail, fontsize=7, color="0.3")
    fig.suptitle(res["id"], fontsize=9, y=0.98)
    fig.savefig(out_path, dpi=95, bbox_inches="tight")
    plt.close(fig)


def build_gallery(results: list[dict], bg_threshold: float, out_path: Path) -> None:
    """Local index.html: KOs grouped by main flag first, clean ones after."""

    def group(res: dict) -> str:
        for f in FLAG_ORDER:
            if f in res["flags"]:
                return f
        return "CLEAN"

    def segment(res: dict) -> str:
        bg = res.get("bg_std")
        if bg is None or (isinstance(bg, float) and np.isnan(bg)):
            return "no measurable background"
        return "busy" if bg > bg_threshold else "plain"

    groups: dict[str, list[dict]] = {f: [] for f in [*FLAG_ORDER, "CLEAN"]}
    for r in results:
        groups[group(r)].append(r)

    html = [
        "<!doctype html><meta charset='utf-8'><title>G0 mass battery — issue #24</title>",
        "<style>body{font-family:sans-serif;margin:20px;background:#fafafa}"
        "h2{border-bottom:2px solid #ccc;padding-bottom:4px}"
        ".card{display:inline-block;margin:6px;padding:6px;background:#fff;"
        "border:1px solid #ddd;border-radius:6px;vertical-align:top;width:560px}"
        ".card img{max-width:100%}.meta{font-size:11px;color:#555}"
        ".ko{border-left:5px solid #d33}.ok{border-left:5px solid #2a2}"
        ".canvas{border-left:5px solid #f39c12}</style>",
        f"<h1>G0 mass battery — {len(results)} photos (Fashionpedia val, seed {SAMPLE_SEED})</h1>",
        f"<p>Plain/busy background threshold: bg_std &gt; {bg_threshold:.0f} = busy. "
        "KO flags are automatic proxies (a lower bound of the real KO rate): validate visually. "
        "<b>NEUTRAL_BASE = canvas mode (D10), not a KO.</b></p>",
        f"<p><b>{format_summary(results)}</b></p>",
    ]
    for name in [*FLAG_ORDER, "CLEAN"]:
        batch = groups[name]
        if not batch:
            continue
        html.append(f"<h2>{name} · {len(batch)} photos</h2>")
        for r in sorted(batch, key=lambda x: x["id"]):
            if KO_FLAGS.intersection(r["flags"]):
                css = "ko"
            elif "NEUTRAL_BASE" in r["flags"]:
                css = "canvas"
            else:
                css = "ok"
            flags = ", ".join(r["flags"]) or "—"
            html.append(
                f"<div class='card {css}'><img src='{r['id']}_panel.png' loading='lazy'>"
                f"<div class='meta'>{r['id']} · flags: {flags} · background: {segment(r)} "
                f"(bg_std={r.get('bg_std', float('nan')):.0f}) · t={r.get('time_s', 0):.1f}s</div></div>"
            )
    out_path.write_text("\n".join(html), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--n", type=int, default=N_MAX, help=f"sample size (<= {N_MAX})"
    )
    parser.add_argument(
        "--limit", type=int, default=None, help="process only the first L (estimation)"
    )
    parser.add_argument(
        "--bg-threshold",
        type=float,
        default=None,
        help="plain/busy bg_std threshold for the gallery (default: median)",
    )
    parser.add_argument(
        "--gallery-only",
        action="store_true",
        help="no processing: rebuild index.html from results.json",
    )
    parser.add_argument(
        "--dir",
        type=Path,
        default=RAW_DIR,
        help="image folder to evaluate (default: the Fashionpedia "
        "battery; e.g. --dir samples/selfies for the CEO selfies)",
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.WARNING)  # silence the pipeline's INFO
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    json_path = OUT_DIR / "results.json"

    if args.gallery_only:
        results = json.loads(json_path.read_text())["results"]
    else:
        # Accept .jpg and .jpeg (the selfies are .jpeg); sample is reproducible.
        files = sorted(
            p for p in args.dir.iterdir() if p.suffix.lower() in (".jpg", ".jpeg")
        )
        if not files:
            raise SystemExit(f"No .jpg/.jpeg images in {args.dir}")
        sample = random.Random(SAMPLE_SEED).sample(files, min(N_MAX, len(files)))
        sample = sample[: args.n]
        if args.limit:
            sample = sample[: args.limit]
        print(
            f"Population: {len(files)} · sample: {len(sample)} (seed={SAMPLE_SEED})",
            flush=True,
        )

        rng_bg = random.Random(SAMPLE_SEED)  # background subsampling, also reproducible
        results = []
        t_batch = time.perf_counter()
        for i, path in enumerate(sample, 1):
            res = evaluate_photo(path, rng_bg)
            compact_panel(res, OUT_DIR / f"{res['id']}_panel.png")
            res.pop("_rgb", None)
            results.append(res)
            mark = ",".join(res["flags"]) or "ok"
            print(
                f"[{i}/{len(sample)}] {res['id']} {res['time_s']:.1f}s {mark}",
                flush=True,
            )
        print(f"Batch total: {time.perf_counter() - t_batch:.0f}s", flush=True)

        json_path.write_text(
            json.dumps(
                {"seed": SAMPLE_SEED, "n": len(results), "results": results}, indent=1
            ),
            encoding="utf-8",
        )

    bgs = [
        r["bg_std"]
        for r in results
        if r.get("bg_std") is not None
        and not (isinstance(r["bg_std"], float) and np.isnan(r["bg_std"]))
    ]
    threshold = (
        args.bg_threshold if args.bg_threshold is not None else float(np.median(bgs))
    )
    build_gallery(results, threshold, OUT_DIR / "index.html")
    print(f"Gallery: {OUT_DIR / 'index.html'} (bg_std threshold={threshold:.1f})")
    print(format_summary(results))


if __name__ == "__main__":
    main()
