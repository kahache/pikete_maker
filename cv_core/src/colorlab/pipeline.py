"""End-to-end composition of the colorlab stages (photo -> palette + base).

This is the single place where the pipeline stages are wired together, so both
the CLI and the tests exercise the SAME composition instead of duplicating it.
Keeping the composition in the library (not in the CLI) also honors the
project rule that the logic lives in the library and the entry points stay
thin.

Two use-case modes (D24, ICEBOX I5 addendum #2, feature F11 "sneaker/product"):

- OUTFIT mode (default): the historical MVP pipeline — person
  background-removal (:mod:`colorlab.background`) + adaptive skin filter
  (:func:`colorlab.filters.gather_pixels` ``drop_skin``) + the
  use-case-agnostic CORE (K-means palette + LAB merge + harmony base).

- PRODUCT mode: sneaker/object photos have a clean background and no person,
  so the two PERSON-specific layers (background-removal and the skin filter)
  are irrelevant or even HARMFUL there (they can erase warm/tan product
  colors or crop a centered object). Product mode OMITS them and runs only the
  CORE on the whole frame. The CORE itself is untouched — this is composition,
  not a second algorithm.

Product mode is OFF by default: with ``product_mode=False`` (and the default
``remove_bg``/``drop_skin``) the output is byte-identical to the pre-D24
pipeline. The border-background layer (#48/#49) stays an orthogonal opt-in.

Phase 2.5 adds a THIRD entry point, :func:`analyze_garments`: when a
per-pixel segmentation class mask is available (on-device MediaPipe, or the
contract PNGs of :mod:`colorlab.segmentation`), attribution is solved by
construction — background, skin and hair pixels are never sampled — and the
analysis becomes PER GARMENT (upper/lower, D21). :func:`analyze_palette` is
untouched: no mask = the legacy whole-photo pipeline, byte-identical.
"""

from __future__ import annotations

import logging
from typing import NamedTuple

import numpy as np
from PIL import Image

from colorlab.background import remove_background
from colorlab.borders import (
    BackgroundCandidate,
    estimate_background_candidates,
    pick_harmony_base_avoiding_background,
    pick_harmony_base_index_avoiding_background,
    product_background_mask,
)
from colorlab.filters import gather_pixels
from colorlab.harmony import RGB, as_rgb, pick_harmony_base_index
from colorlab.palette import DEFAULT_COLORS, dominant_colors
from colorlab.segmentation import (
    REGION_LOWER,
    REGION_UPPER,
    MaskHardening,
    split_garment_masks,
)

logger = logging.getLogger(__name__)

# Product mode (D24) is opt-in: the default is the outfit pipeline. Named here
# so the flag has a single documented source of truth (CLI + Dart mirror it).
PRODUCT_MODE_DEFAULT = False

# Palette size PER GARMENT (Phase 2.5). A single garment is usually 1-2 colors
# plus shading; 3 keeps a two-tone garment plus one genuine accent without
# fragmenting a solid garment into swatch noise the way the whole-photo 5
# would. (The whole-photo default stays DEFAULT_COLORS.)
GARMENT_COLORS = 3


class PaletteAnalysis(NamedTuple):
    """Result of :func:`analyze_palette`.

    ``colors``/``weights`` are the dominant palette (as returned by
    :func:`colorlab.palette.dominant_colors`); ``base`` is the RGB the
    harmonies should be built on (:func:`colorlab.harmony.pick_harmony_base`).
    ``product_mode`` echoes the mode actually run, and
    ``background_candidates`` is the (possibly empty) list of border-background
    candidates — populated only when ``avoid_border_bg`` is on.

    ``base_index`` is the palette index of ``base``, or ``-1`` when NO color is
    eligible to lead the harmonies (a 100% neutral outfit, or one whose only
    chromatic colors were demoted): the canvas-mode signal (D10) the Dart
    engine already returns (``AnalysisResult.baseIndex``). ``base`` then keeps
    its historical fallback (the dominant color; the dominant eligible color
    with ``avoid_border_bg``) so existing callers see unchanged values —
    build harmonies on it only when ``base_index >= 0`` (bug B3, review F14).
    Appended LAST so positional unpacking of the older five fields still works.
    """

    colors: np.ndarray
    weights: np.ndarray
    base: RGB
    product_mode: bool
    background_candidates: list[BackgroundCandidate]
    base_index: int


def analyze_palette(
    img: Image.Image,
    *,
    n_colors: int = DEFAULT_COLORS,
    product_mode: bool = PRODUCT_MODE_DEFAULT,
    remove_bg: bool = True,
    drop_skin: bool = True,
    avoid_border_bg: bool = False,
) -> PaletteAnalysis:
    """Runs the pipeline over ``img`` and returns the palette + harmony base.

    Args:
        img: the input photo (PIL image).
        n_colors: number of dominant colors to extract.
        product_mode: when True (D24), SKIP the two person-specific layers
            (background-removal and the skin filter) and run only the CORE on
            the whole frame — for clean-background product/object photos.
            When True, ``remove_bg`` and ``drop_skin`` are forced off.
        remove_bg: outfit mode only — remove the person background
            (CLI ``--no-bg`` sets this False). Ignored in product mode.
        drop_skin: outfit mode only — filter the subject's skin tone
            (CLI ``--keep-skin`` sets this False). Ignored in product mode.
        avoid_border_bg: optional #48/#49 layer — demote uniform wall/floor
            border colors from leading the harmonies (orthogonal, off by
            default).

    Returns:
        A :class:`PaletteAnalysis`.

    Raises:
        :class:`colorlab.palette.NoPixelsError`: the foreground keeps no pixel
            (the background remover found no subject) — degrade loudly.
    """
    # Normalise the PIL mode like analyze_garments does: an RGBA/L/P image
    # from a library caller must not crash the LAB matmul or K-means with a
    # 4th (or missing) channel. A no-op for the CLI, whose load_image already
    # converts (review F13).
    if img.mode != "RGB":
        img = img.convert("RGB")

    # Product mode omits the person-specific layers. They are the ONLY
    # difference from outfit mode; the CORE below is shared verbatim.
    do_remove_bg = remove_bg and not product_mode
    do_drop_skin = drop_skin and not product_mode
    if product_mode:
        logger.info(
            "product mode (D24): skipping person background-removal and skin filter"
        )

    if do_remove_bg:
        rgb, fg_mask = remove_background(img)
    else:
        rgb = np.asarray(img)
        fg_mask = np.ones(rgb.shape[:2], dtype=bool)
        # Product mode (D24) has no person layers, so a busy real-world
        # background (floor, wall, pant legs) would otherwise win the palette on
        # raw pixel weight (Gate G2S first measurement, 2026-07-11 / #84).
        # Suppress it with the center-subject multi-edge model: colors wrapping
        # >= 2 image edges are background and their pixels are dropped BEFORE
        # clustering, so the product's own colors — including a white sole or a
        # black upper that would otherwise merge into the wall's mid-gray —
        # re-cluster cleanly. Self-disabling, so a clean/edge-to-edge product
        # shot falls back to the whole frame.
        if product_mode:
            drop = product_background_mask(rgb)
            if drop.any():
                fg_mask = ~drop
                logger.info(
                    "product mode: multi-edge background suppression dropped "
                    "%.0f%% of the frame",
                    drop.mean() * 100,
                )

    pixels = gather_pixels(rgb, fg_mask, drop_skin=do_drop_skin)
    # Product mode protects neutral lightness in the merge (#84): a product's
    # true white sole / black upper must stay its own swatch instead of
    # collapsing into a mid-gray. Outfit mode keeps the historical merge.
    colors, weights = dominant_colors(
        pixels, n_colors, protect_neutral_lightness=product_mode
    )

    # Harmony base: the index carries the -1 canvas signal (D10, review F14);
    # the RGB keeps the historical fallback on -1 (dominant color, or the
    # dominant eligible color under the border layer) so return values of
    # existing callers are byte-identical.
    candidates: list[BackgroundCandidate] = []
    if avoid_border_bg:
        candidates = estimate_background_candidates(rgb)
        base_index = pick_harmony_base_index_avoiding_background(
            colors, weights, candidates
        )
        base = (
            as_rgb(colors[base_index])
            if base_index >= 0
            else pick_harmony_base_avoiding_background(colors, weights, candidates)
        )
    else:
        base_index = pick_harmony_base_index(colors, weights)
        base = as_rgb(colors[base_index] if base_index >= 0 else colors[0])

    return PaletteAnalysis(
        colors=colors,
        weights=weights,
        base=base,
        product_mode=product_mode,
        background_candidates=candidates,
        base_index=base_index,
    )


class GarmentPalette(NamedTuple):
    """Palette of ONE garment region (Phase 2.5).

    ``colors``/``weights`` come from :func:`colorlab.palette.dominant_colors`
    over this garment's pixels only (weights sum to ~1 WITHIN the garment).
    ``base_index`` is :func:`colorlab.harmony.pick_harmony_base_index` on this
    garment alone — ``-1`` means the garment is fully neutral (a black tee, a
    white skirt). ``pixel_fraction`` is the garment's share of the FRAME
    (after mask erosion), used to weight it in the combined outfit palette.
    """

    colors: np.ndarray
    weights: np.ndarray
    base_index: int
    pixel_fraction: float


class GarmentAnalysis(NamedTuple):
    """Result of :func:`analyze_garments`.

    ``garments`` maps region name (``"upper"``/``"lower"``, only those
    present) to its :class:`GarmentPalette`. ``colors``/``weights`` are the
    combined OUTFIT palette: the per-garment palettes concatenated with each
    weight scaled by its garment's pixel share, sorted by weight (sum <= 1,
    the :data:`colorlab.palette.MIN_WEIGHT` residual-drop convention).
    They are deliberately NOT re-merged across garments so every swatch keeps
    its attribution — ``swatch_regions[i]`` names the garment that owns
    ``colors[i]`` (cross-garment display dedupe is a display-layer concern).

    ``base``/``base_index`` follow the :class:`PaletteAnalysis` conventions:
    the harmony base is chosen ACROSS garments — the most chromatically
    prominent garment color wins (decision #6), never a neutral; ``base_index``
    is ``-1`` for a 100% neutral outfit (canvas mode D10, with ``base``
    falling back to the dominant color) and ``base_region`` then is ``None``.
    """

    garments: dict[str, GarmentPalette]
    colors: np.ndarray
    weights: np.ndarray
    swatch_regions: tuple[str, ...]
    base: RGB
    base_index: int
    base_region: str | None


def analyze_garments(
    img: Image.Image,
    class_mask: np.ndarray,
    *,
    n_colors: int = GARMENT_COLORS,
    harden: MaskHardening | None = None,
) -> GarmentAnalysis:
    """Per-garment palette analysis driven by a segmentation mask (Phase 2.5).

    ``class_mask`` is a per-pixel class map with the SAME height/width as
    ``img``, using the MediaPipe class ids of :mod:`colorlab.segmentation`
    (generate it on-device, or with ``cv_core/tools/generate_masks.py``, or
    load a contract PNG via :func:`colorlab.segmentation.load_class_mask`).

    With a mask, the person-specific layers of :func:`analyze_palette` are
    all RETIRED: no background removal (background pixels are class 0), no
    YCbCr/adaptive skin filter (skin is classes 2-3), no border heuristics —
    hair (class 1, the #56 sub-class no heuristic covered) is excluded the
    same way. Only clothes pixels are sampled, split into upper/lower
    (:func:`colorlab.segmentation.split_garment_masks`, which also applies
    the erosion + min-region guards).

    ``harden`` (I2 condition C1c, OPT-IN): forwarded to
    :func:`colorlab.segmentation.split_garment_masks`, so the regions — and
    therefore the per-garment palettes, the outfit base and its harmonies —
    come from the HARDENED class map and the hip-line split. The recolor path
    passes :data:`colorlab.segmentation.RECOLOR_HARDENING` so the source colour
    of each region is measured on the same region it paints. The default
    ``None`` is the canonical path, byte-identical to the golden fixtures
    (the Dart palette parity); pass the RAW class map either way (the
    hardening growth is not idempotent).

    Raises :class:`colorlab.segmentation.NoPersonError` when the mask has no
    usable dressed person — callers fall back to :func:`analyze_palette`.
    """
    rgb = np.asarray(img.convert("RGB") if img.mode != "RGB" else img)
    class_mask = np.asarray(class_mask)
    if class_mask.shape != rgb.shape[:2]:
        raise ValueError(
            f"class mask shape {class_mask.shape} != photo shape {rgb.shape[:2]}"
        )

    masks = split_garment_masks(class_mask, harden=harden)  # may raise NoPersonError

    n_frame = rgb.shape[0] * rgb.shape[1]
    garments: dict[str, GarmentPalette] = {}
    for region in (REGION_UPPER, REGION_LOWER):
        mask = masks.get(region)
        if mask is None:
            continue
        pixels = rgb[mask].astype(float)
        colors, weights = dominant_colors(pixels, n_colors)
        # Per-garment DISPLAY base (person path, bug B-G25-1, 2026-07-18): the
        # ARRIBA/ABAJO block shows the garment's OWN dominant colour (max
        # weight), NOT the most-chromatic swatch — a small cross-garment/skin
        # contaminant was hijacking the block's base (grey top + red pants bleed
        # -> block showed red; gate G2.5 #18/#27/#34). Rule #6 (most chromatic)
        # is for HARMONY generation and stays on the COMBINED outfit base below.
        # BUT preserve the all-neutral canvas signal: when the garment has NO
        # chromatic colour, pick_harmony returns -1 -> keep -1 (drives the U7
        # "neutro" caption / canvas mode). Sneaker/product mode (analyze_palette)
        # is a separate path and keeps rule #6 untouched.
        _harm = pick_harmony_base_index(colors, weights)
        base_index = _harm if _harm < 0 else int(np.argmax(weights))
        garments[region] = GarmentPalette(
            colors=colors,
            weights=weights,
            base_index=base_index,
            pixel_fraction=len(pixels) / n_frame,
        )
        logger.info(
            "garment %r: %d px (%.1f%% of frame), %d colors, base_index=%d",
            region,
            len(pixels),
            garments[region].pixel_fraction * 100,
            len(colors),
            base_index,
        )

    # Combined outfit palette: concatenate, scaling each garment's weights by
    # its pixel share so the weights are comparable across garments.
    total_fraction = sum(g.pixel_fraction for g in garments.values())
    all_colors, all_weights, all_regions = [], [], []
    for region, g in garments.items():
        share = g.pixel_fraction / total_fraction
        all_colors.append(g.colors)
        all_weights.append(g.weights * share)
        all_regions.extend([region] * len(g.colors))
    colors = np.concatenate(all_colors)
    weights = np.concatenate(all_weights)
    regions = np.array(all_regions)
    order = np.argsort(-weights)
    colors, weights, regions = colors[order], weights[order], regions[order]

    # Harmony base ACROSS garments (decision #6 lifted to the outfit level):
    # the most chromatically prominent garment color leads; -1 = all-neutral
    # outfit -> canvas mode (D10), base falls back to the dominant color.
    base_index = pick_harmony_base_index(colors, weights)
    base = colors[base_index] if base_index >= 0 else colors[0]
    return GarmentAnalysis(
        garments=garments,
        colors=colors,
        weights=weights,
        swatch_regions=tuple(str(r) for r in regions),
        base=as_rgb(base),
        base_index=base_index,
        base_region=str(regions[base_index]) if base_index >= 0 else None,
    )
