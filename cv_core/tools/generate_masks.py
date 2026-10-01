"""Generates per-pixel class masks (Phase 2.5 contract PNGs) for photos.

Runs MediaPipe Selfie Multiclass (D21) through the `ai-edge-litert` runtime —
the ONLY TFLite runtime with a Python 3.14 / Windows wheel as of 2026-07-14
(tflite-runtime and full tensorflow have none; see the F2.5 canonical-layer
ADR). Install it with the ``seg`` extra:

    pip install -e "cv_core[seg]"

The model file is the same asset the app bundles (16.37 MB, Apache-2.0,
gitignored): fetch it once per machine with ``bash app/tool/fetch_models.sh``.

Pre/post-processing is NOT reimplemented here: it imports the canonical
Dart-parity helpers from :mod:`colorlab.segmentation`, so a mask written by
this tool is byte-compatible with one produced on-device.

Usage:
    python cv_core/tools/generate_masks.py PHOTO [PHOTO ...] [-o OUT_DIR]

Writes ``<photo_stem>.mask.png`` (grayscale class-id PNG, the QA hand-off
format) next to each photo, or into OUT_DIR. Prints one summary line per
photo (this is a tool, not the library — printing is allowed).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

from colorlab.segmentation import (
    MODEL_SIDE,
    NUM_CLASSES,
    class_map_from_scores,
    preprocess_rgb,
    save_class_mask,
    upscale_class_map,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL = (
    REPO_ROOT / "app" / "assets" / "models" / "selfie_multiclass_256x256.tflite"
)

CLASS_NAMES = ("background", "hair", "body-skin", "face-skin", "clothes", "others")


def _load_interpreter(model_path: Path):
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        sys.exit('ai-edge-litert is not installed. Run: pip install -e "cv_core[seg]"')
    if not model_path.exists():
        sys.exit(
            f"model not found: {model_path}\n"
            "Fetch it once per machine: bash app/tool/fetch_models.sh"
        )
    interpreter = Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    in_shape = tuple(interpreter.get_input_details()[0]["shape"])
    out_shape = tuple(interpreter.get_output_details()[0]["shape"])
    expected_in = (1, MODEL_SIDE, MODEL_SIDE, 3)
    expected_out = (1, MODEL_SIDE, MODEL_SIDE, NUM_CLASSES)
    if in_shape != expected_in or out_shape != expected_out:
        sys.exit(f"unexpected model tensors (in {in_shape}, out {out_shape})")
    return interpreter


def classify_image(interpreter, rgb: np.ndarray) -> np.ndarray:
    """RGB uint8 [H, W, 3] -> full-res uint8 class map (Dart-parity path)."""
    inp = preprocess_rgb(rgb)[None, ...]
    in_idx = interpreter.get_input_details()[0]["index"]
    out_idx = interpreter.get_output_details()[0]["index"]
    interpreter.set_tensor(in_idx, inp)
    interpreter.invoke()
    scores = interpreter.get_tensor(out_idx)[0]
    map256 = class_map_from_scores(scores)
    return upscale_class_map(map256, rgb.shape[1], rgb.shape[0])


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("photos", nargs="+", help="input photos")
    parser.add_argument(
        "-o", "--out-dir", help="output dir (default: next to each photo)"
    )
    parser.add_argument(
        "--model", default=str(DEFAULT_MODEL), help="path to the .tflite model"
    )
    args = parser.parse_args(argv)

    interpreter = _load_interpreter(Path(args.model))
    out_dir = Path(args.out_dir) if args.out_dir else None
    if out_dir:
        out_dir.mkdir(parents=True, exist_ok=True)

    for photo in args.photos:
        src = Path(photo)
        # EXIF-transpose like colorlab.image_io.load_image, so mask == photo frame.
        img = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
        rgb = np.asarray(img)
        class_map = classify_image(interpreter, rgb)
        dest_dir = out_dir if out_dir else src.parent
        dest = dest_dir / f"{src.stem}.mask.png"
        save_class_mask(class_map, str(dest))
        counts = np.bincount(class_map.ravel(), minlength=NUM_CLASSES)
        coverage = ", ".join(
            f"{name} {c / class_map.size:.1%}"
            for name, c in zip(CLASS_NAMES, counts, strict=True)
            if c
        )
        print(f"{src.name} -> {dest}  [{coverage}]")


if __name__ == "__main__":
    main()
