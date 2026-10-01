"""Synthetic product-photo fixtures for the F2S product-mode eval (D24, QA).

CONTEXT: the repo has NO real product/sneaker photos on a clean background
(everything under samples/ is people-in-outfits: Fashionpedia, g0, selfies,
vuitton). To source a real commercial-safe set is CEO/manual work (see the
"dataset to source" spec in docs/qa/photo-eval/2026-07-10_2200_F2S_*).

Meanwhile this generator writes a handful of CONTROLLED, obviously-synthetic
"product on clean background, no person" images so the reusable harness
(cv_core/tools/mass_battery.py --dir) can be exercised end-to-end on
product-shaped inputs, and so mechanical RISKS can be surfaced before the real
set exists. These are a MECHANICAL FLOOR, NOT a validation of real photos:
flat solid blobs have no texture, shadow, lace, reflection or product gloss.

QA tool, not part of the package. Writes .jpg (the harness only globs jpg/jpeg).

Usage:
    python cv_core/tools/make_product_fixtures.py [--out samples/product-synth]
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

W = H = 600  # square studio-ish canvas


def _canvas(bg: tuple[int, int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (W, H), bg)
    return img, ImageDraw.Draw(img)


def _blob(draw: ImageDraw.ImageDraw, color, box=(150, 150, 450, 450)) -> None:
    draw.rounded_rectangle(box, radius=60, fill=color)


# Each entry: (filename, background, draw-fn). Backgrounds are "clean studio"
# (white / light gray / black) with a single centered product, no skin.
def build(out: Path) -> list[str]:
    out.mkdir(parents=True, exist_ok=True)
    made: list[str] = []

    def save(name: str, img: Image.Image) -> None:
        p = out / name
        img.save(p, "JPEG", quality=92)
        made.append(name)

    # 1. Single chromatic product (red) on white — base should be that red.
    img, d = _canvas((255, 255, 255))
    _blob(d, (200, 30, 40))
    save("prod-01-red-on-white.jpg", img)

    # 2. Royal blue product on light gray.
    img, d = _canvas((235, 235, 238))
    _blob(d, (30, 60, 170))
    save("prod-02-blue-on-gray.jpg", img)

    # 3. Multicolor product (3 panels) on white — palette must catch all 3,
    #    zero background swatches.
    img, d = _canvas((255, 255, 255))
    d.rounded_rectangle((150, 150, 450, 450), radius=60, fill=(200, 30, 40))
    d.rectangle((150, 250, 450, 350), fill=(30, 90, 190))
    d.rectangle((250, 150, 350, 450), fill=(240, 200, 40))
    save("prod-03-multicolor-on-white.jpg", img)

    # 4. Total-black product on white — neutral; canvas mode (D10) is CORRECT.
    img, d = _canvas((255, 255, 255))
    _blob(d, (15, 15, 18))
    save("prod-04-black-on-white.jpg", img)

    # 5. White/off-white product on medium gray — neutral product.
    img, d = _canvas((150, 150, 150))
    _blob(d, (238, 236, 232))
    save("prod-05-white-on-gray.jpg", img)

    # 6. BEIGE/tan product on white — SKIN-FILTER RISK (YCbCr may strip it).
    img, d = _canvas((255, 255, 255))
    _blob(d, (214, 184, 150))
    save("prod-06-beige-on-white.jpg", img)

    # 7. BROWN leather-ish product on white — skin-filter risk.
    img, d = _canvas((250, 250, 250))
    _blob(d, (120, 78, 50))
    save("prod-07-brown-on-white.jpg", img)

    # 8. Green product on BLACK studio bg — clean but dark background.
    img, d = _canvas((10, 10, 10))
    _blob(d, (40, 160, 70))
    save("prod-08-green-on-black.jpg", img)

    # 9. Pastel multi colorway (sneaker-like) on white.
    img, d = _canvas((252, 252, 252))
    d.rounded_rectangle((150, 220, 450, 400), radius=50, fill=(180, 205, 235))  # body
    d.rectangle((150, 360, 450, 400), fill=(235, 235, 235))  # sole
    d.rectangle((300, 240, 360, 380), fill=(230, 120, 90))  # accent
    save("prod-09-pastel-multi-on-white.jpg", img)

    return made


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "samples" / "product-synth",
        help="output folder for the synthetic fixtures",
    )
    args = ap.parse_args()
    made = build(args.out)
    print(f"Wrote {len(made)} synthetic product fixtures to {args.out}")
    for m in made:
        print("  ", m)


if __name__ == "__main__":
    main()
