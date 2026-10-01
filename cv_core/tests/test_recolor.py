"""Tests for the per-region recolor transform (ICEBOX I2 step 1, PoC).

Everything here runs on SYNTHETIC images (constructed numpy arrays): no
photo, no mask model. The visual verdict on real selfies is the PoC report
(docs/architecture/2026-09-30_*_F2_I2-recolor-poc.md); these tests pin the
CONTRACT of the transform: lightness is preserved inside the mask when asked,
pixels outside the mask are byte-identical, a neutral target collapses
chroma, and feathering is a monotonic soft edge.
"""

import numpy as np
import pytest

from colorlab.palette import NEUTRAL_CHROMA, srgb_to_lab
from colorlab.recolor import (
    FEATHER_PX,
    feather_mask,
    lab_f32_to_rgb,
    lab_of_rgb,
    membership_weights,
    recolor_region,
    rgb_to_lab_f32,
)

H, W = 64, 48
RED = (180, 40, 50)
COBALT = (43, 92, 228)
BLACK_TEE = (30, 30, 32)
WHITE = (240, 240, 240)
GRAY = (128, 128, 128)
GREEN = (40, 170, 60)


def _photo(color, *, shading=True):
    """A solid-colour photo with a vertical lighting gradient (folds proxy)."""
    img = np.zeros((H, W, 3), dtype=np.uint8)
    img[...] = color
    if shading:
        ramp = np.linspace(0.6, 1.0, H, dtype=np.float32)[:, None, None]
        img = np.clip(img.astype(np.float32) * ramp, 0, 255).astype(np.uint8)
    return img


def _center_mask(margin=12):
    mask = np.zeros((H, W), dtype=bool)
    mask[margin:-margin, margin:-margin] = True
    return mask


def _chroma(lab):
    return np.hypot(lab[..., 1], lab[..., 2])


# ---------------------------------------------------------------------------
# Colour space helpers


def test_lab_round_trip_is_close():
    rgb = _photo(RED)
    back = lab_f32_to_rgb(rgb_to_lab_f32(rgb))
    assert np.abs(back.astype(int) - rgb.astype(int)).max() <= 1


def test_lab_of_rgb_matches_palette_conversion():
    ours = np.array(lab_of_rgb(RED))
    ref = srgb_to_lab(np.asarray([RED], dtype=float))[0]
    # Two implementations of the same D65 sRGB->LAB (OpenCV vs the palette's
    # numpy one): they must agree to well under a just-noticeable difference.
    assert np.abs(ours - ref).max() < 1.0


# ---------------------------------------------------------------------------
# recolor_region contract


def test_outside_mask_is_byte_identical():
    rgb = _photo(RED)
    mask = _center_mask()
    out = recolor_region(rgb, mask, COBALT)
    assert out.dtype == np.uint8 and out.shape == rgb.shape
    assert np.array_equal(out[~mask], rgb[~mask])
    assert out is not rgb  # a new image, the input is untouched


def test_inside_mask_takes_target_hue():
    rgb = _photo(RED)
    mask = _center_mask()
    out = recolor_region(rgb, mask, COBALT, feather_px=0)
    lab = rgb_to_lab_f32(out)
    _, a_t, b_t = lab_of_rgb(COBALT)
    target_hue = np.arctan2(b_t, a_t)
    inner = lab[mask]
    hues = np.arctan2(inner[:, 2], inner[:, 1])
    delta = np.abs(np.angle(np.exp(1j * (hues - target_hue))))
    assert np.degrees(delta).max() < 5.0
    assert _chroma(inner).mean() >= NEUTRAL_CHROMA


def test_lightness_preserved_inside_mask_when_shift_is_zero():
    rgb = _photo(RED)
    mask = _center_mask()
    out = recolor_region(rgb, mask, COBALT, feather_px=0, lightness_shift=0.0)
    l_in = rgb_to_lab_f32(rgb)[..., 0][mask]
    l_out = rgb_to_lab_f32(out)[..., 0][mask]
    # The folds proxy (vertical ramp) survives: same L* per pixel, up to the
    # uint8 round trip and sRGB gamut clipping of the new chroma.
    assert np.abs(l_out - l_in).max() < 3.0
    assert np.corrcoef(l_in, l_out)[0, 1] > 0.99


def test_lightness_shift_moves_toward_target():
    rgb = _photo(BLACK_TEE)
    mask = _center_mask()
    l_src = rgb_to_lab_f32(rgb)[..., 0][mask].mean()
    l_tgt = lab_of_rgb(COBALT)[0]
    partial = rgb_to_lab_f32(
        recolor_region(rgb, mask, COBALT, feather_px=0, lightness_shift=0.5)
    )[..., 0][mask].mean()
    full = rgb_to_lab_f32(
        recolor_region(rgb, mask, COBALT, feather_px=0, lightness_shift=1.0)
    )[..., 0][mask].mean()
    assert l_src < partial < full
    assert abs(full - l_tgt) < 6.0


def test_shading_order_is_preserved_by_the_gain():
    rgb = _photo(BLACK_TEE)
    mask = _center_mask()
    out = recolor_region(rgb, mask, COBALT, feather_px=0)
    l_out = rgb_to_lab_f32(out)[..., 0]
    col = l_out[mask.any(axis=1), W // 2]
    # The vertical ramp is monotonic in the input; a multiplicative gain
    # keeps it monotonic (folds are not flattened).
    assert np.all(np.diff(col) >= -0.5)


def test_neutral_target_collapses_chroma():
    rgb = _photo(RED)
    mask = _center_mask()
    out = recolor_region(rgb, mask, GRAY, feather_px=0)
    lab = rgb_to_lab_f32(out)
    assert _chroma(lab[mask]).max() < NEUTRAL_CHROMA
    assert _chroma(rgb_to_lab_f32(rgb)[mask]).min() > NEUTRAL_CHROMA


def test_neutral_target_remaps_lightness():
    rgb = _photo(WHITE, shading=False)
    mask = _center_mask()
    out = recolor_region(rgb, mask, BLACK_TEE, feather_px=0)
    l_out = rgb_to_lab_f32(out)[..., 0][mask].mean()
    assert abs(l_out - lab_of_rgb(BLACK_TEE)[0]) < 4.0


def test_neutral_source_gets_chroma_injected():
    rgb = _photo(BLACK_TEE)
    mask = _center_mask()
    out = recolor_region(rgb, mask, COBALT, feather_px=0)
    lab = rgb_to_lab_f32(out)
    assert _chroma(lab[mask]).mean() >= NEUTRAL_CHROMA
    _, a_t, b_t = lab_of_rgb(COBALT)
    inner = lab[mask]
    hues = np.degrees(np.arctan2(inner[:, 2], inner[:, 1]))
    assert np.abs(hues - np.degrees(np.arctan2(b_t, a_t))).max() < 5.0


def test_selective_leaves_a_foreign_print_alone():
    rgb = _photo(RED, shading=False)
    mask = _center_mask()
    logo = np.zeros((H, W), dtype=bool)
    logo[28:36, 20:28] = True
    rgb[logo] = GREEN
    out = recolor_region(rgb, mask, COBALT, source_rgb=RED, feather_px=0)
    # Membership ~0 for a colour far from the source: the print is untouched.
    assert np.abs(out[logo].astype(int) - np.array(GREEN)).max() <= 2
    # Ablation: without membership the print takes the target hue too.
    uniform = recolor_region(
        rgb, mask, COBALT, source_rgb=RED, feather_px=0, selective=False
    )
    lab = rgb_to_lab_f32(uniform)[logo]
    _, a_t, b_t = lab_of_rgb(COBALT)
    hues = np.degrees(np.arctan2(lab[:, 2], lab[:, 1]))
    # Wider tolerance than the solid-garment test: the vivid print's chroma is
    # scaled past the sRGB gamut and the clip bends its hue by a few degrees.
    assert np.abs(hues - np.degrees(np.arctan2(b_t, a_t))).max() < 10.0


def test_rejects_bad_inputs():
    rgb = _photo(RED)
    with pytest.raises(ValueError):
        recolor_region(rgb, np.zeros((H, W), dtype=bool), COBALT)
    with pytest.raises(ValueError):
        recolor_region(rgb, np.zeros((H + 1, W), dtype=bool), COBALT)
    with pytest.raises(ValueError):
        recolor_region(rgb.astype(np.float32), _center_mask(), COBALT)


# ---------------------------------------------------------------------------
# feather_mask


def test_feather_zero_is_the_hard_mask():
    mask = _center_mask()
    alpha = feather_mask(mask, 0)
    assert alpha.dtype == np.float32
    assert np.array_equal(alpha, mask.astype(np.float32))


def test_feather_is_zero_outside_and_monotonic_inside():
    mask = _center_mask(margin=8)
    alpha = feather_mask(mask, FEATHER_PX)
    assert np.all(alpha[~mask] == 0.0)
    assert alpha.max() <= 1.0 and alpha[H // 2, W // 2] > 0.999
    # Walking inward from the left edge of the region, alpha never decreases.
    row = alpha[H // 2, 8 : W // 2]
    assert np.all(np.diff(row) >= -1e-6)
    assert row[0] < 0.75  # soft at the boundary, not a hard 1


def test_wider_feather_is_softer_at_the_edge():
    mask = _center_mask(margin=8)
    narrow = feather_mask(mask, 2)
    wide = feather_mask(mask, 6)
    edge = (H // 2, 9)
    assert wide[edge] < narrow[edge]


# ---------------------------------------------------------------------------
# membership_weights


def test_membership_full_at_source_and_zero_far_away():
    lab = rgb_to_lab_f32(_photo(RED, shading=False))
    src = lab_of_rgb(RED)
    assert membership_weights(lab, src).min() == pytest.approx(1.0)
    far = rgb_to_lab_f32(_photo(COBALT, shading=False))
    assert membership_weights(far, src).max() == pytest.approx(0.0)


def test_membership_tolerates_shading_of_the_source():
    lab = rgb_to_lab_f32(_photo(RED))  # 0.6..1.0 lighting ramp
    weights = membership_weights(lab, lab_of_rgb(RED))
    assert weights.min() > 0.9
