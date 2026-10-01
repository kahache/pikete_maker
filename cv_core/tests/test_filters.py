import numpy as np

from colorlab.filters import (
    adaptive_skin_mask,
    estimate_skin_tone,
    gather_pixels,
    skin_mask,
)

SKIN = (235, 200, 170)
NAVY = (30, 50, 110)

# Tones for the adaptive filter regressions (issue #20, bugs B1/B2).
DARK_SKIN = (95, 60, 48)  # dark skin: skin chroma but luma < 80
CORAL = (220, 130, 100)  # warm garment the classic heuristic mistakes for skin
CAMEL = (215, 180, 150)  # skin-colored outfit (triggers the anti-B2 guardrail)


def _solid(color, h=10, w=10):
    return np.full((h, w, 3), color, dtype=np.uint8)


def _band(top, bottom, h_top=6, h_bottom=14, w=20):
    """Image with a top strip (face/neck) over the rest (garment)."""
    return np.concatenate([_solid(top, h_top, w), _solid(bottom, h_bottom, w)], axis=0)


def test_skin_mask_detects_typical_skin_tone():
    assert skin_mask(_solid(SKIN)).all()


def test_skin_mask_rejects_clothing_colors():
    assert not skin_mask(_solid(NAVY)).any()
    assert not skin_mask(_solid((225, 54, 131))).any()  # fuchsia


def test_gather_pixels_respects_foreground_mask():
    # left half navy (foreground), right half fuchsia (background)
    img = np.concatenate([_solid(NAVY, 10, 5), _solid((225, 54, 131), 10, 5)], axis=1)
    fg = np.zeros((10, 10), dtype=bool)
    fg[:, :5] = True

    pixels = gather_pixels(img, fg, drop_skin=False)
    assert len(pixels) == 50
    assert np.allclose(pixels, NAVY)


def test_gather_pixels_drops_skin():
    # 20x10 image: top half skin, bottom half navy, all foreground
    img = np.concatenate([_solid(SKIN, 10, 10), _solid(NAVY, 10, 10)], axis=0)
    fg = np.ones((20, 10), dtype=bool)

    pixels = gather_pixels(img, fg, drop_skin=True)
    assert len(pixels) == 100
    assert np.allclose(pixels, NAVY)


def test_gather_pixels_falls_back_when_overfiltered():
    # photo that is all skin: filtering would leave it empty -> must fall back to foreground
    img = _solid(SKIN, 20, 20)
    fg = np.ones((20, 20), dtype=bool)

    pixels = gather_pixels(img, fg, drop_skin=True)
    assert len(pixels) == 400


# ---------------------------------------------------------------------------
# B1 regression (issue #7/#20): the classic heuristic misses dark skin; the
# adaptive filter samples the subject's actual tone and does remove it.
# ---------------------------------------------------------------------------


def test_classic_skin_mask_misses_dark_skin_B1():
    # Documented bias: the y > 80 condition excludes dark skin entirely.
    # This test pins the behavior we start from.
    assert not skin_mask(_solid(DARK_SKIN)).any()


def test_adaptive_mask_catches_dark_skin_B1():
    # With the subject's dark skin in the face band, the adaptive filter
    # samples THEIR tone and filters it just like light skin, leaving the garment.
    img = _band(DARK_SKIN, NAVY)
    fg = np.ones(img.shape[:2], dtype=bool)

    assert estimate_skin_tone(img, fg) is not None
    mask = adaptive_skin_mask(img, fg)
    assert mask[:6].all()  # dark skin marked as skin
    assert not mask[6:].any()  # the garment stays intact

    pixels = gather_pixels(img, fg, drop_skin=True)
    assert np.allclose(pixels, NAVY)


# ---------------------------------------------------------------------------
# B2 regression (issue #20): the classic heuristic erases warm garments as
# skin false positives; the adaptive filter, tied to the subject's tone,
# keeps them unless the whole outfit is skin-colored (guardrail).
# ---------------------------------------------------------------------------


def test_classic_skin_mask_false_positives_warm_garments_B2():
    # The universal YCbCr range flags coral/camel garment tones as skin.
    assert skin_mask(_solid(CORAL)).all()
    assert skin_mask(_solid(CAMEL)).all()


def test_adaptive_keeps_warm_garment_distinct_from_skin_B2():
    # Light-skinned subject + coral garment: the coral is far from THEIR skin
    # tone, so the classic filter would erase it but the adaptive one keeps it.
    img = _band(SKIN, CORAL)
    fg = np.ones(img.shape[:2], dtype=bool)

    mask = adaptive_skin_mask(img, fg)
    assert mask[:6].all()  # actual skin does get filtered
    assert not mask[6:].any()  # the coral is NOT filtered

    pixels = gather_pixels(img, fg, drop_skin=True)
    assert (pixels == np.array(CORAL)).all(axis=1).any()
    assert not (pixels == np.array(SKIN)).all(axis=1).any()


def test_adaptive_guardrail_skips_skin_colored_outfit_B2():
    # Skin-colored (camel) outfit covering > MAX_SKIN_FRACTION of the foreground:
    # the guardrail prefers filtering nothing over erasing the garment.
    img = _band(SKIN, CAMEL, h_top=4, h_bottom=16)
    fg = np.ones(img.shape[:2], dtype=bool)

    assert not adaptive_skin_mask(img, fg).any()


# ---------------------------------------------------------------------------
# Without a sampleable subject (nothing with skin chroma) we fall back to the
# classic heuristic.
# ---------------------------------------------------------------------------


def test_estimate_skin_tone_returns_none_without_seeds():
    img = _solid(NAVY, 20, 20)
    fg = np.ones((20, 20), dtype=bool)
    assert estimate_skin_tone(img, fg) is None


def test_adaptive_falls_back_to_classic_without_subject():
    img = _solid(NAVY, 20, 20)
    fg = np.ones((20, 20), dtype=bool)
    assert np.array_equal(adaptive_skin_mask(img, fg), skin_mask(img))


# ---------------------------------------------------------------------------
# Empty foreground (review F12): the "fall back to the full foreground" path
# must not hand an empty array to K-means.
# ---------------------------------------------------------------------------

import pytest

from colorlab.palette import NoPixelsError


def test_gather_pixels_empty_foreground_raises_typed_error():
    rgb = _solid(NAVY)
    fg_mask = np.zeros(rgb.shape[:2], dtype=bool)  # remover found no subject
    with pytest.raises(NoPixelsError):
        gather_pixels(rgb, fg_mask, drop_skin=True)
    with pytest.raises(NoPixelsError):
        gather_pixels(rgb, fg_mask, drop_skin=False)
