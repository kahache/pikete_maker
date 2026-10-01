"""colorlab — the canonical color engine of PiketeMaker.

Takes a photo of an outfit and returns the colors the person is actually
WEARING, plus the color harmonies that go with them. This package is the
source of truth for the algorithm: the on-device Dart port in
``app/lib/core/color_engine`` mirrors it function by function and is pinned
against it by shared golden fixtures, so every numeric change here is a
change to what ships on the phone.

Pipeline stages (each one module, composed in :mod:`colorlab.pipeline`)
-----------------------------------------------------------------------

1. :mod:`colorlab.image_io` — load and downscale the photo.
2. :mod:`colorlab.background` — separate person from background, degrading
   gracefully across rembg -> GrabCut -> no-op depending on what is
   installed.
3. :mod:`colorlab.filters` — drop the subject's skin pixels, sampling their
   ACTUAL skin tone rather than a universal (and racially biased) range.
4. :mod:`colorlab.palette` — dominant colors: over-cluster with K-means, then
   merge perceptually equal clusters in CIELAB so one garment's lighting
   gradations collapse into one color while a genuine minority "pop"
   survives.
5. :mod:`colorlab.harmony` — pick the harmony base (most chromatic, never a
   neutral — decision #6) and rotate it into the classic schemes.
6. :mod:`colorlab.render` — compose the visual result panel.

Three entry points
------------------

- :func:`analyze_palette` — the whole-photo pipeline (outfit mode), and with
  ``product_mode=True`` the sneaker/object variant that skips the two
  person-specific stages (D24).
- :func:`analyze_garments` — the Phase 2.5 differentiator: given a per-pixel
  segmentation mask, attribution is solved by construction (background, skin
  and hair are never sampled) and the analysis becomes PER GARMENT,
  upper/lower (D21).
- :mod:`colorlab.cli` — the ``colorlab`` command, a thin wrapper over the
  above. The library itself is print-free and logs via :mod:`logging`; only
  the CLI writes to stdout.

Two layers sit beside the pipeline rather than inside it:
:mod:`colorlab.borders` (self-disabling edge-based background models, opt-in)
and :mod:`colorlab.display` (display-time neutral snapping, which must never
feed back into the analysis). :mod:`colorlab.recolor` (ICEBOX I2 proof of
concept) consumes the per-garment masks and a proposed colour to repaint one
garment region of the photo; it is downstream of the analysis, never an
input to it. Its mask comes from the OPT-IN hardening layer of
:mod:`colorlab.segmentation` (:class:`MaskHardening`, :data:`RECOLOR_HARDENING`:
hole fill, detached-component drop, hip-line split, smoothed contours) plus
the :func:`check_applicability` verdict (one person, decent light) the UI
gates the feature on; the canonical palette path never uses either.
"""

from colorlab.background import remove_background
from colorlab.borders import (
    BackgroundCandidate,
    estimate_background_candidates,
    pick_harmony_base_avoiding_background,
    pick_harmony_base_index_avoiding_background,
)
from colorlab.display import snap_neutral_for_display, snap_palette_for_display
from colorlab.filters import gather_pixels, skin_mask
from colorlab.harmony import (
    as_rgb,
    harmonies,
    hexstr,
    is_neutral,
    pick_harmony_base,
    pick_harmony_base_index,
)
from colorlab.image_io import load_image
from colorlab.palette import NoPixelsError, dominant_colors
from colorlab.pipeline import (
    GarmentAnalysis,
    GarmentPalette,
    PaletteAnalysis,
    analyze_garments,
    analyze_palette,
)
from colorlab.recolor import recolor_region
from colorlab.render import render_panel
from colorlab.segmentation import (
    RECOLOR_HARDENING,
    Applicability,
    MaskHardening,
    NoPersonError,
    check_applicability,
    harden_class_map,
    load_class_mask,
    resample_class_map_smooth,
    save_class_mask,
    split_garment_masks,
)

__version__ = "0.1.0"

__all__ = [
    "RECOLOR_HARDENING",
    "Applicability",
    "BackgroundCandidate",
    "GarmentAnalysis",
    "GarmentPalette",
    "MaskHardening",
    "NoPersonError",
    "NoPixelsError",
    "PaletteAnalysis",
    "analyze_garments",
    "analyze_palette",
    "as_rgb",
    "check_applicability",
    "dominant_colors",
    "estimate_background_candidates",
    "gather_pixels",
    "harden_class_map",
    "harmonies",
    "hexstr",
    "is_neutral",
    "load_class_mask",
    "load_image",
    "pick_harmony_base",
    "pick_harmony_base_avoiding_background",
    "pick_harmony_base_index",
    "pick_harmony_base_index_avoiding_background",
    "recolor_region",
    "remove_background",
    "render_panel",
    "resample_class_map_smooth",
    "save_class_mask",
    "skin_mask",
    "snap_neutral_for_display",
    "snap_palette_for_display",
    "split_garment_masks",
]
