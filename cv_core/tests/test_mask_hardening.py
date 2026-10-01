"""Tests for the OPT-IN mask hardening + applicability layer (I2 condition C1).

Synthetic class maps only (deterministic, no model). The canonical path of
``split_garment_masks`` (harden=None) is pinned byte-identical so the golden
fixtures / Dart parity cannot move.
"""

import numpy as np
import pytest

from colorlab.segmentation import (
    CLASS_BACKGROUND,
    CLASS_BODY_SKIN,
    CLASS_CLOTHES,
    CLASS_FACE_SKIN,
    CLASS_HAIR,
    CLASS_OTHERS,
    HIP_WAIST_MIN_UPPER_SHARE,
    HOLE_MAX_FRACTION,
    REASON_MASK_UNRELIABLE,
    REASON_POOR_LIGHT,
    REASON_REGION_TOO_SMALL,
    REASON_SEVERAL_PEOPLE,
    RECOLOR_HARDENING,
    RECOLOR_MIN_REGION_FRACTION,
    REGION_LOWER,
    REGION_UPPER,
    SECOND_PERSON_MIN_RATIO,
    MaskHardening,
    check_applicability,
    drop_detached_clothes,
    fill_clothes_holes,
    harden_class_map,
    hip_split_row,
    mask_reliability_metrics,
    person_component_ratio,
    resample_class_map_smooth,
    split_garment_masks,
    upscale_class_map,
)

H, W = 320, 240


def _empty(h=H, w=W):
    return np.full((h, w), CLASS_BACKGROUND, dtype=np.uint8)


def _person(cm, *, rows=(40, 260), cols=(70, 170)):
    """Hair + face + body skin on top of a clothes rectangle (a dressed torso
    with the head attached)."""
    cm[10:22, 100:140] = CLASS_HAIR
    cm[22:34, 102:138] = CLASS_FACE_SKIN
    cm[34:40, 110:130] = CLASS_BODY_SKIN  # neck touches the clothes
    cm[rows[0] : rows[1], cols[0] : cols[1]] = CLASS_CLOTHES
    return cm


# ---------------------------------------------------------------------------
# Canonical path untouched.
# ---------------------------------------------------------------------------


def test_split_without_harden_is_the_canonical_mid_row_split():
    cm = _person(_empty())
    cm[120:125, 80:160] = CLASS_BACKGROUND  # a gap that a hardening would fill
    cm[280:300, 20:40] = CLASS_CLOTHES  # a detached blob that hardening drops
    plain = split_garment_masks(cm, erode_px=0)
    hard = split_garment_masks(cm, erode_px=0, harden=RECOLOR_HARDENING)
    # Canonical: the gap stays a gap, the blob is still in the mask, mid-row
    # of the FULL bbox (rows 40..299 -> 169).
    assert not plain[REGION_UPPER][120:125, 80:160].any()
    assert plain[REGION_LOWER][280:300, 20:40].all()
    assert plain[REGION_UPPER][168].any() and not plain[REGION_UPPER][169].any()
    # Hardened: gap filled, blob gone, split from the hardened bbox.
    assert hard[REGION_UPPER][122, 100]
    assert not (hard[REGION_UPPER] | hard[REGION_LOWER])[280:300, 20:40].any()


# ---------------------------------------------------------------------------
# Smoothed resample.
# ---------------------------------------------------------------------------


def test_resample_smooth_rounds_the_nearest_staircase():
    """A diagonal edge in a 32-px map upscaled x8: nearest has 8-px steps, the
    smoothed one-hot argmax is within ~2 px of the true diagonal."""
    small = np.full((32, 32), CLASS_BACKGROUND, dtype=np.uint8)
    yy, xx = np.mgrid[0:32, 0:32]
    small[yy + xx >= 32] = CLASS_CLOTHES
    nearest = upscale_class_map(small, 256, 256) == CLASS_CLOTHES
    smooth = resample_class_map_smooth(small, 256, 256) == CLASS_CLOTHES
    yy, xx = np.mgrid[0:256, 0:256]
    # Ideal diagonal: floor(Y/8) + floor(X/8) >= 32 loses 3.5/8 per axis on
    # average, so the staircase straddles the line Y + X >= 263.
    truth = (yy + xx) >= 263
    err_nearest = np.abs(nearest.astype(int) - truth.astype(int)).sum()
    err_smooth = np.abs(smooth.astype(int) - truth.astype(int)).sum()
    assert err_smooth < err_nearest
    # Every class id still valid, one class per pixel, roughly the same area.
    assert set(np.unique(resample_class_map_smooth(small, 256, 256))) <= {0, 4}
    assert abs(smooth.sum() - nearest.sum()) < 0.02 * nearest.sum()


def test_resample_smooth_same_size_no_blur_is_identity():
    cm = _person(_empty())
    np.testing.assert_array_equal(resample_class_map_smooth(cm, W, H, sigma=0), cm)


def test_resample_smooth_never_invents_a_class():
    cm = _person(_empty())
    out = resample_class_map_smooth(cm, 2 * W, 2 * H)
    assert set(np.unique(out)) <= set(np.unique(cm))
    assert out.shape == (2 * H, 2 * W) and out.dtype == np.uint8


# ---------------------------------------------------------------------------
# Hole fill.
# ---------------------------------------------------------------------------


def test_fill_holes_fills_small_background_hole_only():
    cm = _person(_empty())
    cm[100:110, 100:110] = CLASS_BACKGROUND  # 100 px hole (< 5% of 22000)
    cm[150:230, 80:160] = CLASS_BACKGROUND  # 6400 px hole (> 5%): kept open
    filled = fill_clothes_holes(cm)
    assert filled[100:110, 100:110].all()
    assert not filled[150:230, 80:160].any()
    assert filled.sum() == (cm == CLASS_CLOTHES).sum() + 100


def test_fill_holes_keeps_skin_and_hair_inside_a_hole():
    """A hand (body skin) in front of the shirt, with a thin background ring
    around it: the ring is filled, the skin is not."""
    cm = _person(_empty())
    cm[100:120, 100:120] = CLASS_BACKGROUND
    cm[103:117, 103:117] = CLASS_BODY_SKIN
    filled = fill_clothes_holes(cm)
    assert filled[100, 100] and filled[119, 119]  # ring filled
    assert not filled[103:117, 103:117].any()  # skin untouched


def test_fill_holes_fills_enclosed_face_only_island():
    """A face-skin blob with no hair / body skin inside a garment is a print
    or a misfire, not a face: filled."""
    cm = _person(_empty())
    cm[100:120, 100:120] = CLASS_FACE_SKIN
    assert fill_clothes_holes(cm)[100:120, 100:120].all()


def test_fill_holes_ignores_notches_open_to_the_edge():
    cm = _person(_empty(), rows=(40, H))  # garment runs to the frame bottom
    cm[300:H, 100:110] = CLASS_BACKGROUND  # a notch open at the bottom edge
    assert not fill_clothes_holes(cm)[300:H, 100:110].any()


def test_fill_holes_threshold_is_a_fraction_of_clothes_area():
    cm = _person(_empty())
    cm[100:110, 100:110] = CLASS_BACKGROUND
    area = (cm == CLASS_CLOTHES).sum()
    assert fill_clothes_holes(cm, max_fraction=100 / area + 1e-9)[105, 105]
    assert not fill_clothes_holes(cm, max_fraction=100 / area - 1e-9)[105, 105]
    assert HOLE_MAX_FRACTION < 0.1


# ---------------------------------------------------------------------------
# Detached components.
# ---------------------------------------------------------------------------


def test_drop_detached_removes_blob_that_touches_no_person():
    cm = _person(_empty())
    cm[280:310, 10:50] = CLASS_CLOTHES  # coat on a hook: 1200 px, no skin
    kept = drop_detached_clothes(cm)
    assert not kept[280:310, 10:50].any()
    assert kept[40:260, 70:170].all()


def test_drop_detached_keeps_second_garment_attached_by_skin_or_others():
    """Crop top + shorts separated by bare midriff (skin) and trousers under a
    belt (others) are separate components but both stay."""
    cm = _person(_empty(), rows=(40, 120))
    cm[120:140, 70:170] = CLASS_BODY_SKIN  # midriff
    cm[140:200, 80:160] = CLASS_CLOTHES  # shorts touch the skin
    cm[200:206, 80:160] = CLASS_OTHERS  # a belt-like strip
    cm[206:260, 80:160] = CLASS_CLOTHES  # trousers touch only the belt
    kept = drop_detached_clothes(cm)
    assert kept[140:200, 80:160].all()
    assert kept[206:260, 80:160].all()


def test_drop_detached_keeps_largest_only_when_nothing_is_attached():
    cm = _empty()
    cm[40:260, 70:170] = CLASS_CLOTHES  # hood up, gloves: no skin at all
    cm[280:300, 10:40] = CLASS_CLOTHES
    kept = drop_detached_clothes(cm)
    assert kept[40:260, 70:170].all() and not kept[280:300, 10:40].any()


def test_drop_detached_drops_a_blob_larger_than_the_garment():
    """A sofa labelled clothes, bigger than the person's garment: the attached
    garment wins, the largest-component fallback does NOT fire."""
    cm = _person(_empty(), rows=(40, 120))  # 8000 px attached to the neck
    cm[200:300, 20:220] = CLASS_CLOTHES  # 20000 px, no skin
    kept = drop_detached_clothes(cm)
    assert kept[40:120, 70:170].all() and not kept[200:300, 20:220].any()


def test_drop_detached_removes_speckle_even_if_touching_skin():
    cm = _person(_empty())
    cm[36, 109] = CLASS_CLOTHES  # 1 px speckle glued to the neck skin
    assert not drop_detached_clothes(cm)[36, 109]
    assert drop_detached_clothes(cm, speckle_min_fraction=0.0)[36, 109]


# ---------------------------------------------------------------------------
# Hip split.
# ---------------------------------------------------------------------------


def _silhouette(widths, *, top=40, center=120):
    """Clothes mask from a per-row width list (rows top..top+len)."""
    cm = np.zeros((H, W), dtype=bool)
    for i, w in enumerate(widths):
        cm[top + i, center - w // 2 : center + w // 2] = True
    return cm


def test_hip_split_finds_the_waist_minimum():
    widths = [100] * 60 + [60] * 20 + [110] * 100  # torso, waist, hips+legs
    row, from_waist = hip_split_row(_silhouette(widths))
    assert from_waist
    assert 40 + 60 <= row <= 40 + 80  # inside the narrow band


def test_hip_split_falls_back_to_mid_row_on_monotone_profile():
    widths = list(np.linspace(120, 40, 180).astype(int))  # long sleeves: taper
    row, from_waist = hip_split_row(_silhouette(widths))
    assert not from_waist
    assert row == (40 + 40 + 179) // 2


def test_hip_split_ignores_a_shallow_dip():
    widths = [100] * 60 + [95] * 20 + [100] * 100  # 5% dip: not a waist
    row, from_waist = hip_split_row(_silhouette(widths))
    assert not from_waist and row == (40 + 40 + 179) // 2


def test_hip_split_ignores_a_dip_below_the_search_band():
    """The crotch: a dip at 65% of the bbox height (thighs together, then legs
    apart) is outside HIP_SEARCH_BAND -> mid-row."""
    widths = [100] * 110 + [70] * 10 + [100] * 60
    row, from_waist = hip_split_row(_silhouette(widths))
    assert not from_waist and row == (40 + 40 + 179) // 2


def test_hip_split_rejects_empty_mask():
    with pytest.raises(ValueError):
        hip_split_row(np.zeros((H, W), dtype=bool))


# Waist guard (HIP_WAIST_MIN_UPPER_SHARE, 2026-10-01).
# Edge minimum: a raised sleeve mislabelled "others" leaves a narrow flat
# torso band that widens down to the hips; the argmin lands 1 row inside the
# band edge (row 95, band starts at 94) and the "waist" would leave a stub top.
_EDGE_MINIMUM = [50] * 50 + [42] * 5 + [38] * 4 + [120] * 121
# True waist whose top is just above the guard (upper share ~0.31).
_TRUE_WAIST_NEAR_GUARD = [100] * 55 + [60] * 15 + [110] * 110


def _upper_share(clothes, row):
    return clothes[:row].sum() / clothes.sum()


def test_waist_guard_rejects_an_edge_minimum_that_leaves_a_stub_top(monkeypatch):
    clothes = _silhouette(_EDGE_MINIMUM)
    monkeypatch.setattr(
        "colorlab.segmentation.HIP_WAIST_MIN_UPPER_SHARE", 0.0
    )  # the pre-guard rule
    raw_row, raw_from_waist = hip_split_row(clothes)
    assert raw_from_waist and raw_row == 95
    assert _upper_share(clothes, raw_row) < HIP_WAIST_MIN_UPPER_SHARE
    monkeypatch.undo()
    row, from_waist = hip_split_row(clothes)
    assert not from_waist
    assert row == (40 + 40 + len(_EDGE_MINIMUM) - 1) // 2  # the mid-row fallback


def test_waist_guard_keeps_a_true_waist_with_a_full_top():
    clothes = _silhouette(_TRUE_WAIST_NEAR_GUARD)
    row, from_waist = hip_split_row(clothes)
    assert from_waist
    assert 40 + 55 <= row < 40 + 70  # inside the narrow band
    assert _upper_share(clothes, row) >= HIP_WAIST_MIN_UPPER_SHARE


def test_waist_guard_fallback_reaches_the_recolor_regions():
    """End to end through split_garment_masks(harden=...): the edge minimum
    no longer cuts the top short; the upper region reaches the mid-row."""
    cm = _empty()
    cm[10:22, 100:140] = CLASS_HAIR
    cm[22:34, 102:138] = CLASS_FACE_SKIN
    cm[34:40, 110:130] = CLASS_BODY_SKIN
    cm[_silhouette(_EDGE_MINIMUM)] = CLASS_CLOTHES
    regions = split_garment_masks(cm, erode_px=0, harden=RECOLOR_HARDENING)
    upper_rows = np.where(regions[REGION_UPPER].any(axis=1))[0]
    lower_rows = np.where(regions[REGION_LOWER].any(axis=1))[0]
    assert upper_rows[-1] + 1 == lower_rows[0]
    assert lower_rows[0] > 40 + 70  # well below the stub-top row (95)


def test_split_with_harden_uses_the_waist_row():
    cm = _person(_empty(), rows=(40, 100))  # torso 100 wide (cols 70..170)
    cm[100:120, 90:150] = CLASS_CLOTHES  # waist 60 wide
    cm[120:220, 65:175] = CLASS_CLOTHES  # hips 110 wide
    masks = split_garment_masks(cm, erode_px=0, harden=MaskHardening())
    assert masks[REGION_UPPER][40:100].any()
    assert not masks[REGION_UPPER][120:].any()
    assert masks[REGION_LOWER][130:220].any()
    assert not masks[REGION_LOWER][:100].any()


# ---------------------------------------------------------------------------
# harden_class_map composition.
# ---------------------------------------------------------------------------


def test_harden_class_map_only_touches_the_clothes_class():
    cm = _person(_empty())
    cm[100:110, 100:110] = CLASS_BACKGROUND
    cm[280:310, 10:50] = CLASS_CLOTHES
    out = harden_class_map(cm, RECOLOR_HARDENING)
    others = cm != CLASS_CLOTHES
    # Non-clothes pixels are unchanged except where they BECAME clothes.
    changed = out != cm
    assert set(np.unique(out[changed & others])) <= {CLASS_CLOTHES}
    assert (out[280:310, 10:50] == CLASS_BACKGROUND).all()  # dropped
    assert (out[100:110, 100:110] == CLASS_CLOTHES).all()  # filled
    assert out is not cm and cm[105, 105] == CLASS_BACKGROUND  # input untouched


def test_harden_class_map_growth_never_covers_skin_or_hair():
    cm = _person(_empty())
    out = harden_class_map(cm, MaskHardening(grow_px=3))
    assert (out[34:40, 110:130] == CLASS_BODY_SKIN).all()  # neck intact
    assert (out[10:22, 100:140] == CLASS_HAIR).all()
    assert (out[260:263, 70:170] == CLASS_CLOTHES).all()  # grew into background
    assert out[263, 120] == CLASS_BACKGROUND


def test_harden_class_map_all_off_is_identity():
    cm = _person(_empty())
    cm[280:310, 10:50] = CLASS_CLOTHES
    off = MaskHardening(fill_holes=False, drop_detached=False, hip_split=False)
    np.testing.assert_array_equal(harden_class_map(cm, off), cm)


# ---------------------------------------------------------------------------
# Applicability.
# ---------------------------------------------------------------------------


def _bright(h=H, w=W):
    return np.full((h, w, 3), 180, dtype=np.uint8)


def test_applicable_single_lit_person():
    cm = _person(_empty())
    regions = split_garment_masks(cm, erode_px=0, harden=RECOLOR_HARDENING)
    app = check_applicability(cm, _bright(), regions)
    assert app.applicable and app.reason is None
    assert app.regions == {REGION_UPPER: None, REGION_LOWER: None}
    assert app.metrics["person_component_ratio"] == 0.0


def test_several_people_from_second_person_component():
    cm = _person(_empty())
    # A second, smaller dressed person (own skin) away from the first.
    cm[200:212, 200:230] = CLASS_FACE_SKIN
    cm[212:300, 195:235] = CLASS_CLOTHES
    ratio = person_component_ratio(cm)
    assert ratio >= SECOND_PERSON_MIN_RATIO
    assert check_applicability(cm, _bright()).reason == REASON_SEVERAL_PEOPLE


def test_several_people_limit_touching_people_are_one_component():
    """Documented limit: two people in contact form ONE person component."""
    cm = _person(_empty())
    cm[200:212, 170:200] = CLASS_FACE_SKIN  # touches the first person's clothes
    cm[212:300, 170:210] = CLASS_CLOTHES
    assert person_component_ratio(cm) == 0.0
    assert check_applicability(cm, _bright()).applicable


def test_poor_light_on_a_dark_frame_and_dark_person():
    cm = _person(_empty())
    dark = np.full((H, W, 3), 12, dtype=np.uint8)
    app = check_applicability(cm, dark)
    assert app.reason == REASON_POOR_LIGHT
    assert app.metrics["frame_median_l"] < 20


def test_poor_light_not_flagged_for_dark_garment_in_a_lit_scene():
    """Skin-tone / dark-garment safety: a black outfit on a bright wall with
    highlights on the person stays applicable."""
    cm = _person(_empty())
    rgb = _bright()
    rgb[cm == CLASS_CLOTHES] = 15  # black garment
    rgb[cm == CLASS_FACE_SKIN] = (60, 40, 30)  # deep skin tone
    rgb[cm == CLASS_HAIR] = 230  # a highlight on the person
    assert check_applicability(cm, rgb).applicable


def test_light_check_skipped_without_photo():
    cm = _person(_empty())
    app = check_applicability(np.full((H, W), 12, dtype=np.uint8) * 0 + cm)
    assert "frame_median_l" not in app.metrics


def test_region_too_small_per_region_and_photo():
    cm = _person(_empty(), rows=(40, 220))
    regions = {
        REGION_UPPER: cm == CLASS_CLOTHES,
        REGION_LOWER: np.zeros((H, W), dtype=bool),
    }
    regions[REGION_LOWER][230:240, 100:120] = True  # 200 px = 0.26% of frame
    app = check_applicability(cm, _bright(), regions)
    assert app.applicable  # the upper region is usable
    assert app.regions[REGION_LOWER] == REASON_REGION_TOO_SMALL
    assert app.regions[REGION_UPPER] is None
    assert app.metrics[f"{REGION_LOWER}_fraction"] < RECOLOR_MIN_REGION_FRACTION
    only_small = {REGION_LOWER: regions[REGION_LOWER]}
    assert check_applicability(cm, _bright(), only_small).reason == (
        REASON_REGION_TOO_SMALL
    )


def test_mask_unreliable_on_swiss_cheese_mask():
    cm = _person(_empty())
    rng = np.random.default_rng(3)
    yy, xx = np.mgrid[40:260, 70:170]
    holes = rng.random(yy.shape) < 0.2  # ~20% enclosed 1-px holes
    holes[0, :] = holes[-1, :] = holes[:, 0] = holes[:, -1] = False
    cm[yy[holes], xx[holes]] = CLASS_BACKGROUND
    metrics = mask_reliability_metrics(cm)
    assert metrics["hole_fraction"] > 0.1
    assert check_applicability(cm, _bright()).reason == REASON_MASK_UNRELIABLE


def test_mask_unreliable_on_large_detached_fraction():
    cm = _person(_empty(), rows=(40, 120))  # 8000 px on the person
    cm[200:300, 20:220] = CLASS_CLOTHES  # 20000 px detached = 71% of clothes
    assert mask_reliability_metrics(cm)["detached_fraction"] > 0.25
    app = check_applicability(cm, _bright())
    # A detached blob this big is ALSO a second person component (it dwarfs
    # the person mask), and several_people is checked first: either way the
    # photo is refused.
    assert app.reason in (REASON_MASK_UNRELIABLE, REASON_SEVERAL_PEOPLE)
    assert app.metrics["detached_fraction"] > 0.25


def test_reason_priority_several_people_first():
    cm = _person(_empty())
    cm[200:212, 200:230] = CLASS_FACE_SKIN
    cm[212:300, 195:235] = CLASS_CLOTHES
    dark = np.full((H, W, 3), 12, dtype=np.uint8)
    assert check_applicability(cm, dark).reason == REASON_SEVERAL_PEOPLE


def test_check_applicability_rejects_shape_mismatch():
    with pytest.raises(ValueError):
        check_applicability(_person(_empty()), np.zeros((10, 10, 3), np.uint8))
