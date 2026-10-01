"""Tests for the end-to-end composition and the D24 product mode.

Product mode (feature F11, sneaker/object photos) runs only the
use-case-agnostic CORE, skipping the two PERSON-specific layers — background
removal and the skin filter. These tests assert the SKIP (product mode never
touches those layers, outfit mode does) and that the CORE still extracts the
right palette on a synthetic clean-background product photo. Off by default:
outfit mode composition is unchanged.
"""

import numpy as np
from PIL import Image

import colorlab.pipeline as pipeline
from colorlab.harmony import is_neutral

# Synthetic "clean product shot": a light-gray studio background with a
# centered, saturated red product blob (a sneaker box, say). No person, no skin.
STUDIO_GRAY = (205, 205, 205)
PRODUCT_RED = (200, 40, 40)
# A CAMEL/tan product (skin-chroma): outfit mode's skin filter is at risk of
# erasing it; product mode must keep it because it skips the filter.
PRODUCT_CAMEL = (215, 180, 150)


def _product_photo(product=PRODUCT_RED, w=240, h=320):
    arr = np.full((h, w, 3), STUDIO_GRAY, dtype=np.uint8)
    arr[90:230, 80:160] = product
    return Image.fromarray(arr)


def _spy(monkeypatch):
    """Wraps the two person-layer functions inside colorlab.pipeline to record
    whether — and how — they were invoked."""
    calls = {"remove_bg": 0, "drop_skin_args": []}

    real_remove = pipeline.remove_background
    real_gather = pipeline.gather_pixels

    def spy_remove(img):
        calls["remove_bg"] += 1
        return real_remove(img)

    def spy_gather(rgb, fg_mask, drop_skin=True):
        calls["drop_skin_args"].append(drop_skin)
        return real_gather(rgb, fg_mask, drop_skin=drop_skin)

    monkeypatch.setattr(pipeline, "remove_background", spy_remove)
    monkeypatch.setattr(pipeline, "gather_pixels", spy_gather)
    return calls


def test_product_mode_skips_person_background_removal(monkeypatch):
    calls = _spy(monkeypatch)
    pipeline.analyze_palette(_product_photo(), product_mode=True)
    assert calls["remove_bg"] == 0, (
        "product mode must not run person background removal"
    )


def test_product_mode_skips_skin_filter(monkeypatch):
    calls = _spy(monkeypatch)
    pipeline.analyze_palette(_product_photo(), product_mode=True)
    # gather_pixels is still the pixel collector, but always with drop_skin=False.
    assert calls["drop_skin_args"], "gather_pixels should still collect pixels"
    assert not any(calls["drop_skin_args"]), "product mode must not drop skin"


def test_outfit_mode_still_runs_both_person_layers(monkeypatch):
    """Default (outfit) mode is unchanged: it removes the background and, unless
    --keep-skin, drops the skin."""
    calls = _spy(monkeypatch)
    pipeline.analyze_palette(_product_photo())
    assert calls["remove_bg"] == 1, "outfit mode must remove the background"
    assert calls["drop_skin_args"] == [True], "outfit mode must drop skin by default"


def test_product_mode_suppresses_studio_background_and_bases_on_product():
    """Product mode drops the studio background and keeps only the product.

    Behavior refined by #84 (Gate G2S first measurement): the studio gray wraps
    all four edges, so the multi-edge model flags it as background and drops its
    pixels BEFORE clustering. The palette is therefore 100% product — the red —
    and the harmony base is that chromatic red. (Pre-#84 the gray background
    survived in the raw palette; the gate's "palette 100% product" column is
    exactly why it must not.)"""
    analysis = pipeline.analyze_palette(_product_photo(), product_mode=True)
    assert analysis.product_mode is True
    # The base is chromatic (the product), not the neutral studio wall.
    assert not is_neutral(analysis.base)
    br, bg_, bb = analysis.base
    assert br > 150 and bg_ < 90 and bb < 90, (
        f"base {analysis.base} is not the red product"
    )
    # The neutral studio background must NOT survive as a swatch (palette purity).
    assert not any(is_neutral(tuple(int(x) for x in c)) for c in analysis.colors), (
        f"studio background leaked into the palette "
        f"{[tuple(int(x) for x in c) for c in analysis.colors]}"
    )


def test_product_mode_keeps_skin_colored_product():
    """A camel/tan product survives in product mode (the skin filter that could
    erase it is skipped)."""
    analysis = pipeline.analyze_palette(
        _product_photo(product=PRODUCT_CAMEL), product_mode=True
    )
    # The camel tone must appear in the palette (within a generous tolerance).
    hits = [
        c
        for c in analysis.colors
        if abs(int(c[0]) - 215) < 30
        and abs(int(c[1]) - 180) < 30
        and abs(int(c[2]) - 150) < 30
    ]
    assert hits, (
        f"camel product missing from palette {[tuple(int(x) for x in c) for c in analysis.colors]}"
    )


def test_product_mode_is_off_by_default():
    """The flag defaults off: analyze_palette() with no product_mode runs the
    outfit pipeline (product_mode echoed False)."""
    analysis = pipeline.analyze_palette(_product_photo())
    assert analysis.product_mode is False


# ---------------------------------------------------------------------------
# #84 — center-subject background suppression in product mode.
#
# These test the MECHANISM (a centered subject vs. a background wrapping >= 2
# edges) on synthetic images, not the 57 real gate photos: a busy multi-edge
# background is added around a centered product, and the product's own colors —
# including true white and true black, which a whole-frame K-means would merge
# into the background's mid-gray — must survive and lead the harmonies.
# ---------------------------------------------------------------------------

# A busy background wrapping the frame: a warm "floor" on the bottom and a cool
# "wall" on the top/sides. Both wrap >= 2 edges, so both are background; neither
# is the centered subject.
BG_FLOOR = (150, 110, 85)  # warm wood floor, on the bottom + lower sides
BG_WALL = (95, 105, 120)  # cool wall, on the top + upper sides


def _busy_photo(product, w=260, h=340):
    """Centered product over a two-tone multi-edge background (wall + floor)."""
    arr = np.empty((h, w, 3), dtype=np.uint8)
    arr[: h // 2] = BG_WALL  # wall covers the top (and the upper left/right)
    arr[h // 2 :] = BG_FLOOR  # floor covers the bottom (and the lower left/right)
    arr[90:250, 85:175] = product  # centered product blob, touching no edge
    return Image.fromarray(arr)


def _in_palette(analysis, target, tol=26):
    return [
        c
        for c in analysis.colors
        if all(abs(int(c[k]) - target[k]) < tol for k in range(3))
    ]


def test_product_mode_base_flips_from_background_to_subject():
    """The dominant background (it out-weighs the small centered product) must
    NOT become the base; the product's chromatic color does."""
    product = (40, 90, 180)  # a saturated blue sneaker, ~16% of the frame
    analysis = pipeline.analyze_palette(_busy_photo(product), product_mode=True)
    # Base is the blue product, not the warm floor / cool wall.
    br, _bg, bb = analysis.base
    assert bb > br and bb > 120 and br < 110, (
        f"base {analysis.base} is not the blue product"
    )
    # Neither background tone survives as a swatch.
    assert not _in_palette(analysis, BG_FLOOR), "floor leaked into the palette"
    assert not _in_palette(analysis, BG_WALL), "wall leaked into the palette"


def test_product_mode_recovers_true_white_swatch():
    """BUG-N1: a WHITE subject on a non-white multi-edge background must surface
    as a genuine (high-L, low-chroma) white swatch, not be swallowed by the
    background's mid-gray. The whole point of #84 rule 2."""
    analysis = pipeline.analyze_palette(_busy_photo((245, 245, 245)), product_mode=True)
    whites = [c for c in analysis.colors if min(int(c[0]), int(c[1]), int(c[2])) > 200]
    assert whites, (
        "white subject did not surface as a white swatch: "
        f"{[tuple(int(x) for x in c) for c in analysis.colors]}"
    )
    # And the recovered white is neutral (its own color, not merged into a tone).
    assert is_neutral(tuple(int(x) for x in whites[0]))


def test_product_mode_recovers_true_black_swatch():
    """BUG-N2: a BLACK subject on a light multi-edge background must surface as a
    genuinely dark swatch, not be lifted into a mid-gray by the background."""
    analysis = pipeline.analyze_palette(_busy_photo((18, 18, 18)), product_mode=True)
    blacks = [c for c in analysis.colors if max(int(c[0]), int(c[1]), int(c[2])) < 55]
    assert blacks, (
        "black subject did not surface as a dark swatch: "
        f"{[tuple(int(x) for x in c) for c in analysis.colors]}"
    )


def test_product_mode_white_and_gray_subject_stay_separate():
    """#84 round 2 (the white bug), wired at the pipeline level: a two-tone
    sneaker — a white sole plus a mid-gray body — over a colored, multi-edge
    background. The background is suppressed; the neutral-lightness protection
    then keeps the white sole from collapsing into the gray body, so a genuine
    near-white swatch (L* high) survives instead of a single mid-gray."""
    # A saturated background (far from any neutral) so suppression removes the
    # background cleanly and leaves the neutral subject intact — isolating the
    # merge behavior, not the suppression.
    arr = np.full((340, 260, 3), (30, 60, 170), dtype=np.uint8)  # deep blue, all edges
    # Centered two-tone subject: gray upper half, white sole lower half.
    arr[90:170, 85:175] = (150, 150, 150)  # gray body
    arr[170:250, 85:175] = (245, 245, 245)  # white sole
    analysis = pipeline.analyze_palette(Image.fromarray(arr), product_mode=True)
    whites = [c for c in analysis.colors if min(int(c[0]), int(c[1]), int(c[2])) > 200]
    grays = [
        c
        for c in analysis.colors
        if 120 < int(c[0]) < 185
        and abs(int(c[0]) - int(c[1])) < 12
        and abs(int(c[1]) - int(c[2])) < 12
    ]
    assert whites, (
        f"white sole collapsed into gray: {[tuple(int(x) for x in c) for c in analysis.colors]}"
    )
    assert grays, (
        f"gray body missing: {[tuple(int(x) for x in c) for c in analysis.colors]}"
    )


# ---------------------------------------------------------------------------
# Phase 2.5 — analyze_garments (segmentation-driven per-garment analysis).
#
# Synthetic photo + synthetic class map (no model, deterministic): attribution
# must come from the MASK, so background/skin/hair pixels are painted with
# LOUD chromatic colors that would hijack the palette if they leaked.
# ---------------------------------------------------------------------------

import pytest

from colorlab.pipeline import analyze_garments
from colorlab.segmentation import (
    CLASS_BACKGROUND,
    CLASS_BODY_SKIN,
    CLASS_CLOTHES,
    CLASS_FACE_SKIN,
    CLASS_HAIR,
    REGION_LOWER,
    REGION_UPPER,
    NoPersonError,
)

BG_LOUD = (255, 0, 0)  # saturated red background
SKIN_LOUD = (0, 255, 0)  # saturated green "skin"
HAIR_LOUD = (255, 0, 255)  # saturated magenta "hair"
TOP_BLUE = (30, 60, 170)
BOTTOM_MUSTARD = (200, 160, 30)
NEUTRAL_GRAY = (128, 128, 128)
NEUTRAL_WHITE = (240, 240, 240)


def _segmented_photo(top=TOP_BLUE, bottom=BOTTOM_MUSTARD, w=240, h=320):
    """A synthetic dressed person + its ground-truth class map.

    Layout: loud background everywhere, hair band on top, face/body skin
    below it, a top garment and a bottom garment. The garment blobs are far
    from the erosion + min-region guards' limits.
    """
    rgb = np.full((h, w, 3), BG_LOUD, dtype=np.uint8)
    cm = np.full((h, w), CLASS_BACKGROUND, dtype=np.uint8)

    def paint(sl, color, cls):
        rgb[sl] = color
        cm[sl] = cls

    paint(np.s_[10:40, 90:150], HAIR_LOUD, CLASS_HAIR)
    paint(np.s_[40:70, 95:145], SKIN_LOUD, CLASS_FACE_SKIN)
    paint(np.s_[70:80, 95:145], SKIN_LOUD, CLASS_BODY_SKIN)
    paint(np.s_[80:180, 60:180], top, CLASS_CLOTHES)  # top garment
    paint(np.s_[180:290, 70:170], bottom, CLASS_CLOTHES)  # bottom garment
    return Image.fromarray(rgb), cm


def _hits(colors, target, tol=25):
    return [
        c for c in colors if all(abs(int(c[k]) - target[k]) < tol for k in range(3))
    ]


def test_analyze_garments_splits_top_and_bottom():
    img, cm = _segmented_photo()
    result = analyze_garments(img, cm)
    assert set(result.garments) == {REGION_UPPER, REGION_LOWER}
    upper, lower = result.garments[REGION_UPPER], result.garments[REGION_LOWER]
    assert _hits(upper.colors, TOP_BLUE), f"upper palette {upper.colors.tolist()}"
    assert _hits(lower.colors, BOTTOM_MUSTARD), f"lower palette {lower.colors.tolist()}"
    # No cross-contamination: the top's blue never appears in the bottom.
    assert not _hits(lower.colors, TOP_BLUE)
    assert not _hits(upper.colors, BOTTOM_MUSTARD)


def test_analyze_garments_excludes_background_skin_and_hair():
    """The attribution point of Phase 2.5: with a mask, the loud background,
    skin and hair colors must not reach ANY palette — this is what retires
    the YCbCr proxy and the border heuristics (#56 buckets)."""
    img, cm = _segmented_photo()
    result = analyze_garments(img, cm)
    for pollutant in (BG_LOUD, SKIN_LOUD, HAIR_LOUD):
        assert not _hits(result.colors, pollutant), (
            f"non-garment color {pollutant} leaked into the outfit palette "
            f"{result.colors.tolist()}"
        )


def test_analyze_garments_base_is_most_chromatic_across_garments():
    """Decision #6 lifted to the outfit level: a neutral gray top must not
    lead; the chromatic bottom wins and is attributed to its garment."""
    img, cm = _segmented_photo(top=NEUTRAL_GRAY, bottom=BOTTOM_MUSTARD)
    result = analyze_garments(img, cm)
    assert result.base_region == REGION_LOWER
    assert _hits([result.base], BOTTOM_MUSTARD), f"base {result.base}"
    assert result.base_index >= 0
    assert result.swatch_regions[result.base_index] == REGION_LOWER
    # Per-garment canvas signal: the all-neutral top has no base of its own.
    assert result.garments[REGION_UPPER].base_index == -1
    assert result.garments[REGION_LOWER].base_index >= 0


def test_analyze_garments_all_neutral_outfit_is_canvas_mode():
    """100% neutral garments -> base_index -1 (canvas mode D10), base falls
    back to the dominant color, no owning region."""
    img, cm = _segmented_photo(top=NEUTRAL_WHITE, bottom=NEUTRAL_GRAY)
    result = analyze_garments(img, cm)
    assert result.base_index == -1
    assert result.base_region is None
    assert is_neutral(result.base)
    for g in result.garments.values():
        assert g.base_index == -1


def test_analyze_garments_combined_palette_is_weighted_and_attributed():
    img, cm = _segmented_photo()
    result = analyze_garments(img, cm)
    assert len(result.swatch_regions) == len(result.colors) == len(result.weights)
    # <= 1: dominant_colors drops residual clusters (MIN_WEIGHT), same
    # convention as PaletteAnalysis weights.
    assert 0.9 < result.weights.sum() <= 1.0 + 1e-6
    # Sorted by weight, and every swatch belongs to a present garment.
    assert list(result.weights) == sorted(result.weights, reverse=True)
    assert set(result.swatch_regions) <= set(result.garments)
    # The bottom garment is bigger (110x100 vs 100x120 minus erosion is close;
    # weights must reflect pixel share): both garments contribute swatches.
    assert REGION_UPPER in result.swatch_regions
    assert REGION_LOWER in result.swatch_regions


def test_analyze_garments_erosion_keeps_edge_bleed_out():
    """Blocky mask edges (256->full-res upscale) mislabel a ~2 px boundary
    ring: paint the ring with the loud background color while the MASK still
    claims it is clothes. Default erosion must keep it out of the palette."""
    img, cm = _segmented_photo()
    rgb = np.array(img)
    clothes = cm == CLASS_CLOTHES
    from colorlab.segmentation import erode_mask

    ring = clothes & ~erode_mask(clothes, 2)
    rgb[ring] = BG_LOUD  # bleed: mask says clothes, pixels are background
    result = analyze_garments(Image.fromarray(rgb), cm)
    assert not _hits(result.colors, BG_LOUD), (
        f"edge bleed leaked into the palette {result.colors.tolist()}"
    )


def test_analyze_garments_no_person_mask_raises():
    img, _ = _segmented_photo()
    cm = np.full((320, 240), CLASS_BACKGROUND, dtype=np.uint8)
    with pytest.raises(NoPersonError):
        analyze_garments(img, cm)


def test_analyze_garments_rejects_shape_mismatch():
    img, cm = _segmented_photo()
    with pytest.raises(ValueError, match="shape"):
        analyze_garments(img, cm[:-10])


# ---------------------------------------------------------------------------
# Legacy regression pin: analyze_palette (the no-mask path) is UNTOUCHED by
# Phase 2.5. Exact values pinned on the deterministic core path (no GrabCut/
# rembg backend variance, KMeans random_state=42): if these move, the legacy
# pipeline changed and every golden fixture is suspect.
# ---------------------------------------------------------------------------


def test_analyze_palette_legacy_core_path_is_pinned():
    arr = np.full((320, 240, 3), (205, 205, 205), dtype=np.uint8)
    arr[60:180, 70:170] = (200, 40, 40)
    arr[180:290, 80:160] = (30, 60, 170)
    analysis = pipeline.analyze_palette(
        Image.fromarray(arr), remove_bg=False, drop_skin=False
    )
    assert analysis.colors.tolist() == [[205, 205, 205], [200, 40, 40], [30, 60, 170]]
    assert np.round(analysis.weights, 6).tolist() == [0.729167, 0.15625, 0.114583]
    assert analysis.base == (200, 40, 40)


def test_product_mode_frame_filling_subject_guardrail():
    """A solid product shot edge to edge: its single color naturally wraps every
    edge, so the multi-edge model would flag the SUBJECT as background. The
    coverage guardrail must switch suppression off and keep the product."""
    arr = np.full((300, 240, 3), (200, 40, 40), dtype=np.uint8)  # red, no bg
    analysis = pipeline.analyze_palette(Image.fromarray(arr), product_mode=True)
    br, bg_, bb = analysis.base
    assert br > 150 and bg_ < 90 and bb < 90, (
        f"guardrail failed: frame-filling red product was stripped, base {analysis.base}"
    )


# ---------------------------------------------------------------------------
# Edge cases of the whole-photo API (review F12/F13/F14, 2026-09-30).
# ---------------------------------------------------------------------------

from colorlab.harmony import pick_harmony_base_index
from colorlab.palette import NoPixelsError

# A 100% neutral "product": dark-gray blob on the studio gray -> canvas mode.
PRODUCT_DARK_GRAY = (60, 60, 60)


def test_rgba_input_matches_rgb_input():
    # F13: library callers may pass RGBA/L images; product mode is deterministic
    # (no background removal), so the palettes must be identical.
    rgb = _product_photo()
    ref = pipeline.analyze_palette(rgb, product_mode=True)
    got = pipeline.analyze_palette(rgb.convert("RGBA"), product_mode=True)
    assert got.colors.tolist() == ref.colors.tolist()
    assert got.weights.tolist() == ref.weights.tolist()
    assert got.base == ref.base and got.base_index == ref.base_index


def test_grayscale_input_is_accepted_in_outfit_mode():
    gray = _product_photo().convert("L")
    analysis = pipeline.analyze_palette(gray, remove_bg=False, drop_skin=False)
    assert analysis.colors.shape[1] == 3
    assert len(analysis.base) == 3


def test_empty_foreground_degrades_loudly(monkeypatch):
    # F12: a remover that finds no subject (all-transparent alpha) must raise
    # the typed error, never an opaque sklearn InvalidParameterError.
    def no_subject(img):
        rgb = np.asarray(img)
        return rgb, np.zeros(rgb.shape[:2], dtype=bool)

    monkeypatch.setattr(pipeline, "remove_background", no_subject)
    with pytest.raises(NoPixelsError):
        pipeline.analyze_palette(_product_photo())


def test_base_index_matches_harmony_rule_and_base():
    analysis = pipeline.analyze_palette(_product_photo(), product_mode=True)
    assert analysis.base_index == pick_harmony_base_index(
        analysis.colors, analysis.weights
    )
    assert analysis.base_index >= 0
    assert analysis.base == tuple(int(x) for x in analysis.colors[analysis.base_index])


def test_all_neutral_photo_signals_canvas_mode_and_keeps_fallback_base():
    # F14: the -1 canvas signal (D10) reaches the Python API like it does the
    # Dart engine; `base` keeps the historical dominant-color fallback.
    analysis = pipeline.analyze_palette(
        _product_photo(product=PRODUCT_DARK_GRAY), product_mode=True
    )
    assert analysis.base_index == -1
    assert analysis.base == tuple(int(x) for x in analysis.colors[0])
    assert is_neutral(analysis.base)


def test_palette_analysis_positional_unpacking_is_backwards_compatible():
    analysis = pipeline.analyze_palette(_product_photo(), product_mode=True)
    colors, weights, base, product_mode, candidates, base_index = analysis
    assert base == analysis.base and base_index == analysis.base_index
    assert analysis[:5] == (colors, weights, base, product_mode, candidates)


# ---------------------------------------------------------------------------
# I2 C1c — analyze_garments(harden=...) opt-in.
# ---------------------------------------------------------------------------

COAT_LOUD = (0, 200, 90)  # a chromatic coat hanging on the wall


def _photo_with_detached_coat():
    """The synthetic person plus a clothes-labelled coat on the wall that
    touches no skin/hair/others (the PoC's selfie31 hook coat)."""
    img, cm = _segmented_photo()
    rgb = np.asarray(img).copy()
    rgb[100:160, 5:40] = COAT_LOUD
    cm = cm.copy()
    cm[100:160, 5:40] = CLASS_CLOTHES
    return Image.fromarray(rgb), cm


def test_analyze_garments_harden_none_is_the_canonical_path():
    img, cm = _photo_with_detached_coat()
    default = analyze_garments(img, cm)
    explicit = analyze_garments(img, cm, harden=None)
    assert np.array_equal(default.colors, explicit.colors)
    assert np.array_equal(default.weights, explicit.weights)
    assert default.base_index == explicit.base_index
    # The canonical path samples the coat (the defect C1 fixes).
    assert _hits(default.garments[REGION_UPPER].colors, COAT_LOUD)


def test_analyze_garments_harden_drops_the_detached_coat():
    from colorlab.segmentation import RECOLOR_HARDENING

    img, cm = _photo_with_detached_coat()
    hardened = analyze_garments(img, cm, harden=RECOLOR_HARDENING)
    assert set(hardened.garments) == {REGION_UPPER, REGION_LOWER}
    for region in (REGION_UPPER, REGION_LOWER):
        assert not _hits(hardened.garments[region].colors, COAT_LOUD)
    assert _hits(hardened.garments[REGION_UPPER].colors, TOP_BLUE)
    assert _hits(hardened.garments[REGION_LOWER].colors, BOTTOM_MUSTARD)
    assert not _hits(hardened.colors, COAT_LOUD)
