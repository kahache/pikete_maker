"""Per-region garment recolor (ICEBOX I2, step 1 — Python proof of concept).

"See yourself in the palette": given the user's photo, ONE garment region mask
(upper / lower, the same masks Phase 2.5 already produces) and a proposed
harmony colour, repaint that garment toward the proposed colour while the rest
of the photo (the other garment, skin, hair, background) stays as shot.

This is a CLASSIC recolor — no generative model, no server — so it keeps the
D2 ~0-marginal-cost promise and has a credible pure-Dart port (only per-pixel
math plus one blur). The transform works in CIELAB and is deliberately
lighting-preserving: the per-pixel LIGHTNESS variation of the garment (folds,
texture, shading) is kept and only the chromatic component is driven toward
the target.

Three regimes, selected from the LAB chroma of the SOURCE (the garment's own
dominant colour) and of the TARGET:

- chromatic -> chromatic ("hue replacement"): every pixel takes the target's
  LAB hue with its OWN chroma scaled by the target/source chroma ratio
  (clamped). Shading keeps its relative chroma, so a red shirt becomes a
  convincingly shaded blue shirt. Replacement, not rotation by the hue delta:
  a rotation propagates every error of the measured source hue (colour cast,
  mixed edge pixels, noisy shadows) into a wrong output hue.
- neutral source and/or neutral target ("chroma injection"): a black tee has
  no hue to rotate, so the target's (a*, b*) is INJECTED with a lightness
  bell that fades the chroma toward black and white (this is also what
  collapses the chroma when the target is a neutral). Injection is the hard
  case the PoC is meant to expose honestly — see the report.
- in both regimes the lightness is scaled by a MULTIPLICATIVE gain toward the
  target (exponent :data:`LIGHTNESS_SHIFT_CHROMATIC` /
  :data:`LIGHTNESS_SHIFT_NEUTRAL` on the target/source L* ratio): a black tee
  cannot read as cobalt at L* 15, and a white shirt cannot become black
  without moving L*. A gain (not an offset) is what a dye change does to
  reflectance under the same light: deep shadows stay dark and the fold
  contrast is preserved as a ratio (a first offset version lifted shadows
  into a muddy mid-dark — PoC panel review).

Two soft weights modulate the blend per pixel: a FEATHERED alpha at the mask
edge (no hard halo) and a MEMBERSHIP weight from the pixel's distance to the
source colour (a white logo on a black tee, or the second colour of a stripe,
is recolored less than the dominant colour). Pixels outside the mask are
byte-identical to the input.

Pure numpy + OpenCV (colour conversion, one Gaussian blur); no sklearn, so it
is cheap enough to run interactively on-device.
"""

from __future__ import annotations

import logging
import math

import cv2
import numpy as np

from colorlab.harmony import RGB, as_rgb
from colorlab.palette import NEUTRAL_CHROMA

logger = logging.getLogger(__name__)

# --- Edge softening ---------------------------------------------------------
# Half-width in px of the soft transition at the region edge. The MediaPipe
# mask is a 256-side class map upscaled nearest-neighbour, so its edge is
# blocky by 2-4 px at 512 px: feathering hides the staircase without bleeding
# the new colour onto skin/background (the alpha is re-masked to the region).
FEATHER_PX = 3

# --- Lightness handling -----------------------------------------------------
# Exponent on the target/source L* ratio applied as a gain to every pixel of
# the region (0 = lightness fully preserved, 1 = full remap). For a CHROMATIC
# target the harmony proposals are mid-light (harmony() floors v >= 0.55), so
# a partial gain is enough to make a dark garment read as the proposed colour
# while keeping most of the original exposure.
LIGHTNESS_SHIFT_CHROMATIC = 0.7
# A NEUTRAL target (black / white / beige) is DEFINED by its lightness: a
# white shirt cannot become black at L* 90, so the remap is complete.
LIGHTNESS_SHIFT_NEUTRAL = 1.0

# --- Chroma handling --------------------------------------------------------
# Clamp of the target/source chroma ratio in the hue-replacement regime, so a
# barely-chromatic source (chroma just above NEUTRAL_CHROMA) is not blown up
# into posterized noise, and a vivid source is not crushed to gray.
CHROMA_SCALE_MIN = 0.5
CHROMA_SCALE_MAX = 3.0
# In the injection regime the injected chroma follows a lightness bell centred
# on the target L*: real dyes lose chroma toward black and toward white, and
# the bell also keeps most pixels inside the sRGB gamut without a clip.
# Floor of the bell so deep shadows keep a hint of the hue.
INJECT_BELL_FLOOR = 0.25

# --- Membership (which pixels of the region belong to the source colour) ----
# Weighted LAB distance to the source colour below which a pixel is fully
# recolored, and above which it is left untouched (linear ramp in between).
# The lightness axis is down-weighted (as in palette merging) so the shading
# of a solid garment stays inside FULL while a white logo on a black tee
# (L* gap ~80 -> weighted ~40) or the other stripe of a two-tone print falls
# toward ZERO.
MEMBERSHIP_DELTA_E_FULL = 25.0
MEMBERSHIP_DELTA_E_ZERO = 55.0
MEMBERSHIP_LIGHTNESS_WEIGHT = 0.5

# OpenCV float LAB convention: L* in 0..100, a*/b* in -127..127 for RGB input
# scaled to 0..1 (no uint8 offset/scaling).
_LAB_L_MAX = 100.0
# Floor on the L* values entering the lightness gain ratio: a pure-black
# source or target would otherwise give an infinite / zero gain.
_L_GAIN_FLOOR = 2.0


def rgb_to_lab_f32(rgb: np.ndarray) -> np.ndarray:
    """uint8 [H, W, 3] sRGB -> float32 CIELAB (L* 0..100, a*/b* signed)."""
    return cv2.cvtColor(np.asarray(rgb, dtype=np.float32) / 255.0, cv2.COLOR_RGB2LAB)


def lab_f32_to_rgb(lab: np.ndarray) -> np.ndarray:
    """float32 CIELAB -> uint8 [H, W, 3] sRGB, clipped to the sRGB gamut."""
    rgb = cv2.cvtColor(np.ascontiguousarray(lab, dtype=np.float32), cv2.COLOR_LAB2RGB)
    return np.clip(np.rint(rgb * 255.0), 0, 255).astype(np.uint8)


def lab_of_rgb(rgb: RGB) -> tuple[float, float, float]:
    """LAB (L*, a*, b*) of one sRGB triple, OpenCV convention."""
    r, g, b = as_rgb(rgb)
    lab = rgb_to_lab_f32(np.array([[[r, g, b]]], dtype=np.uint8))[0, 0]
    return float(lab[0]), float(lab[1]), float(lab[2])


def feather_mask(mask: np.ndarray, feather_px: int = FEATHER_PX) -> np.ndarray:
    """Boolean mask -> float32 alpha in [0, 1], soft INSIDE the region.

    The mask is Gaussian-blurred (so the alpha ramps from ~0.5 at the edge to
    1 a few px inside) and then re-masked, so every pixel outside the region
    keeps alpha 0: the recolor never bleeds onto skin, hair or background.
    ``feather_px <= 0`` returns the hard mask as float.
    """
    hard = np.asarray(mask, dtype=bool)
    if feather_px <= 0:
        return hard.astype(np.float32)
    sigma = feather_px / 2.0
    ksize = 2 * math.ceil(3.0 * sigma) + 1
    soft = cv2.GaussianBlur(hard.astype(np.float32), (ksize, ksize), sigma)
    return np.where(hard, soft, 0.0).astype(np.float32)


def membership_weights(
    lab: np.ndarray,
    source_lab: tuple[float, float, float],
    *,
    delta_e_full: float = MEMBERSHIP_DELTA_E_FULL,
    delta_e_zero: float = MEMBERSHIP_DELTA_E_ZERO,
) -> np.ndarray:
    """Per-pixel weight in [0, 1]: 1 at the source colour, 0 far from it.

    Lightness-down-weighted LAB distance with a linear ramp between
    ``delta_e_full`` and ``delta_e_zero``. Shading of the source garment stays
    at 1; a print/logo of a clearly different colour falls toward 0.
    """
    dl = (lab[..., 0] - source_lab[0]) * MEMBERSHIP_LIGHTNESS_WEIGHT
    da = lab[..., 1] - source_lab[1]
    db = lab[..., 2] - source_lab[2]
    dist = np.sqrt(dl * dl + da * da + db * db)
    ramp = (delta_e_zero - dist) / (delta_e_zero - delta_e_full)
    return np.clip(ramp, 0.0, 1.0).astype(np.float32)


def _mean_lab_in(lab: np.ndarray, mask: np.ndarray) -> tuple[float, float, float]:
    pixels = lab[mask]
    if len(pixels) == 0:
        raise ValueError("region mask is empty: nothing to recolor")
    mean = pixels.mean(axis=0)
    return float(mean[0]), float(mean[1]), float(mean[2])


def _shift_lab(
    lab: np.ndarray,
    source_lab: tuple[float, float, float],
    target_lab: tuple[float, float, float],
    lightness_shift: float,
) -> np.ndarray:
    """The pure colour transform, applied to EVERY pixel of ``lab`` (the
    caller blends it in with the alpha/membership weights).

    Regime selection and the lightness offset are described in the module
    docstring; the target/source stats are scalars so the whole thing is a
    handful of vectorized numpy ops.
    """
    l_src, a_src, b_src = source_lab
    l_tgt, a_tgt, b_tgt = target_lab
    c_src = math.hypot(a_src, b_src)
    c_tgt = math.hypot(a_tgt, b_tgt)
    # Multiplicative lightness gain (a dye change scales reflectance, it does
    # not add to it): deep shadows stay dark instead of lifting into a muddy
    # mid-dark, highlights scale with the garment. ``lightness_shift`` is the
    # exponent on the target/source ratio (0 = keep L*, 1 = full remap).
    gain = (max(l_tgt, _L_GAIN_FLOOR) / max(l_src, _L_GAIN_FLOOR)) ** lightness_shift
    lightness = np.clip(lab[..., 0] * gain, 0.0, _LAB_L_MAX)

    if c_src >= NEUTRAL_CHROMA and c_tgt >= NEUTRAL_CHROMA:
        # Hue replacement: every pixel takes the TARGET hue with its OWN chroma
        # (scaled by the clamped target/source ratio), so shading keeps its
        # relative chroma. Absolute (not a rotation by the source->target
        # delta) on purpose: a rotation propagates any error in the measured
        # source hue (a colour-cast source, a mixed edge pixel, a noisy deep
        # shadow) into a wrong output hue; replacement cannot.
        scale = float(np.clip(c_tgt / c_src, CHROMA_SCALE_MIN, CHROMA_SCALE_MAX))
        chroma = np.hypot(lab[..., 1], lab[..., 2]) * scale
        a = chroma * (a_tgt / c_tgt)
        b = chroma * (b_tgt / c_tgt)
    else:
        # Chroma injection (neutral source and/or neutral target): the pixel
        # has no usable hue, so the target (a, b) is written in, scaled by a
        # lightness bell that fades toward black and white. For a neutral
        # target this is exactly the chroma collapse (a small a, b).
        bell = _lightness_bell(lightness, l_tgt)
        a = a_tgt * bell
        b = b_tgt * bell
    return np.stack([lightness, a, b], axis=-1).astype(np.float32)


def _lightness_bell(lightness: np.ndarray, l_center: float) -> np.ndarray:
    """Parabolic bell L*(100 - L*) normalized to 1 at ``l_center``, floored."""
    peak = max(l_center * (_LAB_L_MAX - l_center), 1.0)
    bell = lightness * (_LAB_L_MAX - lightness) / peak
    return np.clip(bell, INJECT_BELL_FLOOR, 1.0)


def recolor_region(
    rgb: np.ndarray,
    region_mask: np.ndarray,
    target_rgb: RGB,
    *,
    source_rgb: RGB | None = None,
    feather_px: int = FEATHER_PX,
    lightness_shift: float | None = None,
    selective: bool = True,
) -> np.ndarray:
    """Repaints the garment under ``region_mask`` toward ``target_rgb``.

    Args:
        rgb: the photo, uint8 [H, W, 3] sRGB.
        region_mask: boolean [H, W] — the garment region (use the UN-eroded
            split so the recolor reaches the garment edge; the palette path
            keeps its own eroded masks).
        target_rgb: the proposed colour (a harmony swatch or a canvas accent).
        source_rgb: the garment's dominant colour as the engine measured it
            (``GarmentPalette.colors[argmax weights]``). ``None`` = the mean
            colour of the region.
        feather_px: edge softening half-width (:data:`FEATHER_PX`).
        lightness_shift: exponent of the lightness gain (0 = keep L*, 1 =
            full remap to the target L*);
            ``None`` picks :data:`LIGHTNESS_SHIFT_NEUTRAL` for a neutral target
            and :data:`LIGHTNESS_SHIFT_CHROMATIC` otherwise.
        selective: weight each pixel by its membership to the source colour
            (prints/logos of another colour are preserved). ``False`` recolors
            the whole region uniformly.

    Returns:
        A NEW uint8 [H, W, 3] photo. Pixels with mask False are byte-identical
        to the input.
    """
    rgb = np.asarray(rgb)
    if rgb.dtype != np.uint8 or rgb.ndim != 3 or rgb.shape[2] != 3:
        raise ValueError(f"rgb must be uint8 [H, W, 3], got {rgb.dtype} {rgb.shape}")
    mask = np.asarray(region_mask, dtype=bool)
    if mask.shape != rgb.shape[:2]:
        raise ValueError(f"mask shape {mask.shape} != photo shape {rgb.shape[:2]}")
    if not mask.any():
        raise ValueError("region mask is empty: nothing to recolor")

    lab = rgb_to_lab_f32(rgb)
    source_lab = lab_of_rgb(source_rgb) if source_rgb else _mean_lab_in(lab, mask)
    target_lab = lab_of_rgb(target_rgb)
    target_is_neutral = math.hypot(target_lab[1], target_lab[2]) < NEUTRAL_CHROMA
    if lightness_shift is None:
        lightness_shift = (
            LIGHTNESS_SHIFT_NEUTRAL if target_is_neutral else LIGHTNESS_SHIFT_CHROMATIC
        )
    logger.info(
        "recolor: source LAB=(%.0f, %.0f, %.0f) target LAB=(%.0f, %.0f, %.0f) "
        "regime=%s L-shift=%.2f",
        *source_lab,
        *target_lab,
        "hue-replace"
        if math.hypot(source_lab[1], source_lab[2]) >= NEUTRAL_CHROMA
        and not target_is_neutral
        else "injection",
        lightness_shift,
    )

    shifted = _shift_lab(lab, source_lab, target_lab, lightness_shift)
    weight = feather_mask(mask, feather_px)
    if selective:
        weight = weight * membership_weights(lab, source_lab)
    blended = lab + weight[..., None] * (shifted - lab)
    out = lab_f32_to_rgb(blended)
    # Outside the mask the weight is exactly 0, but the LAB round trip is not
    # bit-exact: copy the originals back so "untouched" means byte-identical.
    out[~mask] = rgb[~mask]
    return out
