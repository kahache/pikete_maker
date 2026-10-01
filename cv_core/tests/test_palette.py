import numpy as np
import pytest

from colorlab.palette import dominant_colors, srgb_to_lab

NAVY = (30.0, 50.0, 110.0)
MUSTARD = (200.0, 150.0, 40.0)

# Conceptual Vuitton case (issue #5): a fuchsia garment that K-means splits
# into variants due to lighting, plus a minority but distinctive color (the
# outfit's "pop") that must survive the merge.
PINK = (225.0, 54.0, 131.0)
PINK_LIGHT = (243.0, 84.0, 156.0)  # dE76 ~ 8.7 from PINK
PINK_DARK = (196.0, 36.0, 106.0)  # dE76 ~ 9.7 from PINK
LAVENDER = (156.0, 166.0, 198.0)  # dE76 > 64 from any pink


def _pixels(color, n, jitter=3.0, seed=0):
    rng = np.random.default_rng(seed)
    return np.clip(np.array(color) + rng.normal(0, jitter, size=(n, 3)), 0, 255)


def test_two_colors_recovered_in_frequency_order():
    pixels = np.vstack([_pixels(NAVY, 700), _pixels(MUSTARD, 300)])
    colors, weights = dominant_colors(pixels, k=2)

    assert len(colors) == 2
    # most frequent first
    assert np.allclose(colors[0], NAVY, atol=10)
    assert np.allclose(colors[1], MUSTARD, atol=10)
    assert weights[0] > weights[1]
    assert np.isclose(weights.sum(), 1.0)


def test_weights_match_pixel_proportions():
    pixels = np.vstack([_pixels(NAVY, 700), _pixels(MUSTARD, 300)])
    _, weights = dominant_colors(pixels, k=2)
    assert np.isclose(weights[0], 0.7, atol=0.05)
    assert np.isclose(weights[1], 0.3, atol=0.05)


def test_residual_clusters_are_dropped():
    # With k=5 over data of just 2 colors, near-empty or duplicate clusters
    # with weight < min_weight must not show up in the result.
    pixels = np.vstack([_pixels(NAVY, 980), _pixels(MUSTARD, 20)])
    colors, weights = dominant_colors(pixels, k=5, min_weight=0.05)
    assert all(w >= 0.05 for w in weights)
    assert len(colors) == len(weights)


def test_colors_are_valid_rgb_ints():
    pixels = _pixels(MUSTARD, 200)
    colors, _ = dominant_colors(pixels, k=1)
    assert colors.dtype.kind == "i"
    assert colors.min() >= 0 and colors.max() <= 255


# --- Merging of perceptually close clusters in LAB (issue #5) ---


def test_srgb_to_lab_reference_values():
    # Reference white and black: L 100/0 with a, b ~ 0 (D65).
    lab = srgb_to_lab(np.array([[255.0, 255.0, 255.0], [0.0, 0.0, 0.0]]))
    assert np.allclose(lab[0], [100.0, 0.0, 0.0], atol=0.5)
    assert np.allclose(lab[1], [0.0, 0.0, 0.0], atol=0.5)


def test_same_hue_light_variants_merge_into_one_color():
    # Two clouds of the same hue with slightly different lightness must
    # merge into a single palette color.
    pixels = np.vstack([_pixels(PINK, 500), _pixels(PINK_LIGHT, 500)])
    colors, weights = dominant_colors(pixels, k=5)

    assert len(colors) == 1
    # the merged color lands between both variants (weighted mean)
    expected = (np.array(PINK) + np.array(PINK_LIGHT)) / 2
    assert np.allclose(colors[0], expected, atol=12)
    assert np.isclose(weights[0], 1.0)


def test_clearly_distinct_colors_are_not_merged():
    # Two clearly distinct colors (dE76 ~ 107) must NOT be merged.
    pixels = np.vstack([_pixels(NAVY, 600), _pixels(MUSTARD, 400)])
    colors, _weights = dominant_colors(pixels, k=5)

    assert len(colors) == 2
    assert np.allclose(colors[0], NAVY, atol=10)
    assert np.allclose(colors[1], MUSTARD, atol=10)


def test_vuitton_case_pink_collapses_and_minority_pop_survives():
    # Pink majority in 3 lighting variants + lavender minority (the pop).
    # After the merge: the pink collapses into 1 color, the lavender survives
    # and RISES in relative weight (from 5th among 4 pinks to 2nd of 2 colors).
    pixels = np.vstack(
        [
            _pixels(PINK, 400),
            _pixels(PINK_LIGHT, 330),
            _pixels(PINK_DARK, 220),
            _pixels(LAVENDER, 50),
        ]
    )
    colors, weights = dominant_colors(pixels, k=5)

    assert len(colors) == 2
    # the collapsed pink dominates and is pink (near the weighted mean of pinks)
    expected_pink = (
        np.array(PINK) * 400 + np.array(PINK_LIGHT) * 330 + np.array(PINK_DARK) * 220
    ) / 950
    assert np.allclose(colors[0], expected_pink, atol=15)
    assert np.isclose(weights[0], 0.95, atol=0.02)
    # the lavender survives as the second color with its full weight
    assert np.allclose(colors[1], LAVENDER, atol=10)
    assert np.isclose(weights[1], 0.05, atol=0.02)


def test_shading_fragments_of_minority_color_reunite_and_survive():
    # Regression for the real bug in the Vuitton photo: over-clustering split
    # the lavender sneakers into a light half / shadow half (~1.7% each,
    # dE76 ~ 24.9 due to the L difference) and both died separately under
    # min_weight. With attenuated L they must reunite and survive.
    lav_shadow = (0x7A, 0x7F, 0x9A)
    lav_light = (0xB5, 0xC1, 0xE3)
    pixels = np.vstack(
        [
            _pixels(PINK, 966),
            _pixels(lav_shadow, 17),
            _pixels(lav_light, 17),
        ]
    )
    colors, weights = dominant_colors(pixels, k=5, min_weight=0.02)

    assert len(colors) == 2
    expected_lavender = (np.array(lav_shadow) + np.array(lav_light)) / 2
    assert np.allclose(colors[1], expected_lavender, atol=12)
    assert weights[1] >= 0.02  # survives the residual filter


def test_merge_can_be_disabled_for_raw_kmeans_behaviour():
    # merge_delta_e <= 0 disables merging: plain K-means with k clusters,
    # the two pink variants stay separate.
    pixels = np.vstack([_pixels(PINK, 500), _pixels(PINK_LIGHT, 500)])
    colors, _ = dominant_colors(pixels, k=2, merge_delta_e=0)
    assert len(colors) == 2


# --- Neutral-lightness merge protection (issue #84 round 2, the white bug) ---

NEAR_WHITE = (245.0, 245.0, 245.0)  # a sneaker sole, L* ~ 96
MID_GRAY = (150.0, 150.0, 150.0)  # a wall / shadow, L* ~ 62
NEAR_BLACK = (20.0, 20.0, 20.0)  # L* ~ 7


def _white_gray_black_pixels():
    """A white minority over a gray majority + some black — the #52 shape,
    where a small near-white sole risks being pulled into the larger mid-gray."""
    return np.vstack(
        [
            _pixels(NEAR_WHITE, 250),
            _pixels(MID_GRAY, 500),
            _pixels(NEAR_BLACK, 250),
        ]
    )


def test_neutrals_collapse_toward_gray_without_protection():
    """Baseline / outfit behavior: with the attenuated-L merge (default OFF),
    the near-white minority fuses with the mid-gray majority, so no genuinely
    white swatch (L* > 85) survives — this is the bug the protection targets."""
    colors, _ = dominant_colors(_white_gray_black_pixels(), k=5)
    lightness = srgb_to_lab(colors.astype(float))[:, 0]
    assert not (lightness > 85).any(), (
        f"unexpected white swatch without protection: {colors.tolist()}"
    )


def test_protection_keeps_white_gray_and_black_as_distinct_swatches():
    """With protection ON (product mode), the three neutrals stay separate: a
    true near-white swatch survives at its real lightness instead of collapsing
    into the mid-gray."""
    colors, _ = dominant_colors(
        _white_gray_black_pixels(), k=5, protect_neutral_lightness=True
    )
    lightness = sorted(srgb_to_lab(colors.astype(float))[:, 0])
    assert any(x > 90 for x in lightness), f"white lost: {colors.tolist()}"
    assert any(x < 20 for x in lightness), f"black lost: {colors.tolist()}"
    assert any(40 < x < 80 for x in lightness), f"mid-gray lost: {colors.tolist()}"


def test_protection_still_merges_two_shades_of_one_near_white():
    """Protection is not 'never merge neutrals': two near-white shades that
    differ only slightly in lightness (a lit sole vs. its own faint shadow)
    still merge into one white — it only stops the white/gray collapse."""
    pixels = np.vstack([_pixels((250, 250, 250), 500), _pixels((232, 232, 232), 500)])
    colors, _ = dominant_colors(pixels, k=5, protect_neutral_lightness=True)
    whites = srgb_to_lab(colors.astype(float))[:, 0] > 85
    assert whites.sum() == 1, f"two near-white shades did not merge: {colors.tolist()}"


def test_protection_does_not_touch_chromatic_shading_merges():
    """The protection only re-scores NEUTRAL-vs-neutral pairs; a chromatic
    garment's light/shadow halves still merge exactly as before (they are not
    neutral), so it never fragments real colors."""
    pixels = np.vstack([_pixels(PINK, 500), _pixels(PINK_DARK, 500)])
    plain, _ = dominant_colors(pixels, k=5)
    protected, _ = dominant_colors(pixels, k=5, protect_neutral_lightness=True)
    assert len(plain) == len(protected) == 1


# ---------------------------------------------------------------------------
# Edge cases (review F12, 2026-09-30): loud typed error, never an opaque
# sklearn crash.
# ---------------------------------------------------------------------------

from colorlab.palette import NoPixelsError


def test_empty_pixel_list_raises_typed_error():
    with pytest.raises(NoPixelsError):
        dominant_colors(np.zeros((0, 3), dtype=float))


def test_fewer_pixels_than_k_without_merge_does_not_crash():
    # merge_delta_e=0 used to request k clusters from 2 pixels (sklearn error).
    pixels = np.array([[10.0, 20.0, 30.0], [200.0, 210.0, 220.0]])
    colors, weights = dominant_colors(pixels, k=5, merge_delta_e=0, min_weight=0)
    assert len(colors) == 2
    assert weights.sum() == pytest.approx(1.0)


def test_single_pixel_is_its_own_palette():
    colors, weights = dominant_colors(np.array([[10.0, 20.0, 30.0]]))
    assert colors.tolist() == [[10, 20, 30]]
    assert weights.tolist() == [1.0]
