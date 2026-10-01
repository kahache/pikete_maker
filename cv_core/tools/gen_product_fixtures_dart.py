"""Golden fixtures for the Dart port of D24 product mode (feature F11).

Additive companion to gen_fixtures_dart.py / gen_border_fixtures_dart.py: it
writes ONLY app/test/core/fixtures/product_mode_D24.json and touches no other
fixture, so the frozen palette/harmony fixtures stay byte-for-byte identical.

The reference output is produced by the CANONICAL colorlab pipeline running in
PRODUCT MODE (colorlab.pipeline.analyze_palette(product_mode=True)). Since #84
(gate G2S review) that branch is MORE than "the CORE on the whole frame": it
also runs the multi-edge background suppression (colors wrapping >= 3 image
edges are dropped BEFORE clustering, with the frame-filling guardrail) and the
neutral-lightness merge protection (white/gray/black stay distinct swatches).
The Dart engine mirrors all three pieces, and each fixture case therefore also
records the intermediate #84 diagnostics (the estimated background colors and
the suppressed pixel fraction) so a parity break points at the exact stage.

Each case dumps the exact input pixels (row-major [r, g, b] triplets, a small
product image kept under the K-means subsampling cap so Dart sees the
identical pixel set) and the colors/weights/base colorlab extracted. The Dart
parity test (app/test/core/product_mode_parity_test.dart) replays the full
product composition (mask -> drop -> cluster with neutral protection) and
compares with an RGB atol, same philosophy as the palette fixtures.

Usage (from the repo root, venv active or direct):
    .venv/Scripts/python.exe cv_core/tools/gen_product_fixtures_dart.py

REAL-SIZE mode (BACKLOG B2): ``real_size_cases()`` builds the 512x384 product
case that gen_garment_fixtures_dart.py --real-size folds into
parity_real_size_B2.json. Running this script directly still writes ONLY
product_mode_D24.json, unchanged.
"""

from __future__ import annotations

import base64
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image

from colorlab.borders import estimate_multiedge_background, product_background_mask
from colorlab.harmony import harmonies, pick_harmony_base_index
from colorlab.pipeline import analyze_palette

REPO = Path(__file__).resolve().parents[2]
FIXTURES = REPO / "app" / "test" / "core" / "fixtures"

# Small product frames (kept well under the 40k-pixel K-means cap so no
# subsampling happens and Dart sees the identical pixel set).
STUDIO_GRAY = (205, 205, 205)
PRODUCT_RED = (200, 40, 40)
PRODUCT_BLUE = (30, 60, 150)
PRODUCT_CAMEL = (215, 180, 150)  # skin-chroma: would be at risk under the skin filter

# Neutral-protection case (#84 round 2, the white bug): a near-white and a
# light gray whose FULL-L deltaE (~21) exceeds the merge threshold (20) while
# the attenuated-L deltaE (~11) does not — without the protection they would
# collapse into one gray. The dark-gray floor is far enough from both
# (attenuated dE > EDGE_MATCH_DELTA_E = 16) that suppression cannot eat them.
NEAR_WHITE = (238, 236, 232)  # L* ~ 93
LIGHT_GRAY = (176, 175, 173)  # L* ~ 72
DARK_FLOOR = (80, 80, 80)  # L* ~ 34

HEIGHT = 100
WIDTH = 75


def _product_photo(product, second=None, bg=STUDIO_GRAY):
    """Uniform background with a centered product blob; optional second blob."""
    arr = np.full((HEIGHT, WIDTH, 3), bg, dtype=np.uint8)
    arr[
        int(0.25 * HEIGHT) : int(0.70 * HEIGHT), int(0.25 * WIDTH) : int(0.55 * WIDTH)
    ] = product
    if second is not None:
        arr[
            int(0.25 * HEIGHT) : int(0.70 * HEIGHT),
            int(0.55 * WIDTH) : int(0.75 * WIDTH),
        ] = second
    return arr


def _flat_pixels(img):
    """Row-major flat list of [r, g, b] ints (i = row * width + col)."""
    h, w = img.shape[:2]
    return [[int(v) for v in img[r, col]] for r in range(h) for col in range(w)]


def _product_case(name, description, arr, atol_rgb=12.0, atol_weight=0.05):
    return {
        "nombre": name,
        "descripcion": description,
        "height": int(arr.shape[0]),
        "width": int(arr.shape[1]),
        "atol_rgb": atol_rgb,
        "atol_peso": atol_weight,
        "pixeles": _flat_pixels(arr),
        "esperado": _expected(arr),
    }


def _expected(arr):
    """The canonical product-mode output + #84 diagnostics for one photo."""
    analysis = analyze_palette(Image.fromarray(arr), product_mode=True)
    colors_int = [[int(x) for x in c] for c in analysis.colors]
    base_index = pick_harmony_base_index(analysis.colors, analysis.weights)
    esperado = {
        "colores": colors_int,
        "pesos": [float(w) for w in analysis.weights],
        "indice_base": int(base_index),
        "base": [int(x) for x in analysis.base],
    }
    if base_index >= 0:
        schemes = harmonies(tuple(analysis.base))
        esperado["armonias"] = {
            nom: [list(c) for c in cols] for nom, cols in schemes.items()
        }
    else:
        esperado["armonias"] = {}
    # #84 intermediate diagnostics: the multi-edge background estimate and the
    # fraction of the frame the (guardrailed) suppression mask drops — so a
    # Dart parity break points at the exact stage instead of just the palette.
    bg_colors = estimate_multiedge_background(arr)
    mask = product_background_mask(arr)
    esperado["bg_colores"] = [[int(x) for x in c] for c in bg_colors]
    esperado["frac_supresion"] = float(mask.mean())
    return esperado


# ---------------------------------------------------------------------------
# REAL-SIZE parity (BACKLOG B2, code-review finding F7, 2026-09-30).
#
# The cases above are 7500 px, under the Dart engine's 40k K-means cap, so the
# fixed-step subsampling of extractRgbaPixels (step from the WHOLE frame, then
# the #84 drop mask) is never exercised against the canonical pipeline, which
# clusters EVERY surviving pixel. This case is a 512x384 landscape product shot
# (196,608 px -> Dart step 5): a textured studio background wrapping all four
# edges (suppressed), a sneaker built from rectangles with seeded fabric noise,
# a white sole (neutral-lightness protection), a red accent at ~3% of the
# surviving product pixels (near MIN_WEIGHT) and a black eyelet strip ~1.5%
# (dropped). Consumed by gen_garment_fixtures_dart.py --real-size, which folds
# it into app/test/core/fixtures/parity_real_size_B2.json (lossless PNG b64).
# ---------------------------------------------------------------------------

REAL_SEED = 20260930
REAL_WIDTH = 512  # landscape product shot after the 512-longest-side decode
REAL_HEIGHT = 384
NOISE_PRODUCT = 6.0
NOISE_STUDIO = 4.0

STUDIO_MID_GRAY = (122, 122, 124)  # L* ~51: far from the white sole at attenuated L
SNEAKER_BLUE = (30, 60, 150)
SOLE_WHITE = (242, 241, 238)
ACCENT_RED = (200, 40, 40)
EYELET_BLACK = (24, 24, 26)


def _textured(rng, h, w, color, sigma, gradient=0.0):
    block = np.full((h, w, 3), color, dtype=float)
    if gradient:
        block += np.linspace(gradient, -gradient, h)[:, None, None]
    if sigma:
        block += rng.normal(0.0, sigma, (h, w, 3))
    return np.clip(np.rint(block), 0, 255).astype(np.uint8)


def _fill(img, rng, rows, cols, color, sigma=NOISE_PRODUCT, gradient=0.0):
    img[rows[0] : rows[1], cols[0] : cols[1]] = _textured(
        rng, rows[1] - rows[0], cols[1] - cols[0], color, sigma, gradient
    )


def _png_b64(arr) -> str:
    buf = io.BytesIO()
    Image.fromarray(arr).save(buf, format="PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode("ascii")


def real_size_cases():
    rng = np.random.default_rng(REAL_SEED)
    img = np.empty((REAL_HEIGHT, REAL_WIDTH, 3), dtype=np.uint8)
    _fill(
        img,
        rng,
        (0, REAL_HEIGHT),
        (0, REAL_WIDTH),
        STUDIO_MID_GRAY,
        sigma=NOISE_STUDIO,
        gradient=6.0,
    )
    # Sneaker: upper 120x220 + toe box 40x60, sole 30x280 under both.
    _fill(img, rng, (150, 270), (150, 370), SNEAKER_BLUE)  # upper 26,400 px
    _fill(img, rng, (230, 270), (370, 430), SNEAKER_BLUE)  # toe 2,400 px
    _fill(img, rng, (270, 300), (140, 440), SOLE_WHITE, sigma=3.0)  # 9,000 px
    # Red accent (swoosh-like) ~ 1,100 px ~ 2.9% of the ~38k product pixels.
    _fill(img, rng, (215, 230), (250, 323), ACCENT_RED)
    # Black eyelet strip ~ 560 px ~ 1.5% of product pixels: under MIN_WEIGHT.
    _fill(img, rng, (160, 168), (200, 270), EYELET_BLACK, sigma=2.0)
    arr = img
    return [
        {
            "nombre": "real_sneaker_studio_textured",
            "descripcion": (
                "512x384 (paso 5 en Dart): fondo de estudio texturizado que "
                "envuelve 4 bordes (suprimido), zapatilla azul + suela blanca "
                "(proteccion neutra #84), acento rojo ~2.9%% del producto "
                "(sobrevive), ojales negros ~1.5%% (caen bajo MIN_WEIGHT)"
            ),
            "height": int(arr.shape[0]),
            "width": int(arr.shape[1]),
            "atol_rgb": 12.0,
            "atol_peso": 0.05,
            "png_b64": _png_b64(arr),
            "suma_canales": [int(arr[:, :, d].sum()) for d in range(3)],
            "esperado": _expected(arr),
        }
    ]


def main() -> None:
    # Guardrail case: a solid frame-filling product — its single color wraps
    # every edge, so the naive rule would flag the SUBJECT; the coverage
    # guardrail must suppress nothing (frac_supresion == 0).
    frame_filling = np.full((HEIGHT, WIDTH, 3), PRODUCT_RED, dtype=np.uint8)

    # A sneaker resting across the bottom edge: its color reaches ONLY the
    # bottom band (< 3 edges) so it must survive, while the wrapping studio
    # gray (4 edges) is suppressed.
    bottom_touch = np.full((HEIGHT, WIDTH, 3), STUDIO_GRAY, dtype=np.uint8)
    bottom_touch[int(0.55 * HEIGHT) :, int(0.25 * WIDTH) : int(0.75 * WIDTH)] = (
        PRODUCT_BLUE
    )

    data = {
        "nombre": "product_mode_D24",
        "descripcion": (
            "modo producto (D24 + #84): la pipeline salta las capas de persona, "
            "SUPRIME el fondo multi-borde (color en >= 3 bordes -> pixeles fuera "
            "antes del clustering, con guardarrail de cobertura) y protege la "
            "luminosidad de los neutros en el merge (blanco/gris/negro separados). "
            "OFF por defecto: el modo outfit es byte-identico."
        ),
        "cases": [
            _product_case(
                "gray_plus_red_product",
                "fondo gris de estudio (4 bordes) SUPRIMIDO: la paleta es el producto rojo",
                _product_photo(PRODUCT_RED),
            ),
            _product_case(
                "two_products_base_pick",
                "dos productos (rojo + azul), gris suprimido: la base D5 elige entre cromaticos",
                _product_photo(PRODUCT_RED, second=PRODUCT_BLUE),
            ),
            _product_case(
                "camel_product_survives",
                "producto camel (croma de piel): sobrevive porque el filtro de piel se salta",
                _product_photo(PRODUCT_CAMEL),
            ),
            _product_case(
                "white_gray_neutral_protection",
                "proteccion #84: blanco (L93) y gris claro (L72) siguen SEPARADOS "
                "(a L atenuada se fusionarian); suelo oscuro suprimido; todo neutro -> lienzo",
                _product_photo(NEAR_WHITE, second=LIGHT_GRAY, bg=DARK_FLOOR),
            ),
            _product_case(
                "guardrail_frame_filling_product",
                "guardarrail #84: producto que llena el frame; su color toca los 4 bordes "
                "pero la supresion se auto-desactiva (frac_supresion 0)",
                frame_filling,
            ),
            _product_case(
                "sneaker_touching_bottom_edge",
                "producto que APOYA en el borde inferior (1 borde < 3): sobrevive; "
                "el gris que envuelve 4 bordes se suprime",
                bottom_touch,
            ),
        ],
    }
    FIXTURES.mkdir(parents=True, exist_ok=True)
    path = FIXTURES / "product_mode_D24.json"
    path.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    for c in data["cases"]:
        e = c["esperado"]
        print(
            f"  {c['nombre']}: base_idx {e['indice_base']} ({e['base']}), "
            f"paleta {['#%02X%02X%02X' % tuple(col) for col in e['colores']]}, "
            f"bg {['#%02X%02X%02X' % tuple(col) for col in e['bg_colores']]}, "
            f"supresion {e['frac_supresion']:.2f}"
        )
    print(f"product_mode_D24 -> {path}")


if __name__ == "__main__":
    main()
