"""Gate G2S product-photo eval battery (Phase 2S, D24/D28). QA tool.

Runs the CANONICAL pipeline in PRODUCT MODE (``analyze_palette(product_mode=
True)`` — D24: no person background-removal, no skin filter, CORE on the whole
frame) over a directory of product/sneaker photos and produces:

- ``results.json``           — per-photo palette / base / auto hints (machine-readable)
- ``<id>_panel.png``         — QA panel per photo (photo + palette, base highlighted)
- ``index.html``             — local gallery for fast visual review
- ``review.md``              — THE GATE ARTIFACT: a markdown table with one row per
  photo and two hand-review verdict columns the CEO fills in (yes/no):
    * "base OK?"              — is the harmony base the product's true dominant /
                                most-chromatic color (or a correct canvas-mode
                                routing for an all-neutral product)?
    * "palette 100% product?" — does every displayed swatch belong to the
                                product (no background swatch)?

Gate G2S (D28): >= GATE_G2S_MIN (70%) of the eval set must pass BOTH columns.
Once the review is annotated, ``--score`` parses it, computes the pass rate and
prints the PASS / FAIL verdict against the D28 threshold.

Why hand-review columns: product mode analyzes the WHOLE frame by design, so
the clean studio background is present in the raw palette; whether a swatch is
"background" or "white sole" is attribution a human must judge (same pattern as
the #56 CEO review). The tool pre-computes an auto HINT — swatches whose LAB
color matches the image border ring (the background in a centered product
shot) — but the hint never decides the gate.

Auto hints (informational, NOT auto-KOs — see the product-photo baseline
report: person-pipeline KO flags mis-fire on products):
- CRASH            — pipeline exception; the only auto-FAIL (pre-filled no/no).
- CANVAS           — neutral base -> canvas mode (D10); VALID for black/white
                     products, the human confirms the routing.
- MONO_PALETTE     — single swatch; VALID for solid-color products.
- BG_MATCH[i,...]  — palette swatches within BG_SWATCH_DELTA_E (LAB) of the
                     border-ring color (marked * in the review table).

Usage (from the repo root):
    python cv_core/tools/product_battery.py --dir samples/product   # run battery
    # ... CEO annotates outputs/product-battery/product/review.md ...
    python cv_core/tools/product_battery.py --score                 # gate verdict

Outputs are per-dataset — outputs/product-battery/<dirname>/ — so a smoke run
on synthetic fixtures never clobbers the real gate run. A review.md that
already carries verdicts is never overwritten without --force.
"""

from __future__ import annotations

import argparse
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

from colorlab.display import snap_neutral_for_display
from colorlab.harmony import hexstr, is_neutral
from colorlab.image_io import load_image
from colorlab.palette import srgb_to_lab
from colorlab.pipeline import analyze_palette
from colorlab.render import label_text_color

REPO = Path(__file__).resolve().parents[2]

# --- Gate G2S parameters (D24 / D28) -----------------------------------------

# D28 (2026-07-11, CEO): >= 70% of the product-photo eval set must come out
# with (a) correct harmony base AND (b) a 100%-product palette. First-
# measurement baseline; the CEO may raise it once the first number is in.
GATE_G2S_MIN = 0.70

# Where the real eval set will live per the baseline spec §4 (gitignored raw).
DEFAULT_DATASET_DIR = REPO / "samples" / "product"
OUT_ROOT = REPO / "outputs" / "product-battery"

ACCEPTED_SUFFIXES = (".jpg", ".jpeg", ".png", ".webp")

# Border-background hint: LAB distance below which a palette swatch is said to
# match the image border ring (the background of a centered product shot).
BG_SWATCH_DELTA_E = 12.0
# Border ring width as a fraction of the short image side (>= 1 px).
BORDER_RING_FRACTION = 0.04

# Hand-review verdict tokens (the CEO may annotate in Spanish or English).
YES_TOKENS = frozenset({"yes", "y", "si", "sí", "ok", "pass", "pasa"})
NO_TOKENS = frozenset({"no", "ko", "fail", "x"})
PENDING = "pending"

# Column headers of the review table (parsing anchors — keep in sync with
# build_review_md / parse_review_md).
COL_BASE_OK = "base OK?"
COL_PALETTE_PURE = "palette 100% product?"


# --- Gate metric (pure functions, unit-tested in tests/test_product_battery.py)


def parse_verdict(cell: str) -> str:
    """Normalizes a hand-review cell to 'yes' / 'no' / 'pending'.

    Lenient on purpose: the CEO annotates by hand (Spanish or English, any
    case, stray bold markers). Anything not recognized stays 'pending' so an
    ambiguous cell can never silently count toward the gate.
    """
    token = cell.strip().strip("*_`").strip().lower()
    if token in YES_TOKENS:
        return "yes"
    if token in NO_TOKENS:
        return "no"
    return PENDING


def row_status(base_ok: str, palette_pure: str) -> str:
    """Gate status of one photo from its two parsed verdicts.

    - 'fail' as soon as EITHER criterion is 'no' (D28 requires both).
    - 'pass' only when BOTH are 'yes'.
    - 'pending' otherwise (any unreviewed cell).
    """
    if base_ok == "no" or palette_pure == "no":
        return "fail"
    if base_ok == "yes" and palette_pure == "yes":
        return "pass"
    return PENDING


def gate_metric(
    verdicts: list[tuple[str, str]], threshold: float = GATE_G2S_MIN
) -> dict:
    """Computes the Gate G2S metric over parsed (base_ok, palette_pure) rows.

    Returns counts plus a bracket for partially-reviewed sets:
    - rate_worst: pass rate if every pending row failed (lower bound).
    - rate_best:  pass rate if every pending row passed (upper bound).
    - verdict: 'PASS' / 'FAIL' when decidable (fully reviewed, or the bracket
      already decides it), else 'UNDECIDED'. 'NO DATA' on an empty set.
    """
    statuses = [row_status(b, p) for b, p in verdicts]
    n = len(statuses)
    passed = statuses.count("pass")
    failed = statuses.count("fail")
    pending = statuses.count(PENDING)
    if n == 0:
        return {
            "n": 0,
            "passed": 0,
            "failed": 0,
            "pending": 0,
            "rate_worst": 0.0,
            "rate_best": 0.0,
            "threshold": threshold,
            "verdict": "NO DATA",
        }
    eps = 1e-9  # guard against float noise at the exact threshold (7/10 vs 0.70)
    rate_worst = passed / n
    rate_best = (passed + pending) / n
    if rate_worst >= threshold - eps:
        verdict = "PASS"  # holds even if every pending row failed
    elif rate_best < threshold - eps:
        verdict = "FAIL"  # unreachable even if every pending row passed
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
        "threshold": threshold,
        "verdict": verdict,
    }


def format_gate_summary(metric: dict) -> str:
    """One-paragraph human summary of gate_metric()'s output."""
    if metric["n"] == 0:
        return "Gate G2S: NO DATA (no rows found in the review table)."
    lines = [
        f"Gate G2S (D28, threshold >= {metric['threshold']:.0%}): "
        f"{metric['passed']}/{metric['n']} pass "
        f"({metric['rate_worst']:.1%})"
        + (
            f", {metric['pending']} row(s) still PENDING "
            f"(best case {metric['rate_best']:.1%})"
            if metric["pending"]
            else ""
        ),
        f"VERDICT: {metric['verdict']}"
        + (
            " — annotate the pending rows to decide the gate"
            if metric["verdict"] == "UNDECIDED"
            else ""
        ),
    ]
    return "\n".join(lines)


# --- Battery run --------------------------------------------------------------


def border_background_color(rgb: np.ndarray) -> tuple[np.ndarray, tuple[int, int, int]]:
    """Median color of the image border ring (product-shot background).

    Returns (median LAB for matching, median RGB for display).
    """
    h, w = rgb.shape[:2]
    ring = max(1, round(BORDER_RING_FRACTION * min(h, w)))
    mask = np.zeros((h, w), dtype=bool)
    mask[:ring, :] = mask[-ring:, :] = True
    mask[:, :ring] = mask[:, -ring:] = True
    border = rgb[mask].astype(float)
    lab = np.median(srgb_to_lab(border), axis=0)
    # int() is NOT redundant: round() on a numpy scalar returns a numpy
    # scalar, and these values are JSON-serialized downstream.
    med_rgb = tuple(int(round(v)) for v in np.median(border, axis=0))  # noqa: RUF046
    return lab, med_rgb


def evaluate_photo(path: Path) -> dict:
    """Runs product mode over one photo -> palette, base and auto hints."""
    res: dict = {"id": path.stem, "file": path.name, "hints": [], "error": None}
    t0 = time.perf_counter()
    try:
        img = load_image(path)
        analysis = analyze_palette(img, product_mode=True)
        res["time_s"] = time.perf_counter() - t0

        # "hex" is the RAW analysis color (what the gate/harmonies run on);
        # "display_hex" is what the app SHOWS after the neutral snap (#85,
        # D31-A: diluted black -> #000000, near-white -> #FFFFFF, chroma-gated).
        res["palette"] = []
        for c, w in zip(analysis.colors, analysis.weights, strict=True):
            rgb = tuple(int(x) for x in c)
            res["palette"].append(
                {
                    "hex": hexstr(rgb),
                    "display_hex": hexstr(snap_neutral_for_display(rgb)),
                    "weight": float(w),
                }
            )
        res["base_hex"] = hexstr(analysis.base)
        res["display_base_hex"] = hexstr(snap_neutral_for_display(analysis.base))
        res["canvas"] = bool(is_neutral(analysis.base))

        # BG_MATCH hint: swatches whose LAB color sits near the border ring's.
        rgb = np.asarray(img)
        bg_lab, bg_rgb = border_background_color(rgb)
        res["border_bg_hex"] = hexstr(bg_rgb)
        palette_lab = srgb_to_lab(analysis.colors.astype(float))
        matches = [
            i
            for i, lab in enumerate(np.atleast_2d(palette_lab))
            if float(np.linalg.norm(lab - bg_lab)) < BG_SWATCH_DELTA_E
        ]
        res["bg_match_indices"] = matches
        res["bg_match_weight"] = float(
            sum(res["palette"][i]["weight"] for i in matches)
        )

        if res["canvas"]:
            res["hints"].append("CANVAS")
        if len(res["palette"]) == 1:
            res["hints"].append("MONO_PALETTE")
        if matches:
            res["hints"].append("BG_MATCH[" + ",".join(map(str, matches)) + "]")
    except Exception:
        res["time_s"] = time.perf_counter() - t0
        res["hints"].insert(0, "CRASH")
        res["error"] = traceback.format_exc(limit=3)
    return res


def compact_panel(res: dict, img_path: Path, out_path: Path) -> None:
    """QA panel (same layout as mass_battery): photo + palette + hints."""
    fig = plt.figure(figsize=(7.2, 2.9))
    gs = fig.add_gridspec(1, 2, width_ratios=[1.0, 1.5], wspace=0.05)
    ax_img = fig.add_subplot(gs[0, 0])
    ax_img.axis("off")
    if "CRASH" in res["hints"]:
        ax_img.text(
            0.5, 0.5, "CRASH", ha="center", va="center", fontsize=20, color="red"
        )
    else:
        ax_img.imshow(np.asarray(load_image(img_path)))

    ax_pal = fig.add_subplot(gs[0, 1])
    ax_pal.set_xlim(0, 1)
    ax_pal.set_ylim(0, 1)
    ax_pal.axis("off")
    palette = res.get("palette", [])
    n = max(len(palette), 1)
    for i, entry in enumerate(palette):
        # The panel shows the DISPLAY swatch (#85 neutral snap), same as the
        # app will; a snapped swatch keeps its raw hex as a small annotation.
        shown_hex = entry.get("display_hex", entry["hex"])
        rgb = tuple(int(shown_hex[j : j + 2], 16) for j in (1, 3, 5))
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
        marks = (
            ("\nBASE" if is_base else "")
            + ("\n(bg?)" if i in res.get("bg_match_indices", []) else "")
            + (f"\n(snap {entry['hex']})" if shown_hex != entry["hex"] else "")
        )
        ax_pal.text(
            (i + 0.5) / n,
            0.62,
            f"{shown_hex}\n{entry['weight'] * 100:.0f}%{marks}",
            ha="center",
            va="center",
            fontsize=7,
            color=label_text_color(rgb),
        )
    hints = ", ".join(res["hints"]) or "no hints"
    color = "red" if "CRASH" in res["hints"] else "0.25"
    ax_pal.text(
        0.0, 0.16, f"product mode (D24) · hints: {hints}", fontsize=9, color=color
    )
    ax_pal.text(
        0.0,
        0.02,
        f"bg_match_weight={res.get('bg_match_weight', float('nan')) * 100:.0f}%  "
        f"t={res.get('time_s', float('nan')):.1f}s",
        fontsize=7,
        color="0.3",
    )
    fig.suptitle(res["id"], fontsize=9, y=0.98)
    fig.savefig(out_path, dpi=95, bbox_inches="tight")
    plt.close(fig)


def build_gallery(results: list[dict], dataset: str, out_path: Path) -> None:
    """Local index.html gallery (crashes first, then alphabetical)."""
    html = [
        "<!doctype html><meta charset='utf-8'>",
        f"<title>Gate G2S product battery — {dataset}</title>",
        "<style>body{font-family:sans-serif;margin:20px;background:#fafafa}"
        ".card{display:inline-block;margin:6px;padding:6px;background:#fff;"
        "border:1px solid #ddd;border-radius:6px;vertical-align:top;width:560px}"
        ".card img{max-width:100%}.meta{font-size:11px;color:#555}"
        ".crash{border-left:5px solid #d33}.ok{border-left:5px solid #888}</style>",
        f"<h1>Gate G2S product battery — {dataset} · {len(results)} photos</h1>",
        f"<p>Product mode (D24). Gate G2S (D28): &ge; {GATE_G2S_MIN:.0%} must pass "
        "base-OK + 100%-product palette — <b>hand-review verdicts live in "
        "review.md</b>; hints here are informational only.</p>",
    ]
    ordered = sorted(results, key=lambda r: ("CRASH" not in r["hints"], r["id"]))
    for r in ordered:
        css = "crash" if "CRASH" in r["hints"] else "ok"
        hints = ", ".join(r["hints"]) or "—"
        html.append(
            f"<div class='card {css}'><img src='{r['id']}_panel.png' loading='lazy'>"
            f"<div class='meta'>{r['id']} · hints: {hints} · t={r.get('time_s', 0):.1f}s</div></div>"
        )
    out_path.write_text("\n".join(html), encoding="utf-8")


def _display_cell_hex(raw_hex: str, display_hex: str | None) -> str:
    """Review-table rendering of one hex: the DISPLAYED value first (what the
    app shows after the #85 neutral snap), with the raw analysis hex kept as
    an annotation when the snap changed it."""
    if display_hex and display_hex != raw_hex:
        return f"`{display_hex}` (snap de `{raw_hex}`)"
    return f"`{raw_hex}`"


def _palette_cell(res: dict) -> str:
    parts = []
    for i, entry in enumerate(res.get("palette", [])):
        star = "\\*" if i in res.get("bg_match_indices", []) else ""
        base = " **BASE**" if entry["hex"] == res.get("base_hex") else ""
        shown = _display_cell_hex(entry["hex"], entry.get("display_hex"))
        parts.append(f"{shown} {entry['weight'] * 100:.0f}%{star}{base}")
    return " · ".join(parts) or "—"


def build_review_md(results: list[dict], dataset_dir: Path) -> str:
    """The annotatable gate artifact: header + one table row per photo."""
    today = _dt.date.today().isoformat()
    lines = [
        f"# Gate G2S product-photo review — `{dataset_dir.as_posix()}`",
        "",
        f"**Generated:** {today} by `cv_core/tools/product_battery.py` · "
        f"**Photos:** {len(results)} · **Mode:** product (D24, whole frame, no person layers)",
        "",
        f"**Gate G2S (D28): >= {GATE_G2S_MIN:.0%}** of rows must have **both** columns = yes.",
        "",
        "How to annotate (CEO): fill the two verdict columns with `yes` / `no`",
        "(`si`/`ok`/`ko` also accepted; anything else stays pending).",
        "",
        f"- **{COL_BASE_OK}** — the highlighted BASE is the product's true dominant /",
        "  most-chromatic color; for an all-neutral product (black/white sneaker) a",
        "  neutral base routing to canvas mode (hint `CANVAS`) is CORRECT -> yes.",
        f"- **{COL_PALETTE_PURE}** — every swatch belongs to the product. `\\*` marks",
        "  swatches that match the border-ring background color (auto hint `BG_MATCH`).",
        "  NOTE: product mode analyzes the whole frame, so a background swatch CAN",
        "  legitimately appear in the raw palette — judge the palette as the app",
        "  displays it. A white sole on a white background may also match: your call.",
        "",
        "Swatches shown as `#000000`/`#FFFFFF` with a `(snap de ...)` note are the",
        "#85 display snap (D31-A): a low-chroma diluted black/near-white is shown",
        "canonical; the analysis (base, weights, gate) still ran on the raw hex.",
        "",
        "Then compute the gate: `python cv_core/tools/product_battery.py --score "
        f"{(OUT_ROOT / dataset_dir.name / 'review.md').relative_to(REPO).as_posix()}`",
        "",
        f"| # | photo | base | palette | auto hints | {COL_BASE_OK} | {COL_PALETTE_PURE} | notes |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for i, r in enumerate(sorted(results, key=lambda x: x["id"]), 1):
        crash = "CRASH" in r["hints"]
        verdict = "no" if crash else PENDING
        note = "CRASH (auto-fail)" if crash else ""
        base = (
            (
                _display_cell_hex(r["base_hex"], r.get("display_base_hex"))
                + (" (canvas)" if r.get("canvas") else "")
            )
            if not crash
            else "—"
        )
        hints = ", ".join(r["hints"]) or "—"
        lines.append(
            f"| {i} | {r['file']} | {base} | {_palette_cell(r)} | {hints} "
            f"| {verdict} | {verdict} | {note} |"
        )
    lines.append("")
    return "\n".join(lines)


def parse_review_md(text: str) -> list[dict]:
    """Parses an annotated review.md back into rows with parsed verdicts.

    Anchors on the header row containing COL_BASE_OK to locate the verdict
    columns, so extra columns or reordering fail loudly instead of misreading.
    """
    rows: list[dict] = []
    header_cols: list[str] | None = None
    for line in text.splitlines():
        if not line.strip().startswith("|"):
            continue
        cols = [c.strip() for c in line.strip().strip("|").split("|")]
        if header_cols is None:
            if COL_BASE_OK in cols and COL_PALETTE_PURE in cols:
                header_cols = cols
            continue
        if set(line) <= {"|", "-", " ", ":"}:  # separator row
            continue
        if len(cols) != len(header_cols):
            continue
        row = dict(zip(header_cols, cols, strict=True))
        rows.append(
            {
                "photo": row.get("photo", ""),
                "base_ok": parse_verdict(row[COL_BASE_OK]),
                "palette_pure": parse_verdict(row[COL_PALETTE_PURE]),
            }
        )
    if header_cols is None:
        raise ValueError(
            f"review table not found: no header row with {COL_BASE_OK!r} and "
            f"{COL_PALETTE_PURE!r} columns"
        )
    return rows


def score(review_path: Path) -> dict:
    """Parses an annotated review.md and returns the gate metric."""
    rows = parse_review_md(review_path.read_text(encoding="utf-8"))
    return gate_metric([(r["base_ok"], r["palette_pure"]) for r in rows])


def _review_has_verdicts(path: Path) -> bool:
    """True if an existing review.md already carries hand-entered verdicts."""
    try:
        rows = parse_review_md(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    # CRASH rows are pre-filled 'no' by the generator; a review counts as
    # annotated once ANY yes appears or a no coexists with a non-CRASH note —
    # keep it simple and safe: any yes, or any no at all, blocks overwrite.
    return any(r["base_ok"] != PENDING or r["palette_pure"] != PENDING for r in rows)


def run_battery(
    dataset_dir: Path, out_dir: Path, limit: int | None, force: bool
) -> None:
    files = sorted(
        p for p in dataset_dir.iterdir() if p.suffix.lower() in ACCEPTED_SUFFIXES
    )
    if not files:
        raise SystemExit(f"No {'/'.join(ACCEPTED_SUFFIXES)} images in {dataset_dir}")
    if limit:
        files = files[:limit]

    review_path = out_dir / "review.md"
    if review_path.exists() and _review_has_verdicts(review_path) and not force:
        raise SystemExit(
            f"{review_path} already carries hand verdicts — refusing to overwrite "
            "the CEO's review. Re-run with --force to discard it."
        )

    out_dir.mkdir(parents=True, exist_ok=True)
    print(
        f"Dataset: {dataset_dir} · {len(files)} photos · product mode (D24)", flush=True
    )
    results = []
    t_batch = time.perf_counter()
    for i, path in enumerate(files, 1):
        res = evaluate_photo(path)
        compact_panel(res, path, out_dir / f"{res['id']}_panel.png")
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
                "dataset": str(dataset_dir),
                "n": len(results),
                "gate_g2s_min": GATE_G2S_MIN,
                "results": results,
            },
            indent=1,
        ),
        encoding="utf-8",
    )
    build_gallery(results, dataset_dir.name, out_dir / "index.html")
    review_path.write_text(build_review_md(results, dataset_dir), encoding="utf-8")

    crashes = sum(1 for r in results if "CRASH" in r["hints"])
    canvas = sum(1 for r in results if "CANVAS" in r["hints"])
    bg_hint = sum(
        1 for r in results if any(h.startswith("BG_MATCH") for h in r["hints"])
    )
    print(
        f"\nAuto summary: {len(results)} photos · {crashes} CRASH · "
        f"{canvas} canvas-mode · {bg_hint} with a border-bg-matching swatch (hint)"
    )
    print(f"Gallery:  {out_dir / 'index.html'}")
    print(f"Review:   {review_path}")
    print("\nNEXT: the CEO annotates the two verdict columns in review.md, then run:")
    print(
        f"  python cv_core/tools/product_battery.py --score "
        f"{review_path.relative_to(REPO).as_posix()}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dir",
        type=Path,
        default=DEFAULT_DATASET_DIR,
        help="photo folder to evaluate (default: samples/product, "
        "the Gate G2S dataset location)",
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
        help="no processing: parse an annotated review.md and print the "
        "Gate G2S verdict (default: outputs/product-battery/"
        "product/review.md)",
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.WARNING)  # silence the pipeline's INFO

    if args.score is not False:  # --score given (with or without a path)
        review = args.score or (OUT_ROOT / DEFAULT_DATASET_DIR.name / "review.md")
        if not review.exists():
            raise SystemExit(f"Review not found: {review} — run the battery first.")
        print(format_gate_summary(score(review)))
        return

    dataset_dir = args.dir if args.dir.is_absolute() else (REPO / args.dir)
    run_battery(dataset_dir, OUT_ROOT / dataset_dir.name, args.limit, args.force)


if __name__ == "__main__":
    main()
