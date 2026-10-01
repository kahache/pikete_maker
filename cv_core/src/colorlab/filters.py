"""Pixel filtering prior to palette extraction (skin, masks).

Skin filter strategy (issue #20): instead of a universal YCbCr range (biased:
misses dark skin and erases warm garments), we sample the subject's ACTUAL
skin tone in the top band of the foreground (where the face is) and filter
only around that tone in CIELAB. The classic YCbCr heuristic remains as a
seed detector and as a documented fallback.
"""

from __future__ import annotations

import logging

import numpy as np

from colorlab.palette import NoPixelsError, srgb_to_lab

logger = logging.getLogger(__name__)

# If fewer pixels than this remain after filtering, the filter discarded
# itself (e.g. a photo that is almost all skin) and we fall back to the full
# foreground.
MIN_PIXELS = 50

# ---------------------------------------------------------------------------
# Classic YCbCr heuristic (Chai & Ngan): typical skin chroma range.
# Detects WELL-LIT skin of any tone; misses dark or shadowed skin because
# chroma amplitude drops with luminance.
# ---------------------------------------------------------------------------
SKIN_CR_RANGE = (135.0, 180.0)
SKIN_CB_RANGE = (85.0, 135.0)

# Minimum luma of the classic heuristic. KNOWN BIAS (issue #20, bug B1):
# it excludes dark skin. Kept only inside skin_mask() as a fallback when the
# subject's tone cannot be sampled; the main path is adaptive_skin_mask().
SKIN_LUMA_MIN = 80.0

# ---------------------------------------------------------------------------
# Adaptive filter (issue #20): subject tone sampling parameters.
# ---------------------------------------------------------------------------

# Top fraction of the foreground height where we look for face/neck.
FACE_BAND_FRACTION = 0.30

# Minimum seed pixels (skin chroma in the face band) to trust the sampled
# tone, and minimum fraction of the band they must cover.
MIN_SEED_PIXELS = 50
MIN_SEED_FRACTION = 0.05

# deltaE radius (with attenuated L, see SKIN_LIGHTNESS_WEIGHT) around the
# sampled tone that counts as skin. Calibrated with samples/g0: the subject's
# own skin sits at median dE ~5-7 (g0-01 chest, g0-05 face/neck in light and
# shadow >93% under 20) and 25 also cleans the deep-shadow skin of g0-05 (the
# remaining residue falls below the neutral threshold), while hair (g0-05,
# median 33), gray/white garments (>37) and the coral dress of g0-01 (median
# 47) stay out with a margin >= 5 dE.
SKIN_DELTA_E = 25.0

# Attenuation of the L term in the distance: light/shadow on the same skin
# moves L a lot but barely a/b (same criterion as the cluster merge).
SKIN_LIGHTNESS_WEIGHT = 0.5

# Anti-B2 guardrail: if the filter would remove more than this fraction of
# the foreground, the outfit is most likely skin-colored (camel, beige,
# coral...) and we filter NOTHING rather than erase the garments.
MAX_SKIN_FRACTION = 0.5


def _ycbcr(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Converts RGB 0-255 to (y, cb, cr) float channels (BT.601)."""
    r = rgb[..., 0].astype(float)
    g = rgb[..., 1].astype(float)
    b = rgb[..., 2].astype(float)
    y = 0.299 * r + 0.587 * g + 0.114 * b
    cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
    cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b
    return y, cb, cr


def _skin_chroma_mask(rgb: np.ndarray) -> np.ndarray:
    """Classic skin chroma WITHOUT the luma condition (works for well-lit dark skin)."""
    _, cb, cr = _ycbcr(rgb)
    return (
        (cr > SKIN_CR_RANGE[0])
        & (cr < SKIN_CR_RANGE[1])
        & (cb > SKIN_CB_RANGE[0])
        & (cb < SKIN_CB_RANGE[1])
    )


def skin_mask(rgb: np.ndarray) -> np.ndarray:
    """Approximate boolean skin mask in YCbCr (classic heuristic).

    WARNING: biased heuristic (issue #20): the minimum luma condition
    excludes dark skin and the universal range flags warm garments. It must
    only be used as a fallback when adaptive_skin_mask() finds no subject.
    """
    y, _, _ = _ycbcr(rgb)
    return _skin_chroma_mask(rgb) & (y > SKIN_LUMA_MIN)


def estimate_skin_tone(rgb: np.ndarray, fg_mask: np.ndarray) -> np.ndarray | None:
    """Estimates the subject's LAB skin tone by sampling the face band.

    Takes the top strip of the foreground (FACE_BAND_FRACTION of the
    subject's height, where face/neck almost always are), selects the pixels
    with skin chroma (classic rule WITHOUT luma, so as not to exclude dark
    skin) and returns their median in CIELAB. Returns None if there are not
    enough seeds (subject too far away/absent) — the caller decides the
    fallback.
    """
    rows = np.where(fg_mask.any(axis=1))[0]
    if len(rows) == 0:
        return None
    top, bottom = rows[0], rows[-1]
    band_end = top + max(1, int(FACE_BAND_FRACTION * (bottom - top + 1)))
    band = np.zeros_like(fg_mask)
    band[top:band_end] = True
    band &= fg_mask

    seeds = band & _skin_chroma_mask(rgb)
    n_seeds = int(seeds.sum())
    n_band = int(band.sum())
    if n_seeds < MIN_SEED_PIXELS or n_seeds < MIN_SEED_FRACTION * n_band:
        logger.info(
            "no reliable skin seeds in face band (%d px out of %d)", n_seeds, n_band
        )
        return None
    tone = srgb_to_lab(np.median(rgb[seeds].reshape(-1, 3).astype(float), axis=0))
    logger.info(
        "skin tone sampled in face band: LAB(%.0f, %.0f, %.0f) with %d seeds",
        tone[0],
        tone[1],
        tone[2],
        n_seeds,
    )
    return tone


def adaptive_skin_mask(rgb: np.ndarray, fg_mask: np.ndarray) -> np.ndarray:
    """Skin mask adapted to the subject (issue #20, replaces the universal range).

    Marks as skin the pixels within SKIN_DELTA_E (deltaE in LAB with
    attenuated L) of the tone sampled by estimate_skin_tone(). This way the
    subject's dark skin is filtered just like light skin (bug B1) and warm
    garments that do not match THEIR specific tone survive (bug B2).

    Guardrails:
    - No sampleable tone -> fallback to the classic skin_mask() heuristic.
    - If the resulting mask covers > MAX_SKIN_FRACTION of the foreground,
      those are probably skin-colored garments -> nothing is filtered.
    """
    tone = estimate_skin_tone(rgb, fg_mask)
    if tone is None:
        logger.info("skin filter: fallback to classic YCbCr heuristic")
        mask = skin_mask(rgb)
    else:
        lab = srgb_to_lab(rgb.astype(float))
        delta = lab - tone
        delta[..., 0] *= SKIN_LIGHTNESS_WEIGHT
        mask = np.sqrt((delta**2).sum(axis=-1)) < SKIN_DELTA_E

    fg_total = int(fg_mask.sum())
    if fg_total == 0:
        return np.zeros_like(fg_mask)
    skin_fraction = (mask & fg_mask).sum() / fg_total
    if skin_fraction > MAX_SKIN_FRACTION:
        logger.warning(
            "skin filter would cover %.0f%% of the foreground (> %.0f%%): "
            "probably a skin-colored outfit -> not filtering",
            skin_fraction * 100,
            MAX_SKIN_FRACTION * 100,
        )
        return np.zeros_like(fg_mask)
    return mask


def gather_pixels(
    rgb: np.ndarray, fg_mask: np.ndarray, drop_skin: bool = True
) -> np.ndarray:
    """Flattens the image into a pixel list [N, 3] honoring the masks.

    Raises :class:`colorlab.palette.NoPixelsError` when ``fg_mask`` selects no
    pixel at all (an empty foreground: the background remover found no
    subject), so the caller degrades loudly instead of crashing in K-means.
    """
    keep = fg_mask.copy()
    if drop_skin:
        skin = adaptive_skin_mask(rgb, fg_mask)
        keep = keep & ~skin
        fg_total = max(int(fg_mask.sum()), 1)
        logger.info(
            "skin tone dropped (%.0f%% of the foreground)",
            (skin & fg_mask).sum() / fg_total * 100,
        )
    pixels = rgb[keep]
    if len(pixels) < MIN_PIXELS:
        logger.warning("almost no pixels left after filtering -> using full foreground")
        pixels = rgb[fg_mask]
    if len(pixels) == 0:
        raise NoPixelsError(
            "empty foreground: the background mask keeps no pixel to analyze "
            "(no subject in the photo?)"
        )
    return pixels.astype(float)
