"""Validation of the adaptive skin filter (issue #20) over the G0 battery.

Does NOT re-evaluate the G0 gate (that is #23, with K-means and palette
judgment): here we check ROBUST invariants of the filter over real photos,
independent of K-means (whose output would vary across sklearn/opencv
versions). GrabCut is seeded so the cutout is deterministic.

Per-photo B1/B2 evidence and verdict: docs/qa/photo-eval/2026-07-06_2125_F0_G0-eval.md.
"""

from pathlib import Path

import cv2
import pytest

from colorlab.background import remove_background
from colorlab.filters import (
    MAX_SKIN_FRACTION,
    adaptive_skin_mask,
    estimate_skin_tone,
)
from colorlab.image_io import load_image

G0_DIR = Path(__file__).resolve().parents[2] / "samples" / "g0"
G0_PHOTOS = sorted(p.name for p in G0_DIR.glob("g0-*.jpg"))

# Dark-skin photos of the battery (issue #7): where the B1 bias was critical.
DARK_SKIN_PHOTOS = [
    "g0-05-medio-cuerpo-piel-oscura.jpg",
    "g0-08-print-piel-oscura.jpg",
]


def _foreground(name):
    # GrabCut initializes its GMMs with OpenCV's global RNG; we seed it so the
    # cutout — and therefore this validation — is reproducible.
    cv2.setRNGSeed(0)
    img = load_image(str(G0_DIR / name))
    return remove_background(img)


@pytest.mark.slow
@pytest.mark.parametrize("name", G0_PHOTOS)
def test_adaptive_filter_respects_guardrail_on_g0(name):
    # B2 over real data: the filter never erases more than MAX_SKIN_FRACTION of
    # the foreground. If it tried (skin-colored outfit), the guardrail voids it.
    rgb, fg = _foreground(name)
    fg_total = int(fg.sum())
    assert fg_total > 0
    skin = adaptive_skin_mask(rgb, fg)
    fraction = (skin & fg).sum() / fg_total
    assert fraction <= MAX_SKIN_FRACTION + 1e-9


@pytest.mark.slow
@pytest.mark.parametrize("name", DARK_SKIN_PHOTOS)
def test_adaptive_filter_samples_dark_skin_subject_B1(name):
    # B1 over real data: in dark-skin photos the adaptive filter DOES manage to
    # sample the subject's tone (the classic heuristic, with y > 80, did not
    # even try). Confirms the mechanism that corrects the bias kicks in.
    rgb, fg = _foreground(name)
    assert estimate_skin_tone(rgb, fg) is not None
