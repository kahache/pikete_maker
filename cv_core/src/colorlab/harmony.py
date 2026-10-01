"""Harmony base selection and classic color-theory schemes (feature 4).

Last stage of the pipeline: given the dominant palette from
:mod:`colorlab.palette`, decide WHICH color the outfit's recommendations
should be built on, then rotate its hue into the classic schemes.

Two responsibilities, in order:

1. **Base selection** (:func:`pick_harmony_base_index`) — the single most
   consequential rule in the engine. The base is NOT the most frequent color
   (that is almost always a neutral or the background) but the most
   *chromatically prominent* one: ``saturation x weight`` among the
   non-neutral colors (committed decision #6). Two guards refine it:
   neutrality is judged by LAB chroma rather than HSV saturation, which is
   unstable near black (#22), and a tiny chromatic patch on an otherwise
   neutral outfit is demoted because color alone cannot tell a real accent
   from a wall or a mirror reflection (#57).

2. **Scheme generation** (:func:`harmonies`) — complementary, analogous,
   triadic and split-complementary, computed by rotating the base hue in HSV
   with saturation/value floors so no proposal comes out washed out.

When no color is eligible as a base the outfit is a neutral "canvas" and the
module returns a curated accent set instead of arbitrary hue math
(:func:`canvas_accents`, canvas mode D10).

This module is mirrored 1:1 by the Dart port in
``app/lib/core/color_engine`` and pinned by shared golden fixtures: the
returned scheme names and the ``-1`` base signal are a wire contract, not
internal detail. Changing any number here moves on-device output.
"""

from __future__ import annotations

import colorsys
from collections.abc import Iterable
from typing import SupportsInt

import numpy as np

from colorlab.palette import NEUTRAL_CHROMA, srgb_to_lab

RGB = tuple[int, int, int]


def as_rgb(values: Iterable[SupportsInt]) -> RGB:
    """Narrows any 3-item sequence (a palette row, a list) to a typed ``RGB``.

    The ONE place that turns a ``tuple[int, ...]``/ndarray row into the
    ``RGB`` triple the engine's signatures promise. It materializes exactly
    three ints and fails loudly on any other length, so an RGBA row or a
    scalar can never flow silently through :func:`hexstr`/:func:`harmonies`
    with a channel dropped (review F13/E4, 2026-09-30).
    """
    channels = tuple(int(x) for x in values)
    if len(channels) != 3:
        raise ValueError(f"expected 3 RGB channels, got {len(channels)}: {channels!r}")
    r, g, b = channels
    return (r, g, b)


# NEUTRAL_CHROMA (the chroma below which a color reads as neutral) is defined
# canonically in colorlab.palette and imported here: it is used by is_neutral
# below and re-exported on harmony's historical API path (tests, the Dart
# mirror). See palette.py for the full rationale (bugs B5/B8, #22).

# Saturation/value floors so the proposals never come out washed out.
PROPOSAL_MIN_SAT = 0.35
PROPOSAL_MIN_VAL = 0.55

# Canvas mode (D10, #21): a 100% neutral outfit (all black/white/gray) has no
# chromatic base to build harmonies on. Rotating an arbitrary hue over a near-
# black produced meaningless proposals (bug B3). Instead we acknowledge the
# neutral "canvas" honestly and offer a curated, versatile set of accent
# "pops" that read well against any neutral — fashion curation, not math.
# CEO-ratified 2026-07-10. A neutral-dependent variant (different accents for
# black vs white vs beige) is deferred to the backlog.
CANVAS_ACCENTS: tuple[RGB, ...] = (
    (0xE4, 0x32, 0x2B),  # Rojo
    (0x2B, 0x5C, 0xE4),  # Cobalto
    (0xE0, 0xA0, 0x00),  # Mostaza
    (0x12, 0xA1, 0x50),  # Esmeralda
    (0xD6, 0x24, 0x8C),  # Frambuesa
)

# On a neutral-dominant outfit (all black/white/gray) a small chromatic patch
# is as likely to be background (a mirror reflection, a wall) as a real garment
# accent — color alone cannot tell them apart (#57). Below this weight we do
# NOT let such a patch lead the harmonies; with no eligible base the photo
# falls to canvas mode (D10), the safe curated fallback. Chosen at 0.10
# (generous): the gate is inert whenever the dominant color is chromatic (e.g.
# a pink outfit with a lavender pop), so a wide margin never endangers a
# legitimate pop. Full attribution (garment vs background) awaits Phase 2.5
# segmentation.
POP_ON_NEUTRAL_MIN = 0.10


def rgb_to_hsv(rgb: RGB) -> tuple[float, float, float]:
    """RGB 0-255 -> HSV with h, s, v in 0..1."""
    r, g, b = [c / 255.0 for c in rgb]
    return colorsys.rgb_to_hsv(r, g, b)


def hsv_to_rgb(h: float, s: float, v: float) -> RGB:
    """HSV in 0..1 (h is normalized modulo 1) -> RGB 0-255."""
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def hexstr(rgb: RGB) -> str:
    """RGB 0-255 -> '#RRGGBB'."""
    return "#{:02X}{:02X}{:02X}".format(*rgb)


def lab_chroma(rgb: RGB) -> float:
    """Perceptual chroma C* = sqrt(a*^2 + b*^2) in CIELAB (colorfulness).

    Stable near black/white, unlike HSV saturation (#22): a near-black scores
    ~0 and a real dark garment color keeps its chroma.
    """
    lab = srgb_to_lab(np.asarray([rgb], dtype=float))[0]
    return float(np.hypot(lab[1], lab[2]))


def is_neutral(rgb: RGB) -> bool:
    """Whites, grays, blacks, beiges: low chroma -> neutral (basic/background).

    Chroma-based (NEUTRAL_CHROMA), not HSV saturation: robust on near-blacks
    and near-neutrals where saturation is unstable (bugs B5/B8, #22).
    """
    return lab_chroma(rgb) < NEUTRAL_CHROMA


def pick_harmony_base_index(colors: np.ndarray, weights: np.ndarray) -> int:
    """Index of the color the harmonies should be built on, or -1.

    NOT the most frequent one (usually background/neutral), but the most
    'chromatically prominent' = saturation * weight among the non-neutral
    colors. Neutrality is judged by LAB chroma (:func:`is_neutral`) so a
    near-black never wins the base off a real garment (#22).

    Dominant-neutral context gate (#57): when the dominant (max-weight) color
    is itself a strong neutral, a *small* chromatic patch (weight <
    :data:`POP_ON_NEUTRAL_MIN`) is demoted — on an all-neutral outfit such a
    patch is as likely to be a reflection/wall as a real accent, and color
    alone cannot tell them apart. The gate is inert when the dominant color is
    chromatic, so legitimate pops on colored outfits are untouched.

    Returns ``-1`` when no color is eligible: a 100% neutral outfit (or a
    neutral outfit whose only chromatic colors were demoted by the gate) has no
    base, which is the trigger for canvas mode (D10). Mirror of the Dart port's
    ``pickHarmonyBase`` (index + ``-1`` signal), the shared fixture contract.
    """
    dominant_is_neutral = is_neutral(as_rgb(colors[int(np.argmax(weights))]))
    best, best_score = -1, -1.0
    for i, (row, w) in enumerate(zip(colors, weights, strict=True)):
        c = as_rgb(row)
        if is_neutral(c):
            continue  # neutrals do not lead harmonies (#22)
        if dominant_is_neutral and w < POP_ON_NEUTRAL_MIN:
            continue  # tiny chromatic on a neutral outfit -> canvas mode (#57)
        _, s, _ = rgb_to_hsv(c)
        score = s * w
        if score > best_score:
            best, best_score = i, score
    return best


def pick_harmony_base(colors: np.ndarray, weights: np.ndarray) -> RGB:
    """Chooses which color to build the harmonies on (RGB).

    Thin wrapper over :func:`pick_harmony_base_index`. When everything is
    neutral (index ``-1``) it falls back to the dominant color, preserving the
    historical behavior; callers that need to detect canvas mode (D10) should
    use the index function and :func:`canvas_accents`.
    """
    idx = pick_harmony_base_index(colors, weights)
    chosen = colors[idx] if idx >= 0 else colors[0]
    return as_rgb(chosen)


def canvas_accents() -> list[RGB]:
    """Curated accent 'pops' proposed for a neutral canvas (canvas mode, D10).

    See :data:`CANVAS_ACCENTS`. Returned as a fresh list so callers cannot
    mutate the module-level curated set.
    """
    return list(CANVAS_ACCENTS)


def harmonies(base_rgb: RGB) -> dict[str, list[RGB]]:
    """Classic harmony schemes rotating the hue of the base color.

    The scheme names are PRODUCT-facing strings and stay in Spanish (the
    product speaks Spanish, decision #28) — they are also baked into the
    golden fixtures consumed by the Dart tests: do NOT rename them.
    """
    h, s, v = rgb_to_hsv(base_rgb)
    s = max(s, PROPOSAL_MIN_SAT)
    v = max(v, PROPOSAL_MIN_VAL)

    def deg(d: float) -> float:
        return h + d / 360.0

    return {
        "Complementario": [base_rgb, hsv_to_rgb(deg(180), s, v)],
        "Análogo": [hsv_to_rgb(deg(-30), s, v), base_rgb, hsv_to_rgb(deg(30), s, v)],
        "Triádico": [base_rgb, hsv_to_rgb(deg(120), s, v), hsv_to_rgb(deg(240), s, v)],
        "Complementario dividido": [
            base_rgb,
            hsv_to_rgb(deg(150), s, v),
            hsv_to_rgb(deg(210), s, v),
        ],
    }
