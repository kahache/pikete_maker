import numpy as np
from PIL import Image

import colorlab.background as bg


def _synthetic_subject(w=240, h=320):
    """Beige background with a centered blue 'subject'."""
    arr = np.full((h, w, 3), (210, 205, 195), dtype=np.uint8)
    arr[80:260, 80:160] = (30, 50, 110)
    return Image.fromarray(arr)


def test_remove_background_returns_image_and_boolean_mask():
    img = _synthetic_subject()
    rgb, mask = bg.remove_background(img)
    assert rgb.shape == (320, 240, 3)
    assert mask.shape == (320, 240)
    assert mask.dtype == bool


def test_grabcut_keeps_centered_subject():
    img = _synthetic_subject()
    _rgb, mask = bg._remove_bg_grabcut(img)
    # the subject's center survives and the cutout removes part of the photo
    assert mask[170, 120]
    assert 0.02 < mask.mean() < 0.95


def _subject_with_beige_center(w=240, h=320):
    """Blue subject filling the frame, but a beige 'hole' at the center that is
    connected to the top background by a beige corridor.

    The center pixel's colour equals the background, so plain GrabCut (rect
    init, no seed) reassigns it to the background: the corridor lets the
    background 'flow' down into it. It is exactly the kind of central region
    the GRABCUT_SEED_FRACTION hard-foreground seed exists to protect (#20/#25).
    """
    beige = (210, 205, 195)
    arr = np.full((h, w, 3), beige, dtype=np.uint8)
    arr[20:300, 20:220] = (30, 50, 110)  # blue subject over the frame
    arr[0:180, 108:132] = beige  # corridor: top bg -> center
    arr[140:180, 96:144] = beige  # beige hole at the center
    return Image.fromarray(arr)


def test_seed_protects_central_subject_grabcut_would_drop(monkeypatch):
    img = _subject_with_beige_center()
    cy, cx = 160, 120  # frame centre

    # No seed (fraction 0 -> empty central box): GrabCut drops the beige centre.
    monkeypatch.setattr(bg, "GRABCUT_SEED_FRACTION", 0.0)
    _, mask_no_seed = bg._remove_bg_grabcut(img)
    assert not mask_no_seed[cy, cx]

    # Default seed: the central box is hard foreground and survives.
    monkeypatch.setattr(bg, "GRABCUT_SEED_FRACTION", 0.10)
    _, mask_seed = bg._remove_bg_grabcut(img)
    assert mask_seed[cy, cx]


def test_grabcut_mask_is_computed_downscaled_but_returned_full_res():
    """#30: a frame larger than GRABCUT_MAX_SIDE has its mask computed on the
    downscaled working image and upscaled back — the returned mask must match
    the FULL resolution (the palette is computed on full-res pixels), and the
    centered subject must still survive at scale."""
    w, h = 900, 1200  # max side 1200 > GRABCUT_MAX_SIDE (400) -> downscale path
    arr = np.full((h, w, 3), (210, 205, 195), dtype=np.uint8)
    arr[300:980, 300:600] = (30, 50, 110)  # centered blue subject
    img = Image.fromarray(arr)

    rgb, mask = bg._remove_bg_grabcut(img)
    assert rgb.shape == (h, w, 3)
    assert mask.shape == (h, w)  # upscaled back to full res, not left at ~400
    assert mask.dtype == bool
    assert mask[640, 450]  # subject centre survives
    assert 0.02 < mask.mean() < 0.95


def test_cascade_degrades_to_full_image(monkeypatch):
    def boom(img):
        raise RuntimeError("dependency unavailable")

    monkeypatch.setattr(bg, "_remove_bg_rembg", boom)
    monkeypatch.setattr(bg, "_remove_bg_grabcut", boom)

    img = _synthetic_subject()
    rgb, mask = bg.remove_background(img)
    assert mask.all()  # no background removal: the whole photo is "foreground"
    assert rgb.shape == (320, 240, 3)
