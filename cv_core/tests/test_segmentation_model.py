"""Real-model parity pin (slow): Python masks == on-device spike masks.

Runs actual MediaPipe Selfie Multiclass inference through ai-edge-litert on
``samples/vuitton2006lr.jpg`` and pins the class coverage the on-device Dart
spike measured (2026-07-14 spike report §4, identical on the x86_64 emulator
and the Galaxy M33). If this moves, the Python pre/post contract has drifted
from the Dart one and masks are no longer interchangeable.

Skipped automatically when the optional ``seg`` extra is not installed or the
gitignored model asset has not been fetched (``bash app/tool/fetch_models.sh``).
"""

from pathlib import Path

import numpy as np
import pytest
from PIL import Image, ImageOps

from colorlab.segmentation import (
    CLASS_BACKGROUND,
    CLASS_CLOTHES,
    NUM_CLASSES,
    REGION_LOWER,
    REGION_UPPER,
    split_garment_masks,
)

litert = pytest.importorskip("ai_edge_litert.interpreter")

REPO_ROOT = Path(__file__).resolve().parents[2]
MODEL = REPO_ROOT / "app" / "assets" / "models" / "selfie_multiclass_256x256.tflite"
PHOTO = REPO_ROOT / "samples" / "vuitton2006lr.jpg"

pytestmark = [
    pytest.mark.slow,
    pytest.mark.skipif(
        not MODEL.exists(), reason="model not fetched (app/tool/fetch_models.sh)"
    ),
    pytest.mark.skipif(not PHOTO.exists(), reason="reference photo missing"),
]

# Spike report §4 (and ADDENDUM: identical on ARM): per-class coverage on
# vuitton2006lr at 721x1080, rounded to 0.1%.
SPIKE_COVERAGE = {
    CLASS_BACKGROUND: 0.745,
    CLASS_CLOTHES: 0.195,
}
# Region means the Dart harness reported (upper #D74085, lower #DC2F7F);
# tolerance 2/255 per channel covers the harness' rounding convention.
SPIKE_UPPER_MEAN = (0xD7, 0x40, 0x85)
SPIKE_LOWER_MEAN = (0xDC, 0x2F, 0x7F)
MEAN_TOL = 2.0


def test_python_masks_match_on_device_spike():
    import sys

    sys.path.insert(0, str(REPO_ROOT / "cv_core" / "tools"))
    from generate_masks import _load_interpreter, classify_image

    rgb = np.asarray(ImageOps.exif_transpose(Image.open(PHOTO)).convert("RGB"))
    interpreter = _load_interpreter(MODEL)
    class_map = classify_image(interpreter, rgb)

    counts = np.bincount(class_map.ravel(), minlength=NUM_CLASSES)
    for cls, expected in SPIKE_COVERAGE.items():
        coverage = counts[cls] / class_map.size
        assert coverage == pytest.approx(expected, abs=0.001), (
            f"class {cls} coverage {coverage:.3%} drifted from spike {expected:.1%}"
        )

    masks = split_garment_masks(class_map, erode_px=0)  # spike measured uneroded
    assert not (masks[REGION_UPPER] & masks[REGION_LOWER]).any()
    for region, expected in (
        (REGION_UPPER, SPIKE_UPPER_MEAN),
        (REGION_LOWER, SPIKE_LOWER_MEAN),
    ):
        mean = rgb[masks[region]].mean(axis=0)
        assert np.abs(mean - np.array(expected)).max() <= MEAN_TOL, (
            f"{region} mean {mean} drifted from spike {expected}"
        )
