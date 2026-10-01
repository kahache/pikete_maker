"""Golden fixtures for the Dart port of the I2 recolor engine (D38, pass 1).

Writes ONLY ``app/test/core/fixtures/recolor_parity_I2.json`` and touches no
other fixture, so the frozen palette / garment / product fixtures stay
byte-for-byte identical.

Every reference value is produced by the CANONICAL Python:

- ``colorlab.segmentation`` — the I2 condition C1 mask hardening
  (:func:`resample_class_map_smooth`, :func:`fill_clothes_holes`,
  :func:`drop_detached_clothes`, :func:`hip_split_row`,
  :func:`harden_class_map`, :func:`split_garment_masks` with ``harden=``)
  and :func:`check_applicability`;
- ``colorlab.recolor`` — :func:`recolor_region` and its OpenCV float LAB.

SYNTHETIC SCENES ONLY (no real photo, no model): ``app/test/**`` is exported
to the public repo. Scenes are drawn with integer rectangles/ellipses and a
seeded texture, so the generator is deterministic.

Payload: class maps and 0/1 masks as grayscale PNG base64, photos and
recolored outputs as RGB PNG base64 (lossless; a channel checksum proves the
transport). The Dart parity test is
``app/test/core/recolor/recolor_parity_test.dart``.

Usage (from the repo root):
    .venv/Scripts/python.exe cv_core/tools/gen_recolor_fixtures_dart.py
"""

from __future__ import annotations

import base64
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image

from colorlab.recolor import lab_f32_to_rgb, recolor_region, rgb_to_lab_f32
from colorlab.segmentation import (
    CLASS_BACKGROUND,
    CLASS_BODY_SKIN,
    CLASS_CLOTHES,
    CLASS_FACE_SKIN,
    CLASS_HAIR,
    CLASS_OTHERS,
    DEFAULT_HARDENING,
    RECOLOR_HARDENING,
    REGION_LOWER,
    REGION_UPPER,
    NoPersonError,
    check_applicability,
    drop_detached_clothes,
    fill_clothes_holes,
    harden_class_map,
    hip_split_row,
    resample_class_map_smooth,
    split_garment_masks,
)

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "app" / "test" / "core" / "fixtures" / "recolor_parity_I2.json"

SEED = 20260930

# Scene frame for the hardening / applicability cases (W x H).
SCENE_W = 96
SCENE_H = 128

# Recolor photo frame (W x H).
PHOTO_W = 64
PHOTO_H = 80

WALL = (196, 190, 180)
SKIN = (205, 160, 125)
HAIR = (60, 45, 35)
TROUSERS = (60, 70, 95)


# --------------------------------------------------------------------------
# Encoding helpers
# --------------------------------------------------------------------------


def _png_b64(array: np.ndarray) -> str:
    buf = io.BytesIO()
    Image.fromarray(np.ascontiguousarray(array)).save(buf, format="PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode("ascii")


def _map_payload(class_map: np.ndarray) -> dict:
    class_map = np.asarray(class_map, dtype=np.uint8)
    return {
        "width": int(class_map.shape[1]),
        "height": int(class_map.shape[0]),
        "png": _png_b64(class_map),
        "sum": int(class_map.astype(np.int64).sum()),
    }


def _mask_payload(mask: np.ndarray) -> dict:
    mask = np.asarray(mask, dtype=bool)
    return {
        "png": _png_b64(mask.astype(np.uint8)),
        "count": int(mask.sum()),
    }


def _rgb_payload(rgb: np.ndarray) -> dict:
    rgb = np.asarray(rgb, dtype=np.uint8)
    return {
        "width": int(rgb.shape[1]),
        "height": int(rgb.shape[0]),
        "png": _png_b64(rgb),
        "sums": [int(rgb[..., c].astype(np.int64).sum()) for c in range(3)],
    }


# --------------------------------------------------------------------------
# Scene drawing (class map + a matching photo)
# --------------------------------------------------------------------------


class Scene:
    def __init__(self, w: int = SCENE_W, h: int = SCENE_H, wall=WALL) -> None:
        self.map = np.full((h, w), CLASS_BACKGROUND, dtype=np.uint8)
        self.rgb = np.empty((h, w, 3), dtype=np.uint8)
        self.rgb[:] = wall

    def rect(self, y0: int, y1: int, x0: int, x1: int, cls: int, color) -> None:
        self.map[y0:y1, x0:x1] = cls
        self.rgb[y0:y1, x0:x1] = color

    def rows(self, y0: int, widths: list[int], cx: int, cls: int, color) -> None:
        """One centred run of ``widths[i]`` px per row starting at ``y0``."""
        for i, width in enumerate(widths):
            x0 = cx - width // 2
            self.rect(y0 + i, y0 + i + 1, x0, x0 + width, cls, color)

    def person(
        self, cx: int, top: int = 4, scale: float = 1.0, upper=(170, 40, 50)
    ) -> None:
        def s(v: float) -> int:
            return max(1, round(v * scale))

        self.rect(top, top + s(10), cx - s(10), cx + s(10), CLASS_HAIR, HAIR)
        self.rect(top + s(10), top + s(26), cx - s(8), cx + s(8), CLASS_FACE_SKIN, SKIN)
        self.rect(top + s(26), top + s(30), cx - s(4), cx + s(4), CLASS_BODY_SKIN, SKIN)
        self.rect(
            top + s(30), top + s(66), cx - s(20), cx + s(20), CLASS_CLOTHES, upper
        )
        self.rect(
            top + s(66), top + s(116), cx - s(16), cx + s(16), CLASS_CLOTHES, TROUSERS
        )


def _texture(rng: np.random.Generator, h: int, w: int, amp: float) -> np.ndarray:
    return rng.normal(0.0, amp, size=(h, w, 1))


# --------------------------------------------------------------------------
# Section 1 — smoothed resample
# --------------------------------------------------------------------------


def _blob_map(side_w: int, side_h: int) -> np.ndarray:
    """A small person-like class map with diagonal / curved contours."""
    yy, xx = np.mgrid[0:side_h, 0:side_w]
    cm = np.full((side_h, side_w), CLASS_BACKGROUND, dtype=np.uint8)
    cx = side_w / 2
    head = ((xx - cx) / (0.14 * side_w)) ** 2 + (
        (yy - 0.18 * side_h) / (0.1 * side_h)
    ) ** 2 <= 1
    hair = head & (yy < 0.14 * side_h)
    torso = (
        (np.abs(xx - cx) <= 0.28 * side_w - 0.1 * (yy - 0.3 * side_h))
        & (yy >= 0.3 * side_h)
        & (yy < 0.62 * side_h)
    )
    legs = (
        (np.abs(xx - cx) <= 0.2 * side_w) & (yy >= 0.62 * side_h) & (yy < 0.95 * side_h)
    )
    arm = (
        (np.abs(xx - (cx + 0.3 * side_w) - 0.2 * (yy - 0.3 * side_h)) <= 0.05 * side_w)
        & (yy >= 0.3 * side_h)
        & (yy < 0.6 * side_h)
    )
    bag = ((xx - 0.15 * side_w) ** 2 + (yy - 0.7 * side_h) ** 2) <= (0.07 * side_w) ** 2
    cm[torso | legs] = CLASS_CLOTHES
    cm[arm] = CLASS_BODY_SKIN
    cm[head] = CLASS_FACE_SKIN
    cm[hair] = CLASS_HAIR
    cm[bag] = CLASS_OTHERS
    return cm


def resample_cases() -> list[dict]:
    cases = []
    for name, (sw, sh), (tw, th) in (
        ("up_nonint_32_to_90x120", (32, 32), (90, 120)),
        ("same_size_sigma_only_48x64", (48, 64), (48, 64)),
        ("model_256_to_384x512", (256, 256), (384, 512)),
    ):
        src = _blob_map(sw, sh)
        out = resample_class_map_smooth(src, tw, th)
        cases.append(
            {
                "name": name,
                "input": _map_payload(src),
                "target_width": tw,
                "target_height": th,
                "expected": _map_payload(out),
            }
        )
    return cases


# --------------------------------------------------------------------------
# Section 2 — hardening + split
# --------------------------------------------------------------------------


def _scene_holes() -> Scene:
    sc = Scene()
    sc.person(48)
    sc.rect(44, 48, 36, 40, CLASS_BACKGROUND, WALL)  # small bg hole -> filled
    sc.rect(50, 56, 52, 58, CLASS_BODY_SKIN, SKIN)  # a hand -> kept
    sc.rect(90, 95, 42, 48, CLASS_FACE_SKIN, SKIN)  # face-only island -> filled
    sc.rect(58, 62, 30, 34, CLASS_BODY_SKIN, SKIN)  # mixed hole: skin kept,
    sc.rect(58, 62, 34, 37, CLASS_OTHERS, (20, 20, 20))  # its others filled
    sc.rect(76, 90, 52, 62, CLASS_BACKGROUND, WALL)  # large hole -> kept open
    return sc


def _scene_detached() -> Scene:
    sc = Scene()
    sc.person(40)
    sc.rect(30, 70, 76, 92, CLASS_CLOTHES, (40, 150, 90))  # coat on a hook
    sc.rect(10, 13, 70, 73, CLASS_CLOTHES, (40, 150, 90))  # speckle
    sc.rect(80, 100, 66, 80, CLASS_CLOTHES, (150, 110, 60))  # bag body
    sc.rect(80, 82, 56, 66, CLASS_OTHERS, (20, 20, 20))  # strap to the person
    return sc


def _scene_waist() -> Scene:
    sc = Scene()
    sc.rect(4, 14, 38, 58, CLASS_HAIR, HAIR)
    sc.rect(14, 30, 40, 56, CLASS_FACE_SKIN, SKIN)
    sc.rect(30, 34, 44, 52, CLASS_BODY_SKIN, SKIN)
    widths = [40] * 22 + [36, 32, 28, 24, 22, 22, 22, 24, 28, 32] + [38] * 44
    sc.rows(34, widths, 48, CLASS_CLOTHES, (170, 40, 50))
    return sc


def _scene_no_waist() -> Scene:
    sc = Scene()
    sc.person(48)
    return sc


def _scene_grow() -> Scene:
    sc = Scene()
    sc.person(48)
    # Arms of body skin flush with the torso: the growth must not cover them.
    sc.rect(36, 60, 22, 28, CLASS_BODY_SKIN, SKIN)
    sc.rect(36, 60, 68, 74, CLASS_OTHERS, (20, 20, 20))
    return sc


def _scene_waist_up() -> Scene:
    sc = Scene()
    sc.rect(10, 30, 36, 60, CLASS_HAIR, HAIR)
    sc.rect(30, 60, 38, 58, CLASS_FACE_SKIN, SKIN)
    sc.rect(60, 68, 42, 54, CLASS_BODY_SKIN, SKIN)
    sc.rect(68, 128, 14, 82, CLASS_CLOTHES, (170, 40, 50))
    return sc


HARDEN_SCENES = {
    "holes": _scene_holes,
    "detached": _scene_detached,
    "waist": _scene_waist,
    "no_waist": _scene_no_waist,
    "grow": _scene_grow,
    "waist_up": _scene_waist_up,
}


def _regions_payload(class_map: np.ndarray, **kwargs) -> dict:
    try:
        regions = split_garment_masks(class_map, **kwargs)
    except NoPersonError:
        return {"no_person": True}
    return {
        "no_person": False,
        "regions": {name: _mask_payload(mask) for name, mask in regions.items()},
    }


def harden_cases() -> list[dict]:
    cases = []
    for name, build in HARDEN_SCENES.items():
        cm = build().map
        clothes = cm == CLASS_CLOTHES
        filled = fill_clothes_holes(cm)
        kept = drop_detached_clothes(cm)
        default_map = harden_class_map(cm, DEFAULT_HARDENING)
        recolor_map = harden_class_map(cm, RECOLOR_HARDENING)
        row, from_waist = hip_split_row(recolor_map == CLASS_CLOTHES)
        raw_row, raw_from_waist = hip_split_row(clothes)
        cases.append(
            {
                "name": name,
                "input": _map_payload(cm),
                "fill_clothes_holes": _mask_payload(filled),
                "drop_detached_clothes": _mask_payload(kept),
                "harden_default": _map_payload(default_map),
                "harden_recolor": _map_payload(recolor_map),
                "hip_split_raw": {"row": raw_row, "from_waist": raw_from_waist},
                "hip_split_recolor": {"row": row, "from_waist": from_waist},
                # The recolor regions: un-eroded, hardened, hip-split.
                "split_recolor": _regions_payload(
                    cm, erode_px=0, harden=RECOLOR_HARDENING
                ),
                # The analysis regions of analyze_garments(harden=RECOLOR_HARDENING)
                # (C1c): same hardening, default erosion + min-region guard.
                "split_recolor_eroded": _regions_payload(cm, harden=RECOLOR_HARDENING),
            }
        )
    return cases


# --------------------------------------------------------------------------
# Section 3 — applicability
# --------------------------------------------------------------------------


def _textured(sc: Scene, rng: np.random.Generator, amp: float = 3.0) -> np.ndarray:
    noisy = sc.rgb.astype(np.float64) + _texture(rng, *sc.rgb.shape[:2], amp)
    return np.clip(np.rint(noisy), 0, 255).astype(np.uint8)


def _scale_rgb(rgb: np.ndarray, factor: float) -> np.ndarray:
    return np.clip(np.rint(rgb.astype(np.float64) * factor), 0, 255).astype(np.uint8)


def applicability_cases() -> list[dict]:
    rng = np.random.default_rng(SEED)
    scenes: list[tuple[str, Scene, float]] = []

    ok = Scene()
    ok.person(48)
    scenes.append(("ok", ok, 1.0))

    two = Scene()
    two.person(28, scale=0.95)
    two.person(76, top=40, scale=0.7, upper=(40, 90, 170))
    scenes.append(("several_people", two, 1.0))

    dark = Scene()
    dark.person(48)
    scenes.append(("poor_light_dark_frame", dark, 0.12))

    dim = Scene(wall=(70, 66, 62))
    dim.person(48, upper=(60, 20, 25))
    scenes.append(("poor_light_dim_person", dim, 0.75))

    cheese = Scene()
    cheese.person(48)
    for y in range(38, 116, 7):
        for x in range(36, 62, 6):
            cheese.rect(y, y + 3, x, x + 3, CLASS_BACKGROUND, WALL)
    scenes.append(("mask_unreliable_holes", cheese, 1.0))

    tiny = Scene()
    tiny.rect(40, 44, 44, 52, CLASS_HAIR, HAIR)
    tiny.rect(44, 50, 45, 51, CLASS_FACE_SKIN, SKIN)
    tiny.rect(50, 62, 42, 54, CLASS_CLOTHES, (170, 40, 50))
    tiny.rect(62, 72, 43, 53, CLASS_CLOTHES, TROUSERS)
    scenes.append(("region_too_small_all", tiny, 1.0))

    # A narrow top flanked by bare arms (the growth cannot widen it) over wide
    # trousers: the upper region exists (> 0.5 %) but is under the 2 % bar.
    one_small = Scene()
    one_small.rect(20, 28, 43, 53, CLASS_HAIR, HAIR)
    one_small.rect(28, 36, 44, 52, CLASS_FACE_SKIN, SKIN)
    one_small.rect(36, 40, 46, 50, CLASS_BODY_SKIN, SKIN)
    one_small.rect(40, 60, 37, 59, CLASS_BODY_SKIN, SKIN)
    one_small.rect(40, 60, 43, 53, CLASS_CLOTHES, (170, 40, 50))
    one_small.rect(60, 80, 33, 63, CLASS_CLOTHES, TROUSERS)
    scenes.append(("region_too_small_upper_only", one_small, 1.0))

    cases = []
    for name, sc, exposure in scenes:
        rgb = _scale_rgb(_textured(sc, rng), exposure)
        try:
            regions = split_garment_masks(sc.map, erode_px=0, harden=RECOLOR_HARDENING)
        except NoPersonError:
            regions = {}
        result = check_applicability(sc.map, rgb, regions)
        cases.append(
            {
                "name": name,
                "class_map": _map_payload(sc.map),
                "rgb": _rgb_payload(rgb),
                "region_names": list(regions),
                "reason": result.reason,
                "regions": result.regions,
                "metrics": {k: float(v) for k, v in result.metrics.items()},
            }
        )
    return cases


# --------------------------------------------------------------------------
# Section 4 — recolor
# --------------------------------------------------------------------------

GARMENTS = {
    "red": (178, 42, 52),
    "black": (30, 30, 34),
    "blue": (40, 72, 160),
    "white": (234, 233, 228),
}


def _recolor_photo(
    garment_rgb, rng: np.random.Generator
) -> tuple[np.ndarray, np.ndarray]:
    """A textured garment on a wall, with a logo of another colour."""
    h, w = PHOTO_H, PHOTO_W
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    rgb = np.empty((h, w, 3), dtype=np.float64)
    rgb[:] = WALL
    rgb[4:18, 24:40] = SKIN
    garment = np.zeros((h, w), dtype=bool)
    garment[18:76, 12:52] = True
    garment[18:40, 6:12] = True  # a sleeve
    shade = 0.78 + 0.22 * np.sin(xx / 3.5) * np.cos(yy / 6.0)
    base = np.asarray(garment_rgb, dtype=np.float64)
    rgb[garment] = (base[None, :] * shade[garment][:, None]).clip(0, 255)
    logo = np.zeros_like(garment)
    logo[30:38, 26:38] = True
    logo_color = (245, 215, 40) if np.mean(garment_rgb) < 128 else (20, 20, 25)
    rgb[logo] = logo_color
    rgb += _texture(rng, h, w, 2.5)
    return np.clip(np.rint(rgb), 0, 255).astype(np.uint8), garment


RECOLOR_CASES = [
    # name, garment, target, source (None = region mean), kwargs
    ("hue_red_to_teal", "red", (38, 160, 150), "red", {}),
    ("hue_red_to_teal_mean_source", "red", (38, 160, 150), None, {}),
    ("inject_black_to_mustard", "black", (212, 170, 42), "black", {}),
    ("collapse_blue_to_beige", "blue", (200, 194, 184), "blue", {}),
    ("inject_white_to_cobalt", "white", (42, 82, 200), "white", {}),
    (
        "hue_red_to_teal_nonselective",
        "red",
        (38, 160, 150),
        "red",
        {"selective": False},
    ),
    (
        "hue_red_to_teal_feather0_shift03",
        "red",
        (38, 160, 150),
        "red",
        {"feather_px": 0, "lightness_shift": 0.3},
    ),
]


def recolor_section() -> dict:
    rng = np.random.default_rng(SEED + 1)
    photos = {}
    mask = None
    for name, colour in GARMENTS.items():
        rgb, mask = _recolor_photo(colour, rng)
        photos[name] = rgb
    assert mask is not None
    cases = []
    for name, garment, target, source, kwargs in RECOLOR_CASES:
        source_rgb = GARMENTS[source] if source else None
        out = recolor_region(
            photos[garment], mask, target, source_rgb=source_rgb, **kwargs
        )
        cases.append(
            {
                "name": name,
                "photo": garment,
                "target": list(target),
                "source": list(source_rgb) if source_rgb else None,
                "feather_px": kwargs.get("feather_px"),
                "lightness_shift": kwargs.get("lightness_shift"),
                "selective": kwargs.get("selective", True),
                "expected": _rgb_payload(out),
            }
        )
    return {
        "mask": _mask_payload(mask),
        "photos": {name: _rgb_payload(rgb) for name, rgb in photos.items()},
        "cases": cases,
    }


# --------------------------------------------------------------------------
# Section 5 — LAB probes (diagnostics for the colour conversion)
# --------------------------------------------------------------------------


def lab_probes() -> dict:
    rng = np.random.default_rng(SEED + 2)
    rgb = rng.integers(0, 256, size=(64, 3), dtype=np.uint8)
    rgb = np.concatenate(
        [
            rgb,
            np.array(
                [[0, 0, 0], [255, 255, 255], [1, 1, 1], [128, 128, 128]], np.uint8
            ),
        ]
    )
    lab = rgb_to_lab_f32(rgb[None, :, :])[0]
    lab_in = np.stack(
        [
            rng.uniform(0, 100, 64),
            rng.uniform(-100, 100, 64),
            rng.uniform(-100, 100, 64),
        ],
        axis=-1,
    ).astype(np.float32)
    rgb_out = lab_f32_to_rgb(lab_in[None, :, :])[0]
    return {
        "rgb_to_lab": {
            "rgb": rgb.tolist(),
            "lab": [[float(v) for v in row] for row in lab],
        },
        "lab_to_rgb": {
            "lab": [[float(v) for v in row] for row in lab_in],
            "rgb": rgb_out.tolist(),
        },
    }


def main() -> int:
    payload = {
        "_comment": (
            "GENERATED by cv_core/tools/gen_recolor_fixtures_dart.py from the "
            "canonical colorlab (segmentation C1 hardening + applicability, "
            "recolor.recolor_region). Synthetic scenes only. Do not edit."
        ),
        "regions": [REGION_UPPER, REGION_LOWER],
        "resample": resample_cases(),
        "harden": harden_cases(),
        "applicability": applicability_cases(),
        "recolor": recolor_section(),
        "lab": lab_probes(),
    }
    OUT.write_text(json.dumps(payload, indent=1) + "\n", encoding="utf-8")
    size_kb = OUT.stat().st_size / 1024
    print(f"wrote {OUT.relative_to(REPO)} ({size_kb:.0f} KB)")
    for case in payload["applicability"]:
        print(f"  applicability {case['name']}: {case['reason']} {case['regions']}")
    for case in payload["harden"]:
        print(
            f"  harden {case['name']}: split {case['hip_split_recolor']} "
            f"regions {list(case['split_recolor'].get('regions', {}))}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
