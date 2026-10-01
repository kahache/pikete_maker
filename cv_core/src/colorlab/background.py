"""Separating the person from the background (feature 1).

Cascade by dependency availability: rembg (best quality, requires
onnxruntime) -> OpenCV GrabCut -> no background removal. Degrades gracefully
so the pipeline runs in any environment.
"""

from __future__ import annotations

import logging

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# Alpha threshold above which a rembg pixel counts as foreground.
ALPHA_THRESHOLD = 30

# GrabCut: initial rectangle margin (fraction of width/height) and iterations.
GRABCUT_MARGIN_X = 0.08
GRABCUT_MARGIN_Y = 0.06
# 3 (was 5): GrabCut dominates pipeline latency and its p95 tail comes from
# running many iterations at full resolution (#30). 3 iters converge the mask
# on centered subjects; the extra 2 barely move it but cost ~0.6x more time.
GRABCUT_ITERS = 3

# Cap the GrabCut *working* resolution: the mask is computed on an image
# downscaled to this longest side and then upscaled back (nearest) to full
# size. GrabCut cost is ~linear in pixels, so 600->400 is ~2.2x fewer pixels
# (~0.45x time) and kills the p95 tail on large frames (#30). The palette is
# still computed from the FULL-resolution pixels; only the mask is coarser at
# the edges, which barely moves the interior color mix. Only affects the
# GrabCut fallback (rembg, when present, does its own thing).
GRABCUT_MAX_SIDE = 400

# Hard foreground seed: half-width/half-height (fraction of the side) of the
# central box marked GC_FGD. GrabCut already assumes a centered subject
# (rect); without this seed it can reassign to the background a central
# garment whose color differs strongly from the rest of the outfit (evidence
# in issue #20: the coral dress of g0-01 was 9.8% of the photo but only 0.03%
# of the foreground).
GRABCUT_SEED_FRACTION = 0.10

# GrabCut initializes its GMMs with OpenCV's *global* RNG: we set the seed
# before each call so the cutout is deterministic and testable (otherwise the
# result depends on whatever ran earlier in the same process).
GRABCUT_RNG_SEED = 0


def _remove_bg_rembg(img: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    """Background removal with rembg (U^2-Net). Best quality, but needs onnxruntime."""
    from rembg import remove  # late import: optional dependency

    cut = remove(img).convert("RGBA")
    arr = np.asarray(cut)
    mask = arr[:, :, 3] > ALPHA_THRESHOLD
    logger.info("background removed with rembg (%.0f%% foreground)", mask.mean() * 100)
    return arr[:, :, :3], mask


def _remove_bg_grabcut(img: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    """Background removal with OpenCV GrabCut (no onnxruntime).

    Assumes a centered subject: initializes with a rectangle that discards
    the borders as background. Coarser than rembg but enough for the MVP.
    """
    import cv2  # late import: optional dependency

    arr = np.asarray(img)  # FULL-resolution RGB: the palette is computed on this
    full_h, full_w = arr.shape[:2]

    # Downscale for the mask computation only (#30): GrabCut is ~linear in
    # pixels, so a smaller working image is the main p95 lever. The mask is
    # upscaled back to full size afterwards.
    scale = GRABCUT_MAX_SIDE / max(full_h, full_w)
    if scale < 1.0:
        work = img.resize(
            (max(1, round(full_w * scale)), max(1, round(full_h * scale))),
            Image.Resampling.BILINEAR,
        )
    else:
        work = img
    bgr = cv2.cvtColor(np.asarray(work), cv2.COLOR_RGB2BGR)
    h, w = bgr.shape[:2]
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    mx, my = int(w * GRABCUT_MARGIN_X), int(h * GRABCUT_MARGIN_Y)
    rect = (mx, my, w - 2 * mx, h - 2 * my)

    # Build the init mask by hand (GC_INIT_WITH_MASK) instead of letting the
    # rect do it: the border stays background, the rect interior is probable
    # foreground, and a central box is HARD foreground (GC_FGD). GrabCut never
    # reassigns a GC_FGD pixel, so this protects a central garment whose color
    # differs strongly from the rest of the outfit (issue #20 / #25).
    mask = np.zeros((h, w), np.uint8)  # GC_BGD outside the rect
    mask[my : h - my, mx : w - mx] = cv2.GC_PR_FGD
    sw, sh = int(w * GRABCUT_SEED_FRACTION), int(h * GRABCUT_SEED_FRACTION)
    cx, cy = w // 2, h // 2
    mask[cy - sh : cy + sh, cx - sw : cx + sw] = cv2.GC_FGD

    cv2.setRNGSeed(GRABCUT_RNG_SEED)  # determinism: see the constant's comment
    cv2.grabCut(bgr, mask, rect, bgd, fgd, GRABCUT_ITERS, cv2.GC_INIT_WITH_MASK)
    fg = np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD))
    if fg.shape != (full_h, full_w):
        # Nearest upscale back to full resolution (bool mask -> uint8 -> resize).
        fg = np.asarray(
            Image.fromarray(fg.astype(np.uint8)).resize(
                (full_w, full_h), Image.Resampling.NEAREST
            )
        ).astype(bool)
    logger.info("background removed with GrabCut (%.0f%% foreground)", fg.mean() * 100)
    return arr, fg


def remove_background(img: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    """Returns (rgb, mask_bool) with the photo's foreground.

    Tries each background remover in quality order and falls through to the
    next one if its dependency is unavailable or fails. Last resort: the
    whole photo.
    """
    for fn in (_remove_bg_rembg, _remove_bg_grabcut):
        try:
            return fn(img)
        except Exception as e:
            logger.warning("%s unavailable (%s)", fn.__name__, type(e).__name__)
    logger.warning("no background removal -> using the whole photo")
    rgb = np.asarray(img)
    return rgb, np.ones(rgb.shape[:2], dtype=bool)
