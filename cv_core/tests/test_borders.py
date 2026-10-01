"""Border-band background model (issue #48): synthetic and real-photo tests.

The layer is optional and only affects harmony-BASE eligibility; the palette
is never modified. Evaluation evidence:
docs/architecture/2026-07-09_*_F1_three-border-rnd.md.
"""

from pathlib import Path

import cv2
import numpy as np
import pytest

from colorlab.background import remove_background
from colorlab.borders import (
    BORDER_COVERAGE_MIN,
    MULTI_EDGE_MIN,
    estimate_background_candidates,
    estimate_multiedge_background,
    pick_harmony_base_avoiding_background,
    product_background_mask,
)
from colorlab.filters import gather_pixels
from colorlab.harmony import pick_harmony_base, pick_harmony_base_index
from colorlab.image_io import load_image
from colorlab.palette import dominant_colors, srgb_to_lab

SAMPLES = Path(__file__).resolve().parents[2] / "samples"

WALL_GRAY = (200, 200, 200)
FLOOR_BROWN = (120, 90, 60)
GARMENT_RED = (200, 40, 40)


def _studio_photo(
    wall=WALL_GRAY, floor=FLOOR_BROWN, garment=GARMENT_RED, height=200, width=150
):
    """Synthetic full-body studio shot: wall on top, floor strip at the
    bottom, centered garment blob that touches no border. The floor is a thin
    sliver (5% of the height): at the frame edge the floor recedes with
    perspective, which is exactly why only the bottom strip is excluded from
    the wall band."""
    img = np.zeros((height, width, 3), dtype=np.uint8)
    img[:] = wall
    img[int(0.95 * height) :] = floor
    img[
        int(0.25 * height) : int(0.70 * height), int(0.30 * width) : int(0.70 * width)
    ] = garment
    return img


def _delta_e(rgb_a, rgb_b):
    d = srgb_to_lab(np.asarray(rgb_a, float)) - srgb_to_lab(np.asarray(rgb_b, float))
    d[0] *= 0.5  # attenuated-L repo convention
    return float(np.sqrt((d**2).sum()))


# ---------------------------------------------------------------- candidates


def test_wall_and_floor_candidates_detected():
    candidates = estimate_background_candidates(_studio_photo())
    origins = {c.origin: c for c in candidates}
    assert set(origins) == {"wall", "floor"}
    assert _delta_e(origins["wall"].color, WALL_GRAY) < 5
    assert _delta_e(origins["floor"].color, FLOOR_BROWN) < 5
    assert all(c.coverage >= BORDER_COVERAGE_MIN for c in candidates)


def test_floor_only_candidate_when_wall_is_busy():
    """The V2 differentiator: a floor different from a busy wall still
    qualifies on its own (a single whole-frame band would see neither)."""
    rng = np.random.default_rng(42)
    img = _studio_photo()
    height, width = img.shape[:2]
    busy = rng.integers(0, 256, size=(height, width, 3), dtype=np.uint8)
    img[: int(0.95 * height)] = busy[: int(0.95 * height)]  # wall area -> noise
    candidates = estimate_background_candidates(img)
    assert [c.origin for c in candidates] == ["floor"]


def test_busy_borders_yield_no_candidates():
    """Do-no-harm gate: if no band is nearly uniform the layer stays off."""
    rng = np.random.default_rng(42)
    img = rng.integers(0, 256, size=(200, 150, 3), dtype=np.uint8)
    assert estimate_background_candidates(img) == []


# ------------------------------------------------------------------ demotion

# Slightly chromatic beige (LAB chroma ~18 > NEUTRAL_CHROMA): a wall tone that
# CAN win the baseline pick, the exact failure mode of the background category.
BEIGE_WALL = (200, 180, 150)
MUTED_BLUE = (110, 130, 160)


def _wallish_palette():
    colors = np.array([BEIGE_WALL, MUTED_BLUE])
    weights = np.array([0.75, 0.25])
    return colors, weights


def test_demotion_moves_base_off_the_background():
    colors, weights = _wallish_palette()
    # Sanity: without the layer the beige wall leads (saturation x weight).
    assert pick_harmony_base(colors, weights) == BEIGE_WALL
    img = _studio_photo(wall=BEIGE_WALL)
    candidates = estimate_background_candidates(img)
    base = pick_harmony_base_avoiding_background(colors, weights, candidates)
    assert base == MUTED_BLUE


def test_no_candidates_keeps_baseline_pick():
    colors, weights = _wallish_palette()
    assert pick_harmony_base_avoiding_background(
        colors, weights, []
    ) == pick_harmony_base(colors, weights)


def test_all_background_like_palette_falls_back_to_baseline():
    """If the whole palette matches the border (monochrome outfit against a
    matching wall), demotion refuses to act instead of returning nothing."""
    colors = np.array([BEIGE_WALL, (205, 185, 155)])
    weights = np.array([0.6, 0.4])
    candidates = estimate_background_candidates(_studio_photo(wall=BEIGE_WALL))
    assert any(c.origin == "wall" for c in candidates)
    base = pick_harmony_base_avoiding_background(colors, weights, candidates)
    assert base == pick_harmony_base(colors, weights)


def test_palette_is_not_modified():
    colors, weights = _wallish_palette()
    colors_before, weights_before = colors.copy(), weights.copy()
    candidates = estimate_background_candidates(_studio_photo(wall=BEIGE_WALL))
    pick_harmony_base_avoiding_background(colors, weights, candidates)
    assert np.array_equal(colors, colors_before)
    assert np.array_equal(weights, weights_before)


# ------------------------------------------------------------- real photos


def _pipeline(path):
    cv2.setRNGSeed(0)  # deterministic GrabCut, same anchor as test_g0_skin
    img = load_image(str(path))
    rgb, fg_mask = remove_background(img)
    pixels = gather_pixels(rgb, fg_mask)
    colors, weights = dominant_colors(pixels)
    return rgb, colors, weights


@pytest.mark.slow
def test_busy_real_background_gate_stays_off():
    """g0-03 (cluttered background): no band is uniform -> layer inert."""
    rgb, colors, weights = _pipeline(SAMPLES / "g0" / "g0-03-fondo-recargado.jpg")
    candidates = estimate_background_candidates(rgb)
    assert candidates == []
    assert pick_harmony_base_avoiding_background(
        colors, weights, candidates
    ) == pick_harmony_base(colors, weights)


@pytest.mark.slow
def test_correct_photo_base_survives_fired_gate():
    """g0-01 (white studio wall, correct baseline): the gate fires on the
    wall but the teal garment base is nowhere near it -> base unchanged.
    This is the do-no-harm property that killed #44 and that #48 must keep."""
    rgb, colors, weights = _pipeline(SAMPLES / "g0" / "g0-01-multicolor.jpg")
    candidates = estimate_background_candidates(rgb)
    assert any(c.origin == "wall" for c in candidates)
    assert pick_harmony_base_avoiding_background(
        colors, weights, candidates
    ) == pick_harmony_base(colors, weights)


# Battery photo of labeled row 11 (background KO fixed by the floor model in
# the #48 evaluation). The battery lives outside git: skip where absent.
ROW11_PHOTO = SAMPLES / "g0" / "raw" / "test" / "247ac98e288609e616f1dde9aede4e94.jpg"


@pytest.mark.slow
@pytest.mark.skipif(not ROW11_PHOTO.exists(), reason="local battery photo not present")
def test_row11_floor_leak_demoted():
    """Row 11 of the CEO's labels: baseline base #735F58 sits on the floor
    color; the floor candidate demotes it and a garment color leads."""
    rgb, colors, weights = _pipeline(ROW11_PHOTO)
    candidates = estimate_background_candidates(rgb)
    assert [c.origin for c in candidates] == ["floor"]
    baseline = pick_harmony_base(colors, weights)
    base = pick_harmony_base_avoiding_background(colors, weights, candidates)
    assert _delta_e(baseline, candidates[0].color) < 15  # baseline WAS the floor
    assert _delta_e(base, baseline) >= 10  # the base actually moved
    assert _delta_e(base, candidates[0].color) >= 15  # ... and off the floor


# ---------------------------------------- multi-edge co-occurrence model (#84)
#
# PRODUCT mode's center-subject background suppression. Principle: a color on
# >= MULTI_EDGE_MIN (3) distinct edges wraps the frame and is background; a
# centered subject touches at most 1-2 adjacent edges. Tested on synthetics
# that isolate the mechanism (not the 57 real gate photos).

PRODUCT_BLUE = (40, 90, 180)


def _wrapping_bg_photo(
    subject=PRODUCT_BLUE,
    wall=(95, 105, 120),
    floor=(150, 110, 85),
    height=340,
    width=260,
):
    """Centered subject over a wall (top) + floor (bottom) background.

    The wall wraps top + the upper left/right; the floor wraps bottom + the
    lower left/right — so EACH background tone is present on 3 edges, while the
    centered subject touches none."""
    img = np.empty((height, width, 3), dtype=np.uint8)
    img[: height // 2] = wall
    img[height // 2 :] = floor
    img[
        int(0.26 * height) : int(0.74 * height), int(0.33 * width) : int(0.67 * width)
    ] = subject
    return img


def test_multiedge_flags_colors_wrapping_three_edges():
    """Both background tones (each on 3 edges) are flagged; the centered
    subject (on 0 edges) is not."""
    img = _wrapping_bg_photo()
    bg = estimate_multiedge_background(img)
    assert bg, "wrapping background not detected"
    assert any(_delta_e(c, (95, 105, 120)) < 12 for c in bg), "wall missed"
    assert any(_delta_e(c, (150, 110, 85)) < 12 for c in bg), "floor missed"
    # The centered subject color must NOT be flagged as background.
    assert all(_delta_e(c, PRODUCT_BLUE) >= 12 for c in bg), "subject wrongly flagged"


def test_multiedge_ignores_subject_sharing_only_the_bottom_edge():
    """False-positive guard (the CEO's >= 3 rationale): a subject that fills the
    frame bottom (touching only the bottom edge, and the lower left/right) still
    stays below the 3-edge bar for its own distinctive color, so it survives.

    Here a plain wall wraps top/left/right (3 edges -> background) while a
    colored 'ground' subject occupies the whole lower third (bottom edge only,
    plus the two lower side slivers = its color reaches at most the bottom and
    the very bottom of the sides). The wall is flagged; the ground is a genuine
    2-edge-or-fewer color and is not hard-dropped."""
    wall = (200, 200, 200)
    ground = (60, 140, 90)  # a green 'subject' resting across the bottom
    img = np.full((340, 260, 3), wall, dtype=np.uint8)
    img[int(0.80 * 340) :] = ground  # only the bottom 20% -> bottom edge only
    bg = estimate_multiedge_background(img)
    assert any(_delta_e(c, wall) < 12 for c in bg), "3-edge wall not flagged"
    assert all(_delta_e(c, ground) >= 12 for c in bg), (
        "a bottom-only color was wrongly flagged as background (>= 3 rule broken)"
    )


def test_product_background_mask_drops_wrapping_bg_keeps_subject():
    """The mask covers the background pixels and spares the centered subject."""
    img = _wrapping_bg_photo()
    mask = product_background_mask(img)
    assert mask.any() and not mask.all()
    # Center (subject) is kept; a top-edge sample (wall) is dropped.
    cy, cx = img.shape[0] // 2, img.shape[1] // 2
    assert not mask[cy, cx], "subject center was dropped"
    assert mask[2, cx], "top-edge background was not dropped"


def test_product_background_mask_guardrail_on_frame_filling_subject():
    """A solid frame-filling product: its single color wraps every edge, so the
    naive rule would flag the SUBJECT. The coverage guardrail returns an
    all-False mask so the product is preserved."""
    img = np.full((300, 240, 3), PRODUCT_BLUE, dtype=np.uint8)
    mask = product_background_mask(img)
    assert not mask.any(), "guardrail failed: frame-filling subject would be dropped"


def test_multiedge_min_is_three():
    """Lock the CEO's false-positive-safe threshold (guided sneaker touches at
    most 1-2 edges)."""
    assert MULTI_EDGE_MIN == 3


# ---------------------------------------------------------------------------
# Index variant with the -1 canvas signal (review F14, 2026-09-30) — the
# Python mirror of Dart `pickHarmonyBaseAvoidingBackground`.
# ---------------------------------------------------------------------------

from colorlab.borders import (
    BackgroundCandidate,
    pick_harmony_base_index_avoiding_background,
)

PINK_WALL = (230, 180, 200)
NEAR_BLACK = (20, 20, 22)
RED_POP = (200, 30, 40)
MID_GRAY = (128, 128, 128)


def _f14_palette(red_weight):
    colors = np.array([PINK_WALL, NEAR_BLACK, RED_POP, MID_GRAY])
    weights = np.array([0.5, 0.4, red_weight, 0.02])
    wall = BackgroundCandidate(origin="wall", color=PINK_WALL, coverage=1.0)
    return colors, weights, [wall]


def test_index_variant_propagates_canvas_signal_when_survivors_are_neutral():
    # Wall demoted; the red pop (8%) is under POP_ON_NEUTRAL_MIN on a
    # neutral-dominant survivor set -> nothing eligible -> -1, like Dart.
    colors, weights, candidates = _f14_palette(red_weight=0.08)
    assert (
        pick_harmony_base_index_avoiding_background(colors, weights, candidates) == -1
    )
    # The RGB form keeps its historical (near-black) fallback: unchanged API.
    assert pick_harmony_base_avoiding_background(colors, weights, candidates) == (
        NEAR_BLACK
    )


def test_index_variant_maps_back_to_the_original_palette_index():
    colors, weights, candidates = _f14_palette(red_weight=0.15)
    idx = pick_harmony_base_index_avoiding_background(colors, weights, candidates)
    assert idx == 2, "red pop is index 2 of the ORIGINAL palette, not of the survivors"
    assert pick_harmony_base_avoiding_background(colors, weights, candidates) == RED_POP


def test_index_variant_without_candidates_is_the_plain_rule():
    colors, weights, _ = _f14_palette(red_weight=0.15)
    assert pick_harmony_base_index_avoiding_background(
        colors, weights, []
    ) == pick_harmony_base_index(colors, weights)
