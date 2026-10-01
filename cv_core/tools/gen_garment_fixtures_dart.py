"""Golden fixtures for the Dart port of the Phase 2.5 per-garment analysis.

Additive companion to gen_fixtures_dart.py / gen_product_fixtures_dart.py: it
writes ONLY app/test/core/fixtures/garment_analysis_F25.json and touches no
other fixture, so the frozen palette/harmony/border/product fixtures stay
byte-for-byte identical.

The reference output is produced by the CANONICAL per-garment layer (issue
#89): colorlab.pipeline.analyze_garments over a SYNTHETIC photo plus a
SYNTHETIC class map (MediaPipe class ids, colorlab.segmentation contract) —
model-free, deterministic, CI-safe. Each case dumps the exact input pixels
and class map (row-major, small frames kept under the K-means subsampling cap
so Dart sees the identical pixel set), the split/guard diagnostics (surviving
regions + eroded pixel counts, so a parity break points at the mask stage),
the per-garment palettes, and the combined outfit palette with its
swatch-region attribution and global base.

The Dart parity test (app/test/core/garment_parity_test.dart) replays the
full on-device composition — buildMasks (spike split) -> applyGarmentGuards
(#89 erosion + min-region) -> extractRgbaPixels per region ->
buildGarmentAnalysis — and compares with the same RGB/weight tolerances as
the product-mode fixtures.

Usage (from the repo root, venv active or direct):
    .venv/Scripts/python.exe cv_core/tools/gen_garment_fixtures_dart.py

REAL-SIZE mode (BACKLOG B2): ``--real-size`` writes ONLY
app/test/core/fixtures/parity_real_size_B2.json — frames at the size the app
feeds the engine (longest side 512), where the Dart K-means subsampling fires —
folding in the product cases of gen_product_fixtures_dart.real_size_cases. The
default (no flag) output is untouched.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image

from colorlab.harmony import harmonies
from colorlab.pipeline import analyze_garments
from colorlab.segmentation import (
    CLASS_BACKGROUND,
    CLASS_BODY_SKIN,
    CLASS_CLOTHES,
    CLASS_HAIR,
    NoPersonError,
    preprocess_rgb,
    split_garment_masks,
)

REPO = Path(__file__).resolve().parents[2]
FIXTURES = REPO / "app" / "test" / "core" / "fixtures"

# Small frames: 80x100 = 8000 px, far under the Dart 40k K-means subsampling
# cap, so extraction is 1:1 and Dart clusters the identical pixel set.
HEIGHT = 100
WIDTH = 80

# Photo colors. The background/hair/skin colors are deliberately LOUD: if
# attribution ever leaks a non-clothes pixel, the palette shows it instantly.
WALL_CYAN = (0, 255, 255)
HAIR_BROWN = (90, 60, 30)
SKIN_TAN = (224, 172, 105)

GREEN_MAIN = (126, 156, 123)  # mockup-ish upper hoodie
GREEN_DARK = (85, 112, 79)
PURPLE_MAIN = (155, 89, 208)  # mockup-ish lower shorts (global base owner)
TEAL_SOFT = (96, 160, 168)  # big, moderately saturated
ORANGE_VIVID = (240, 90, 20)  # small, highly saturated
RED_HOODIE = (208, 52, 44)
JEAN_BLACK = (35, 33, 40)  # near-black neutral (chroma < 13)
JEAN_GRAY = (107, 106, 117)  # dark neutral
OFF_WHITE = (238, 238, 238)
BLUE_SOLID = (36, 86, 184)
YELLOW_BLEED = (255, 220, 0)  # boundary contamination the erosion removes


def _scene(bg=WALL_CYAN, with_person=True):
    """Base photo + class map: wall everywhere, hair and skin patches."""
    img = np.full((HEIGHT, WIDTH, 3), bg, dtype=np.uint8)
    cm = np.full((HEIGHT, WIDTH), CLASS_BACKGROUND, dtype=np.uint8)
    if with_person:
        img[2:12, 30:50] = HAIR_BROWN
        cm[2:12, 30:50] = CLASS_HAIR
        img[12:20, 32:48] = SKIN_TAN
        cm[12:20, 32:48] = CLASS_BODY_SKIN
    return img, cm


def _paint(img, cm, rows, cols, color):
    """Paints a clothes rectangle in both the photo and the class map."""
    img[rows[0] : rows[1], cols[0] : cols[1]] = color
    cm[rows[0] : rows[1], cols[0] : cols[1]] = CLASS_CLOTHES


def _flat_pixels(img):
    """Row-major flat list of [r, g, b] ints (i = row * width + col)."""
    return [[int(v) for v in img[r, c]] for r in range(HEIGHT) for c in range(WIDTH)]


def _flat_classes(cm):
    return [int(v) for v in cm.reshape(-1)]


def _case(name, description, img, cm, atol_rgb=12.0, atol_weight=0.05):
    base = {
        "nombre": name,
        "descripcion": description,
        "height": HEIGHT,
        "width": WIDTH,
        "atol_rgb": atol_rgb,
        "atol_peso": atol_weight,
        "pixeles": _flat_pixels(img),
        "mapa_clases": _flat_classes(cm),
    }
    try:
        masks = split_garment_masks(cm)
    except NoPersonError:
        base["espera_no_person"] = True
        return base
    base["espera_no_person"] = False
    base["esperado"] = _expected(img, cm, masks)
    return base


def _expected(img, cm, masks):
    """The canonical analyze_garments output + mask diagnostics for one case."""
    analysis = analyze_garments(Image.fromarray(img), cm)
    esperado = {
        # Mask-stage diagnostics: a Dart parity break points at the exact stage.
        "regiones_supervivientes": list(masks),
        "pixeles_region": {r: int(m.sum()) for r, m in masks.items()},
        # Per-garment palettes (weights normalized WITHIN the garment).
        "prendas": {
            region: {
                "colores": [[int(x) for x in c] for c in g.colors],
                "pesos": [float(w) for w in g.weights],
                "indice_base": int(g.base_index),
                "fraccion": float(g.pixel_fraction),
            }
            for region, g in analysis.garments.items()
        },
        # Combined outfit palette + attribution + global base (#89 contract).
        "colores": [[int(x) for x in c] for c in analysis.colors],
        "pesos": [float(w) for w in analysis.weights],
        "regiones": list(analysis.swatch_regions),
        "indice_base": int(analysis.base_index),
        "base": [int(x) for x in analysis.base],
        "region_base": analysis.base_region,
    }
    if analysis.base_index >= 0:
        schemes = harmonies(tuple(analysis.base))
        esperado["armonias"] = {
            nom: [list(c) for c in cols] for nom, cols in schemes.items()
        }
    else:
        esperado["armonias"] = {}
    return esperado


# ---------------------------------------------------------------------------
# REAL-SIZE parity (BACKLOG B2, code-review finding F7, 2026-09-30).
#
# Every case above is tiny (8000 px), so the Dart engine's fixed-step
# K-means subsampling (kMaxKmeansPixels = 40k, step computed from the WHOLE
# frame) never fires and the fixtures cannot see it, while the canonical
# analyze_garments clusters EVERY mask pixel. These cases run at the size the
# app actually feeds the engine — the codec caps the longest side at
# kMaxDecodeSide = 512, so a 4:3 selfie arrives as 384x512 (196,608 px ->
# step 5) — with textured garments (seeded noise + a lighting gradient), one
# SMALL region (~1% of the frame) and minority swatches on both sides of the
# MIN_WEIGHT = 2% cutoff. Pixels travel as lossless PNG (base64) instead of
# JSON triplets to keep the fixture small; a channel checksum lets the Dart
# side prove the transport is exact before comparing palettes.
# ---------------------------------------------------------------------------

REAL_SEED = 20260930
REAL_WIDTH = 384  # 4:3 portrait selfie after the app's 512-longest-side decode
REAL_HEIGHT = 512
NOISE_GARMENT = 6.0  # fabric texture, RGB sigma
NOISE_BACKGROUND = 4.0
GRADIENT_LIGHTING = 14.0  # top-to-bottom lighting ramp, +-RGB

WALL_GRAYBLUE = (168, 176, 190)
DENIM_BLUE = (52, 78, 132)
DENIM_FADE = (88, 116, 168)
TEE_BLACK = (28, 27, 31)
CHINO_GRAY = (118, 116, 120)
LOGO_ORANGE = (240, 90, 20)
TAG_YELLOW = (250, 214, 30)
SHORTS_PURPLE = (155, 89, 208)
STRIPE_WHITE = (240, 240, 240)


def _textured(rng, h, w, color, sigma=NOISE_GARMENT, gradient=GRADIENT_LIGHTING):
    """A (h, w, 3) uint8 block: color + vertical lighting ramp + seeded noise."""
    block = np.full((h, w, 3), color, dtype=float)
    if gradient:
        block += np.linspace(gradient, -gradient, h)[:, None, None]
    if sigma:
        block += rng.normal(0.0, sigma, (h, w, 3))
    return np.clip(np.rint(block), 0, 255).astype(np.uint8)


def _fill(img, rng, rows, cols, color, **kw):
    img[rows[0] : rows[1], cols[0] : cols[1]] = _textured(
        rng, rows[1] - rows[0], cols[1] - cols[0], color, **kw
    )


def _paint_real(img, cm, rng, rows, cols, color, **kw):
    _fill(img, rng, rows, cols, color, **kw)
    cm[rows[0] : rows[1], cols[0] : cols[1]] = CLASS_CLOTHES


def _real_scene(rng):
    img = np.empty((REAL_HEIGHT, REAL_WIDTH, 3), dtype=np.uint8)
    _fill(
        img,
        rng,
        (0, REAL_HEIGHT),
        (0, REAL_WIDTH),
        WALL_GRAYBLUE,
        sigma=NOISE_BACKGROUND,
        gradient=8.0,
    )
    cm = np.full((REAL_HEIGHT, REAL_WIDTH), CLASS_BACKGROUND, dtype=np.uint8)
    _fill(img, rng, (20, 70), (150, 234), HAIR_BROWN, gradient=0.0)
    cm[20:70, 150:234] = CLASS_HAIR
    _fill(img, rng, (70, 118), (158, 226), SKIN_TAN, gradient=0.0)
    cm[70:118, 158:226] = CLASS_BODY_SKIN
    return img, cm


def png_b64(arr) -> str:
    """Lossless PNG (RGB or L) as base64 text."""
    buf = io.BytesIO()
    Image.fromarray(arr).save(buf, format="PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode("ascii")


# MediaPipe preprocess parity (F7's second note): the model input tensor
# (256x256x3 float32 bilinear, center-aligned sampling) is stored as a strided
# sample plus its double-precision sum — 197 values instead of 196,608.
PREPROCESS_STRIDE = 997  # prime: sweeps rows, columns and channels


def _preprocess_case(img):
    tensor = preprocess_rgb(img).reshape(-1)
    return {
        "stride": PREPROCESS_STRIDE,
        "muestras": [float(v) for v in tensor[::PREPROCESS_STRIDE]],
        "suma": float(tensor.astype(np.float64).sum()),
        "longitud": int(tensor.size),
    }


def _case_real_size(
    name, description, img, cm, atol_rgb=12.0, atol_weight=0.05, with_preprocess=False
):
    base = {
        "nombre": name,
        "descripcion": description,
        "height": int(img.shape[0]),
        "width": int(img.shape[1]),
        "atol_rgb": atol_rgb,
        "atol_peso": atol_weight,
        "png_b64": png_b64(img),
        "mapa_clases_png_b64": png_b64(cm),
        # Transport proof: the Dart decode must reproduce these exactly.
        "suma_canales": [int(img[:, :, d].sum()) for d in range(3)],
        "histograma_clases": [int((cm == c).sum()) for c in range(6)],
    }
    if with_preprocess:
        base["preproceso"] = _preprocess_case(img)
    masks = split_garment_masks(cm)  # every real-size case has a person
    base["espera_no_person"] = False
    base["esperado"] = _expected(img, cm, masks)
    return base


def real_size_cases():
    rng = np.random.default_rng(REAL_SEED)
    cases = []

    # R1: two textured garments, minority swatches on BOTH sides of the 2%
    # cutoff inside the upper garment. Upper 170x200 = 34,000 px (eroded
    # 166x196 = 32,536); the orange logo 30x30 = 900 px ~ 2.8% of it (must
    # SURVIVE on both sides), the yellow tag 18x18 = 324 px ~ 1.0% (must be
    # DROPPED on both sides). Clothes bbox rows 120..479 -> mid 299: the
    # upper ends at 290 and the lower starts at 300, so the split is clean.
    img, cm = _real_scene(rng)
    _paint_real(img, cm, rng, (120, 290), (90, 290), GREEN_MAIN)
    _fill(img, rng, (170, 200), (175, 205), LOGO_ORANGE, gradient=0.0)
    _fill(img, rng, (230, 248), (120, 138), TAG_YELLOW, gradient=0.0)
    _paint_real(img, cm, rng, (300, 480), (110, 270), DENIM_BLUE, sigma=8.0)
    _fill(img, rng, (380, 400), (110, 270), DENIM_FADE, sigma=8.0, gradient=0.0)
    cases.append(
        _case_real_size(
            "real_two_garments_textured",
            "384x512 (step 5 en Dart): sudadera verde texturizada con logo "
            "naranja ~2.8%% (sobrevive) y etiqueta amarilla ~1%% (cae bajo "
            "MIN_WEIGHT) + vaquero azul con rodilla desgastada; incluye la "
            "muestra del tensor de entrada MediaPipe (preprocess_rgb)",
            img,
            cm,
            with_preprocess=True,
        )
    )

    # R2: SMALL lower region ~1% of the frame (shorts peeking under a big red
    # hoodie): 50x44 = 2200 px, eroded 46x40 = 1840 px = 0.94% of 196,608
    # (above the 0.5% min-region guard). Dart samples ~1/5 of it. A white
    # stripe (6 rows of the eroded 46 ~ 13%) must survive inside the shorts.
    img, cm = _real_scene(rng)
    _paint_real(img, cm, rng, (120, 280), (80, 300), RED_HOODIE)
    _paint_real(img, cm, rng, (400, 450), (170, 214), SHORTS_PURPLE)
    _fill(img, rng, (420, 426), (170, 214), STRIPE_WHITE, gradient=0.0)
    cases.append(
        _case_real_size(
            "real_small_lower_region",
            "region inferior PEQUENA (0.94%% del frame, > guarda 0.5%%): Dart "
            "muestrea ~368 px de 1840; raya blanca ~13%% dentro del short",
            img,
            cm,
        )
    )

    # R3: all-neutral outfit at real size (canvas D10): textured black tee +
    # gray chinos; the noise must not push any swatch over NEUTRAL_CHROMA.
    img, cm = _real_scene(rng)
    _paint_real(img, cm, rng, (120, 290), (90, 290), TEE_BLACK)
    _paint_real(img, cm, rng, (300, 480), (110, 270), CHINO_GRAY)
    cases.append(
        _case_real_size(
            "real_all_neutral_canvas",
            "outfit 100%% neutro texturizado a tamano real -> indice_base -1 "
            "(lienzo D10) en ambos lados",
            img,
            cm,
        )
    )
    return cases


def main_real_size() -> None:
    # Sibling generator (same directory, importable when run as a script).
    from gen_product_fixtures_dart import real_size_cases as product_real_size_cases

    data = {
        "nombre": "parity_real_size_B2",
        "descripcion": (
            "paridad Python<->Dart a TAMANO REAL (BACKLOG B2, F7): frames de "
            "196,608 px (lado mayor 512 = kMaxDecodeSide) donde el motor Dart "
            "submuestrea con paso fijo 5 (kMaxKmeansPixels 40k) y Python "
            "agrupa TODOS los pixeles de la mascara. Casos por prenda "
            "(analyze_garments) y de producto (analyze_palette product_mode). "
            "Pixeles como PNG base64 sin perdida + checksum de transporte."
        ),
        "seed": REAL_SEED,
        "garment_cases": real_size_cases(),
        "product_cases": product_real_size_cases(),
    }
    FIXTURES.mkdir(parents=True, exist_ok=True)
    path = FIXTURES / "parity_real_size_B2.json"
    path.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    for c in data["garment_cases"]:
        e = c["esperado"]
        print(
            f"  [garment] {c['nombre']}: regiones {e['regiones_supervivientes']} "
            f"{e['pixeles_region']}, base_idx {e['indice_base']} ({e['base']}) "
            f"en {e['region_base']}, combinada "
            f"{['#%02X%02X%02X' % tuple(col) for col in e['colores']]} "
            f"{[f'{w:.3f}' for w in e['pesos']]} {e['regiones']}"
        )
        for region, g in e["prendas"].items():
            print(
                f"      {region}: "
                f"{['#%02X%02X%02X' % tuple(col) for col in g['colores']]} "
                f"{[f'{w:.3f}' for w in g['pesos']]} base_idx {g['indice_base']}"
            )
    for c in data["product_cases"]:
        e = c["esperado"]
        print(
            f"  [product] {c['nombre']}: base_idx {e['indice_base']} ({e['base']}), "
            f"paleta {['#%02X%02X%02X' % tuple(col) for col in e['colores']]} "
            f"{[f'{w:.3f}' for w in e['pesos']]}, "
            f"bg {['#%02X%02X%02X' % tuple(col) for col in e['bg_colores']]}, "
            f"supresion {e['frac_supresion']:.3f}"
        )
    print(f"parity_real_size_B2 -> {path} ({path.stat().st_size} bytes)")


def main() -> None:
    cases = []

    # S1 happy path: two garments, the LOWER (purple) owns the global base.
    # Upper rows 20:50, lower rows 60:100 -> bbox mid = (20+99)//2 = 59, so
    # the geometric split lands exactly between the garments.
    img, cm = _scene()
    _paint(img, cm, (20, 40), (20, 60), GREEN_MAIN)
    _paint(img, cm, (40, 50), (20, 60), GREEN_DARK)
    _paint(img, cm, (60, 100), (25, 55), PURPLE_MAIN)
    cases.append(
        _case(
            "two_garments_global_base",
            "S1: verde arriba (2 tonos) + morado abajo; base global = morado "
            "(region 'lower'); fondo/pelo/piel jamas muestreados",
            img,
            cm,
        )
    )

    # Pixel-share scaling (spec §6 contract #1): the SMALL vivid orange would
    # win a per-garment-normalized comparison (w~1.0 x s~0.9), but the scaled
    # combined weights hand the base to the BIG soft teal — the exact bias the
    # UX spec warned about.
    img, cm = _scene()
    _paint(img, cm, (20, 52), (10, 70), TEAL_SOFT)  # big upper
    _paint(img, cm, (66, 78), (35, 45), ORANGE_VIVID)  # small lower
    cases.append(
        _case(
            "pixel_share_scaled_base",
            "base global comparada con pesos escalados por share de pixeles: el "
            "teal grande gana al naranja vivido pequeno (sin escala ganaria el "
            "naranja)",
            img,
            cm,
        )
    )

    # U7: chromatic upper + fully NEUTRAL lower (per-garment base_index -1),
    # global base lives in the upper garment.
    img, cm = _scene()
    _paint(img, cm, (20, 50), (20, 60), RED_HOODIE)
    _paint(img, cm, (60, 90), (25, 55), JEAN_BLACK)
    _paint(img, cm, (90, 100), (25, 55), JEAN_GRAY)
    cases.append(
        _case(
            "upper_chromatic_lower_neutral",
            "U7: sudadera roja + vaquero negro/gris (prenda 100%% neutra, "
            "indice_base -1); base global en 'upper'",
            img,
            cm,
        )
    )

    # Canvas D10: BOTH garments neutral -> combined base_index -1.
    img, cm = _scene()
    _paint(img, cm, (20, 50), (20, 60), JEAN_BLACK)
    _paint(img, cm, (60, 100), (25, 55), OFF_WHITE)
    cases.append(
        _case(
            "all_neutral_canvas",
            "D10: negro arriba + blanco abajo -> outfit 100%% neutro, "
            "indice_base global -1 (modo lienzo)",
            img,
            cm,
        )
    )

    # S3 single region: a lower sliver dies in the min-region guard
    # (48 px pre-erosion -> 8 px post-erosion < 0.5% of 8000).
    img, cm = _scene()
    _paint(img, cm, (20, 50), (20, 60), BLUE_SOLID)
    _paint(img, cm, (90, 96), (36, 44), JEAN_GRAY)  # 6x8 sliver
    cases.append(
        _case(
            "single_region_guard",
            "S3: la guarda min-region tira el sliver inferior post-erosion; "
            "sobrevive solo 'upper'",
            img,
            cm,
        )
    )

    # Erosion parity: the outermost 2 px of the garment are painted a LOUD
    # yellow INSIDE the clothes class — without the 5x5 erosion the palette
    # would carry yellow; with it, the palette is pure blue/purple. Neither
    # garment touches the frame edge (cv2's erode border value is +inf, so a
    # frame-edge ring would legitimately survive — a separate behavior both
    # sides share but this case deliberately avoids).
    img, cm = _scene()
    _paint(img, cm, (20, 50), (20, 60), YELLOW_BLEED)  # whole upper garment
    img[22:48, 22:58] = BLUE_SOLID  # interior repainted
    _paint(img, cm, (60, 96), (25, 55), YELLOW_BLEED)  # whole lower garment
    img[62:94, 27:53] = PURPLE_MAIN
    cases.append(
        _case(
            "erosion_excludes_boundary_bleed",
            "paridad de la erosion 5x5: el anillo amarillo de 2 px en el borde de "
            "cada prenda NO aparece en las paletas",
            img,
            cm,
        )
    )

    # NoPerson (coverage): clothes under 1% of the frame.
    img, cm = _scene()
    _paint(img, cm, (50, 55), (38, 48), RED_HOODIE)  # 50 px < 80 (1%)
    cases.append(
        _case(
            "no_person_low_coverage",
            "cobertura de ropa < 1%% -> NoPersonError / SegmentationException "
            "isNoPerson (degrada a foto completa, S4)",
            img,
            cm,
        )
    )

    # NoPerson (guards): coverage passes but 1-px-thin stripes erode to
    # nothing, so no region survives the hygiene guards.
    img, cm = _scene(with_person=False)
    for r in range(20, 90, 4):
        _paint(img, cm, (r, r + 1), (10, 70), RED_HOODIE)
    cases.append(
        _case(
            "no_person_guards_kill_all",
            "la cobertura pasa pero las lineas de 1 px se erosionan a nada -> "
            "ninguna region sobrevive -> isNoPerson",
            img,
            cm,
        )
    )

    data = {
        "nombre": "garment_analysis_F25",
        "descripcion": (
            "analisis por prenda (F2.5, #89): mascara sintetica de clases "
            "MediaPipe + foto sintetica -> split con guardas (erosion 5x5 + "
            "min-region), paleta k=3 por prenda, paleta combinada con pesos "
            "escalados por share y atribucion por swatch, base global (regla "
            "#6 a nivel outfit; -1 = lienzo D10). Generado por la pipeline "
            "canonica analyze_garments."
        ),
        "cases": cases,
    }
    FIXTURES.mkdir(parents=True, exist_ok=True)
    path = FIXTURES / "garment_analysis_F25.json"
    path.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    for c in cases:
        if c.get("espera_no_person"):
            print(f"  {c['nombre']}: NoPersonError (esperado)")
            continue
        e = c["esperado"]
        print(
            f"  {c['nombre']}: regiones {e['regiones_supervivientes']}, "
            f"base_idx {e['indice_base']} ({e['base']}) en "
            f"{e['region_base']}, combinada "
            f"{['#%02X%02X%02X' % tuple(col) for col in e['colores']]} "
            f"{[f'{w:.3f}' for w in e['pesos']]} {e['regiones']}"
        )
    print(f"garment_analysis_F25 -> {path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--real-size",
        action="store_true",
        help="write ONLY the real-size parity fixture (parity_real_size_B2.json) "
        "instead of garment_analysis_F25.json",
    )
    args = parser.parse_args()
    if args.real_size:
        main_real_size()
    else:
        main()
