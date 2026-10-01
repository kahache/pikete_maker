"""Display-time canonicalization of neutral swatches (issue #85, D31 option A).

Under real lighting/flash a black sneaker never clusters to pure black: the
extracted swatch is the actual illuminated color (a #2E2928 / #3C3937 dark
gray, sometimes navy- or brown-tinted), and a white one reads as a light gray
(#D0CCC9). Technically correct, but it does not match what the user KNOWS
their shoe to be ("es negra") — the CEO flagged it photo by photo across the
gate G2S set (see docs/qa/photo-eval/2026-07-11_1500_F2S_gate-g2s-primera-medida.md).

D31-A: snap those neutrals AT DISPLAY TIME only. This module is pure
presentation — it must NEVER feed back into the analysis:

- the stored palette, weights, harmony base and canvas-mode routing are
  computed on the RAW colors and stay byte-identical;
- callers apply :func:`snap_neutral_for_display` only when *showing* a swatch
  (render panel, battery review/panels, and the Dart result screen).

Rule (exact contract, mirrored 1:1 by the Dart port in
``app/lib/core/color_engine``):

    chroma = LAB C* of the sRGB color (D65, same srgb_to_lab as the merge)
    if chroma >= NEUTRAL_CHROMA (13.0):        -> unchanged   (chroma gate)
    elif L* <= SNAP_BLACK_L_HARD (21.0):       -> #000000     (deep dark)
    elif (L* <= SNAP_BLACK_L_MAX (28.0)
          and chroma < SNAP_BLACK_SOFT_CHROMA  -> #000000     (soft band)
               (4.0)):
    elif L* >= SNAP_WHITE_L_MIN (80.0):        -> #FFFFFF
    else:                                      -> unchanged   (genuine mid gray)

The chroma gate is the safety property the CEO insisted on: a navy shoe that
is truly blue (#051C56, C* 41) or a maroon (#451316, C* 27) is never touched —
only hue-less colors (C* < NEUTRAL_CHROMA, the same neutrality definition as
``is_neutral``/the #84 merge) are candidates.

The two-tier black branch (bug B-G25-3, measured 2026-07-20) exists because
NEUTRAL_CHROMA is far too loose a neutrality test in the top of the snap's
lightness range: chroma compresses as L* falls, so a garment that is visibly
coloured at L* 25 (the CEO's blue crochet fishnet #3C414D, C* 8.0, and his
olive/brown wool sweater #413934, C* 5.1) still clears C* < 13 and was being
painted pure black ("no hay negro, es azul"). Below SNAP_BLACK_L_HARD the
original single-threshold behaviour is kept verbatim — that is where every
genuine "negro diluido" from gate G2S lives, and where real garment colour is
no longer perceptible anyway. See the measurement note on the B-G25-3 issue.

Fixture table (input hex -> display hex) — the Dart parity tests mirror these
rows exactly; they are asserted in cv_core/tests/test_display.py:

    #2E2928 -> #000000   diluted black, CEO row 04 (L 17.1, C  2.6)
    #221A1A -> #000000   diluted black, CEO row 06 (L 10.2, C  4.2)
    #3C3937 -> #000000   the CEO's canonical example (L 24.2, C  1.9)
    #3D3B39 -> #000000   lightest measured diluted black (L 25.0, C 1.6)
    #D0CCC9 -> #FFFFFF   "blanco leído como gris", row 29 (L 82.3, C 2.2)
    #CDDDD8 -> #FFFFFF   white sole read as gray (L 86.8, C 6.3)
    #FFFFFB -> #FFFFFF   near-white (L 99.9, C 2.0)
    #051C56 -> #051C56   real navy, chroma-gated (C 41.2)
    #451316 -> #451316   real maroon, chroma-gated (C 26.6)
    #6C747B -> #6C747B   genuine mid gray stays (L 48.4, C 5.1)
    #AEAEB4 -> #AEAEB4   genuine light gray stays (L 71.3, C 3.3)
    #52463E -> #52463E   dark flesh-suede, NOT black (L 30.7, above L max)
    #3C414D -> #3C414D   B-G25-3: blue fishnet, soft band (L 27.5, C 8.0)
    #303745 -> #303745   B-G25-3: same garment lower (L 23.0, C 9.7)
    #413934 -> #413934   B-G25-3: olive/brown wool sweater (L 24.6, C 5.1)
    #39403F -> #000000   soft band, still black: L 26.4 but C 3.2 < 4.0
    #424242 -> #000000   boundary: L 27.97 <= 28.0 snaps
    #434343 -> #434343   boundary: L 28.41 >  28.0 stays
    #C6C6C6 -> #C6C6C6   boundary: L 79.88 <  80.0 stays
    #CACACA -> #FFFFFF   boundary: L 81.33 >= 80.0 snaps
    #232B3F -> #232B3F   boundary: C 14.05 >= 13.0, chroma gate holds
"""

from __future__ import annotations

import numpy as np

from colorlab.harmony import RGB, as_rgb
from colorlab.palette import NEUTRAL_CHROMA, srgb_to_lab

# Above (or at) this L* nothing snaps to black. 28.0 sits in the empty band
# measured on the gate G2S phone battery between the CEO's "negro diluido"
# swatches (all L* <= 25.0, e.g. #3D3B39) and the darkest genuine NON-black
# neutrals that must stay themselves (#52463E flesh-suede L* 30.7, #4B5F59
# L* 38.6) — comfortable margin on both sides.
SNAP_BLACK_L_MAX = 28.0

# Below (or at) this L* a low-chroma color snaps to black UNCONDITIONALLY — the
# original D31-A behaviour, kept verbatim for the deep darks it was built for.
# 21.0 is the midpoint of the empty band measured on the 65-photo gate G2.5 set
# (B-G25-3, 2026-07-20) between the lightest CORRECTLY-snapped swatch carrying
# real chroma (#372E24 seg-fp-37, L* 19.6 C* 8.3) and the darkest swatch the CEO
# rejected as black (#303745 fishnet lower, L* 23.0) — margins 1.4 / 2.0.
SNAP_BLACK_L_HARD = 21.0

# In the soft band (SNAP_BLACK_L_HARD, SNAP_BLACK_L_MAX] a color must be much
# closer to hue-less than NEUTRAL_CHROMA to be called black, because chroma
# compresses in dark colors and C* < 13 there admits visibly coloured garments.
# 4.0 sits in the measured empty band between the lightest correctly-snapped
# neutral in that band (#39403F selfie15 trousers, C* 3.2 — CEO says "black")
# and the least-chromatic swatch he rejected (#413934 wool sweater, C* 5.1).
# Thin evidence (n = 5 swatches above L* 22 in the set) — widen deliberately.
SNAP_BLACK_SOFT_CHROMA = 4.0

# Below this L* nothing snaps to white. 80.0 sits in the measured empty band
# between the lightest genuine gray (#C2C0C3 background gray, L* 77.9) and the
# darkest "white read as gray" the CEO flagged (#D0CCC9, L* 82.3).
SNAP_WHITE_L_MIN = 80.0

# Canonical snap targets: what the user believes the garment IS.
SNAP_BLACK: RGB = (0, 0, 0)
SNAP_WHITE: RGB = (255, 255, 255)


def snap_neutral_for_display(rgb: RGB) -> RGB:
    """Canonical display color for a swatch (D31-A): pure, display-only.

    Snaps a low-chroma dark to pure black and a low-chroma light to white; any
    color with real chroma (>= :data:`~colorlab.palette.NEUTRAL_CHROMA`) or a
    genuine mid gray is returned unchanged. See the module docstring for the
    exact rule and the Dart-parity fixture table.

    Args:
        rgb: sRGB 0-255 tuple as stored in the analysis palette.

    Returns:
        The RGB to *show* — never feed this back into harmony/palette math.
    """
    lightness, a, b = srgb_to_lab(np.asarray([rgb], dtype=float))[0]
    chroma = float(np.hypot(a, b))
    if chroma >= NEUTRAL_CHROMA:
        return as_rgb(rgb)  # chromatic: never touched
    if lightness <= SNAP_BLACK_L_HARD:
        return SNAP_BLACK  # deep dark: unconditional (original D31-A band)
    if lightness <= SNAP_BLACK_L_MAX and chroma < SNAP_BLACK_SOFT_CHROMA:
        return SNAP_BLACK  # soft band: only if near hue-less (B-G25-3)
    if lightness >= SNAP_WHITE_L_MIN:
        return SNAP_WHITE
    return as_rgb(rgb)  # genuine mid gray


def snap_palette_for_display(colors: np.ndarray) -> np.ndarray:
    """Applies :func:`snap_neutral_for_display` row-wise to a palette [m, 3].

    Convenience for the render paths; returns a NEW int array (the analysis
    palette is never mutated).
    """
    return np.array(
        [snap_neutral_for_display(as_rgb(c)) for c in np.atleast_2d(colors)],
        dtype=int,
    )
