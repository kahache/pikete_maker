"""The `colorlab` CLI is a thin wrapper: only the composition it adds is
tested here — canvas mode routing (bug B3 in the reference tool, review F14).
"""

import sys

import numpy as np
from PIL import Image

from colorlab import cli

STUDIO_GRAY = (205, 205, 205)
DARK_GRAY = (60, 60, 60)
RED = (200, 40, 40)


def _photo(tmp_path, product):
    arr = np.full((120, 90, 3), STUDIO_GRAY, dtype=np.uint8)
    arr[30:90, 30:60] = product
    path = tmp_path / "photo.png"
    Image.fromarray(arr).save(path)
    return path


def _run(monkeypatch, capsys, tmp_path, product):
    path = _photo(tmp_path, product)
    out = tmp_path / "panel.png"
    monkeypatch.setattr(
        sys, "argv", ["colorlab", str(path), "--product-mode", "-o", str(out)]
    )
    cli.main()
    assert out.exists()
    return capsys.readouterr().out


def test_neutral_outfit_routes_to_canvas_mode(monkeypatch, capsys, tmp_path):
    out = _run(monkeypatch, capsys, tmp_path, DARK_GRAY)
    assert "Neutral canvas (D10)" in out
    assert "harmony BASE" not in out, "no neutral may be tagged as the harmony base"


def test_chromatic_outfit_tags_the_base(monkeypatch, capsys, tmp_path):
    out = _run(monkeypatch, capsys, tmp_path, RED)
    assert "harmony BASE" in out
    assert "Neutral canvas" not in out
