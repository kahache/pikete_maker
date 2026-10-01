"""Background models estimated from the image edges.

This module holds two complementary, self-disabling background estimators that
share the same principle — a color that dominates the frame's edges is probably
background, not subject — but serve different pipelines:

1. Two-color WALL/FLOOR model (issue #48, OUTFIT mode, opt-in). The frame is
   split into a WALL band (top + left + right) and a FLOOR band (bottom); each
   band that is almost uniform contributes one candidate, and palette colors
   close to a candidate are DEMOTED from harmony-BASE eligibility — the palette
   itself is never touched. Evaluated against the CEO's 50 labeled rows + 4
   private selfies (docs/architecture/2026-07-09_*_F1_three-border-rnd.md):
   net +2 with zero broken CEO-correct rows, stable across sim in [13, 15] x
   coverage in [0.83, 0.90]. Off by default; only affects which color leads.

2. Multi-EDGE co-occurrence model (issue #84, PRODUCT mode). A centered product
   (a sneaker in the guided #83 shot) touches AT MOST 1-2 adjacent image edges;
   the background wraps 3+. So a color that appears on >= 3 DISTINCT edges is
   flagged as background and its pixels are DROPPED before clustering (a mask,
   not just base demotion), so the product's own colors — including a white
   sole or a black upper that a whole-frame K-means would otherwise MERGE into a
   mid-gray shared with the wall/floor — re-cluster cleanly. This is the
   center-subject background suppression the Gate G2S first-measurement review
   (2026-07-11) found product mode needs: D24's "clean background" premise is
   falsified by real phone photos (floors, walls, pant legs). Validated on the
   phone + store product sets: the harmony base flips from floor/wall to the
   real sneaker color and true white/black resurface as swatches.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import numpy as np

from colorlab.harmony import RGB, as_rgb, pick_harmony_base, pick_harmony_base_index
from colorlab.palette import dominant_colors, srgb_to_lab

logger = logging.getLogger(__name__)

# Width of the border strips as a fraction of min(height, width). 0.04 was the
# better of the two widths evaluated in #44 (0.08 diluted the band with subject
# pixels) and is reused here unchanged.
BORDER_BAND_FRACTION = 0.04

# deltaE radius (attenuated L, repo convention) that counts as "the same
# background color", used both for the band coverage measure and for demoting
# palette colors. 15 is the safe edge of the evaluated plateau: at sim >= 16
# the layer starts breaking CEO-correct rows (garments 15-20 dE from the wall
# get demoted).
BORDER_SIMILARITY_DELTA_E = 15.0

# Minimum fraction of a band covered by its dominant color for that color to
# qualify as a background candidate. This is the #48 recalibration: the loose
# #44 gate (0.45-0.60 on a mixed band) fired on MORE CEO-correct rows than on
# background failures; at 0.85 per clean band the layer only acts on nearly
# uniform walls/floors and broke zero CEO-correct rows in the evaluation.
BORDER_COVERAGE_MIN = 0.85

# Clusters used to summarize a band. 3 absorbs shadows/gradients so the
# dominant cluster represents the actual surface color (same as #44).
BORDER_BAND_CLUSTERS = 3

# Attenuation of the L term in deltaE: same convention as the palette merge
# and the skin filter (lighting moves L a lot but barely a/b).
BORDER_LIGHTNESS_WEIGHT = 0.5


@dataclass(frozen=True)
class BackgroundCandidate:
    """A border-band color that qualified as probable background."""

    origin: str  # "wall" (top + sides) or "floor" (bottom)
    color: RGB
    coverage: float  # fraction of its band within the similarity radius


def _attenuated_delta_e(lab_pixels: np.ndarray, rgb_color: RGB) -> np.ndarray:
    """deltaE-76 with attenuated L between LAB pixels [..., 3] and one sRGB color."""
    delta = lab_pixels - srgb_to_lab(np.asarray(rgb_color, dtype=float))
    delta[..., 0] *= BORDER_LIGHTNESS_WEIGHT
    return np.sqrt((delta**2).sum(axis=-1))


def _band_masks(
    height: int, width: int, band_fraction: float
) -> tuple[np.ndarray, np.ndarray]:
    """Boolean masks for the wall band (top + sides, excluding the bottom
    strip rows so no floor pixel pollutes the wall estimate) and the floor
    band (bottom strip, full width)."""
    thickness = max(1, round(band_fraction * min(height, width)))
    wall = np.zeros((height, width), dtype=bool)
    wall[:thickness, :] = True  # top strip
    wall[: height - thickness, :thickness] = True  # left strip, above the floor strip
    wall[: height - thickness, -thickness:] = True  # right strip, idem
    floor = np.zeros((height, width), dtype=bool)
    floor[-thickness:, :] = True
    return wall, floor


def _band_candidate(
    rgb: np.ndarray,
    band_mask: np.ndarray,
    origin: str,
    similarity_delta_e: float,
    coverage_min: float,
) -> BackgroundCandidate | None:
    """Dominant band color if the band is uniform enough, else None."""
    band_pixels = rgb[band_mask].astype(float)
    colors, _ = dominant_colors(band_pixels, k=BORDER_BAND_CLUSTERS)
    top = as_rgb(colors[0])
    distances = _attenuated_delta_e(srgb_to_lab(band_pixels), top)
    coverage = float((distances < similarity_delta_e).mean())
    if coverage < coverage_min:
        logger.info(
            "%s band not uniform enough (coverage %.0f%% < %.0f%%): no candidate",
            origin,
            coverage * 100,
            coverage_min * 100,
        )
        return None
    logger.info(
        "%s background candidate %s (coverage %.0f%%)",
        origin,
        "#%02X%02X%02X" % top,
        coverage * 100,
    )
    return BackgroundCandidate(origin=origin, color=top, coverage=coverage)


def estimate_background_candidates(
    rgb: np.ndarray,
    band_fraction: float = BORDER_BAND_FRACTION,
    similarity_delta_e: float = BORDER_SIMILARITY_DELTA_E,
    coverage_min: float = BORDER_COVERAGE_MIN,
) -> list[BackgroundCandidate]:
    """Estimates up to two background candidates (wall, floor) from the frame.

    A busy band (coverage below coverage_min) yields no candidate: the layer
    switches itself off rather than guessing (the do-no-harm lesson of #29/#44).
    """
    height, width = rgb.shape[:2]
    wall_mask, floor_mask = _band_masks(height, width, band_fraction)
    candidates = []
    for origin, mask in (("wall", wall_mask), ("floor", floor_mask)):
        candidate = _band_candidate(rgb, mask, origin, similarity_delta_e, coverage_min)
        if candidate is not None:
            candidates.append(candidate)
    return candidates


def _background_eligible(
    colors: np.ndarray,
    candidates: list[BackgroundCandidate],
    similarity_delta_e: float,
) -> np.ndarray:
    """Boolean mask [m] of the palette colors still ELIGIBLE to lead harmonies.

    Palette colors within ``similarity_delta_e`` of ANY qualified candidate are
    demoted. All-True (the layer is inert) when no candidate qualified, or when
    demotion would leave nothing eligible (the whole palette looks like
    background — more likely a monochrome outfit): do-no-harm, #29/#44 lesson.
    """
    eligible = np.ones(len(colors), dtype=bool)
    if not candidates:
        return eligible
    lab = srgb_to_lab(np.asarray(colors, dtype=float))
    background_like = np.zeros(len(colors), dtype=bool)
    for candidate in candidates:
        background_like |= (
            _attenuated_delta_e(lab, candidate.color) < similarity_delta_e
        )
    if background_like.all():
        logger.info(
            "all palette colors look like the border background: keeping baseline base"
        )
        return eligible
    if background_like.any():
        demoted = [
            "#%02X%02X%02X" % as_rgb(c) for c in np.asarray(colors)[background_like]
        ]
        logger.info("demoted from harmony-base eligibility: %s", ", ".join(demoted))
    return ~background_like


def pick_harmony_base_index_avoiding_background(
    colors: np.ndarray,
    weights: np.ndarray,
    candidates: list[BackgroundCandidate],
    similarity_delta_e: float = BORDER_SIMILARITY_DELTA_E,
) -> int:
    """Index of the harmony base with background-like colors demoted, or -1.

    The index/``-1`` contract of :func:`colorlab.harmony.pick_harmony_base_index`
    lifted to the border layer, mirroring the Dart
    ``pickHarmonyBaseAvoidingBackground``: the normal base pick runs over the
    eligible survivors and the result is mapped back to the ORIGINAL palette
    index; when the survivors are all neutral the ``-1`` canvas signal (D10)
    propagates instead of silently falling back to a neutral (review F14).
    The palette and its weights are never modified.
    """
    colors, weights = np.asarray(colors), np.asarray(weights)
    eligible = _background_eligible(colors, candidates, similarity_delta_e)
    sub = pick_harmony_base_index(colors[eligible], weights[eligible])
    return -1 if sub < 0 else int(np.flatnonzero(eligible)[sub])


def pick_harmony_base_avoiding_background(
    colors: np.ndarray,
    weights: np.ndarray,
    candidates: list[BackgroundCandidate],
    similarity_delta_e: float = BORDER_SIMILARITY_DELTA_E,
) -> RGB:
    """pick_harmony_base with background-like colors demoted from eligibility.

    Historical RGB form: when the eligible survivors are all neutral it falls
    back to the dominant SURVIVOR (which can be a near-black), exactly as
    :func:`colorlab.harmony.pick_harmony_base` falls back to the dominant
    color. Callers that must detect canvas mode (D10) use
    :func:`pick_harmony_base_index_avoiding_background` instead; this form is
    kept so existing return values stay byte-identical.
    """
    colors, weights = np.asarray(colors), np.asarray(weights)
    eligible = _background_eligible(colors, candidates, similarity_delta_e)
    return pick_harmony_base(colors[eligible], weights[eligible])


# ---------------------------------------------------------------------------
# Multi-edge co-occurrence background model (issue #84, PRODUCT mode)
# ---------------------------------------------------------------------------

# Thickness of each of the four edge bands, as a fraction of min(h, w). 0.06 is
# a touch wider than the #48 wall/floor band (0.04): a product shot's edge is
# more likely to carry a lighting gradient (a floor receding under the sneaker),
# and a slightly thicker band gives K-means enough pixels to summarize it.
EDGE_BAND_FRACTION = 0.06

# Clusters used to summarize each edge band. 3 absorbs shadows/gradients so a
# receding floor or a lit wall is still captured by one dominant cluster (same
# reasoning as BORDER_BAND_CLUSTERS in the #48 model).
EDGE_BAND_CLUSTERS = 3

# deltaE radius (attenuated L, repo convention) at which a pixel/color counts as
# "the same color" as an edge cluster — used both to measure an edge candidate's
# coverage of a band and to select the pixels dropped from the frame. 16 sits
# just above the #48 wall radius (15): floors span more lighting variation than
# a flat studio wall, so a marginally wider radius catches the whole surface
# without reaching into a distinctly-colored sneaker (validated on the product
# sets — the sneaker's chromatic colors and true white/black stay clear of it).
EDGE_MATCH_DELTA_E = 16.0

# Minimum fraction of an edge band that a candidate color must cover to count as
# "present" on that edge. 0.30 tolerates an edge partly occupied by the subject
# (a sneaker resting across the bottom edge) while still requiring the color to
# be a real, substantial part of the band — not an incidental speck.
EDGE_PRESENCE_MIN = 0.30

# Number of DISTINCT edges a color must be present on to be judged background
# and hard-dropped. 3 (not 2) is the CEO's false-positive-safe threshold for the
# GUIDED sneaker flow (tutorial #83 orients the user to a centered shot on a
# floor): the sneaker itself touches AT MOST 1-2 adjacent edges — only the
# surrounding floor/wall wraps 3+. Requiring >= 3 therefore never nukes a
# sneaker color that merely shares the bottom-edge floor tone, while still
# catching every real background (validated on the phone + store product sets:
# the >= 3 rule keeps every base-flip and white/black recovery that the looser
# >= 2 rule found, minus one white-on-white-background shot whose background
# happens to wrap only 2 edges — left as known residual, not worth the
# false-positive risk of dropping to >= 2). A softer >= 2 base-eligibility
# DEMOTE (never a pixel drop) is a possible future lever if that residual grows.
MULTI_EDGE_MIN = 3

# Two candidate edge colors within this deltaE (attenuated L) are treated as the
# same background color when de-duplicating, so the same floor sampled on three
# edges yields one entry instead of three near-identical ones.
EDGE_DEDUP_DELTA_E = 8.0

# Guardrail: if the multi-edge mask would drop MORE than this fraction of the
# frame, the "background" is really a frame-filling subject (a solid-color
# sneaker shot edge to edge) whose single color naturally touches every edge —
# suppress nothing and let the whole-frame palette stand. 0.99 (not lower) so
# the genuinely useful aggressive cases — a small product on a large uniform
# background, which correctly drop 90-98% — are kept; only a near-total wipe
# (the subject IS the flagged color) trips the guard.
PRODUCT_BG_MAX_COVERAGE = 0.99


def _four_edge_masks(
    height: int, width: int, band_fraction: float
) -> dict[str, np.ndarray]:
    """Boolean masks for the four independent edge bands (top/bottom/left/right).

    Unlike the #48 wall/floor split, the bands are kept separate (and may
    overlap at the corners) so co-occurrence across DISTINCT edges can be
    counted — the core signal of the multi-edge model.
    """
    thickness = max(1, round(band_fraction * min(height, width)))
    top = np.zeros((height, width), dtype=bool)
    top[:thickness, :] = True
    bottom = np.zeros((height, width), dtype=bool)
    bottom[-thickness:, :] = True
    left = np.zeros((height, width), dtype=bool)
    left[:, :thickness] = True
    right = np.zeros((height, width), dtype=bool)
    right[:, -thickness:] = True
    return {"top": top, "bottom": bottom, "left": left, "right": right}


def _dedup_colors(colors: list[RGB], delta_e: float) -> list[RGB]:
    """Collapses near-identical colors (attenuated-L deltaE) into one each."""
    kept: list[RGB] = []
    for color in colors:
        lab = srgb_to_lab(np.asarray([color], dtype=float))
        if not any(_attenuated_delta_e(lab, k)[0] < delta_e for k in kept):
            kept.append(color)
    return kept


def estimate_multiedge_background(
    rgb: np.ndarray,
    band_fraction: float = EDGE_BAND_FRACTION,
    match_delta_e: float = EDGE_MATCH_DELTA_E,
    presence_min: float = EDGE_PRESENCE_MIN,
    min_edges: int = MULTI_EDGE_MIN,
) -> list[RGB]:
    """Colors that occur on >= ``min_edges`` distinct image edges (background).

    Each of the four edge bands is summarized by K-means; every resulting
    candidate color is then tested against ALL four bands, and a candidate is
    returned as background when it substantially covers (``presence_min``) at
    least ``min_edges`` of them. Returns an empty list when nothing qualifies
    (a clean single-edge or subject-filled frame), so the caller's suppression
    switches itself off — the do-no-harm lesson carried over from #29/#44/#48.
    """
    height, width = rgb.shape[:2]
    edge_masks = _four_edge_masks(height, width, band_fraction)
    edge_labs = {
        name: srgb_to_lab(rgb[mask].astype(float)) for name, mask in edge_masks.items()
    }

    # Candidate background colors = the dominant colors of each edge band.
    candidates: list[RGB] = []
    for mask in edge_masks.values():
        colors, _ = dominant_colors(rgb[mask].astype(float), k=EDGE_BAND_CLUSTERS)
        candidates.extend(as_rgb(color) for color in colors)
    candidates = _dedup_colors(candidates, EDGE_DEDUP_DELTA_E)

    background: list[RGB] = []
    for color in candidates:
        hits = sum(
            1
            for lab_pixels in edge_labs.values()
            if float((_attenuated_delta_e(lab_pixels, color) < match_delta_e).mean())
            >= presence_min
        )
        if hits >= min_edges:
            background.append(color)
    background = _dedup_colors(background, EDGE_DEDUP_DELTA_E)
    if background:
        logger.info(
            "multi-edge background (>= %d edges): %s",
            min_edges,
            ", ".join("#%02X%02X%02X" % c for c in background),
        )
    return background


def multiedge_background_mask(
    rgb: np.ndarray,
    bg_colors: list[RGB],
    match_delta_e: float = EDGE_MATCH_DELTA_E,
) -> np.ndarray:
    """Boolean mask of pixels within ``match_delta_e`` of any background color."""
    if not bg_colors:
        return np.zeros(rgb.shape[:2], dtype=bool)
    lab = srgb_to_lab(rgb.astype(float))
    drop = np.zeros(rgb.shape[:2], dtype=bool)
    for color in bg_colors:
        drop |= _attenuated_delta_e(lab, color) < match_delta_e
    return drop


def product_background_mask(
    rgb: np.ndarray,
    band_fraction: float = EDGE_BAND_FRACTION,
    match_delta_e: float = EDGE_MATCH_DELTA_E,
    presence_min: float = EDGE_PRESENCE_MIN,
    min_edges: int = MULTI_EDGE_MIN,
    max_coverage: float = PRODUCT_BG_MAX_COVERAGE,
) -> np.ndarray:
    """Center-subject background mask for PRODUCT mode (issue #84).

    Estimates the multi-edge background colors and returns the mask of pixels to
    drop before clustering. Self-disables (returns an all-False mask) both when
    no color qualifies as background AND when the mask would cover more than
    ``max_coverage`` of the frame (the flagged color IS a frame-filling
    subject) — so the whole-frame palette is the graceful fallback in the two
    ambiguous extremes.
    """
    bg_colors = estimate_multiedge_background(
        rgb, band_fraction, match_delta_e, presence_min, min_edges
    )
    mask = multiedge_background_mask(rgb, bg_colors, match_delta_e)
    coverage = float(mask.mean())
    if coverage > max_coverage:
        logger.info(
            "multi-edge background would cover %.0f%% of the frame (> %.0f%%): "
            "subject likely fills it — suppressing nothing",
            coverage * 100,
            max_coverage * 100,
        )
        return np.zeros(rgb.shape[:2], dtype=bool)
    return mask
