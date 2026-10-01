"""Segmentation-driven garment attribution (Phase 2.5, D21).

This module is the canonical Python side of the on-device segmenter: the
MASK CONTRACT (how a per-pixel class map is represented, stored and split
into garment regions), NOT an inference engine. Inference lives outside the
library (``cv_core/tools/generate_masks.py`` via the optional ``seg`` extra,
or the Dart `MediaPipeGarmentSegmenter` on-device) and hands the class map
in through :func:`colorlab.pipeline.analyze_garments`.

Class map = MediaPipe Selfie Multiclass 256x256 (D21): one uint8 per pixel,
values 0..5 (:data:`CLASS_BACKGROUND` .. :data:`CLASS_OTHERS`). The learned
skin/hair classes are what RETIRES the YCbCr skin proxy and the border
background heuristics for outfit photos: when a mask is present, background,
skin and hair pixels are simply never sampled (attribution by construction,
the #56 error buckets).

File contract (agreed with QA for the eval battery hand-off): a GRAYSCALE
8-bit PNG with the SAME width/height as the photo, where the pixel VALUE is
the class id (0..5). No palette, no scaling to 0..255 — a mask viewer will
show it near-black, that is expected. Suggested naming: ``<photo>.mask.png``
next to the photo.

The pre/post-processing helpers (:func:`preprocess_rgb`,
:func:`class_map_from_scores`, :func:`upscale_class_map`,
:func:`split_garment_masks`) mirror the Dart implementation in
``app/lib/core/segmentation/mediapipe_garment_segmenter.dart`` STEP BY STEP
(bilinear resize convention included) so that a mask generated in Python and
one generated on-device are interchangeable. Parity was verified on
``samples/vuitton2006lr.jpg`` against the on-device spike numbers
(``docs/architecture/2026-07-14_2235_F2.5_mediapipe-ondevice-spike.md`` §4).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

import cv2
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Model contract — MediaPipe Selfie Multiclass 256x256 (D21). Mirror of the
# Dart constants in MediaPipeGarmentSegmenter; do not renumber.
# ---------------------------------------------------------------------------
CLASS_BACKGROUND = 0
CLASS_HAIR = 1
CLASS_BODY_SKIN = 2
CLASS_FACE_SKIN = 3
CLASS_CLOTHES = 4
CLASS_OTHERS = 5
NUM_CLASSES = 6

# Model input/output side (square).
MODEL_SIDE = 256

# Garment region names (v1 = top/bottom split, D21; footwear = ICEBOX I1).
# These strings are the keys of every per-garment dict in the library and
# will be baked into golden fixtures — do not rename.
REGION_UPPER = "upper"
REGION_LOWER = "lower"

# Minimum fraction of pixels that must be clothes to accept the frame as "a
# dressed person". Mirror of Dart `minClothesCoverage`: the prototype measured
# clothes coverage > 1% on 35/35 real selfies (mean 25.1%).
MIN_CLOTHES_COVERAGE = 0.01

# Mask hygiene before sampling pixels (spike §4): the 256 -> full-res
# nearest-neighbor upscale leaves blocky edges, so a few boundary pixels of
# every garment mask are really background/skin. Eroding the mask 2 px keeps
# that boundary bleed out of the palette.
MASK_ERODE_PX = 2

# A garment region smaller than this fraction of the FRAME (after erosion) is
# treated as absent rather than emitting a confident palette from a handful
# of pixels (e.g. a sliver of waistband when the photo is chest-up).
MIN_REGION_FRACTION = 0.005


class NoPersonError(ValueError):
    """The class map has no usable dressed person (clothes coverage below
    :data:`MIN_CLOTHES_COVERAGE`, or no garment region survived the guards).

    Mirror of the Dart ``SegmentationException(isNoPerson: true)`` loud-degrade
    path: callers fall back to the whole-photo pipeline
    (:func:`colorlab.pipeline.analyze_palette`), never a silent wrong answer.
    """


# ---------------------------------------------------------------------------
# Mask file contract (grayscale-PNG-class-id, shared with the QA battery).
# ---------------------------------------------------------------------------


def save_class_mask(class_map: np.ndarray, path: str) -> None:
    """Writes a class map as the contract's grayscale 8-bit PNG."""
    class_map = _validate_class_map(class_map)
    Image.fromarray(class_map, mode="L").save(path, format="PNG")


def load_class_mask(path: str) -> np.ndarray:
    """Loads a contract PNG back into a uint8 [H, W] class map.

    Validates the contract: single-channel image, values < NUM_CLASSES. A
    colored or 0..255-scaled mask fails loudly here instead of silently
    attributing every pixel to "others".
    """
    img = Image.open(path)
    if img.mode != "L":
        raise ValueError(
            f"class mask {path!r} must be a grayscale (mode 'L') PNG, got mode {img.mode!r}"
        )
    return _validate_class_map(np.asarray(img))


def _validate_class_map(class_map: np.ndarray) -> np.ndarray:
    class_map = np.asarray(class_map)
    if class_map.ndim != 2:
        raise ValueError(f"class map must be 2-D [H, W], got shape {class_map.shape}")
    # The uint8 cast below would silently TRUNCATE a float map (4.9 -> 4) and
    # WRAP a negative id (-1 -> 255, "not clothes"): both are contract
    # violations that must fail loudly here (review F15).
    if not np.issubdtype(class_map.dtype, np.integer):
        raise ValueError(
            f"class map must have an integer dtype, got {class_map.dtype}: "
            "not a class-id mask (scores/probabilities? take the argmax first)"
        )
    min_id = int(class_map.min()) if class_map.size else 0
    max_id = int(class_map.max()) if class_map.size else 0
    if min_id < 0:
        raise ValueError(
            f"class map has negative value {min_id}: not a class-id mask "
            "(a uint8 cast would wrap it into a valid-looking id)"
        )
    if max_id >= NUM_CLASSES:
        raise ValueError(
            f"class map has value {max_id} >= NUM_CLASSES ({NUM_CLASSES}): "
            "not a class-id mask (a scaled/visualization PNG?)"
        )
    return class_map.astype(np.uint8, copy=False)


# ---------------------------------------------------------------------------
# Pre/post-processing — Dart parity (mediapipe_garment_segmenter.dart).
# ---------------------------------------------------------------------------


def preprocess_rgb(rgb: np.ndarray) -> np.ndarray:
    """RGB uint8 [H, W, 3] -> float32 [MODEL_SIDE, MODEL_SIDE, 3] in [0, 1].

    Bilinear resize with the exact sampling convention of the Dart
    ``preprocess`` (center-aligned: ``src = (dst + 0.5) * scale - 0.5``,
    clamped at 0 on the low side, edge-clamped neighbors), then /255. Kept
    sample-for-sample identical so Python masks == on-device masks.
    """
    h, w = rgb.shape[:2]

    def _axis(size: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        src = (np.arange(MODEL_SIDE) + 0.5) * (size / MODEL_SIDE) - 0.5
        src = np.maximum(src, 0.0)
        lo = np.floor(src).astype(np.int64)
        hi = np.minimum(lo + 1, size - 1)
        return lo, hi, src - lo

    y0, y1, fy = _axis(h)
    x0, x1, fx = _axis(w)
    img = rgb.astype(np.float32)
    top = img[y0][:, x0] * (1 - fx)[None, :, None] + img[y0][:, x1] * fx[None, :, None]
    bot = img[y1][:, x0] * (1 - fx)[None, :, None] + img[y1][:, x1] * fx[None, :, None]
    out = top * (1 - fy)[:, None, None] + bot * fy[:, None, None]
    return (out / 255.0).astype(np.float32)


def class_map_from_scores(scores: np.ndarray) -> np.ndarray:
    """[MODEL_SIDE, MODEL_SIDE, NUM_CLASSES] scores -> uint8 argmax class map.

    Ties resolve to the LOWEST class index (numpy argmax first-max), same as
    the Dart strict ``>`` scan.
    """
    if scores.shape != (MODEL_SIDE, MODEL_SIDE, NUM_CLASSES):
        raise ValueError(
            f"scores shape {scores.shape} != ({MODEL_SIDE}, {MODEL_SIDE}, {NUM_CLASSES})"
        )
    return scores.argmax(axis=-1).astype(np.uint8)


def upscale_class_map(map256: np.ndarray, width: int, height: int) -> np.ndarray:
    """Nearest-neighbor upscale of the model-side class map to (height, width).

    Same index arithmetic as the Dart ``_upscaleNearest``
    (``my = y * MODEL_SIDE // height``), so edge blockiness is identical too —
    which is exactly what :data:`MASK_ERODE_PX` compensates downstream.
    """
    map256 = _validate_class_map(map256)
    if (height, width) == map256.shape:
        return map256
    ys = np.arange(height) * map256.shape[0] // height
    xs = np.arange(width) * map256.shape[1] // width
    return map256[ys][:, xs]


# ---------------------------------------------------------------------------
# Garment isolation (the attribution layer).
# ---------------------------------------------------------------------------


def erode_mask(mask: np.ndarray, radius: int) -> np.ndarray:
    """Erodes a boolean mask by ``radius`` px (square kernel). radius 0 = no-op."""
    if radius <= 0:
        return mask
    kernel = np.ones((2 * radius + 1, 2 * radius + 1), np.uint8)
    return cv2.erode(mask.astype(np.uint8), kernel).astype(bool)


def split_garment_masks(
    class_map: np.ndarray,
    *,
    erode_px: int = MASK_ERODE_PX,
    min_region_fraction: float = MIN_REGION_FRACTION,
    harden: MaskHardening | None = None,
) -> dict[str, np.ndarray]:
    """Full-res class map -> {region: bool mask} for the present garments.

    Steps (1:1 with the Dart ``buildMasks``, plus the two hygiene guards the
    spike flagged for v1):

    1. clothes coverage < :data:`MIN_CLOTHES_COVERAGE` -> :class:`NoPersonError`;
    2. clothes bounding-box mid-row split -> upper / lower (v1 geometric
       split, D21; v1.1 = Pose hip line);
    3. each region mask eroded ``erode_px`` px (edge-bleed hygiene, spike §4).
       Eroding per REGION (not the whole clothes mask) also trims the
       upper/lower seam, so hem-transition pixels vote in neither garment;
    4. a region below ``min_region_fraction`` of the frame after erosion is
       dropped (absent garment, e.g. chest-up framing). If NO region survives,
       :class:`NoPersonError` (loud degrade, same fallback as step 1).

    ``harden`` (I2 condition C1, OPT-IN, default ``None`` = the canonical path
    above, byte-identical to the golden fixtures): the class map first goes
    through :func:`harden_class_map` with those options and, when
    ``harden.hip_split`` is set, step 2 uses :func:`hip_split_row` (waist
    minimum of the clothes width profile, mid-row fallback) instead of the
    bare mid-row. Not idempotent when ``harden.grow_px > 0`` (the growth is
    applied on every call), so pass the RAW map, not one already hardened.

    Returns an ordered dict — :data:`REGION_UPPER` first — with only the
    regions actually present.
    """
    class_map = _validate_class_map(class_map)
    if harden is not None:
        class_map = harden_class_map(class_map, harden)
    clothes = class_map == CLASS_CLOTHES
    n_pixels = class_map.size
    if int(clothes.sum()) < n_pixels * MIN_CLOTHES_COVERAGE:
        raise NoPersonError(
            "no dressed person found (clothes coverage below threshold)"
        )

    rows = np.where(clothes.any(axis=1))[0]
    mid = (int(rows[0]) + int(rows[-1])) // 2
    if harden is not None and harden.hip_split:
        mid, _ = hip_split_row(clothes)
    upper = clothes.copy()
    upper[mid:] = False
    lower = clothes.copy()
    lower[:mid] = False

    masks: dict[str, np.ndarray] = {}
    for region, mask in ((REGION_UPPER, upper), (REGION_LOWER, lower)):
        eroded = erode_mask(mask, erode_px)
        count = int(eroded.sum())
        if count < n_pixels * min_region_fraction:
            logger.info(
                "garment region %r dropped: %d px after erosion (< %.2f%% of frame)",
                region,
                count,
                min_region_fraction * 100,
            )
            continue
        masks[region] = eroded

    if not masks:
        raise NoPersonError("no garment region survived erosion + min-size guards")
    return masks


# ---------------------------------------------------------------------------
# Mask hardening (ICEBOX I2 condition C1, 2026-09-30) — OPT-IN.
#
# The palette path can live with a blocky, holed or fragmented clothes mask
# (erosion + K-means average the defects away); a RECOLOR cannot, because it
# paints every mask error onto the user's own photo. Everything below is a
# pure function of the class map, behind :class:`MaskHardening`, and the
# canonical path (``harden=None``) is untouched so the golden fixtures and the
# Dart parity stay byte-identical. The recolor path opts in with
# :data:`RECOLOR_HARDENING`.
# ---------------------------------------------------------------------------

# Smoothed resample: per-class one-hot planes are resized with area (down) /
# bilinear (up) interpolation, blurred with this sigma (in TARGET px) and
# arg-maxed. This is the closest equivalent of a bilinear upscale of the
# model's per-class probabilities when only the argmax map is available (the
# stored eval masks and the Dart class map are argmax maps): the 256-side
# staircase (2-4 px at 512) becomes a smooth contour. Sigma 1.5 = one model
# cell at 512 px (512/256 = 2 px), enough to round the steps without moving
# the contour more than ~1 px.
CLASS_MAP_SMOOTH_SIGMA = 1.5

# Hole fill: an enclosed non-clothes component (not touching the frame edge)
# below this fraction of the CLOTHES area is filled, except where it is skin
# or hair (a hand in front of the shirt is not a hole). 5% of a 20%-of-frame
# garment at 512 px is ~2000 px (~45x45): logo-sized gaps and speckle holes
# are filled, a bag or an open jacket showing the shirt is not.
HOLE_MAX_FRACTION = 0.05

# Detached components: a clothes connected component that is not the largest
# one and touches no skin / hair / others pixel (within PERSON_ADJACENCY_PX)
# is not on the person (a coat on a hook, a cushion, a bag on the floor) and
# is dropped. "Others" (accessories) counts as attachment because a belt or a
# bag strap labelled others can be the only thing joining the trousers to the
# top; a gap of BACKGROUND between two garments (the synthetic fixture
# scenes) still separates them — the known blind spot. Components below
# SPECKLE_MIN_FRACTION of the clothes area are dropped regardless (noise).
PERSON_ADJACENCY_PX = 1
SPECKLE_MIN_FRACTION = 0.01

# Hip-line split: the split row is the minimum of the (smoothed) clothes
# width profile inside HIP_SEARCH_BAND (fractions of the clothes bbox height,
# measured from its top row) — the waist is the narrowest band between the
# torso and the hips. The minimum counts as a waist only when it is strictly
# INSIDE the band (a minimum on a band edge = a monotone profile = no waist)
# and narrower than HIP_WAIST_MAX_RATIO x the widest row on BOTH sides;
# otherwise the split falls back to the v1 bbox mid-row. The band stops at
# 0.55 because the CROTCH is a second dip (thighs together, then the legs
# separate) that sits at ~0.45-0.6 of a shoulder-to-ankle span: with the band
# open to 0.70 it was picked on a tracksuit photo (split 46 px below the
# hem; the mid-row was 16 px below it). VERIFIED limit: the waist dip only
# exists when the arms are bare or raised — long sleeves hanging at hip
# level fill the waist in, and the fallback fires (7/29 CEO selfies split on
# a waist at the first measurement, the rest on the mid-row).
HIP_SEARCH_BAND = (0.30, 0.55)
HIP_PROFILE_SMOOTH_FRACTION = 0.04
HIP_WAIST_MAX_RATIO = 0.85

# Waist guard (2026-10-01): a waist is trusted only when the UPPER region it
# yields (clothes pixels on rows < the waist row) holds at least this share
# of the whole clothes area; otherwise the split falls back to the mid-row.
# Failure it stops (VERIFIED on a head-pixelated selfie): the model labels a
# raised sleeve "others", the torso reads as a narrow flat band that widens
# down to the hips, and the argmin lands a few rows inside the band edge,
# mid-shirt (upper share 0.22-0.24) -> the lower shirt was painted with the
# trousers. On the 65 eval masks no accepted waist is below 0.34, so the
# guard changes no decision there (VERIFIED); the safe interval is
# (0.24, 0.34]. A band-edge guard (reject a minimum within one smoothing
# window of either band edge) was rejected: it also flips correct waists
# (2026-10-01 waist-guard report). Known blind spot (HYPOTHESIS, not in the
# eval set): a cropped top over long wide bottoms can have a true waist
# below 0.30 and would fall back to the mid-row.
HIP_WAIST_MIN_UPPER_SHARE = 0.30

# Recolor growth: after smoothing the contour sits ~1 px inside the true
# garment edge, so the recolor path grows the clothes mask this many px into
# background / others (never skin or hair) to reach the edge; the recolor
# membership weight ignores grown-in pixels of another colour.
RECOLOR_GROW_PX = 2


@dataclass(frozen=True)
class MaskHardening:
    """Options of :func:`harden_class_map` / :func:`split_garment_masks`.

    The defaults switch every step ON except the growth (a recolor-only
    need); :data:`RECOLOR_HARDENING` is the recolor path preset.
    """

    fill_holes: bool = True
    hole_max_fraction: float = HOLE_MAX_FRACTION
    drop_detached: bool = True
    speckle_min_fraction: float = SPECKLE_MIN_FRACTION
    hip_split: bool = True
    grow_px: int = 0


DEFAULT_HARDENING = MaskHardening()
RECOLOR_HARDENING = MaskHardening(grow_px=RECOLOR_GROW_PX)

_PROTECTED_CLASSES = (CLASS_HAIR, CLASS_BODY_SKIN, CLASS_FACE_SKIN)


def _protected_mask(class_map: np.ndarray) -> np.ndarray:
    """Skin + hair: never turned into clothes, never grown over."""
    return np.isin(class_map, _PROTECTED_CLASSES)


def _square_kernel(radius: int) -> np.ndarray:
    return np.ones((2 * radius + 1, 2 * radius + 1), np.uint8)


def resample_class_map_smooth(
    class_map: np.ndarray,
    width: int,
    height: int,
    *,
    sigma: float = CLASS_MAP_SMOOTH_SIGMA,
) -> np.ndarray:
    """Class map -> (height, width) class map with SMOOTH class contours.

    One-hot plane per class, resized (INTER_AREA when shrinking, INTER_LINEAR
    when enlarging — the bilinear convention the model probabilities would
    get), Gaussian-blurred with ``sigma`` target px (0 = no blur) and
    arg-maxed; ties resolve to the lowest class id like
    :func:`class_map_from_scores`. Every pixel keeps exactly one class, so no
    class grows at the expense of another beyond the contour rounding.

    This is NOT the Dart-parity path (:func:`upscale_class_map` stays the
    canonical nearest upscale); it is the recolor mask-build step.
    """
    class_map = _validate_class_map(class_map)
    h, w = class_map.shape
    interp = cv2.INTER_AREA if (width * height) < (w * h) else cv2.INTER_LINEAR
    planes = np.empty((height, width, NUM_CLASSES), dtype=np.float32)
    for c in range(NUM_CLASSES):
        plane = (class_map == c).astype(np.float32)
        if (height, width) != (h, w):
            plane = cv2.resize(plane, (width, height), interpolation=interp)
        if sigma > 0:
            plane = cv2.GaussianBlur(plane, (0, 0), sigma)
        planes[..., c] = plane
    return planes.argmax(axis=-1).astype(np.uint8)


def fill_clothes_holes(
    class_map: np.ndarray, *, max_fraction: float = HOLE_MAX_FRACTION
) -> np.ndarray:
    """Clothes mask with the small enclosed holes filled.

    A hole is a 4-connected component of non-clothes pixels that does not
    touch the frame edge; it is filled when its area is below ``max_fraction``
    of the clothes area, and only on its background/others pixels (skin and
    hair inside a hole stay what they are) — with one exception: a hole made
    ENTIRELY of face skin, touching no hair and no body skin, is filled too.
    A real face is attached to hair or to the neck; an enclosed face-only
    island inside a garment is a printed face or a model misfire (VERIFIED:
    a 68x52 px face-skin blob in the middle of a plain burgundy top). Returns
    a NEW boolean mask.
    """
    class_map = _validate_class_map(class_map)
    clothes = class_map == CLASS_CLOTHES
    clothes_area = int(clothes.sum())
    if clothes_area == 0:
        return clothes
    h, w = clothes.shape
    n, labels, stats, _ = cv2.connectedComponentsWithStats(
        (~clothes).astype(np.uint8), connectivity=4
    )
    protected = _protected_mask(class_map)
    anchored = (class_map == CLASS_HAIR) | (class_map == CLASS_BODY_SKIN)
    fill = np.zeros_like(clothes)
    for i in range(1, n):
        x, y, cw, ch, area = (int(v) for v in stats[i])
        touches_edge = x == 0 or y == 0 or x + cw == w or y + ch == h
        if touches_edge or area >= max_fraction * clothes_area:
            continue
        component = labels == i
        if anchored[component].any():
            component &= ~protected  # a real face/hand: keep its skin and hair
        fill |= component
    return clothes | fill


def drop_detached_clothes(
    class_map: np.ndarray,
    *,
    speckle_min_fraction: float = SPECKLE_MIN_FRACTION,
    adjacency_px: int = PERSON_ADJACENCY_PX,
) -> np.ndarray:
    """Clothes mask without the components that are not on the person.

    Rule: 8-connected components of the clothes class; a component is kept
    when it touches the skin / hair / others mask within ``adjacency_px`` (a
    crop top and shorts separated by bare skin, or trousers under a belt,
    are two components, both attached) AND is at least
    ``speckle_min_fraction`` of the clothes area. When NO component is
    attached (a person whose skin/hair is invisible — hood up, gloves) the
    largest one is kept. Everything else (a coat on a hook, a cushion, a
    sofa labelled clothes, a bag on the floor, speckle) is dropped.

    Limit (VERIFIED on the CEO selfies): a second PERSON wears clothes that
    touch that person's own skin, so they are NOT detached — that case is
    the ``several_people`` reason of :func:`check_applicability`.
    """
    class_map = _validate_class_map(class_map)
    clothes = class_map == CLASS_CLOTHES
    n, labels, stats, _ = cv2.connectedComponentsWithStats(
        clothes.astype(np.uint8), connectivity=8
    )
    if n <= 2:  # background label + at most one component
        return clothes
    areas = stats[1:, cv2.CC_STAT_AREA].astype(np.int64)
    clothes_area = int(areas.sum())
    attachment = _protected_mask(class_map) | (class_map == CLASS_OTHERS)
    near_person = cv2.dilate(
        attachment.astype(np.uint8), _square_kernel(adjacency_px)
    ).astype(bool)
    keep = np.zeros_like(clothes)
    for i in range(1, n):
        if areas[i - 1] < speckle_min_fraction * clothes_area:
            continue
        component = labels == i
        if (component & near_person).any():
            keep |= component
    if not keep.any():
        keep = labels == int(np.argmax(areas)) + 1
    return keep


def hip_split_row(clothes: np.ndarray) -> tuple[int, bool]:
    """Upper/lower split row of a clothes mask: the waist, else the mid-row.

    Returns ``(row, from_waist)``. The row is the first row of the LOWER
    region (``y < row`` -> upper), the same convention as the v1 mid-row.
    Rule and limits: see :data:`HIP_SEARCH_BAND` and the waist guard
    :data:`HIP_WAIST_MIN_UPPER_SHARE`.
    """
    clothes = np.asarray(clothes, dtype=bool)
    rows = np.where(clothes.any(axis=1))[0]
    if len(rows) == 0:
        raise ValueError("empty clothes mask: nothing to split")
    top, bottom = int(rows[0]), int(rows[-1])
    mid = (top + bottom) // 2
    height = bottom - top + 1
    lo = top + int(HIP_SEARCH_BAND[0] * height)
    hi = top + int(HIP_SEARCH_BAND[1] * height)
    if hi - lo < 3:
        return mid, False

    profile = clothes.sum(axis=1).astype(np.float64)
    window = max(3, int(HIP_PROFILE_SMOOTH_FRACTION * height) | 1)
    smooth = np.convolve(profile, np.ones(window) / window, mode="same")
    band = smooth[lo : hi + 1]
    row = lo + int(np.argmin(band))
    if row == lo or row == hi:
        return mid, False  # monotone inside the band: no waist
    widest_above = float(smooth[top:row].max())
    widest_below = float(smooth[row + 1 : bottom + 1].max())
    if smooth[row] > HIP_WAIST_MAX_RATIO * min(widest_above, widest_below):
        return mid, False
    upper = int(clothes[:row].sum())
    if upper < HIP_WAIST_MIN_UPPER_SHARE * int(clothes.sum()):
        return mid, False  # waist guard: the "waist" would leave a stub top
    return row, True


def harden_class_map(
    class_map: np.ndarray, options: MaskHardening = DEFAULT_HARDENING
) -> np.ndarray:
    """Class map with a hardened CLOTHES class (other classes untouched).

    Order: detached-component drop (dropped pixels -> background), hole fill
    (filled pixels -> clothes), growth of ``options.grow_px`` px into
    background/others. The hip split is NOT baked in (a class map has no
    region notion): :func:`split_garment_masks` applies it from the same
    options. Returns a NEW uint8 map.
    """
    class_map = _validate_class_map(class_map)
    clothes = class_map == CLASS_CLOTHES
    if options.drop_detached:
        clothes = drop_detached_clothes(
            class_map, speckle_min_fraction=options.speckle_min_fraction
        )
    out = class_map.copy()
    out[(class_map == CLASS_CLOTHES) & ~clothes] = CLASS_BACKGROUND
    if options.fill_holes:
        clothes = fill_clothes_holes(out, max_fraction=options.hole_max_fraction)
        out[clothes] = CLASS_CLOTHES
    if options.grow_px > 0:
        grown = cv2.dilate(
            clothes.astype(np.uint8), _square_kernel(options.grow_px)
        ).astype(bool)
        out[grown & ~_protected_mask(out)] = CLASS_CLOTHES
    return out


# ---------------------------------------------------------------------------
# Applicability (I2 v1 scope: ONE person, decent light). The engine DETECTS
# and REPORTS "not applicable" so the UI can hide the recolor instead of
# painting garbage. Rules are cheap statistics of the class map + photo.
# ---------------------------------------------------------------------------

REASON_SEVERAL_PEOPLE = "several_people"
REASON_POOR_LIGHT = "poor_light"
REASON_REGION_TOO_SMALL = "region_too_small"
REASON_MASK_UNRELIABLE = "mask_unreliable"

# several_people: MediaPipe Selfie Multiclass has NO instance notion, so a
# second person = a second 8-connected component of the PERSON mask (clothes
# + skin + hair, closed by PERSON_CLOSE_PX to bridge 1-px gaps) whose area is
# at least this fraction of the largest one. VERIFIED on the CEO selfies:
# the two-person photo scores 0.29, every single-person photo <= 0.09 (a
# detached coat). Limit: two people TOUCHING (holding hands, hugging) form
# one component and are NOT detected. Face-component counting was rejected:
# mirror selfies split the face with the phone (2-3 face blobs, one person).
SECOND_PERSON_MIN_RATIO = 0.15
PERSON_CLOSE_PX = 2

# poor_light: a dim SCENE (frame median L* below POOR_LIGHT_FRAME_MEDIAN_L),
# or a person with no highlights at all (90th percentile of L* over the
# person mask below POOR_LIGHT_PERSON_P90_L) in a scene that is not bright
# either (frame median below POOR_LIGHT_DIM_SCENE_MEDIAN_L). The second rule
# needs BOTH because the person p90 is confounded by dark garments (an
# all-black outfit in a lit room has a low p90) and by skin tone (PRD §9
# bias risk: a dark-skinned person in a lit room must NOT be flagged). All
# thresholds are deliberately LOW: only the clearly dark frames are refused
# and the "vivid colour on a dim scene looks pasted" impression of the PoC
# is left to the visual gate (VERIFIED: the PoC dark panel and its best
# panels have the same person p90 L*; 2/29 CEO selfies are flagged).
POOR_LIGHT_FRAME_MEDIAN_L = 20.0
POOR_LIGHT_PERSON_P90_L = 45.0
POOR_LIGHT_DIM_SCENE_MEDIAN_L = 40.0

# region_too_small: a garment region (un-eroded, hardened) below this
# fraction of the frame is not worth a "see it on me" (the palette guard is
# MIN_REGION_FRACTION = 0.5%; a recolor needs a visible garment).
RECOLOR_MIN_REGION_FRACTION = 0.02

# mask_unreliable: computed on the RAW clothes class, before hardening —
# enclosed holes above MASK_HOLE_MAX of the clothes area (swiss-cheese
# mask), speckle components above MASK_SPECKLE_MAX, or detached components
# above MASK_DETACHED_MAX (the hardening would be deleting a large part of
# what the model called clothes).
MASK_HOLE_MAX = 0.10
MASK_SPECKLE_MAX = 0.05
MASK_DETACHED_MAX = 0.25


@dataclass(frozen=True)
class Applicability:
    """Result of :func:`check_applicability`.

    ``reason`` is ``None`` when the photo is applicable, else one of the
    ``REASON_*`` strings (the first rule that fired, in the order
    several_people, poor_light, mask_unreliable, region_too_small).
    ``regions`` maps each region to ``None`` (usable) or
    :data:`REASON_REGION_TOO_SMALL`. ``metrics`` holds every statistic the
    rules looked at, for the gate harness and for tuning.
    """

    reason: str | None
    regions: dict[str, str | None] = field(default_factory=dict)
    metrics: dict[str, float] = field(default_factory=dict)

    @property
    def applicable(self) -> bool:
        return self.reason is None


def person_component_ratio(class_map: np.ndarray) -> float:
    """Area of the 2nd-largest person component / the largest (0 = one)."""
    class_map = _validate_class_map(class_map)
    person = (class_map == CLASS_CLOTHES) | _protected_mask(class_map)
    closed = cv2.morphologyEx(
        person.astype(np.uint8), cv2.MORPH_CLOSE, _square_kernel(PERSON_CLOSE_PX)
    )
    n, _, stats, _ = cv2.connectedComponentsWithStats(closed, connectivity=8)
    if n <= 2:
        return 0.0
    areas = np.sort(stats[1:, cv2.CC_STAT_AREA])[::-1]
    return float(areas[1] / areas[0])


def mask_reliability_metrics(class_map: np.ndarray) -> dict[str, float]:
    """hole / speckle / detached fractions of the RAW clothes class."""
    class_map = _validate_class_map(class_map)
    clothes = class_map == CLASS_CLOTHES
    area = int(clothes.sum())
    if area == 0:
        return {"hole_fraction": 0.0, "speckle_fraction": 0.0, "detached_fraction": 0.0}
    filled = fill_clothes_holes(class_map, max_fraction=1.0)
    kept = drop_detached_clothes(class_map, speckle_min_fraction=0.0)
    n, _, stats, _ = cv2.connectedComponentsWithStats(
        clothes.astype(np.uint8), connectivity=8
    )
    areas = stats[1:, cv2.CC_STAT_AREA].astype(np.int64)
    speckle = int(areas[areas < SPECKLE_MIN_FRACTION * area].sum()) if n > 1 else 0
    return {
        "hole_fraction": float((filled & ~clothes).sum() / area),
        "speckle_fraction": float(speckle / area),
        "detached_fraction": float((clothes & ~kept).sum() / area),
    }


def check_applicability(
    class_map: np.ndarray,
    rgb: np.ndarray | None = None,
    regions: dict[str, np.ndarray] | None = None,
) -> Applicability:
    """Is a per-region recolor applicable to this photo (I2 v1 scope)?

    ``class_map`` is the RAW (un-hardened) class map at the photo size,
    ``rgb`` the uint8 photo (``None`` skips the light check) and ``regions``
    the hardened, un-eroded region masks (``None`` skips the size check).
    Pure statistics; never raises on a valid class map of the photo size.
    """
    class_map = _validate_class_map(class_map)
    metrics: dict[str, float] = {}
    reason: str | None = None

    ratio = person_component_ratio(class_map)
    metrics["person_component_ratio"] = ratio
    if ratio >= SECOND_PERSON_MIN_RATIO:
        reason = REASON_SEVERAL_PEOPLE

    if rgb is not None:
        rgb = np.asarray(rgb)
        if rgb.shape[:2] != class_map.shape:
            raise ValueError(
                f"photo shape {rgb.shape[:2]} != class map shape {class_map.shape}"
            )
        lightness = cv2.cvtColor(rgb.astype(np.float32) / 255.0, cv2.COLOR_RGB2LAB)[
            ..., 0
        ]
        person = (class_map == CLASS_CLOTHES) | _protected_mask(class_map)
        frame_median = float(np.median(lightness))
        person_p90 = (
            float(np.percentile(lightness[person], 90)) if person.any() else 0.0
        )
        metrics["frame_median_l"] = frame_median
        metrics["person_p90_l"] = person_p90
        dim_person = (
            person_p90 < POOR_LIGHT_PERSON_P90_L
            and frame_median < POOR_LIGHT_DIM_SCENE_MEDIAN_L
        )
        if reason is None and (frame_median < POOR_LIGHT_FRAME_MEDIAN_L or dim_person):
            reason = REASON_POOR_LIGHT

    reliability = mask_reliability_metrics(class_map)
    metrics.update(reliability)
    if reason is None and (
        reliability["hole_fraction"] > MASK_HOLE_MAX
        or reliability["speckle_fraction"] > MASK_SPECKLE_MAX
        or reliability["detached_fraction"] > MASK_DETACHED_MAX
    ):
        reason = REASON_MASK_UNRELIABLE

    region_status: dict[str, str | None] = {}
    if regions is not None:
        n_pixels = class_map.size
        for name, mask in regions.items():
            fraction = float(np.asarray(mask, dtype=bool).sum() / n_pixels)
            metrics[f"{name}_fraction"] = fraction
            region_status[name] = (
                None
                if fraction >= RECOLOR_MIN_REGION_FRACTION
                else REASON_REGION_TOO_SMALL
            )
        if reason is None and regions and all(region_status.values()):
            reason = REASON_REGION_TOO_SMALL

    return Applicability(reason=reason, regions=region_status, metrics=metrics)
