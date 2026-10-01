"""Dominant color extraction (features 2 and 3).

Strategy: over-cluster with K-means (more clusters than requested) and then
merge the perceptually equal clusters in CIELAB space. This way the lighting
gradations of a single garment collapse into one color while minority but
distinctive colors (the outfit's "pop") survive.
"""

from __future__ import annotations

import logging

import numpy as np
from sklearn.cluster import KMeans

logger = logging.getLogger(__name__)


class NoPixelsError(ValueError):
    """There is no pixel to cluster.

    Raised by :func:`dominant_colors` on an empty pixel list and by
    :func:`colorlab.filters.gather_pixels` when the foreground mask is empty
    (reachable when the background remover returns an all-transparent alpha
    for a photo without a person). Typed, like
    :class:`colorlab.segmentation.NoPersonError`, so callers degrade LOUDLY
    (the app's E3 error path) instead of surfacing an opaque sklearn
    ``InvalidParameterError`` (review F12, 2026-09-30).
    """


DEFAULT_COLORS = 5

# Clusters weighing less than this are residual (noise, duplicates) and are dropped.
MIN_WEIGHT = 0.02

# Over-clustering factor: K-means starts with k * factor clusters to capture
# nuances (lighting gradations, minority colors) that are later merged if
# perceptually equal. With the default k (5) this yields 10 initial clusters,
# within the 8-10 range validated with the Vuitton photo.
OVERSEGMENT_FACTOR = 2

# Merge threshold in deltaE (Euclidean in CIELAB with attenuated L, see below).
# References: ~2.3 is the just-noticeable difference (JND), and at 10-20 two
# colors are perceived as "the same color" under different lighting.
# We chose 20.0, validated with samples/vuitton2006lr.jpg: the fuchsia
# variants of the same garment collapse by chaining through the closest pair,
# while the maroon and the lavender (dE > 60 from the fuchsia) stay intact.
MERGE_DELTA_E = 20.0

# Attenuation of the L term in the merge distance (equivalent to kL=2 of the
# TEXTILES variant of CIE94). Shading on a single garment moves lightness L a
# lot but barely a/b; with pure deltaE-76 the two halves (light/shadow) of the
# lavender sneakers in the Vuitton photo were 24.9 apart and did not merge,
# both dying separately under MIN_WEIGHT. With L/2 they are 12.7 apart and
# reunite, without merging genuinely distinct pairs (white-black stays at 50,
# navy-mustard at 100).
MERGE_LIGHTNESS_WEIGHT = 0.5

# Below this LAB chroma (C* = sqrt(a*^2 + b*^2)) a color reads as neutral
# (gray/black/white/beige). Perceptual chroma, NOT HSV saturation: saturation is
# numerically unstable near black — #030203 has HSV saturation 0.33 yet is
# visually black (bug B8) — and turns a dark blue-gray like #3A3946 (sat 0.19)
# into a false "chromatic" base (bug B5). Chroma separates dark-neutral (low C*)
# from dark-chromatic (a real maroon #601222 keeps C* ~37). Threshold 13 sits in
# the empty band between the neutrals (<= ~9) and the most washed-out real
# garment tones (>= ~18) measured on the batch-200 failures (#22). Canonical
# here (the color-space module); re-exported by :mod:`colorlab.harmony`.
NEUTRAL_CHROMA = 13.0

# When merging NEUTRAL-vs-NEUTRAL clusters, L* is the ONLY signal that separates
# white from gray from black (their a*/b* are all ~0), so attenuating it
# (MERGE_LIGHTNESS_WEIGHT) is exactly wrong there: it lets a near-white sole
# chain down into a mid-gray and render as gray (the white bug, #84 round 2 —
# e.g. a #CDDDD8 L87 sole collapsing into a #99998F L63 wall to a #A3A69E L68
# swatch). With neutral-lightness protection ON we score neutral-neutral pairs
# at FULL L, so white/gray/black stay distinct while similar neutrals (two light
# grays, or the two halves of one white) still merge. Chromatic pairs keep the
# attenuated L (garment shading still collapses). Opt-in — product mode only —
# so outfit-mode palettes are byte-identical.
NEUTRAL_MERGE_LIGHTNESS_WEIGHT = 1.0

# sRGB -> CIELAB conversion with D65 illuminant (pure numpy, portable to mobile).
# Linear sRGB -> XYZ matrix (IEC 61966-2-1) and D65 reference white.
_SRGB_TO_XYZ = np.array(
    [
        [0.4124564, 0.3575761, 0.1804375],
        [0.2126729, 0.7151522, 0.0721750],
        [0.0193339, 0.1191920, 0.9503041],
    ]
)
_D65_WHITE = np.array([0.95047, 1.0, 1.08883])
# Knee of the sRGB gamma curve (linear segment vs power segment).
_SRGB_GAMMA_KNEE = 0.04045
# Threshold (6/29)^3 of the linear segment of the LAB model's f(t) function.
_LAB_EPSILON = (6.0 / 29.0) ** 3


def srgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    """Converts sRGB 0-255 [..., 3] to CIELAB (D65) in pure numpy.

    No new dependencies: standard sRGB -> XYZ -> LAB implementation, good
    enough to measure deltaE-76 perceptual distances between clusters.
    """
    srgb = np.asarray(rgb, dtype=np.float64) / 255.0
    # Linearize the sRGB gamma curve.
    linear = np.where(
        srgb <= _SRGB_GAMMA_KNEE,
        srgb / 12.92,
        ((srgb + 0.055) / 1.055) ** 2.4,
    )
    xyz = linear @ _SRGB_TO_XYZ.T / _D65_WHITE
    f = np.where(
        xyz > _LAB_EPSILON,
        np.cbrt(xyz),
        xyz / (3.0 * (6.0 / 29.0) ** 2) + 4.0 / 29.0,
    )
    lightness = 116.0 * f[..., 1] - 16.0
    a = 500.0 * (f[..., 0] - f[..., 1])
    b = 200.0 * (f[..., 1] - f[..., 2])
    return np.stack([lightness, a, b], axis=-1)


def _merge_similar_colors(
    colors: np.ndarray,
    weights: np.ndarray,
    threshold: float,
    protect_neutral_lightness: bool = False,
) -> tuple[np.ndarray, np.ndarray]:
    """Iteratively merges the closest pair of colors in LAB.

    While a pair exists with deltaE < threshold (Euclidean in LAB with L
    attenuated by MERGE_LIGHTNESS_WEIGHT, CIE94-textiles style), the closest
    one is merged: center = weight-weighted mean, weight = sum of weights.
    We average in RGB because the merged colors are nearly equal by
    definition of the threshold (the error vs averaging in LAB is negligible
    and it saves us the inverse LAB -> sRGB conversion).

    When ``protect_neutral_lightness`` is set (product mode, #84), a pair in
    which BOTH clusters are neutral (chroma < NEUTRAL_CHROMA) is scored at FULL
    L instead of the attenuated L, so a near-white never collapses into a
    mid-gray it merely shares a hue-less axis with. Chromatic pairs are
    unaffected. Off by default: outfit-mode output is byte-identical.
    """
    colors = colors.astype(np.float64).copy()
    weights = weights.astype(np.float64).copy()
    lab_scale = np.array([MERGE_LIGHTNESS_WEIGHT, 1.0, 1.0])
    neutral_scale = np.array([NEUTRAL_MERGE_LIGHTNESS_WEIGHT, 1.0, 1.0])

    while len(colors) > 1:
        lab = srgb_to_lab(colors)
        att = lab * lab_scale
        # deltaE distance matrix (attenuated L) between all pairs of centers.
        dists = np.linalg.norm(att[:, None, :] - att[None, :, :], axis=-1)
        if protect_neutral_lightness:
            # For neutral-vs-neutral pairs, re-score at full L: L* is their only
            # separating axis, so attenuating it would fuse white into gray.
            full = lab * neutral_scale
            dists_full = np.linalg.norm(full[:, None, :] - full[None, :, :], axis=-1)
            is_neutral = np.hypot(lab[:, 1], lab[:, 2]) < NEUTRAL_CHROMA
            both_neutral = is_neutral[:, None] & is_neutral[None, :]
            dists = np.where(both_neutral, dists_full, dists)
        np.fill_diagonal(dists, np.inf)
        i, j = np.unravel_index(np.argmin(dists), dists.shape)
        if dists[i, j] >= threshold:
            break
        merged_weight = weights[i] + weights[j]
        merged_color = (colors[i] * weights[i] + colors[j] * weights[j]) / merged_weight
        logger.debug(
            "LAB merge: dE=%.1f, weights %.3f + %.3f",
            dists[i, j],
            weights[i],
            weights[j],
        )
        keep = np.ones(len(colors), dtype=bool)
        keep[[i, j]] = False
        colors = np.vstack([colors[keep], merged_color])
        weights = np.append(weights[keep], merged_weight)

    return colors, weights


def dominant_colors(
    pixels: np.ndarray,
    k: int = DEFAULT_COLORS,
    min_weight: float = MIN_WEIGHT,
    merge_delta_e: float = MERGE_DELTA_E,
    protect_neutral_lightness: bool = False,
) -> tuple[np.ndarray, np.ndarray]:
    """Dominant colors via K-means over a pixel list [N, 3].

    Over-clusters with k * OVERSEGMENT_FACTOR clusters and then merges the
    clusters whose deltaE distance in LAB (with attenuated L, see
    MERGE_LIGHTNESS_WEIGHT) is below merge_delta_e (merge_delta_e <= 0
    disables merging and is equivalent to plain K-means).

    ``protect_neutral_lightness`` (product mode, #84) keeps neutral clusters
    that differ mainly in lightness — white vs. gray vs. black — from merging
    into one gray; see :func:`_merge_similar_colors`. Off by default so
    outfit-mode palettes are unchanged.

    Returns (colors [m, 3] int, weights [m] float) sorted from most to least
    frequent, with m <= k, dropping clusters with weight < min_weight.
    """
    n_pixels = len(pixels)
    if n_pixels == 0:
        raise NoPixelsError("dominant_colors: empty pixel list, nothing to cluster")
    # Never request more clusters than available pixels (sklearn requires
    # n_samples >= n_clusters) — in BOTH the over-clustering and the raw
    # K-means (merge_delta_e <= 0) paths (F12).
    k_over = min(k * OVERSEGMENT_FACTOR if merge_delta_e > 0 else k, n_pixels)
    km = KMeans(n_clusters=k_over, n_init=4, random_state=42)
    labels = km.fit_predict(pixels)
    counts = np.bincount(labels, minlength=k_over)
    centers = np.clip(km.cluster_centers_, 0, 255)
    weights = counts / counts.sum()

    # Empty clusters add nothing and would break the weighted mean.
    occupied = counts > 0
    centers, weights = centers[occupied], weights[occupied]

    if merge_delta_e > 0:
        centers, weights = _merge_similar_colors(
            centers, weights, merge_delta_e, protect_neutral_lightness
        )

    order = np.argsort(-weights)
    centers, weights = centers[order][:k], weights[order][:k]
    keep = weights >= min_weight
    return np.rint(centers[keep]).astype(int), weights[keep]
