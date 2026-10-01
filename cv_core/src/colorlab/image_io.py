"""Loading and normalizing input images."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

# Maximum side after rescaling: enough color detail, fast K-means.
MAX_SIDE = 600


def load_image(path: str | Path, max_side: int = MAX_SIDE) -> Image.Image:
    """Loads an image as RGB, rescaled so its longest side is <= max_side."""
    img = Image.open(path).convert("RGB")
    w, h = img.size
    scale = max_side / max(w, h)
    if scale < 1:
        # Truncation (int) is the historical rounding the golden fixtures were
        # generated with — keep it. The clamp only guards an extreme aspect
        # ratio (a 4000x5 strip) whose short side would truncate to 0 px and
        # make Pillow raise (review F16).
        img = img.resize((max(1, int(w * scale)), max(1, int(h * scale))))
    return img
