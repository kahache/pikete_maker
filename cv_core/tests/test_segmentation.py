"""Tests for the Phase 2.5 segmentation mask contract and garment isolation.

Everything here runs on SYNTHETIC class maps (constructed numpy arrays):
deterministic, no model, no inference runtime. The Dart-parity pre/post
helpers are additionally validated against the on-device spike numbers by
the slow test in test_segmentation_model.py (needs the gitignored model).
"""

import numpy as np
import pytest
from PIL import Image

from colorlab.segmentation import (
    CLASS_BACKGROUND,
    CLASS_BODY_SKIN,
    CLASS_CLOTHES,
    CLASS_HAIR,
    MODEL_SIDE,
    NUM_CLASSES,
    REGION_LOWER,
    REGION_UPPER,
    NoPersonError,
    class_map_from_scores,
    erode_mask,
    load_class_mask,
    preprocess_rgb,
    save_class_mask,
    split_garment_masks,
    upscale_class_map,
)

H, W = 320, 240


def _empty_map(h=H, w=W):
    return np.full((h, w), CLASS_BACKGROUND, dtype=np.uint8)


# ---------------------------------------------------------------------------
# Mask file contract (grayscale-PNG-class-id — the QA hand-off format).
# ---------------------------------------------------------------------------


def test_class_mask_png_roundtrip(tmp_path):
    class_map = _empty_map()
    class_map[50:150, 60:180] = CLASS_CLOTHES
    class_map[20:50, 90:150] = CLASS_HAIR
    path = str(tmp_path / "photo.mask.png")
    save_class_mask(class_map, path)
    loaded = load_class_mask(path)
    assert loaded.dtype == np.uint8
    np.testing.assert_array_equal(loaded, class_map)


def test_load_class_mask_rejects_scaled_visualization(tmp_path):
    """A 0..255-scaled mask (a visualization, not class ids) must fail loudly
    instead of silently attributing pixels to nonexistent classes."""
    path = str(tmp_path / "scaled.mask.png")
    Image.fromarray(np.full((10, 10), 200, dtype=np.uint8), mode="L").save(path)
    with pytest.raises(ValueError, match="NUM_CLASSES"):
        load_class_mask(path)


def test_load_class_mask_rejects_rgb_png(tmp_path):
    path = str(tmp_path / "rgb.mask.png")
    Image.fromarray(np.zeros((10, 10, 3), dtype=np.uint8)).save(path)
    with pytest.raises(ValueError, match="grayscale"):
        load_class_mask(path)


# ---------------------------------------------------------------------------
# Dart-parity pre/post helpers.
# ---------------------------------------------------------------------------


def test_preprocess_rgb_constant_image_and_range():
    rgb = np.full((100, 80, 3), (51, 102, 204), dtype=np.uint8)
    out = preprocess_rgb(rgb)
    assert out.shape == (MODEL_SIDE, MODEL_SIDE, 3)
    assert out.dtype == np.float32
    np.testing.assert_allclose(out[..., 0], 51 / 255.0, atol=1e-6)
    np.testing.assert_allclose(out[..., 2], 204 / 255.0, atol=1e-6)


def test_preprocess_rgb_matches_dart_sampling_convention():
    """The Dart preprocess samples src = (dst + 0.5) * scale - 0.5 clamped at 0.
    A vertical gradient checks the row mapping is the same convention (i.e.
    NOT the naive dst * scale)."""
    h = 512  # scale 2: src(oy) = 2*oy + 0.5 -> mean of rows 2oy and 2oy+1
    rgb = np.zeros((h, 64, 3), dtype=np.uint8)
    rgb[:, :, 0] = np.minimum(np.arange(h), 255)[:, None]
    out = preprocess_rgb(rgb)
    # Row oy=10 -> src 20.5 -> (20 + 21)/2 = 20.5
    np.testing.assert_allclose(out[10, 0, 0], 20.5 / 255.0, atol=1e-6)
    # Row oy=0 -> src 0.5 -> (0 + 1)/2 = 0.5
    np.testing.assert_allclose(out[0, 0, 0], 0.5 / 255.0, atol=1e-6)


def test_class_map_from_scores_argmax_first_max_wins():
    scores = np.zeros((MODEL_SIDE, MODEL_SIDE, NUM_CLASSES), dtype=np.float32)
    scores[..., CLASS_CLOTHES] = 0.9
    scores[0, 0, :] = 0.5  # exact tie on every class -> lowest index (Dart strict >)
    cm = class_map_from_scores(scores)
    assert cm[0, 0] == CLASS_BACKGROUND
    assert cm[10, 10] == CLASS_CLOTHES
    assert cm.dtype == np.uint8


def test_class_map_from_scores_rejects_wrong_shape():
    with pytest.raises(ValueError):
        class_map_from_scores(np.zeros((10, 10, NUM_CLASSES), dtype=np.float32))


def test_upscale_class_map_nearest_indexing():
    """my = y * MODEL_SIDE // height — the exact Dart integer arithmetic."""
    map256 = np.zeros((MODEL_SIDE, MODEL_SIDE), dtype=np.uint8)
    map256[128:, :] = CLASS_CLOTHES  # bottom half clothes
    up = upscale_class_map(map256, width=100, height=500)
    assert up.shape == (500, 100)
    # y=249 -> 249*256//500 = 127 (background); y=250 -> 128 (clothes)
    assert up[249, 50] == CLASS_BACKGROUND
    assert up[250, 50] == CLASS_CLOTHES


def test_upscale_class_map_same_size_is_identity():
    map256 = (
        np.random.default_rng(1)
        .integers(0, NUM_CLASSES, (MODEL_SIDE, MODEL_SIDE))
        .astype(np.uint8)
    )
    np.testing.assert_array_equal(
        upscale_class_map(map256, MODEL_SIDE, MODEL_SIDE), map256
    )


# ---------------------------------------------------------------------------
# Garment isolation: split, erosion, guards.
# ---------------------------------------------------------------------------


def test_split_masks_mid_row_assignment():
    """Two clothes blobs -> bbox mid-row split assigns each to its region
    (Dart parity: mid = (r0 + r1) // 2, y < mid -> upper)."""
    cm = _empty_map()
    cm[40:120, 60:180] = CLASS_CLOTHES  # top blob
    cm[200:280, 70:170] = CLASS_CLOTHES  # bottom blob
    masks = split_garment_masks(cm, erode_px=0)
    assert set(masks) == {REGION_UPPER, REGION_LOWER}
    mid = (40 + 279) // 2  # 159
    assert masks[REGION_UPPER][:mid][cm[:mid] == CLASS_CLOTHES].all()
    assert not masks[REGION_UPPER][mid:].any()
    assert masks[REGION_LOWER][mid:][cm[mid:] == CLASS_CLOTHES].all()
    assert not masks[REGION_LOWER][:mid].any()
    # Regions are disjoint and cover exactly the clothes pixels.
    assert not (masks[REGION_UPPER] & masks[REGION_LOWER]).any()
    np.testing.assert_array_equal(
        masks[REGION_UPPER] | masks[REGION_LOWER], cm == CLASS_CLOTHES
    )


def test_split_masks_no_person_below_coverage():
    """Clothes coverage under MIN_CLOTHES_COVERAGE (1%) -> NoPersonError,
    the loud-degrade path mirroring the Dart isNoPerson exception."""
    cm = _empty_map()
    cm[100:110, 100:150] = CLASS_CLOTHES  # 500 px of 76800 = 0.65%
    with pytest.raises(NoPersonError):
        split_garment_masks(cm)


def test_split_masks_all_background_is_no_person():
    with pytest.raises(NoPersonError):
        split_garment_masks(_empty_map())


def test_erode_mask_removes_boundary_ring():
    mask = np.zeros((50, 50), dtype=bool)
    mask[10:40, 10:40] = True
    eroded = erode_mask(mask, 2)
    assert eroded[12:38, 12:38].all()  # interior survives
    assert not eroded[10:12, 10:40].any()  # 2-px boundary is gone
    assert not eroded[:, 10:12].any()
    assert erode_mask(mask, 0) is mask  # radius 0 = no-op


def test_split_masks_erosion_shrinks_regions():
    cm = _empty_map()
    cm[40:160, 60:180] = CLASS_CLOTHES
    cm[160:280, 60:180] = CLASS_CLOTHES
    full = split_garment_masks(cm, erode_px=0)
    eroded = split_garment_masks(cm)  # default MASK_ERODE_PX
    for region in (REGION_UPPER, REGION_LOWER):
        assert eroded[region].sum() < full[region].sum()
        # Eroded region is a strict subset of the raw region.
        assert not (eroded[region] & ~full[region]).any()


def test_split_masks_min_region_guard_drops_tiny_garment():
    """A sliver of a lower garment (chest-up framing) must not emit a palette:
    the region is dropped and only the upper garment remains."""
    cm = _empty_map()
    cm[30:100, 50:190] = CLASS_CLOTHES  # solid upper garment
    cm[300:315, 110:125] = CLASS_CLOTHES  # 225 px sliver < 0.5% of 76800
    masks = split_garment_masks(cm)
    assert REGION_UPPER in masks
    assert REGION_LOWER not in masks


def test_split_masks_no_region_survives_guards_is_no_person():
    """Coverage passes but every region dies post-erosion -> NoPersonError
    (scattered 1-px-thin clothes are not an analyzable person)."""
    cm = _empty_map()
    cm[::4, :] = CLASS_CLOTHES  # thin 1-px lines: 25% coverage, erode to nothing
    with pytest.raises(NoPersonError):
        split_garment_masks(cm)


def test_split_masks_rejects_invalid_class_values():
    cm = _empty_map()
    cm[0, 0] = NUM_CLASSES  # invalid id
    cm[100:200, 60:180] = CLASS_CLOTHES
    with pytest.raises(ValueError, match="NUM_CLASSES"):
        split_garment_masks(cm)


def test_split_masks_ignores_non_clothes_classes():
    """Skin/hair pixels adjacent to the garment never leak into a region mask."""
    cm = _empty_map()
    cm[40:200, 60:180] = CLASS_CLOTHES
    cm[10:40, 90:150] = CLASS_HAIR
    cm[200:260, 90:150] = CLASS_BODY_SKIN
    masks = split_garment_masks(cm, erode_px=0)
    for mask in masks.values():
        assert not mask[cm == CLASS_HAIR].any()
        assert not mask[cm == CLASS_BODY_SKIN].any()
        assert not mask[cm == CLASS_BACKGROUND].any()


# ---------------------------------------------------------------------------
# Class-map contract guard (review F15, 2026-09-30): fail loudly on maps the
# uint8 cast would silently corrupt.
# ---------------------------------------------------------------------------

from colorlab.segmentation import _validate_class_map


def test_validate_class_map_rejects_negative_ids():
    cm = np.zeros((4, 4), dtype=np.int64)
    cm[0, 0] = -1  # would wrap to 255 ("not clothes") under a uint8 cast
    with pytest.raises(ValueError, match="negative"):
        _validate_class_map(cm)


def test_validate_class_map_rejects_float_maps():
    cm = np.full((4, 4), 3.99)  # would truncate to 3 under a uint8 cast
    with pytest.raises(ValueError, match="integer dtype"):
        _validate_class_map(cm)


def test_validate_class_map_accepts_int64_argmax_output():
    cm = np.full((4, 4), CLASS_CLOTHES, dtype=np.int64)
    out = _validate_class_map(cm)
    assert out.dtype == np.uint8 and int(out[0, 0]) == CLASS_CLOTHES
