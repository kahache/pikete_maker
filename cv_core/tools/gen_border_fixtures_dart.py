"""Golden fixtures for the Dart port of the #48 border-bg model (issue #49).

Additive companion to gen_fixtures_dart.py: it writes ONLY
app/test/core/fixtures/border_bg_D48.json and touches no other fixture, so the
frozen palette/harmony fixtures stay byte-for-byte identical.

The reference output is produced by the CANONICAL colorlab.borders (the winning
#48 two-color wall+floor model, with tests). The Dart parity test in
app/test/core/borders_parity_test.dart loads this JSON and asserts the Dart
port matches, with the same tolerance philosophy as the palette fixtures
(K-means-derived candidate colors compared with an RGB atol; the pure demotion
logic compared exactly by index).

Two surfaces are exercised:
  * estimate_background_candidates(rgb) — synthetic studio frames dumped as
    exact pixels + the candidates colorlab extracted (origin, color, coverage).
  * pick_harmony_base_avoiding_background(colors, weights, candidates) — palette
    + the exact candidates + the base colorlab chose (RGB) and the index that
    base occupies in the palette (the Dart contract works with indices, -1 for
    canvas mode D10).

Usage (from the repo root, venv active or direct):
    .venv/bin/python cv_core/tools/gen_border_fixtures_dart.py
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from colorlab.borders import (
    BORDER_BAND_CLUSTERS,
    BORDER_BAND_FRACTION,
    BORDER_COVERAGE_MIN,
    BORDER_SIMILARITY_DELTA_E,
    estimate_background_candidates,
    pick_harmony_base_avoiding_background,
)
from colorlab.harmony import pick_harmony_base_index

REPO = Path(__file__).resolve().parents[2]
FIXTURES = REPO / "app" / "test" / "core" / "fixtures"

# Same tones as cv_core/tests/test_borders.py, so the fixture reproduces the
# canonical test scenarios (kept small — 100x75 — to bound the JSON size while
# still exercising the wall/floor split).
WALL_GRAY = (200, 200, 200)
FLOOR_BROWN = (120, 90, 60)
GARMENT_RED = (200, 40, 40)
BEIGE_WALL = (200, 180, 150)
MUTED_BLUE = (110, 130, 160)

HEIGHT = 100
WIDTH = 75


def _studio_photo(
    wall=WALL_GRAY, floor=FLOOR_BROWN, garment=GARMENT_RED, height=HEIGHT, width=WIDTH
):
    """Mirror of test_borders._studio_photo (wall + bottom floor sliver +
    centered garment blob touching no border)."""
    img = np.zeros((height, width, 3), dtype=np.uint8)
    img[:] = wall
    img[int(0.95 * height) :] = floor
    img[
        int(0.25 * height) : int(0.70 * height), int(0.30 * width) : int(0.70 * width)
    ] = garment
    return img


def _busy_wall_photo():
    rng = np.random.default_rng(42)
    img = _studio_photo()
    busy = rng.integers(0, 256, size=(HEIGHT, WIDTH, 3), dtype=np.uint8)
    img[: int(0.95 * HEIGHT)] = busy[: int(0.95 * HEIGHT)]
    return img


def _busy_photo():
    rng = np.random.default_rng(42)
    return rng.integers(0, 256, size=(HEIGHT, WIDTH, 3), dtype=np.uint8)


def _candidates_json(candidates):
    return [
        {
            "origin": c.origin,
            "color": [int(x) for x in c.color],
            "coverage": float(c.coverage),
        }
        for c in candidates
    ]


def _flat_pixels(img):
    """Row-major flat list of [r, g, b] ints (i = row * width + col)."""
    h, w = img.shape[:2]
    return [[int(v) for v in img[r, col]] for r in range(h) for col in range(w)]


def _estimate_case(name, description, img):
    candidates = estimate_background_candidates(img)
    return {
        "nombre": name,
        "descripcion": description,
        "height": int(img.shape[0]),
        "width": int(img.shape[1]),
        "pixeles": _flat_pixels(img),
        "esperado_candidatos": _candidates_json(candidates),
    }


def _index_of(colors, rgb):
    """Palette index whose color equals rgb (the base picker returns an RGB;
    the Dart contract needs the index). -1 if not found (never expected here)."""
    for i, c in enumerate(colors):
        if tuple(int(x) for x in c) == tuple(int(x) for x in rgb):
            return i
    return -1


def _pick_case(name, description, colors, weights, image_for_candidates):
    colors = np.array(colors)
    weights = np.array(weights)
    candidates = (
        estimate_background_candidates(image_for_candidates)
        if image_for_candidates is not None
        else []
    )
    baseline_index = pick_harmony_base_index(colors, weights)
    base = pick_harmony_base_avoiding_background(colors, weights, candidates)
    return {
        "nombre": name,
        "descripcion": description,
        "colores": [[int(x) for x in c] for c in colors],
        "pesos": [float(w) for w in weights],
        "candidatos": _candidates_json(candidates),
        "baseline_indice": int(baseline_index),
        "esperado_base": [int(x) for x in base],
        "esperado_indice": _index_of(colors, base),
    }


def main() -> None:
    data = {
        "nombre": "border_bg_D48",
        "descripcion": (
            "modelo de fondo por bandas #48 (D48, issue #49): candidatos "
            "pared/suelo y democion de la base de armonias; capa opcional, "
            "OFF por defecto — el flujo MVP no la usa."
        ),
        "band_fraction": BORDER_BAND_FRACTION,
        "similarity_delta_e": BORDER_SIMILARITY_DELTA_E,
        "coverage_min": BORDER_COVERAGE_MIN,
        "border_band_clusters": BORDER_BAND_CLUSTERS,
        "atol_rgb": 12,
        "atol_coverage": 0.05,
        "estimate_cases": [
            _estimate_case(
                "wall_and_floor",
                "pared gris + suelo marron: dos candidatos uniformes",
                _studio_photo(),
            ),
            _estimate_case(
                "floor_only_busy_wall",
                "pared ruidosa, suelo uniforme: solo candidato de suelo",
                _busy_wall_photo(),
            ),
            _estimate_case(
                "busy_no_candidates",
                "todo ruido: ninguna banda uniforme -> capa inerte",
                _busy_photo(),
            ),
        ],
        "pick_cases": [
            _pick_case(
                "demotion_moves_off_bg",
                "beige pared (lidera baseline) demovido -> lidera el azul apagado",
                [BEIGE_WALL, MUTED_BLUE],
                [0.75, 0.25],
                _studio_photo(wall=BEIGE_WALL),
            ),
            _pick_case(
                "no_candidates_keeps_baseline",
                "sin candidatos: base identica a la baseline",
                [BEIGE_WALL, MUTED_BLUE],
                [0.75, 0.25],
                None,
            ),
            _pick_case(
                "all_bg_like_falls_back",
                "paleta entera parece fondo (outfit monocromo): baseline sin cambios",
                [BEIGE_WALL, (205, 185, 155)],
                [0.6, 0.4],
                _studio_photo(wall=BEIGE_WALL),
            ),
        ],
    }
    FIXTURES.mkdir(parents=True, exist_ok=True)
    path = FIXTURES / "border_bg_D48.json"
    path.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    est = ", ".join(
        f"{c['nombre']}={[x['origin'] for x in c['esperado_candidatos']]}"
        for c in data["estimate_cases"]
    )
    pick = ", ".join(
        f"{c['nombre']}=idx{c['esperado_indice']}" for c in data["pick_cases"]
    )
    print(f"border_bg_D48 -> {path}")
    print(f"  estimate: {est}")
    print(f"  pick:     {pick}")


if __name__ == "__main__":
    main()
