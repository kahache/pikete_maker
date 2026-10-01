import numpy as np
import pytest

from colorlab.harmony import (
    CANVAS_ACCENTS,
    canvas_accents,
    harmonies,
    hexstr,
    hsv_to_rgb,
    is_neutral,
    pick_harmony_base,
    pick_harmony_base_index,
    rgb_to_hsv,
)

FUCHSIA = (225, 54, 131)
NAVY = (30, 50, 110)
GRAY = (128, 128, 128)
BEIGE = (210, 205, 195)


def test_rgb_hsv_roundtrip():
    h, s, v = rgb_to_hsv(FUCHSIA)
    assert hsv_to_rgb(h, s, v) == pytest.approx(FUCHSIA, abs=1)


def test_hexstr():
    assert hexstr((225, 54, 131)) == "#E13683"
    assert hexstr((0, 0, 0)) == "#000000"


def test_is_neutral_detects_grays_and_beiges():
    assert is_neutral(GRAY)
    assert is_neutral(BEIGE)
    assert is_neutral((255, 255, 255))


def test_is_neutral_rejects_vivid_colors():
    assert not is_neutral(FUCHSIA)
    assert not is_neutral(NAVY)


# --- #22: chroma-based neutrality is stable on near-blacks (bugs B5/B8) ---

NEAR_BLACK = (3, 2, 3)  # B8: HSV sat 0.33 (unstable) but visually black
DARK_BLUE_GRAY = (58, 57, 70)  # B5: #3A3946, sat 0.19 -> was a false chromatic base
DARK_MAROON = (96, 18, 34)  # dark BUT genuinely chromatic: must stay chromatic
BEIGE_WALL = (200, 180, 150)  # slightly chromatic beige (sat 0.25): stays chromatic


def test_is_neutral_catches_near_black_B8():
    # HSV saturation calls #030203 "chromatic" (0.33); chroma knows it is black.
    assert is_neutral(NEAR_BLACK)


def test_is_neutral_catches_dark_neutral_B5():
    # #3A3946 is a desaturated dark blue-gray, not a garment color.
    assert is_neutral(DARK_BLUE_GRAY)


def test_is_neutral_keeps_dark_but_chromatic_colors():
    # The fix must NOT swallow real dark garment colors (maroon) or muted walls.
    assert not is_neutral(DARK_MAROON)
    assert not is_neutral(BEIGE_WALL)


def test_near_black_does_not_steal_the_base_from_a_real_garment_B8():
    # Repro of B8: a black (70%) used to outscore a saturated red cardigan
    # (25%) because HSV made the black look chromatic. Now the red leads.
    red = (238, 43, 56)
    colors = np.array([NEAR_BLACK, red, (128, 128, 128)])
    weights = np.array([0.70, 0.25, 0.05])
    assert pick_harmony_base(colors, weights) == red
    assert pick_harmony_base_index(colors, weights) == 1


# --- #57: dominant-neutral context gate (reflection attribution) ---

BLACK = (18, 18, 20)
WALL = (180, 178, 175)  # neutral wall
BLUE_REFLECTION = (45, 90, 205)


def test_tiny_chromatic_on_neutral_outfit_goes_to_canvas_57():
    # selfie22 repro: a 3% blue reflection on an all-black outfit must NOT lead
    # the harmonies. Dominant is black (neutral) -> the tiny pop is demoted ->
    # no eligible base -> canvas mode (-1).
    colors = np.array([BLACK, GRAY, WALL, BLUE_REFLECTION])
    weights = np.array([0.70, 0.17, 0.10, 0.03])
    assert pick_harmony_base_index(colors, weights) == -1


def test_substantial_accent_on_neutral_outfit_still_leads():
    # The gate must not over-fire: a real 20% accent on a neutral outfit still
    # leads (20% >= POP_ON_NEUTRAL_MIN).
    red = (200, 40, 45)
    colors = np.array([BLACK, GRAY, red])
    weights = np.array([0.62, 0.18, 0.20])
    assert pick_harmony_base(colors, weights) == red


def test_gate_inactive_when_dominant_is_chromatic():
    # Vuitton guard: dominant pink is chromatic -> gate inert -> the small
    # lavender pop does not change the result; the pink leads by weight.
    pink = (225, 54, 131)
    lavender = (156, 166, 198)
    colors = np.array([pink, lavender])
    weights = np.array([0.95, 0.05])
    assert pick_harmony_base(colors, weights) == pink
    assert pick_harmony_base_index(colors, weights) == 0


def test_pick_harmony_base_skips_dominant_neutral():
    # The neutral (background) is the most frequent, but the base must be the chromatic color.
    colors = np.array([BEIGE, NAVY])
    weights = np.array([0.7, 0.3])
    assert pick_harmony_base(colors, weights) == NAVY


def test_pick_harmony_base_weighs_saturation_and_frequency():
    # Between two chromatic colors, the highest saturation*weight wins.
    washed_out = hsv_to_rgb(0.6, 0.25, 0.8)  # washed-out blue, frequent
    vivid = hsv_to_rgb(0.9, 0.95, 0.85)  # vivid fuchsia, less frequent
    colors = np.array([washed_out, vivid])
    weights = np.array([0.55, 0.45])
    assert pick_harmony_base(colors, weights) == vivid


def test_pick_harmony_base_falls_back_to_dominant_when_all_neutral():
    colors = np.array([BEIGE, GRAY])
    weights = np.array([0.6, 0.4])
    assert pick_harmony_base(colors, weights) == BEIGE


def test_pick_harmony_base_index_returns_chromatic_position():
    # The neutral is the most frequent (index 0), but the base is the chromatic
    # NAVY at index 1.
    colors = np.array([BEIGE, NAVY])
    weights = np.array([0.7, 0.3])
    assert pick_harmony_base_index(colors, weights) == 1


def test_pick_harmony_base_index_is_minus_one_when_all_neutral():
    # Canvas mode (D10): no chromatic base -> -1, the trigger the Dart port and
    # the golden fixtures share.
    colors = np.array([BEIGE, GRAY, (255, 255, 255)])
    weights = np.array([0.5, 0.3, 0.2])
    assert pick_harmony_base_index(colors, weights) == -1


def test_canvas_accents_are_the_curated_set():
    accents = canvas_accents()
    # The curated set is the CEO-ratified fashion curation (D10), not derived
    # from the outfit: exactly the 5 versatile pops, all valid, all chromatic.
    assert accents == list(CANVAS_ACCENTS)
    assert len(accents) == 5
    for rgb in accents:
        assert all(0 <= c <= 255 for c in rgb)
        assert not is_neutral(rgb)  # a "pop" must actually pop


def test_canvas_accents_returns_fresh_list():
    # Callers must not be able to mutate the module-level curated set.
    canvas_accents().append((0, 0, 0))
    assert len(CANVAS_ACCENTS) == 5


def test_harmonies_structure():
    # Scheme names are product-facing strings and stay in Spanish (see harmonies()).
    schemes = harmonies(FUCHSIA)
    assert set(schemes) == {
        "Complementario",
        "Análogo",
        "Triádico",
        "Complementario dividido",
    }
    assert len(schemes["Complementario"]) == 2
    assert len(schemes["Análogo"]) == 3
    assert len(schemes["Triádico"]) == 3
    # the base color shows up in every scheme
    for cols in schemes.values():
        assert FUCHSIA in cols
    # every proposed color is valid RGB
    for cols in schemes.values():
        for rgb in cols:
            assert all(0 <= c <= 255 for c in rgb)


def test_complementary_is_opposite_hue():
    base_h, _, _ = rgb_to_hsv(FUCHSIA)
    comp = harmonies(FUCHSIA)["Complementario"][1]
    comp_h, _, _ = rgb_to_hsv(comp)
    delta = abs((comp_h - base_h) % 1.0)
    assert delta == pytest.approx(0.5, abs=0.02)


# ---------------------------------------------------------------------------
# as_rgb() narrowing helper (E4, 2026-09-30): the one place a palette row
# becomes the typed RGB triple; wrong lengths fail loudly.
# ---------------------------------------------------------------------------

from colorlab.harmony import as_rgb


def test_as_rgb_narrows_numpy_rows_and_lists():
    assert as_rgb(np.array([200.6, 30.2, 40.9])) == (200, 30, 40)
    assert as_rgb([1, 2, 3]) == (1, 2, 3)
    assert type(as_rgb(np.array([1, 2, 3]))[0]) is int


def test_as_rgb_rejects_rgba_and_scalars():
    with pytest.raises(ValueError):
        as_rgb((1, 2, 3, 255))
    with pytest.raises(ValueError):
        as_rgb((1, 2))
