"""Gate G2.5 per-garment segmentation eval battery (Phase 2.5, D21/D23). QA tool.

Scores the MediaPipe per-garment path against the D23 eval dataset and the
PRD gate G2.5: "correct per-garment colors on >= 80% of the evaluation set"
PLUS the PRD SS9 skin-tone bias test (a gate that passes overall but fails a
skin-tone bucket is a FAIL).

The harness does not run TFLite itself. It consumes class-mask PNGs in the
SHARED CONTRACT of :mod:`colorlab.segmentation` (grayscale mode-'L' 8-bit
PNG, pixel value = raw class index 0 bg / 1 hair / 2 body-skin / 3 face-skin
/ 4 clothes / 5 others; ``load_class_mask`` validates it loudly). Per photo
``photos/<stem>.<ext>`` the mask lives at ``masks/<stem>.mask.png``. Two
producers exist:

- ``cv_core/tools/generate_masks.py`` (canonical Python parity layer via
  ai-edge-litert, byte-compatible with the on-device path) -- the bulk path;
- the on-device/emulator harness (spike 2026-07-14: emulator masks are
  numerically identical to the Galaxy M33's) -- the parity spot-check.

The upper/lower split, erosion hygiene and min-region guards come UNMODIFIED
from :func:`colorlab.segmentation.split_garment_masks` (the Dart-parity
canonical layer), so the scored colors are exactly what the engine will
deliver. Per-region colors: region pixels -> colorlab ``dominant_colors`` ->
``pick_harmony_base_index`` (same wiring as the per-garment prototype,
docs/qa/photo-eval/2026-07-10_1800_F2.5_*).

Outputs (per-dataset dir under outputs/segmentation-battery/):
- ``results.json``    -- machine-readable per-photo results
- ``<id>_panel.png``  -- photo + class overlay + upper/lower palettes + expected words
- ``index.html``      -- local gallery
- ``review.md``       -- THE GATE ARTIFACT: two verdict columns the CEO fills
                         ("top color OK?" / "bottom color OK?", ``n/a`` allowed
                         for a garment legitimately out of frame)

Usage (from the repo root):
    python cv_core/tools/segmentation_battery.py --dir samples/segmentation/photos --masks samples/segmentation/masks
    # ... CEO annotates outputs/segmentation-battery/segmentation/review.md ...
    python cv_core/tools/segmentation_battery.py --score          # gate + bias table
    python cv_core/tools/segmentation_battery.py --coverage       # dataset planning aid

Dataset spec + annotation guide:
docs/qa/photo-eval/2026-07-14_2330_F2.5_D23-eval-dataset-spec.md
The latency leg of gate G2.5 is NOT measured here (evidence = the on-device
spike's Galaxy M33 numbers).
"""

from __future__ import annotations

import argparse
import csv
import datetime as _dt
import json
import logging
import time
import traceback
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Rectangle
from PIL import Image

from colorlab.display import snap_neutral_for_display
from colorlab.harmony import hexstr
from colorlab.image_io import load_image
from colorlab.palette import dominant_colors
from colorlab.render import label_text_color
from colorlab.segmentation import (
    CLASS_BODY_SKIN,
    CLASS_CLOTHES,
    CLASS_FACE_SKIN,
    REGION_LOWER,
    REGION_UPPER,
    NoPersonError,
    load_class_mask,
    split_garment_masks,
)

REPO = Path(__file__).resolve().parents[2]

# --- Gate G2.5 parameters (PRD SS7 gate + SS9 bias risk; dataset spec D23) ----

# PRD gate G2.5: correct per-garment colors on >= 80% of the evaluation set.
GATE_G25_MIN = 0.80

# Skin-tone bias test (PRD SS9, precedent bug B1): the same >= 80% bar applies
# to EVERY skin-tone bucket independently. A bucket with fewer than
# MIN_BUCKET_N annotated photos leaves the bias test underpowered: the gate
# verdict is then capped at UNDECIDED (never PASS).
SKIN_BUCKETS = ("light", "medium", "dark")
MIN_BUCKET_N = 10
UNKNOWN_BUCKET = "unknown"

# --- Split / mask parameters --------------------------------------------------
# The Dart-parity split constants and hygiene guards (MIN_CLOTHES_COVERAGE,
# MASK_ERODE_PX, MIN_REGION_FRACTION) live in colorlab.segmentation -- the
# canonical layer this harness consumes via split_garment_masks. Only
# harness-local perf knobs are defined here:

MAX_REGION_SAMPLE = 40_000  # deterministic subsample cap for K-means speed
_SAMPLE_SEED = 42

DEFAULT_PHOTOS_DIR = REPO / "samples" / "segmentation" / "photos"
DEFAULT_MASKS_DIR = REPO / "samples" / "segmentation" / "masks"
DEFAULT_MANIFEST = REPO / "samples" / "segmentation" / "MANIFEST.csv"
OUT_ROOT = REPO / "outputs" / "segmentation-battery"

ACCEPTED_SUFFIXES = (".jpg", ".jpeg", ".png", ".webp")
# Mask filename contract shared with cv_core/tools/generate_masks.py.
MASK_SUFFIX = ".mask.png"


def dataset_label(photos_dir: Path) -> str:
    """Output-dir key for a dataset. D23 datasets are laid out as
    <name>/photos + <name>/masks, so a dir literally named 'photos' is keyed
    by its parent — otherwise a smoke set would clobber the real gate run
    under outputs/segmentation-battery/photos/."""
    if photos_dir.name.lower() == "photos" and photos_dir.parent.name:
        return photos_dir.parent.name
    return photos_dir.name


# Class overlay tints (same colors as the on-device spike overlay, so panels
# and adb-pulled overlays read the same): upper green / lower blue.
CLASS_TINTS = {
    0: (32, 32, 32),  # background: dim
    1: (255, 233, 74),  # hair: yellow
    2: (229, 57, 53),  # body-skin: red
    3: (255, 138, 48),  # face-skin: orange
    5: (224, 64, 251),  # others: magenta
}
UPPER_TINT = (46, 204, 113)  # green
LOWER_TINT = (52, 152, 219)  # blue

# Hand-review verdict tokens (the CEO may annotate in Spanish or English).
YES_TOKENS = frozenset({"yes", "y", "si", "sí", "ok", "pass", "pasa"})
NO_TOKENS = frozenset({"no", "ko", "fail", "x"})
NA_TOKENS = frozenset({"n/a", "na", "n.a.", "no aplica"})
PENDING = "pending"

# Column headers of the review table (parsing anchors -- keep in sync with
# build_review_md / parse_review_md).
COL_TOP_OK = "top color OK?"
COL_BOTTOM_OK = "bottom color OK?"
COL_SKIN = "skin"

# Diversity-matrix quotas for --coverage (dataset spec SS2; planning aid only,
# NOT part of the gate arithmetic).
MATRIX_QUOTAS = {
    "skin": {"light": 10, "medium": 10, "dark": 10},
    "garments": {"top_bottom": 15, "mono": 6, "dress": 6, "coat": 3, "accent": 3},
    "background": {"plain": 20, "busy": 10, "mirror": 6},
    "lighting": {"good": 24, "backlight": 5, "dim": 5},
    "framing": {"mirror_selfie": 20, "other_full": 8, "waist_up": 5},
}


# --- Verdict parsing / row status (pure functions, unit-tested) ---------------


def parse_verdict(cell: str) -> str:
    """Normalizes a hand-review cell to 'yes' / 'no' / 'na' / 'pending'.

    Lenient on purpose (hand annotation, Spanish or English, stray markdown).
    Anything unrecognized stays 'pending' so an ambiguous cell can never
    silently count toward the gate.
    """
    token = cell.strip().strip("*_`").strip().lower()
    if token in YES_TOKENS:
        return "yes"
    if token in NO_TOKENS:
        return "no"
    if token in NA_TOKENS:
        return "na"
    return PENDING


def row_status(top_ok: str, bottom_ok: str) -> str:
    """Gate status of one photo from its two parsed verdicts.

    - 'fail' as soon as EITHER applicable column is 'no'.
    - 'excluded' when BOTH columns are 'na' (no judgeable garment: such a
      photo does not belong in the eval set -- surfaced loudly by the scorer).
    - 'pass' when every non-'na' column is 'yes' (and at least one applies).
    - 'pending' otherwise (any unreviewed applicable cell).
    """
    statuses = (top_ok, bottom_ok)
    if "no" in statuses:
        return "fail"
    applicable = [s for s in statuses if s != "na"]
    if not applicable:
        return "excluded"
    if all(s == "yes" for s in applicable):
        return "pass"
    return PENDING


def _bracket(passed: int, failed: int, pending: int, threshold: float) -> dict:
    """Worst/best pass-rate bracket + verdict for one population."""
    n = passed + failed + pending
    if n == 0:
        return {
            "n": 0,
            "passed": 0,
            "failed": 0,
            "pending": 0,
            "rate_worst": 0.0,
            "rate_best": 0.0,
            "verdict": "NO DATA",
        }
    eps = 1e-9  # float noise at the exact threshold (8/10 vs 0.80)
    rate_worst = passed / n
    rate_best = (passed + pending) / n
    if rate_worst >= threshold - eps:
        verdict = "PASS"
    elif rate_best < threshold - eps:
        verdict = "FAIL"
    elif pending:
        verdict = "UNDECIDED"
    else:
        verdict = "FAIL"
    return {
        "n": n,
        "passed": passed,
        "failed": failed,
        "pending": pending,
        "rate_worst": rate_worst,
        "rate_best": rate_best,
        "verdict": verdict,
    }


def gate_metric(
    rows: list[tuple[str, str, str]],
    threshold: float = GATE_G25_MIN,
    min_bucket_n: int = MIN_BUCKET_N,
) -> dict:
    """Gate G2.5 metric over (skin_bucket, top_ok, bottom_ok) parsed rows.

    Returns the overall bracket, the per-skin-bucket brackets (the SS9 bias
    table) and the combined verdict:

    - FAIL     -- overall decidably fails, OR any canonical bucket decidably
                  fails (bias rule: overall-pass + bucket-fail = FAIL).
    - PASS     -- overall passes AND all three canonical buckets pass, each
                  with n >= min_bucket_n, AND no row has an unknown bucket.
    - UNDECIDED otherwise (pending swings, an underpowered bucket, or
                  unbucketed rows -- none of these may silently become PASS).
    - NO DATA  -- empty set.

    Both-'na' rows are excluded from every denominator and reported in
    ``excluded`` (a fully-n/a photo does not belong in the eval set).
    """
    counted = [(b, row_status(t, bo)) for b, t, bo in rows]
    excluded = sum(1 for _, s in counted if s == "excluded")
    counted = [(b, s) for b, s in counted if s != "excluded"]

    def counts(statuses: list[str]) -> tuple[int, int, int]:
        return (statuses.count("pass"), statuses.count("fail"), statuses.count(PENDING))

    overall = _bracket(*counts([s for _, s in counted]), threshold)
    overall["excluded"] = excluded

    buckets: dict[str, dict] = {}
    seen = list(SKIN_BUCKETS) + sorted(
        {b for b, _ in counted} - set(SKIN_BUCKETS) - {UNKNOWN_BUCKET}
    )
    unknown_n = sum(1 for b, _ in counted if b == UNKNOWN_BUCKET)
    if unknown_n:
        seen.append(UNKNOWN_BUCKET)
    for bucket in seen:
        br = _bracket(*counts([s for b, s in counted if b == bucket]), threshold)
        if bucket in SKIN_BUCKETS and br["n"] < min_bucket_n:
            br["verdict"] = "INSUFFICIENT"
        buckets[bucket] = br

    canonical = [buckets[b] for b in SKIN_BUCKETS]
    if overall["verdict"] == "NO DATA":
        verdict = "NO DATA"
    elif overall["verdict"] == "FAIL" or any(b["verdict"] == "FAIL" for b in canonical):
        verdict = "FAIL"
    elif (
        overall["verdict"] == "PASS"
        and all(b["verdict"] == "PASS" for b in canonical)
        and unknown_n == 0
    ):
        verdict = "PASS"
    else:
        verdict = "UNDECIDED"

    return {
        "threshold": threshold,
        "min_bucket_n": min_bucket_n,
        "overall": overall,
        "buckets": buckets,
        "unknown_bucket_rows": unknown_n,
        "verdict": verdict,
    }


def format_gate_summary(metric: dict) -> str:
    """Human summary of gate_metric(): overall + the bias table + verdict."""
    ov = metric["overall"]
    if ov["n"] == 0 and not ov.get("excluded"):
        return "Gate G2.5: NO DATA (no rows found in the review table)."
    lines = [
        f"Gate G2.5 (threshold >= {metric['threshold']:.0%}, per-garment colors):",
        f"  overall: {ov['passed']}/{ov['n']} pass ({ov['rate_worst']:.1%})"
        + (
            f", {ov['pending']} pending (best case {ov['rate_best']:.1%})"
            if ov["pending"]
            else ""
        )
        + f" -> {ov['verdict']}",
        "",
        f"Skin-tone bias table (PRD SS9; every bucket must reach the same "
        f">= {metric['threshold']:.0%} bar, n >= {metric['min_bucket_n']}):",
    ]
    for name, br in metric["buckets"].items():
        detail = (
            f"{br['passed']}/{br['n']} pass ({br['rate_worst']:.1%})"
            if br["n"]
            else "0 photos"
        )
        if br["pending"]:
            detail += f", {br['pending']} pending"
        lines.append(f"  {name:>8}: {detail} -> {br['verdict']}")
    if metric["unknown_bucket_rows"]:
        lines.append(
            f"  WARNING: {metric['unknown_bucket_rows']} row(s) without a skin "
            "bucket (missing MANIFEST.csv entry) -- the bias table is "
            "incomplete, PASS is blocked until they are bucketed."
        )
    if ov.get("excluded"):
        lines.append(
            f"  WARNING: {ov['excluded']} row(s) fully n/a were EXCLUDED -- if "
            "a garment was actually visible, that is a mis-annotation."
        )
    lines += [
        "",
        f"VERDICT: {metric['verdict']}"
        + (
            " -- annotate pending rows / complete the dataset to decide"
            if metric["verdict"] == "UNDECIDED"
            else ""
        ),
        "Latency leg: NOT measured here -- evidence lives in the on-device "
        "spike (Galaxy M33, docs/architecture/2026-07-14_2235_F2.5_"
        "mediapipe-ondevice-spike.md ADDENDUM); re-confirm on the M33 with "
        "the final wired engine before signing the gate.",
    ]
    return "\n".join(lines)


# --- Per-region palette (masks come from colorlab.segmentation) ---------------


def region_palette(rgb: np.ndarray, mask: np.ndarray | None) -> dict | None:
    """colorlab palette + harmony base for one garment region.

    Returns None for an absent/empty region (split_garment_masks already
    applies the canonical erosion + min-region guards, so an absent region
    means "no usable garment there"). Pixels are subsampled deterministically
    above MAX_REGION_SAMPLE.
    """
    if mask is None:
        return None
    pixels = rgb[mask].astype(float)
    if len(pixels) == 0:
        return None
    if len(pixels) > MAX_REGION_SAMPLE:
        rng = np.random.default_rng(_SAMPLE_SEED)
        pixels = pixels[rng.choice(len(pixels), MAX_REGION_SAMPLE, replace=False)]
    colors, weights = dominant_colors(pixels)
    # Per-garment DISPLAY base = the garment's OWN dominant colour (max weight),
    # mirroring the engine's person-path fix (analyze_garments, bug B-G25-1,
    # 2026-07-18): the block labels "your top is X" with the dominant garment
    # colour, not the most-chromatic swatch that a cross-garment/skin contaminant
    # could hijack. The gate judges the DISPLAYED colour, so we always highlight
    # the dominant here (the engine additionally emits base_index=-1 for an
    # all-neutral garment as a harmony/canvas flag — not a display concern).
    base_i = int(np.argmax(weights))
    entries = []
    for i, (c, w) in enumerate(zip(colors, weights, strict=True)):
        rgb_t = tuple(int(x) for x in c)
        entries.append(
            {
                "hex": hexstr(rgb_t),
                "display_hex": hexstr(snap_neutral_for_display(rgb_t)),
                "weight": float(w),
                "is_base": i == base_i,
            }
        )
    return {
        "palette": entries,
        "base_hex": entries[base_i]["hex"],
        "display_base_hex": entries[base_i]["display_hex"],
        "px": int(mask.sum()),
    }


# --- Manifest -------------------------------------------------------------------


def load_manifest(path: Path) -> dict[str, dict]:
    """MANIFEST.csv -> {file: row dict}. Missing file -> empty (rows then get
    an 'unknown' skin bucket, which blocks a gate PASS by design)."""
    if not path.exists():
        return {}
    with path.open(encoding="utf-8-sig", newline="") as fh:
        return {
            row["file"].strip(): row
            for row in csv.DictReader(fh)
            if row.get("file", "").strip()
        }


def skin_bucket(manifest_row: dict | None) -> str:
    bucket = (manifest_row or {}).get("skin", "").strip().lower()
    return bucket if bucket in SKIN_BUCKETS else UNKNOWN_BUCKET


# --- Battery run ------------------------------------------------------------------


def evaluate_photo(
    photo_path: Path, classmap_path: Path | None, manifest_row: dict | None
) -> dict:
    """One photo + its contract class mask -> per-region palettes + hints."""
    res: dict = {
        "id": photo_path.stem,
        "file": photo_path.name,
        "skin": skin_bucket(manifest_row),
        "expected_top": (manifest_row or {}).get("expected_top", ""),
        "expected_bottom": (manifest_row or {}).get("expected_bottom", ""),
        "hints": [],
        "upper": None,
        "lower": None,
        "error": None,
    }
    t0 = time.perf_counter()
    try:
        if res["skin"] == UNKNOWN_BUCKET:
            res["hints"].append("NO_BUCKET")
        if classmap_path is None or not classmap_path.exists():
            res["hints"].append("MISSING_MASK")
            return res
        classmap = load_class_mask(str(classmap_path))
        h, w = classmap.shape

        rgb = np.asarray(load_image(photo_path))
        if rgb.shape[:2] != (h, w):
            # Align the photo to the frame the model actually classified
            # (on-device masks come at the decode-capped size).
            rgb = np.asarray(Image.fromarray(rgb).resize((w, h), Image.BILINEAR))
        res["coverage"] = {
            "clothes": float((classmap == CLASS_CLOTHES).mean()),
            "background": float((classmap == 0).mean()),
            "skin": float(np.isin(classmap, (CLASS_BODY_SKIN, CLASS_FACE_SKIN)).mean()),
        }

        try:
            # Canonical Dart-parity split + erosion + min-region guards.
            garment_masks = split_garment_masks(classmap)
        except NoPersonError:
            res["hints"].append("NO_PERSON")
            return res

        upper_mask = garment_masks.get(REGION_UPPER)
        lower_mask = garment_masks.get(REGION_LOWER)
        for name, mask in (("upper", upper_mask), ("lower", lower_mask)):
            region = region_palette(rgb, mask)
            res[name] = region
            if region is None:
                res["hints"].append(f"EMPTY_{name.upper()}")
        res["_masks"] = (upper_mask, lower_mask, classmap)  # for the panel only
    except Exception:
        res["hints"].insert(0, "CRASH")
        res["error"] = traceback.format_exc(limit=3)
    finally:
        res["time_s"] = time.perf_counter() - t0
    return res


def _overlay_rgb(
    rgb: np.ndarray,
    classmap: np.ndarray,
    upper: np.ndarray | None,
    lower: np.ndarray | None,
) -> np.ndarray:
    """50/50 tint blend, same palette as the on-device spike overlay."""
    tint = np.zeros_like(rgb)
    for cls, color in CLASS_TINTS.items():
        tint[classmap == cls] = color
    if upper is not None:
        tint[upper] = UPPER_TINT
    if lower is not None:
        tint[lower] = LOWER_TINT
    return ((rgb.astype(np.uint16) + tint.astype(np.uint16)) // 2).astype(np.uint8)


def _draw_region_palette(ax, title: str, region: dict | None, expected: str) -> None:
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")
    ax.text(0.0, 0.97, title, fontsize=9, fontweight="bold", va="top")
    ax.text(
        0.0,
        0.88,
        f"expected: {expected or '(not pre-registered)'}",
        fontsize=7,
        color="0.35",
        va="top",
    )
    if region is None:
        ax.text(0.5, 0.45, "EMPTY", ha="center", va="center", fontsize=14, color="red")
        return
    palette = region["palette"]
    n = max(len(palette), 1)
    for i, entry in enumerate(palette):
        shown = entry["display_hex"]
        rgb = tuple(int(shown[j : j + 2], 16) for j in (1, 3, 5))
        ax.add_patch(
            Rectangle(
                (i / n, 0.25),
                1 / n,
                0.5,
                facecolor=np.array(rgb) / 255,
                edgecolor="red" if entry["is_base"] else "0.7",
                linewidth=3 if entry["is_base"] else 0.5,
            )
        )
        marks = ("\nBASE" if entry["is_base"] else "") + (
            f"\n(snap {entry['hex']})" if shown != entry["hex"] else ""
        )
        ax.text(
            (i + 0.5) / n,
            0.5,
            f"{shown}\n{entry['weight'] * 100:.0f}%{marks}",
            ha="center",
            va="center",
            fontsize=6.5,
            color=label_text_color(rgb),
        )
    ax.text(0.0, 0.12, f"{region['px']} px", fontsize=7, color="0.4")


def panel(res: dict, photo_path: Path, out_path: Path) -> None:
    """QA panel: photo | class overlay | upper palette | lower palette."""
    fig = plt.figure(figsize=(11.5, 3.1))
    gs = fig.add_gridspec(1, 4, width_ratios=[1.0, 1.0, 1.2, 1.2], wspace=0.06)
    ax_img = fig.add_subplot(gs[0, 0])
    ax_ovl = fig.add_subplot(gs[0, 1])
    for ax in (ax_img, ax_ovl):
        ax.axis("off")

    masks = res.pop("_masks", None)
    if "CRASH" in res["hints"]:
        ax_img.text(
            0.5, 0.5, "CRASH", ha="center", va="center", fontsize=20, color="red"
        )
    else:
        rgb = np.asarray(load_image(photo_path))
        if masks is not None and rgb.shape[:2] != masks[2].shape:
            rgb = np.asarray(
                Image.fromarray(rgb).resize(
                    (masks[2].shape[1], masks[2].shape[0]), Image.BILINEAR
                )
            )
        ax_img.imshow(rgb)
        if masks is not None:
            upper, lower, classmap = masks
            ax_ovl.imshow(_overlay_rgb(rgb, classmap, upper, lower))
        else:
            ax_ovl.text(
                0.5, 0.5, "NO MASK", ha="center", va="center", fontsize=14, color="red"
            )

    _draw_region_palette(
        fig.add_subplot(gs[0, 2]),
        "UPPER (top garment)",
        res.get("upper"),
        res.get("expected_top", ""),
    )
    _draw_region_palette(
        fig.add_subplot(gs[0, 3]),
        "LOWER (bottom garment)",
        res.get("lower"),
        res.get("expected_bottom", ""),
    )

    hints = ", ".join(res["hints"]) or "no hints"
    color = (
        "red"
        if any(h in ("CRASH", "NO_PERSON", "MISSING_MASK") for h in res["hints"])
        else "0.25"
    )
    fig.suptitle(
        f"{res['id']} · skin={res['skin']} · {hints}", fontsize=9, y=0.99, color=color
    )
    fig.savefig(out_path, dpi=95, bbox_inches="tight")
    plt.close(fig)


def build_gallery(results: list[dict], dataset: str, out_path: Path) -> None:
    """Local index.html gallery (problem rows first, then alphabetical)."""
    bad = ("CRASH", "NO_PERSON", "MISSING_MASK")
    html = [
        "<!doctype html><meta charset='utf-8'>",
        f"<title>Gate G2.5 segmentation battery — {dataset}</title>",
        "<style>body{font-family:sans-serif;margin:20px;background:#fafafa}"
        ".card{display:inline-block;margin:6px;padding:6px;background:#fff;"
        "border:1px solid #ddd;border-radius:6px;vertical-align:top;width:860px}"
        ".card img{max-width:100%}.meta{font-size:11px;color:#555}"
        ".bad{border-left:5px solid #d33}.ok{border-left:5px solid #888}</style>",
        f"<h1>Gate G2.5 segmentation battery — {dataset} · {len(results)} photos</h1>",
        f"<p>Per-garment colors (D21 upper/lower split). Gate G2.5: &ge; "
        f"{GATE_G25_MIN:.0%} overall AND per skin bucket — <b>verdicts live in "
        "review.md</b>; hints here are informational.</p>",
    ]
    ordered = sorted(
        results, key=lambda r: (not any(h in bad for h in r["hints"]), r["id"])
    )
    for r in ordered:
        css = "bad" if any(h in bad for h in r["hints"]) else "ok"
        hints = ", ".join(r["hints"]) or "—"
        html.append(
            f"<div class='card {css}'><img src='{r['id']}_panel.png' loading='lazy'>"
            f"<div class='meta'>{r['id']} · skin={r['skin']} · hints: {hints}</div></div>"
        )
    out_path.write_text("\n".join(html), encoding="utf-8")


def _region_cell(region: dict | None) -> str:
    if region is None:
        return "EMPTY"
    parts = []
    for entry in region["palette"]:
        shown = (
            f"`{entry['display_hex']}` (snap de `{entry['hex']}`)"
            if entry["display_hex"] != entry["hex"]
            else f"`{entry['hex']}`"
        )
        parts.append(
            f"{shown} {entry['weight'] * 100:.0f}%"
            + (" **BASE**" if entry["is_base"] else "")
        )
    return " · ".join(parts)


def build_review_md(results: list[dict], dataset_dir: Path) -> str:
    """The annotatable gate artifact: header + one table row per photo."""
    today = _dt.date.today().isoformat()
    lines = [
        f"# Gate G2.5 segmentation review — `{dataset_dir.as_posix()}`",
        "",
        f"**Generated:** {today} by `cv_core/tools/segmentation_battery.py` · "
        f"**Photos:** {len(results)} · **Mode:** per-garment "
        "(colorlab.segmentation split_garment_masks, D21 upper/lower)",
        "",
        f"**Gate G2.5: >= {GATE_G25_MIN:.0%}** of rows must pass, **overall AND "
        f"inside every skin bucket** (bias test, PRD SS9; n >= {MIN_BUCKET_N} per "
        "bucket). A bucket failing fails the gate even if the overall rate passes.",
        "",
        "How to annotate (CEO): fill the two verdict columns with `yes` / `no` /",
        "`n/a` (`si`/`ok`/`ko` also accepted; anything else stays pending).",
        "",
        f"- **{COL_TOP_OK}** — the UPPER region's highlighted BASE swatch honestly",
        "  reads as the color you pre-registered for the top garment (column",
        "  *expected*). For a dress: judge BOTH columns against the dress color.",
        f"- **{COL_BOTTOM_OK}** — same for the LOWER region / bottom garment.",
        "- `n/a` ONLY when that garment is legitimately out of frame (waist-up",
        "  shot). A region shown as EMPTY while the garment IS visible = `no`.",
        "- `NO_PERSON` / CRASH rows are pre-filled `no`/`no` (auto-fail: every",
        "  eval photo contains a dressed person).",
        "- `MISSING_MASK` rows stay pending: generate the class mask first",
        "  (`python cv_core/tools/generate_masks.py`; dataset spec SS6.3).",
        "",
        "Swatches shown as `#000000`/`#FFFFFF` with `(snap de ...)` are the #85",
        "display snap (D31-A): judge the snapped color — it is what the app shows.",
        "",
        "Then compute the gate: `python cv_core/tools/segmentation_battery.py --score "
        f"{(OUT_ROOT / dataset_label(dataset_dir) / 'review.md').relative_to(REPO).as_posix()}`",
        "",
        f"| # | photo | {COL_SKIN} | expected (pre-registered) | upper | lower "
        f"| hints | {COL_TOP_OK} | {COL_BOTTOM_OK} | notes |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for i, r in enumerate(sorted(results, key=lambda x: x["id"]), 1):
        auto_fail = any(h in ("CRASH", "NO_PERSON") for h in r["hints"])
        verdict = "no" if auto_fail else PENDING
        note = (
            "CRASH (auto-fail)"
            if "CRASH" in r["hints"]
            else "NO_PERSON (auto-fail)"
            if "NO_PERSON" in r["hints"]
            else "mask missing"
            if "MISSING_MASK" in r["hints"]
            else ""
        )
        expected = (
            " / ".join(x for x in (r["expected_top"], r["expected_bottom"]) if x) or "—"
        )
        hints = ", ".join(r["hints"]) or "—"
        lines.append(
            f"| {i} | {r['file']} | {r['skin']} | {expected} "
            f"| {_region_cell(r.get('upper'))} | {_region_cell(r.get('lower'))} "
            f"| {hints} | {verdict} | {verdict} | {note} |"
        )
    lines.append("")
    return "\n".join(lines)


def parse_review_md(text: str) -> list[dict]:
    """Annotated review.md -> rows with parsed verdicts + skin bucket.

    Anchors on the header row containing the verdict columns, so extra
    columns or reordering fail loudly instead of misreading.
    """
    rows: list[dict] = []
    header_cols: list[str] | None = None
    for line in text.splitlines():
        if not line.strip().startswith("|"):
            continue
        cols = [c.strip() for c in line.strip().strip("|").split("|")]
        if header_cols is None:
            if COL_TOP_OK in cols and COL_BOTTOM_OK in cols:
                header_cols = cols
            continue
        if set(line) <= {"|", "-", " ", ":"}:  # separator row
            continue
        if len(cols) != len(header_cols):
            continue
        row = dict(zip(header_cols, cols, strict=True))
        bucket = row.get(COL_SKIN, "").strip().lower()
        rows.append(
            {
                "photo": row.get("photo", ""),
                "skin": bucket if bucket in SKIN_BUCKETS else UNKNOWN_BUCKET,
                "top_ok": parse_verdict(row[COL_TOP_OK]),
                "bottom_ok": parse_verdict(row[COL_BOTTOM_OK]),
            }
        )
    if header_cols is None:
        raise ValueError(
            f"review table not found: no header row with {COL_TOP_OK!r} and "
            f"{COL_BOTTOM_OK!r} columns"
        )
    return rows


def score(review_path: Path) -> dict:
    rows = parse_review_md(review_path.read_text(encoding="utf-8"))
    return gate_metric([(r["skin"], r["top_ok"], r["bottom_ok"]) for r in rows])


def _review_has_verdicts(path: Path) -> bool:
    """True if an existing review.md already carries hand-entered verdicts."""
    try:
        rows = parse_review_md(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    return any(r["top_ok"] != PENDING or r["bottom_ok"] != PENDING for r in rows)


def coverage_report(manifest_path: Path) -> str:
    """Dataset planning aid: manifest counts vs the SS2 diversity quotas."""
    manifest = load_manifest(manifest_path)
    lines = [f"D23 dataset coverage — {manifest_path} ({len(manifest)} photos)"]
    if not manifest:
        lines.append("  (manifest missing or empty — nothing sourced yet)")
    for axis, quotas in MATRIX_QUOTAS.items():
        lines.append(f"{axis}:")
        for value, need in quotas.items():
            have = sum(
                1
                for row in manifest.values()
                if row.get(axis, "").strip().lower() == value
            )
            flag = "OK " if have >= need else "SHORT"
            lines.append(f"  {flag} {value:<14} {have}/{need}")
    lines.append(f"total: {len(manifest)} (target 36–48, hard floor 30)")
    return "\n".join(lines)


def run_battery(
    photos_dir: Path,
    masks_dir: Path,
    manifest_path: Path,
    out_dir: Path,
    limit: int | None,
    force: bool,
) -> None:
    files = sorted(
        p for p in photos_dir.iterdir() if p.suffix.lower() in ACCEPTED_SUFFIXES
    )
    if not files:
        raise SystemExit(f"No {'/'.join(ACCEPTED_SUFFIXES)} images in {photos_dir}")
    if limit:
        files = files[:limit]

    review_path = out_dir / "review.md"
    if review_path.exists() and _review_has_verdicts(review_path) and not force:
        raise SystemExit(
            f"{review_path} already carries hand verdicts — refusing to overwrite "
            "the CEO's review. Re-run with --force to discard it."
        )

    manifest = load_manifest(manifest_path)
    if not manifest:
        print(
            f"WARNING: no manifest at {manifest_path} — every row will be "
            "bucket 'unknown' and the gate cannot PASS.",
            flush=True,
        )

    out_dir.mkdir(parents=True, exist_ok=True)
    print(
        f"Photos: {photos_dir} · masks: {masks_dir} · {len(files)} photos", flush=True
    )
    results = []
    t_batch = time.perf_counter()
    for i, path in enumerate(files, 1):
        classmap_path = masks_dir / f"{path.stem}{MASK_SUFFIX}"
        res = evaluate_photo(
            path, classmap_path if masks_dir else None, manifest.get(path.name)
        )
        panel(res, path, out_dir / f"{res['id']}_panel.png")
        results.append(res)
        print(
            f"[{i}/{len(files)}] {res['id']} {res['time_s']:.1f}s "
            f"{','.join(res['hints']) or 'clean'}",
            flush=True,
        )
    print(f"Batch total: {time.perf_counter() - t_batch:.0f}s", flush=True)

    (out_dir / "results.json").write_text(
        json.dumps(
            {
                "photos_dir": str(photos_dir),
                "masks_dir": str(masks_dir),
                "n": len(results),
                "gate_g25_min": GATE_G25_MIN,
                "min_bucket_n": MIN_BUCKET_N,
                "results": results,
            },
            indent=1,
        ),
        encoding="utf-8",
    )
    build_gallery(results, dataset_label(photos_dir), out_dir / "index.html")
    review_path.write_text(build_review_md(results, photos_dir), encoding="utf-8")

    missing = sum(1 for r in results if "MISSING_MASK" in r["hints"])
    no_person = sum(1 for r in results if "NO_PERSON" in r["hints"])
    unbucketed = sum(1 for r in results if r["skin"] == UNKNOWN_BUCKET)
    print(
        f"\nAuto summary: {len(results)} photos · {missing} missing mask · "
        f"{no_person} NO_PERSON (auto-fail) · {unbucketed} without skin bucket"
    )
    print(f"Gallery:  {out_dir / 'index.html'}")
    print(f"Review:   {review_path}")
    print("\nNEXT: the CEO annotates the verdict columns in review.md, then run:")
    print(
        f"  python cv_core/tools/segmentation_battery.py --score "
        f"{review_path.relative_to(REPO).as_posix()}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dir",
        type=Path,
        default=DEFAULT_PHOTOS_DIR,
        help="photo folder (default: samples/segmentation/photos)",
    )
    parser.add_argument(
        "--masks",
        type=Path,
        default=DEFAULT_MASKS_DIR,
        help="folder with <stem>.mask.png contract files "
        "(from cv_core/tools/generate_masks.py or the "
        "on-device path; default: samples/segmentation/masks)",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="MANIFEST.csv with skin buckets + pre-registered expected colors",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="process only the first L photos (smoke runs)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="overwrite a review.md that already carries verdicts",
    )
    parser.add_argument(
        "--score",
        nargs="?",
        type=Path,
        const=None,
        default=False,
        metavar="REVIEW_MD",
        help="no processing: parse an annotated review.md and print "
        "the Gate G2.5 verdict + skin-bias table (default: "
        "outputs/segmentation-battery/segmentation/review.md)",
    )
    parser.add_argument(
        "--coverage",
        action="store_true",
        help="dataset planning aid: manifest counts vs the "
        "diversity-matrix quotas (no photos needed)",
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.WARNING)

    manifest_path = (
        args.manifest if args.manifest.is_absolute() else (REPO / args.manifest)
    )
    if args.coverage:
        print(coverage_report(manifest_path))
        return
    if args.score is not False:  # --score given (with or without a path)
        review = args.score or (
            OUT_ROOT / dataset_label(DEFAULT_PHOTOS_DIR) / "review.md"
        )
        if not review.exists():
            raise SystemExit(f"Review not found: {review} — run the battery first.")
        print(format_gate_summary(score(review)))
        return

    photos_dir = args.dir if args.dir.is_absolute() else (REPO / args.dir)
    masks_dir = args.masks if args.masks.is_absolute() else (REPO / args.masks)
    run_battery(
        photos_dir,
        masks_dir,
        manifest_path,
        OUT_ROOT / dataset_label(photos_dir),
        args.limit,
        args.force,
    )


if __name__ == "__main__":
    main()
