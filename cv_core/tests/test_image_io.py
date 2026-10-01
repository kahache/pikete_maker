import numpy as np
from PIL import Image

from colorlab.image_io import load_image


def _save_tmp(tmp_path, size, name="img.png"):
    path = tmp_path / name
    Image.fromarray(np.zeros((size[1], size[0], 3), dtype=np.uint8)).save(path)
    return path


def test_large_image_is_downscaled(tmp_path):
    path = _save_tmp(tmp_path, (1200, 1800))
    img = load_image(path, max_side=600)
    assert max(img.size) == 600
    # keeps the aspect ratio
    assert img.size[0] / img.size[1] == 1200 / 1800


def test_small_image_is_untouched(tmp_path):
    path = _save_tmp(tmp_path, (300, 200))
    img = load_image(path, max_side=600)
    assert img.size == (300, 200)


def test_output_is_rgb(tmp_path):
    path = tmp_path / "gray.png"
    Image.new("L", (50, 50), 128).save(path)  # grayscale image
    img = load_image(path)
    assert img.mode == "RGB"


def test_extreme_aspect_ratio_keeps_at_least_one_pixel(tmp_path):
    # F16: a 4000x5 strip used to truncate the short side to 0 px (Pillow error).
    path = _save_tmp(tmp_path, (4000, 5))
    img = load_image(path, max_side=600)
    assert img.size == (600, 1)
