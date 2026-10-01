"""Rendering of the visual result panel (photo + palette + harmonies)."""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # no window: we save to a file
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Rectangle

from colorlab.display import snap_palette_for_display
from colorlab.harmony import RGB, hexstr

# Luminance threshold to decide black or white text over a swatch.
LABEL_LUM_THRESHOLD = 140


def label_text_color(rgb: RGB) -> str:
    """Black or white, whichever is readable over the given swatch color (BT.601 luma)."""
    lum = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]
    return "black" if lum > LABEL_LUM_THRESHOLD else "white"


def _swatch_row(ax, title: str, rgb_list: list[RGB], weights=None) -> None:
    ax.set_xlim(0, len(rgb_list))
    ax.set_ylim(0, 1)
    ax.axis("off")
    ax.set_title(title, fontsize=10, loc="left")
    for i, rgb in enumerate(rgb_list):
        ax.add_patch(Rectangle((i, 0), 1, 1, color=np.array(rgb) / 255))
        label = hexstr(rgb)
        if weights is not None:
            label += f"\n{weights[i] * 100:.0f}%"
        ax.text(
            i + 0.5,
            0.5,
            label,
            ha="center",
            va="center",
            fontsize=8,
            color=label_text_color(rgb),
        )


def render_panel(
    original: np.ndarray,
    colors: np.ndarray,
    weights: np.ndarray,
    schemes: dict[str, list[RGB]],
    out_path: str | Path,
    snap_display_neutrals: bool = False,
) -> None:
    """Saves to out_path a PNG with the photo, the extracted palette and the harmonies.

    ``snap_display_neutrals`` (issue #85, D31-A) canonicalizes the DISPLAYED
    palette swatches — diluted blacks to #000000, near-whites to #FFFFFF, see
    :func:`colorlab.display.snap_neutral_for_display` — without touching the
    analysis (``colors``/``weights``/``schemes`` are computed on raw colors).
    Off by default so historical panels stay byte-identical; the CLI turns it
    on in product mode.
    """
    if snap_display_neutrals:
        colors = snap_palette_for_display(colors)
    n_rows = 2 + len(schemes)
    fig = plt.figure(figsize=(10, 2.2 + n_rows * 0.9))
    gs = fig.add_gridspec(n_rows, 2, width_ratios=[1, 2], hspace=0.5)

    ax_img = fig.add_subplot(gs[0:2, 0])
    ax_img.imshow(original)
    ax_img.set_title("Photo", fontsize=11)
    ax_img.axis("off")

    _swatch_row(
        fig.add_subplot(gs[0, 1]),
        "Extracted palette (your garments)",
        [tuple(c) for c in colors],
        weights,
    )

    for i, (name, cols) in enumerate(schemes.items()):
        _swatch_row(fig.add_subplot(gs[2 + i, 0:2]), f"Harmony · {name}", cols)

    fig.suptitle("Palette and proposed harmonies", fontsize=13, y=0.99)
    fig.savefig(out_path, bbox_inches="tight", dpi=130)
    plt.close(fig)
