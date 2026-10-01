"""ICEBOX I2 step 1 — per-region recolor proof of concept (ML tool, not shipped).

For a photo + its MediaPipe class mask (the contract PNG of
:mod:`colorlab.segmentation`) this runs the shipped per-garment analysis
(:func:`colorlab.pipeline.analyze_garments`, k = GARMENT_COLORS), takes the
hero combo the app shows (the COMPLEMENTARY of the outfit base, D36; a curated
canvas accent when the outfit is all-neutral, D10) and repaints ONE region at
a time toward the proposed colour with :func:`colorlab.recolor.recolor_region`
while the other region stays as shot.

Mask preparation (I2 condition C1, 2026-09-30) is the library's hardening:
smoothed resample of the class map to the working size
(:func:`colorlab.segmentation.resample_class_map_smooth`), then
:data:`colorlab.segmentation.RECOLOR_HARDENING` (hole fill, detached-component
drop, hip-line split, 2 px growth into background) through
:func:`colorlab.segmentation.split_garment_masks`, plus the applicability
verdict of :func:`colorlab.segmentation.check_applicability`. ``--no-harden``
keeps only the smoothed resample and the v1 mid-row split (A/B reference).

Output: a before/after panel per photo — original | recolor ARRIBA | recolor
ABAJO | mask overlay — with the target swatch, the combo name, the
applicability and the per-region runtime written on it, under
``outputs/i2-poc/`` (gitignored: the photos are the CEO's own selfies and
never leave the machine).

Usage (from the repo root, venv active):
    python cv_core/tools/recolor_poc.py --photo samples/selfies/selfie04.jpeg
    python cv_core/tools/recolor_poc.py --photo ... --region upper --target "#2B5CE4"
    python cv_core/tools/recolor_poc.py --all                # the curated 10 + 2 failure panels
    python cv_core/tools/recolor_poc.py --all --variant uniform   # ablation: no membership
    python cv_core/tools/recolor_poc.py --all --no-harden --tag raw   # A/B without C1
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import time
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from colorlab.harmony import CANVAS_ACCENTS, RGB, as_rgb, harmonies, hexstr
from colorlab.image_io import load_image
from colorlab.palette import dominant_colors
from colorlab.pipeline import GARMENT_COLORS, GarmentAnalysis, analyze_garments
from colorlab.recolor import recolor_region
from colorlab.segmentation import (
    CLASS_CLOTHES,
    MASK_ERODE_PX,
    RECOLOR_HARDENING,
    REGION_LOWER,
    REGION_UPPER,
    Applicability,
    MaskHardening,
    NoPersonError,
    check_applicability,
    erode_mask,
    harden_class_map,
    hip_split_row,
    load_class_mask,
    resample_class_map_smooth,
    split_garment_masks,
    upscale_class_map,
)

logger = logging.getLogger("recolor_poc")

REPO = Path(__file__).resolve().parents[2]
DEFAULT_MASKS_DIR = REPO / "samples" / "segmentation" / "masks"
DEFAULT_PHOTOS_DIR = REPO / "samples" / "selfies"
DEFAULT_OUT_DIR = REPO / "outputs" / "i2-poc"
MASK_SUFFIX = ".mask.png"

# Working resolution of the PoC (the app analyzes at MAX_SIDE 600; 512 is the
# figure the I2 brief asks the runtime for).
WORK_MAX_SIDE = 512

# ``--no-harden``: smoothed resample only, v1 mid-row split, no growth.
NO_HARDENING = MaskHardening(
    fill_holes=False, drop_detached=False, hip_split=False, grow_px=0
)

# Curated batch (I2 brief): plain chromatic garments, a printed garment, a
# neutral target region, a dark photo, an imperfect mask. Coverage notes are
# in the report; the stems are the CEO's private selfies (never exported).
CURATED_STEMS = (
    "selfie04",  # plain chromatic top (burgundy)
    "selfie06",  # plain chromatic top + bottom (blue hoodie + jeans)
    "selfie10",  # chromatic top, dim funhouse mirror + neon cast
    "selfie24",  # navy shirt + blue jeans, both chromatic
    "selfie02",  # printed: black/white striped tee (neutral source)
    "selfie27",  # multicolour knit sweater (patterned, chromatic)
    "selfie17",  # black shirt (neutral source) + cream pants (neutral target)
    "selfie22",  # total black (canvas mode: injection on both regions)
    "selfie31",  # dark home-mirror photo, warm cast
    "selfie08",  # glass-pane reflection with glare: imperfect mask
)
# Deliberate "ugly" cases so the CEO sees the limits.
FAILURE_STEMS = (
    "selfie05",  # two people in frame, busy background
    "selfie13",  # dim elevator, gray tank top: injection on a mid gray
)

# Panel layout.
PANEL_GAP = 12
PANEL_HEADER = 56
PANEL_FOOTER = 112
SWATCH_SIDE = 40
PANEL_BG = (250, 250, 250)
PANEL_TEXT = (20, 20, 20)
PANEL_WARN = (190, 30, 30)
CANVAS_PREFIX = "Lienzo"

# Mask overlay column: tints over the original (alpha 0..1).
OVERLAY_ALPHA = 0.55
TINT_UPPER = (40, 200, 120)
TINT_LOWER = (150, 80, 220)
TINT_DROPPED = (230, 40, 40)  # raw clothes pixels the hardening removed
TINT_ADDED = (255, 200, 0)  # pixels the hardening added (holes, growth)
SPLIT_LINE = (255, 255, 255)


def _font(size: int) -> ImageFont.ImageFont | ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def parse_hex(text: str) -> RGB:
    text = text.strip().lstrip("#")
    if len(text) != 6:
        raise argparse.ArgumentTypeError(f"expected #RRGGBB, got {text!r}")
    return as_rgb(int(text[i : i + 2], 16) for i in (0, 2, 4))


@dataclass
class PreparedPhoto:
    """Everything the recolor needs for one photo, at WORK_MAX_SIDE."""

    rgb: np.ndarray
    raw_map: np.ndarray  # nearest resize of the stored map (canonical path)
    smooth_map: np.ndarray  # smoothed resample (no hardening yet)
    hardened_map: np.ndarray  # smooth + hardening (analysis input)
    regions: dict[str, np.ndarray]  # un-eroded recolor masks (hardened split)
    applicability: Applicability
    split_row: int
    split_from_waist: bool


def prepare_photo(
    photo: Path, masks_dir: Path, *, hardening: MaskHardening = RECOLOR_HARDENING
) -> PreparedPhoto:
    """Loads the photo at WORK_MAX_SIDE and builds the recolor masks.

    ``raw_map`` is the nearest resize the canonical analysis path uses (Dart
    parity); it feeds the applicability metrics (which are defined on the RAW
    class map). ``hardened_map`` is the smoothed resample after
    :func:`harden_class_map` and is what the per-garment analysis sees.
    ``regions`` are the un-eroded, hardened, hip-split masks the recolor
    paints (may raise :class:`NoPersonError`).
    """
    rgb = np.asarray(load_image(photo, max_side=WORK_MAX_SIDE))
    h, w = rgb.shape[:2]
    stored = load_class_mask(str(masks_dir / f"{photo.stem}{MASK_SUFFIX}"))
    raw_map = upscale_class_map(stored, w, h)
    smooth_map = resample_class_map_smooth(stored, w, h)
    hardened_map = harden_class_map(smooth_map, hardening)
    # Same options, RAW smooth map (split_garment_masks hardens internally and
    # the growth is not idempotent).
    regions = split_garment_masks(smooth_map, erode_px=0, harden=hardening)
    clothes = hardened_map == CLASS_CLOTHES
    if hardening.hip_split:
        split_row, from_waist = hip_split_row(clothes)
    else:
        rows = np.where(clothes.any(axis=1))[0]
        split_row, from_waist = (int(rows[0]) + int(rows[-1])) // 2, False
    applicability = check_applicability(raw_map, rgb, regions)
    return PreparedPhoto(
        rgb=rgb,
        raw_map=raw_map,
        smooth_map=smooth_map,
        hardened_map=hardened_map,
        regions=regions,
        applicability=applicability,
        split_row=split_row,
        split_from_waist=from_waist,
    )


def pick_target(analysis: GarmentAnalysis, stem_index: int) -> tuple[RGB, str]:
    """The hero combo colour the app would show (D36) + its display name."""
    if analysis.base_index >= 0:
        return harmonies(analysis.base)["Complementario"][1], "Complementario"
    accent = CANVAS_ACCENTS[stem_index % len(CANVAS_ACCENTS)]
    return accent, f"{CANVAS_PREFIX} (canvas mode, curated accent)"


def region_source_colour(rgb: np.ndarray, mask: np.ndarray) -> RGB:
    """The dominant colour of the region the recolor paints (same recipe as
    the per-garment block: MASK_ERODE_PX erosion, k = GARMENT_COLORS, max
    weight), measured on the HARDENED region so source and paint agree."""
    eroded = erode_mask(mask, MASK_ERODE_PX)
    if not eroded.any():
        eroded = mask
    colors, weights = dominant_colors(rgb[eroded].astype(float), GARMENT_COLORS)
    return as_rgb(colors[int(np.argmax(weights))])


def recolor_photo(
    prepared: PreparedPhoto,
    *,
    target: RGB | None,
    stem_index: int = 0,
    selective: bool = True,
    lightness_shift: float | None = None,
    repeats: int = 1,
) -> dict:
    """Runs analysis + both per-region recolors; returns images and metrics.

    ``repeats`` > 1 re-runs each region recolor and reports the MEDIAN time,
    so the first-call OpenCV warm-up does not pollute the benchmark.
    """
    rgb = prepared.rgb
    t0 = time.perf_counter()
    analysis = analyze_garments(
        Image.fromarray(rgb), prepared.hardened_map, n_colors=GARMENT_COLORS
    )
    t_analysis = time.perf_counter() - t0
    if target is None:
        target, combo = pick_target(analysis, stem_index)
    else:
        combo = "manual target"

    outputs: dict[str, np.ndarray] = {}
    timings: dict[str, float] = {}
    sources: dict[str, RGB] = {}
    for region in (REGION_UPPER, REGION_LOWER):
        mask = prepared.regions.get(region)
        if mask is None:
            continue
        source = region_source_colour(rgb, mask)
        sources[region] = source
        laps = []
        for _ in range(max(1, repeats)):
            t0 = time.perf_counter()
            outputs[region] = recolor_region(
                rgb,
                mask,
                target,
                source_rgb=source,
                selective=selective,
                lightness_shift=lightness_shift,
            )
            laps.append(time.perf_counter() - t0)
        timings[region] = float(np.median(laps))
    return {
        "analysis": analysis,
        "target": target,
        "combo": combo,
        "outputs": outputs,
        "timings": timings,
        "sources": sources,
        "t_analysis": t_analysis,
    }


def mask_overlay(prepared: PreparedPhoto) -> np.ndarray:
    """Original tinted by region (upper/lower), by what the hardening REMOVED
    (raw clothes now dropped) and ADDED (filled holes / growth), with the
    split row drawn — the diagnostic column of the panel."""
    out = prepared.rgb.astype(np.float32)
    raw_clothes = prepared.raw_map == CLASS_CLOTHES
    painted = np.zeros(raw_clothes.shape, dtype=bool)
    for region, tint in ((REGION_UPPER, TINT_UPPER), (REGION_LOWER, TINT_LOWER)):
        mask = prepared.regions.get(region)
        if mask is None:
            continue
        painted |= mask
        out[mask] = out[mask] * (1 - OVERLAY_ALPHA) + np.array(tint) * OVERLAY_ALPHA
    dropped = raw_clothes & ~painted
    added = painted & ~raw_clothes
    out[dropped] = out[dropped] * (1 - OVERLAY_ALPHA) + np.array(TINT_DROPPED) * (
        OVERLAY_ALPHA
    )
    out[added] = out[added] * (1 - OVERLAY_ALPHA) + np.array(TINT_ADDED) * (
        OVERLAY_ALPHA
    )
    row = min(max(prepared.split_row, 0), out.shape[0] - 1)
    out[row, :] = SPLIT_LINE
    return np.clip(np.rint(out), 0, 255).astype(np.uint8)


def compose_panel(prepared: PreparedPhoto, result: dict, title: str) -> Image.Image:
    """original | recolor ARRIBA | recolor ABAJO | mask overlay, with swatch +
    combo + applicability + timing."""
    rgb = prepared.rgb
    h, w = rgb.shape[:2]
    columns = [("Original", rgb)]
    for region, label in (
        (REGION_UPPER, "Recolor ARRIBA"),
        (REGION_LOWER, "Recolor ABAJO"),
    ):
        out = result["outputs"].get(region)
        if out is not None:
            ms = result["timings"][region] * 1000
            too_small = prepared.applicability.regions.get(region)
            flag = "  [too small]" if too_small else ""
            columns.append((f"{label}  ({ms:.0f} ms){flag}", out))
        else:
            columns.append((f"{label}  (region absent)", rgb))
    split = "waist" if prepared.split_from_waist else "mid-row"
    columns.append((f"Mask (split: {split})", mask_overlay(prepared)))
    n = len(columns)
    panel_w = n * w + (n + 1) * PANEL_GAP
    panel_h = PANEL_HEADER + h + PANEL_FOOTER
    panel = Image.new("RGB", (panel_w, panel_h), PANEL_BG)
    draw = ImageDraw.Draw(panel)
    font, small = _font(20), _font(16)

    for i, (label, img) in enumerate(columns):
        x = PANEL_GAP + i * (w + PANEL_GAP)
        draw.text((x, 16), label, fill=PANEL_TEXT, font=font)
        panel.paste(Image.fromarray(img), (x, PANEL_HEADER))

    y = PANEL_HEADER + h + 12
    target = result["target"]
    draw.rectangle(
        [PANEL_GAP, y, PANEL_GAP + SWATCH_SIDE, y + SWATCH_SIDE],
        fill=target,
        outline=(80, 80, 80),
    )
    analysis = result["analysis"]
    base_txt = (
        f"base {hexstr(analysis.base)} ({analysis.base_region})"
        if analysis.base_index >= 0
        else "no chromatic base (canvas)"
    )
    src_txt = ", ".join(f"{r}: {hexstr(c)}" for r, c in result["sources"].items())
    draw.text(
        (PANEL_GAP + SWATCH_SIDE + 10, y),
        f"{title}  ·  combo: {result['combo']}  ·  target {hexstr(target)}  ·  {base_txt}",
        fill=PANEL_TEXT,
        font=font,
    )
    draw.text(
        (PANEL_GAP + SWATCH_SIDE + 10, y + 28),
        f"recolored source per region: {src_txt}  ·  analysis {result['t_analysis'] * 1000:.0f} ms  ·  {w}x{h}",
        fill=PANEL_TEXT,
        font=small,
    )
    app = prepared.applicability
    m = app.metrics
    verdict = "APPLICABLE" if app.applicable else f"NOT APPLICABLE: {app.reason}"
    draw.text(
        (PANEL_GAP + SWATCH_SIDE + 10, y + 50),
        f"{verdict}  ·  person ratio {m.get('person_component_ratio', 0):.2f}  ·  "
        f"L median {m.get('frame_median_l', 0):.0f} / person p90 {m.get('person_p90_l', 0):.0f}  ·  "
        f"holes {m.get('hole_fraction', 0):.3f} speckle {m.get('speckle_fraction', 0):.3f} "
        f"detached {m.get('detached_fraction', 0):.3f}",
        fill=PANEL_TEXT if app.applicable else PANEL_WARN,
        font=small,
    )
    return panel


def run_one(
    photo: Path,
    masks_dir: Path,
    out_dir: Path,
    *,
    region: str | None,
    target: RGB | None,
    stem_index: int,
    tag: str,
    selective: bool,
    lightness_shift: float | None,
    repeats: int,
    hardening: MaskHardening = RECOLOR_HARDENING,
) -> dict | None:
    try:
        prepared = prepare_photo(photo, masks_dir, hardening=hardening)
        result = recolor_photo(
            prepared,
            target=target,
            stem_index=stem_index,
            selective=selective,
            lightness_shift=lightness_shift,
            repeats=repeats,
        )
    except NoPersonError as exc:
        logger.warning("%s: %s", photo.name, exc)
        return None
    out_dir.mkdir(parents=True, exist_ok=True)
    suffix = f"_{tag}" if tag else ""
    if region:
        out = result["outputs"].get(region)
        if out is None:
            logger.warning("%s: region %r absent", photo.name, region)
            return None
        path = out_dir / f"{photo.stem}_{region}{suffix}.png"
        Image.fromarray(out).save(path)
    else:
        path = out_dir / f"{photo.stem}_panel{suffix}.png"
        compose_panel(prepared, result, photo.stem).save(path)
    logger.info("wrote %s", path)
    app = prepared.applicability
    return {
        "photo": photo.name,
        "panel": path.name,
        "combo": result["combo"],
        "target": hexstr(result["target"]),
        "base": hexstr(result["analysis"].base),
        "base_index": result["analysis"].base_index,
        "base_region": result["analysis"].base_region,
        "sources": {r: hexstr(c) for r, c in result["sources"].items()},
        "recolor_ms": {r: round(t * 1000, 1) for r, t in result["timings"].items()},
        "analysis_ms": round(result["t_analysis"] * 1000, 1),
        "size": list(prepared.rgb.shape[:2][::-1]),
        "applicable": app.applicable,
        "reason": app.reason,
        "region_reasons": app.regions,
        "split_from_waist": prepared.split_from_waist,
        "metrics": {k: round(v, 4) for k, v in app.metrics.items()},
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--photo", type=Path, help="one photo (needs its mask)")
    parser.add_argument(
        "--all", action="store_true", help="curated 10 + 2 failure panels"
    )
    parser.add_argument("--masks-dir", type=Path, default=DEFAULT_MASKS_DIR)
    parser.add_argument("--photos-dir", type=Path, default=DEFAULT_PHOTOS_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument(
        "--region",
        choices=(REGION_UPPER, REGION_LOWER),
        help="write only that region's recolored photo instead of the panel",
    )
    parser.add_argument(
        "--target", type=parse_hex, help="override the target (#RRGGBB)"
    )
    parser.add_argument(
        "--variant",
        choices=("selective", "uniform"),
        default="selective",
        help="uniform = no membership weighting (ablation)",
    )
    parser.add_argument(
        "--lightness-shift",
        type=float,
        default=None,
        help="override the L* shift fraction",
    )
    parser.add_argument(
        "--bench",
        type=int,
        default=1,
        metavar="N",
        help="repeat each region recolor N times and report the median (warm-up free)",
    )
    parser.add_argument(
        "--no-harden",
        action="store_true",
        help="A/B reference: smoothed resample only, v1 mid-row split, no C1 steps",
    )
    parser.add_argument("--tag", default="", help="suffix for the output files")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)
    logging.basicConfig(
        level=logging.INFO if args.verbose else logging.WARNING,
        format="%(levelname)s %(name)s: %(message)s",
    )
    if not args.photo and not args.all:
        parser.error("--photo or --all required")
    hardening = NO_HARDENING if args.no_harden else RECOLOR_HARDENING

    photos: list[tuple[Path, str]] = []
    if args.photo:
        photos.append((args.photo, args.tag))
    if args.all:
        photos += [(args.photos_dir / f"{s}.jpeg", args.tag) for s in CURATED_STEMS]
        fail_tag = f"FAIL{('_' + args.tag) if args.tag else ''}"
        photos += [(args.photos_dir / f"{s}.jpeg", fail_tag) for s in FAILURE_STEMS]

    rows = []
    for i, (photo, tag) in enumerate(photos):
        row = run_one(
            photo,
            args.masks_dir,
            args.out,
            region=args.region,
            target=args.target,
            stem_index=i,
            tag=tag,
            selective=args.variant == "selective",
            lightness_shift=args.lightness_shift,
            repeats=args.bench,
            hardening=hardening,
        )
        if row:
            rows.append(row)
            print(json.dumps(row))
    if rows:
        ms = [t for r in rows for t in r["recolor_ms"].values()]
        print(
            f"{len(rows)} photos · recolor per region: mean {np.mean(ms):.0f} ms, "
            f"max {np.max(ms):.0f} ms · analysis mean {np.mean([r['analysis_ms'] for r in rows]):.0f} ms"
        )
        (args.out / f"summary{('_' + args.tag) if args.tag else ''}.json").write_text(
            json.dumps(rows, indent=2)
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
