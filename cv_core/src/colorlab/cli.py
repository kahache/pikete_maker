"""colorlab CLI: outfit photo -> palette + harmonies in a PNG panel.

Usage:
  colorlab path/to/photo.jpg
  colorlab photo.jpg --colors 5 --no-bg --keep-skin -o result.png
  colorlab sneaker.jpg --product-mode        # clean-background product/object
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import numpy as np

from colorlab.display import snap_neutral_for_display
from colorlab.harmony import as_rgb, canvas_accents, harmonies, hexstr, is_neutral
from colorlab.image_io import load_image
from colorlab.palette import DEFAULT_COLORS
from colorlab.pipeline import analyze_palette
from colorlab.render import render_panel


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Palette + harmonies from an outfit photo."
    )
    ap.add_argument("image", help="path to the photo")
    ap.add_argument(
        "--colors",
        "-c",
        type=int,
        default=DEFAULT_COLORS,
        help=f"number of dominant colors (default {DEFAULT_COLORS})",
    )
    ap.add_argument(
        "--no-bg", action="store_true", help="do not try to remove the background"
    )
    ap.add_argument(
        "--keep-skin", action="store_true", help="do not filter the skin tone"
    )
    ap.add_argument(
        "--product-mode",
        action="store_true",
        help="clean-background product/object photo (D24, feature F11): "
        "run only the core, skipping the person background-removal "
        "and the skin filter (both irrelevant/harmful there)",
    )
    ap.add_argument(
        "--avoid-border-bg",
        action="store_true",
        help="demote wall/floor border colors from leading the harmonies "
        "(optional two-color background model, issue #48)",
    )
    ap.add_argument("-o", "--out", default=None, help="output PNG path")
    args = ap.parse_args()

    logging.basicConfig(level=logging.INFO, format="  [%(levelname)s] %(message)s")

    image_path = Path(args.image)
    if not image_path.exists():
        sys.exit(f"File not found: {image_path}")
    out = (
        Path(args.out)
        if args.out
        else image_path.with_name(image_path.stem + "_palette.png")
    )

    print("Loading image...")
    img = load_image(image_path)

    mode = "product mode (D24)" if args.product_mode else "outfit mode"
    print(f"Analyzing ({mode})...")
    analysis = analyze_palette(
        img,
        n_colors=args.colors,
        product_mode=args.product_mode,
        remove_bg=not args.no_bg,
        drop_skin=not args.keep_skin,
        avoid_border_bg=args.avoid_border_bg,
    )
    colors, weights, base = analysis.colors, analysis.weights, analysis.base
    # -1 = no chromatic color may lead the harmonies (100% neutral outfit):
    # canvas mode (D10). Rotating a hue over the dominant neutral would give
    # meaningless proposals (bug B3) — the Dart engine never did that.
    canvas_mode = analysis.base_index < 0

    print("\nDetected palette:")
    for i, (row, w) in enumerate(zip(colors, weights, strict=True)):
        c = as_rgb(row)
        tags = []
        if is_neutral(c):
            tags.append("neutral")
        if i == analysis.base_index:
            tags.append("harmony BASE")
        # Display snap (issue #85, D31-A) is product-mode presentation only:
        # the analysis above ran on the raw color.
        if args.product_mode:
            shown = snap_neutral_for_display(c)
            if shown != c:
                tags.append(f"shown as {hexstr(shown)}")
        suffix = ("  <- " + ", ".join(tags)) if tags else ""
        print(f"  {hexstr(c)}   {w * 100:5.1f}%{suffix}")

    if canvas_mode:
        print("\nNeutral canvas (D10): no chromatic base -> curated accent pops")
        schemes = {"Canvas (D10)": canvas_accents()}
    else:
        schemes = harmonies(base)
    render_panel(
        np.asarray(img),
        colors,
        weights,
        schemes,
        out,
        snap_display_neutrals=args.product_mode,
    )
    print(f"\nResult saved to: {out}")


if __name__ == "__main__":
    main()
