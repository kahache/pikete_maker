"""Tests for the display-time neutral snap (colorlab.display — issue #85, D31-A).

The parametrized fixture table below IS the Dart-parity contract: the port in
``app/lib/core/color_engine`` must reproduce every (input hex -> display hex)
row 1:1. Evidence hexes come from the gate G2S phone battery
(outputs/product-battery/phone/review.md) and the CEO's photo-by-photo notes.
"""

import numpy as np
import pytest

from colorlab.display import (
    SNAP_BLACK_L_HARD,
    SNAP_BLACK_L_MAX,
    SNAP_BLACK_SOFT_CHROMA,
    SNAP_WHITE_L_MIN,
    snap_neutral_for_display,
    snap_palette_for_display,
)
from colorlab.palette import NEUTRAL_CHROMA


def _rgb(hexstr: str) -> tuple[int, int, int]:
    h = hexstr.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def _hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb)


# --- Threshold pins (D31-A) ----------------------------------------------------


def test_thresholds_are_pinned():
    """The snap thresholds are calibrated on the gate G2S measured data (see
    display.py rationale). If they change, the Dart port and these fixtures
    must change WITH them — deliberately, not by drift."""
    assert SNAP_BLACK_L_MAX == 28.0
    assert SNAP_WHITE_L_MIN == 80.0
    assert NEUTRAL_CHROMA == 13.0
    # Two-tier black branch (B-G25-3, measured on the 65-photo gate G2.5 set).
    assert SNAP_BLACK_L_HARD == 21.0
    assert SNAP_BLACK_SOFT_CHROMA == 4.0
    assert SNAP_BLACK_L_HARD < SNAP_BLACK_L_MAX
    assert SNAP_BLACK_SOFT_CHROMA < NEUTRAL_CHROMA


# --- Fixture table: the exact contract the Dart port mirrors 1:1 ---------------

DART_PARITY_FIXTURES = [
    # (input hex, expected display hex, why)
    ("#2E2928", "#000000", "diluted black, CEO row 04 (L 17.1, C 2.6)"),
    ("#221A1A", "#000000", "diluted black, CEO row 06 (L 10.2, C 4.2)"),
    ("#3C3937", "#000000", "the CEO's canonical example (L 24.2, C 1.9)"),
    ("#3D3B39", "#000000", "lightest measured diluted black (L 25.0, C 1.6)"),
    ("#383737", "#000000", "diluted black, row 32 (L 23.2, C 0.5)"),
    ("#1F1F27", "#000000", "diluted black, row 14 (L 12.1, C 5.8)"),
    ("#000000", "#000000", "pure black is idempotent"),
    ("#D0CCC9", "#FFFFFF", "'blanco leído como gris', row 29 (L 82.3, C 2.2)"),
    ("#CDDDD8", "#FFFFFF", "white sole read as gray (L 86.8, C 6.3)"),
    ("#FFFFFB", "#FFFFFF", "near-white, row 27 (L 99.9, C 2.0)"),
    ("#FFFFFF", "#FFFFFF", "pure white is idempotent"),
    ("#051C56", "#051C56", "real navy: chroma 41.2 >= gate, NEVER touched"),
    ("#304474", "#304474", "real blue: chroma 31.0 >= gate, untouched"),
    ("#451316", "#451316", "real dark maroon: chroma 26.6 >= gate, untouched"),
    ("#2E1F3A", "#2E1F3A", "real dark purple: chroma 20.1 >= gate, untouched"),
    ("#6C747B", "#6C747B", "genuine mid gray stays (L 48.4, C 5.1)"),
    ("#99A39D", "#99A39D", "genuine gray stays (L 66.1, C 5.1)"),
    ("#AEAEB4", "#AEAEB4", "genuine light gray stays (L 71.3, C 3.3)"),
    ("#C2C0C3", "#C2C0C3", "lightest genuine gray stays (L 77.9 < 80)"),
    ("#52463E", "#52463E", "dark flesh-suede, NOT black (L 30.7 > 28)"),
    ("#4B5F59", "#4B5F59", "dark green-gray, NOT black (L 38.6 > 28)"),
    # Boundary rows (see display.py: <= for black, >= for white, < for chroma).
    ("#424242", "#000000", "boundary: L 27.97 <= 28.0 snaps"),
    ("#434343", "#434343", "boundary: L 28.41 > 28.0 stays"),
    ("#C6C6C6", "#C6C6C6", "boundary: L 79.88 < 80.0 stays"),
    ("#CACACA", "#FFFFFF", "boundary: L 81.33 >= 80.0 snaps"),
    ("#232B3F", "#232B3F", "boundary: chroma 14.05 >= 13.0, gate holds"),
    ("#222F39", "#000000", "dark slate: chroma 8.5 < 13, L 18.7 -> black"),
    # --- B-G25-3: the soft band (L* 21-28 needs chroma < 4.0 to read black) ---
    # The three swatches the CEO rejected as black on the gate G2.5 set.
    ("#3C414D", "#3C414D", "B-G25-3 blue fishnet: L 27.5, C 8.0 -> stays blue"),
    ("#303745", "#303745", "B-G25-3 fishnet lower: L 23.0, C 9.7 -> stays"),
    ("#413934", "#413934", "B-G25-3 olive/brown wool: L 24.6, C 5.1 -> stays"),
    # ...while the genuine dark neutrals in the SAME band still snap: this is
    # the #85-A/D31 behaviour the loosening must not resurrect.
    ("#39403F", "#000000", "selfie15 trousers: L 26.4 but C 3.2 < 4 -> black"),
    # (#383737, L 23.2 C 0.5, is already covered above and also lives in this
    #  band — the soft gate keeps it black.)
    # Below the hard floor the original single-threshold rule is verbatim:
    # chroma is IGNORED there, so a C* 8.3 deep dark still snaps.
    ("#372E24", "#000000", "L 19.6 C 8.3: under the hard floor, snaps anyway"),
    ("#1F0E07", "#000000", "L 5.6 C 9.0: deep dark, chroma irrelevant"),
]


@pytest.mark.parametrize(
    "input_hex, expected_hex, why",
    DART_PARITY_FIXTURES,
    ids=[f"{i}->{e}" for i, e, _ in DART_PARITY_FIXTURES],
)
def test_dart_parity_fixture(input_hex, expected_hex, why):
    assert _hex(snap_neutral_for_display(_rgb(input_hex))) == expected_hex, why


def test_snap_returns_plain_int_tuple():
    """The contract type is RGB = tuple[int, int, int] (numpy ints would break
    hexstr formatting and the fixture JSON the Dart side consumes)."""
    out = snap_neutral_for_display((110, 120, 130))
    assert isinstance(out, tuple) and all(type(v) is int for v in out)


def test_snap_never_touches_the_analysis_input():
    """Display-only guarantee (D31-A): the palette array passed in is not
    mutated; the snapped copy is a NEW array."""
    colors = np.array([[46, 41, 40], [208, 204, 201], [5, 28, 86]])
    before = colors.copy()
    snapped = snap_palette_for_display(colors)
    assert np.array_equal(colors, before)
    assert snapped is not colors
    assert snapped.tolist() == [[0, 0, 0], [255, 255, 255], [5, 28, 86]]


# --- Wiring: the battery reports display hexes; render accepts the flag --------


def test_product_battery_reports_display_hexes(tmp_path):
    """evaluate_photo must carry both the raw and the display hex per swatch
    (and for the base), so review.md/panels show what the app will show."""
    import sys
    from pathlib import Path

    from PIL import Image

    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
    import product_battery as pb

    # Diluted-black product (#2E2928) on a mid-gray studio background: the
    # background is edge-suppressed (#84) and the product swatch must be
    # DISPLAYED as pure black while the raw analysis hex stays diluted.
    arr = np.full((160, 120, 3), (150, 150, 150), dtype=np.uint8)
    arr[45:115, 40:80] = (46, 41, 40)  # #2E2928
    path = tmp_path / "prod-black.png"
    Image.fromarray(arr).save(path)

    res = pb.evaluate_photo(path)
    assert "CRASH" not in res["hints"], res.get("error")
    assert "display_base_hex" in res
    by_hex = {e["hex"]: e for e in res["palette"]}
    assert "#2E2928" in by_hex, f"palette was {sorted(by_hex)}"
    assert by_hex["#2E2928"]["display_hex"] == "#000000"

    # The review table shows the snapped hex with the raw kept as annotation.
    cell = pb._palette_cell(res)
    assert "`#000000` (snap de `#2E2928`)" in cell


def test_render_panel_snap_flag_smoke(tmp_path):
    """render_panel(snap_display_neutrals=True) renders without error and the
    default (False) stays available — presentation flag only."""
    from colorlab.render import render_panel

    original = np.zeros((10, 10, 3), dtype=np.uint8)
    colors = np.array([[46, 41, 40], [200, 40, 40]])
    weights = np.array([0.7, 0.3])
    schemes = {"Complementario": [(200, 40, 40), (40, 200, 200)]}
    out = tmp_path / "panel.png"
    render_panel(original, colors, weights, schemes, out, snap_display_neutrals=True)
    assert out.exists() and out.stat().st_size > 0
