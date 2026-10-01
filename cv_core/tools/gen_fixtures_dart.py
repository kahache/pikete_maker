"""Generates the golden fixtures for the Dart port of the color core (D15, #32).

Replicates the SAME cases as cv_core/tests/test_palette.py and
test_harmony.py (NAVY/MUSTARD/PINK/LAVENDER clouds with the same numpy seed,
the Vuitton case and the shading fragments) and dumps them to
app/test/core/fixtures/*.json:

  - the EXACT input pixels (float64; json uses repr, so the round-trip to
    Dart's double is bit-for-bit), and
  - the expected colorlab output (colors, weights, D5 base and harmonies),
    which is the canonical reference of the algorithm.

The tests in app/test/core/paridad_fixtures_test.dart load these JSON files
and verify the Dart port against this output with the same tolerances as the
Python tests (atol 10-15 in RGB, 0.02-0.05 in weights).

NOTE (#28): the JSON keys, fixture file names and description strings are a
CONTRACT with the Dart tests (another territory) — they stay in Spanish and
must be reproduced byte-for-byte. Only the code around them is in English.

Usage (from the repo root, with the venv active or directly):
    .venv/bin/python cv_core/tools/gen_fixtures_dart.py
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from colorlab.harmony import (
    canvas_accents,
    harmonies,
    hsv_to_rgb,
    is_neutral,
    pick_harmony_base,
    pick_harmony_base_index,
    rgb_to_hsv,
)
from colorlab.palette import dominant_colors

REPO = Path(__file__).resolve().parents[2]
FIXTURES = REPO / "app" / "test" / "core" / "fixtures"

# Colors from the canonical tests (test_palette.py / test_harmony.py).
NAVY = (30.0, 50.0, 110.0)
MUSTARD = (200.0, 150.0, 40.0)
PINK = (225.0, 54.0, 131.0)
PINK_LIGHT = (243.0, 84.0, 156.0)  # dE76 ~ 8.7 from PINK
PINK_DARK = (196.0, 36.0, 106.0)  # dE76 ~ 9.7 from PINK
LAVENDER = (156.0, 166.0, 198.0)  # dE76 > 64 from any pink
LAV_SHADOW = (0x7A, 0x7F, 0x9A)  # shadow half of the sneakers (real Vuitton bug)
LAV_LIGHT = (0xB5, 0xC1, 0xE3)  # light half
FUCHSIA = (225, 54, 131)
BEIGE = (210, 205, 195)
# Neutral canvas (D10): a black hoodie + gray + white outfit — every cluster is
# neutral, so pick_harmony_base_index returns -1 and canvas mode kicks in.
CHARCOAL = (34, 34, 38)
MID_GRAY = (128, 128, 128)
OFF_WHITE = (238, 238, 238)


def _pixels(color, n, jitter=3.0, seed=0):
    """Gaussian cloud of n pixels around a color (identical to the helper in
    test_palette.py, same seed per cloud)."""
    rng = np.random.default_rng(seed)
    return np.clip(np.array(color) + rng.normal(0, jitter, size=(n, 3)), 0, 255)


def _palette_case(
    name,
    description,
    clouds,
    k,
    min_weight=0.02,
    merge_delta_e=20.0,
    atol_rgb=10.0,
    atol_weight=0.05,
):
    """Runs colorlab over the clouds and dumps input + expected output."""
    pixels = np.vstack([_pixels(c, n) for c, n in clouds])
    colors, weights = dominant_colors(
        pixels, k=k, min_weight=min_weight, merge_delta_e=merge_delta_e
    )
    colors_int = [[int(x) for x in c] for c in colors]

    # D5 base (index into the palette; -1 = all neutral -> canvas mode, D10).
    base_index = pick_harmony_base_index(colors, weights)
    base = pick_harmony_base(colors, weights)  # RGB (fallback dominant if -1)

    esperado = {
        "colores": colors_int,
        "pesos": [float(w) for w in weights],
        "indice_base": base_index,
        # Kept for schema stability; the Dart parity test ignores it when -1.
        "base": [int(x) for x in base],
    }
    if base_index >= 0:
        # The fixture's harmonies are computed from Python's EXACT base so the
        # Dart test can verify the harmony module with tolerance ~1 (decoupled
        # from the K-means tolerance).
        schemes = harmonies(tuple(base))
        esperado["armonias"] = {
            nom: [list(c) for c in cols] for nom, cols in schemes.items()
        }
    else:
        # Canvas mode (D10): no chromatic base -> no arbitrary-hue harmonies.
        # The proposal is the curated accent set (this fixture also verifies
        # that the Dart const mirrors the Python one byte-for-byte).
        esperado["armonias"] = {}
        esperado["acentos_lienzo"] = [list(c) for c in canvas_accents()]

    data = {
        "nombre": name,
        "descripcion": description,
        "k": k,
        "min_weight": min_weight,
        "merge_delta_e": merge_delta_e,
        "atol_rgb": atol_rgb,
        "atol_peso": atol_weight,
        "pixeles": pixels.tolist(),
        "esperado": esperado,
    }
    FIXTURES.mkdir(parents=True, exist_ok=True)
    path = FIXTURES / f"{name}.json"
    path.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    print(
        f"{name}: {len(pixels)} px -> {colors_int} weights={[round(float(w), 4) for w in weights]} base_idx={base_index}"
    )


def _palette_fixtures():
    _palette_case(
        "dos_colores_700_300",
        "test_two_colors_recovered_in_frequency_order + weights_match_pixel_proportions",
        [(NAVY, 700), (MUSTARD, 300)],
        k=2,
        atol_rgb=10,
        atol_weight=0.05,
    )
    _palette_case(
        "residuales_980_20",
        "test_residual_clusters_are_dropped: el mostaza (2%) muere bajo min_weight=0.05",
        [(NAVY, 980), (MUSTARD, 20)],
        k=5,
        min_weight=0.05,
        atol_rgb=10,
        atol_weight=0.03,
    )
    _palette_case(
        "mostaza_solo_200",
        "test_colors_are_valid_rgb_ints: un solo color, k=1 (sobre-clusterizado a 2 y refusionado)",
        [(MUSTARD, 200)],
        k=1,
        atol_rgb=10,
        atol_weight=0.02,
    )
    _palette_case(
        "fusion_rosa_500_500",
        "test_same_hue_light_variants_merge_into_one_color: dos variantes de rosa colapsan en 1",
        [(PINK, 500), (PINK_LIGHT, 500)],
        k=5,
        atol_rgb=12,
        atol_weight=0.02,
    )
    _palette_case(
        "distintos_no_fusionan_600_400",
        "test_clearly_distinct_colors_are_not_merged: navy vs mostaza (dE76 ~107) intactos",
        [(NAVY, 600), (MUSTARD, 400)],
        k=5,
        atol_rgb=10,
        atol_weight=0.05,
    )
    _palette_case(
        "vuitton_pop_lavanda",
        "test_vuitton_case: 3 variantes de rosa colapsan y el pop lavanda (5%) sobrevive",
        [(PINK, 400), (PINK_LIGHT, 330), (PINK_DARK, 220), (LAVENDER, 50)],
        k=5,
        atol_rgb=15,
        atol_weight=0.02,
    )
    _palette_case(
        "sombras_lavanda_reunificadas",
        "test_shading_fragments: mitades luz/sombra (1.7% cada una) se reunifican gracias a la L atenuada",
        [(PINK, 966), (LAV_SHADOW, 17), (LAV_LIGHT, 17)],
        k=5,
        min_weight=0.02,
        atol_rgb=12,
        atol_weight=0.02,
    )
    # 550/450 instead of the Python test's 500/500: with tied weights the
    # palette ORDER would be ambiguous between sklearn and Dart's K-means and
    # the fixture could not compare position by position (the Python test only
    # asserts len == 2; that mirror version lives in palette_test.dart).
    _palette_case(
        "sin_fusion_kmeans_directo",
        "test_merge_can_be_disabled: merge_delta_e=0 mantiene las dos variantes de rosa separadas",
        [(PINK, 550), (PINK_LIGHT, 450)],
        k=2,
        merge_delta_e=0.0,
        atol_rgb=10,
        atol_weight=0.05,
    )
    _palette_case(
        "lienzo_neutro_D10",
        "modo lienzo (D10, #21): outfit 100% neutro (negro+gris+blanco) -> indice_base=-1 "
        "y acentos_lienzo curados en vez de armonias de matiz arbitrario (bug B3)",
        [(CHARCOAL, 600), (MID_GRAY, 250), (OFF_WHITE, 150)],
        k=5,
        atol_rgb=12,
        atol_weight=0.05,
    )


def _harmony_fixtures():
    """Harmony cases with Python's exact output (~exact parity: it is
    deterministic float arithmetic, no K-means involved)."""
    bases = {
        "fucsia": FUCHSIA,
        "navy": (30, 50, 110),
        # triggers the PROPOSAL_MIN_SAT floor (s=0.25 < 0.35)
        "azul_lavado": hsv_to_rgb(0.6, 0.25, 0.8),
        # triggers the PROPOSAL_MIN_VAL floor (v ~0.38 < 0.55)
        "granate_oscuro": (96, 18, 34),
        # neutral base (pick_harmony_base fallback): triggers both floors
        "beige_neutro": BEIGE,
        "blanco": (255, 255, 255),
    }
    cases = []
    for name, rgb in bases.items():
        h, s, v = rgb_to_hsv(rgb)
        cases.append(
            {
                "nombre": name,
                "base": list(rgb),
                "hsv": [h, s, v],
                "es_neutro": is_neutral(rgb),
                "hex": "#{:02X}{:02X}{:02X}".format(*rgb),
                "armonias": {
                    nom: [list(c) for c in cols] for nom, cols in harmonies(rgb).items()
                },
            }
        )
    path = FIXTURES / "armonias_casos.json"
    path.write_text(
        json.dumps({"casos": cases}, separators=(",", ":")), encoding="utf-8"
    )
    print(f"armonias_casos: {len(cases)} bases")


if __name__ == "__main__":
    _palette_fixtures()
    _harmony_fixtures()
    print(f"\nFixtures at {FIXTURES}")
