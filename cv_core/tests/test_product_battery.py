"""Unit tests for the Gate G2S product battery (cv_core/tools/product_battery.py).

Covers the gate-metric math (D28: >= 70% of the eval set with base OK +
100%-product palette), the verdict parsing the CEO's hand annotations go
through, and the review.md round-trip — all on synthetic data, no real photos,
so everything here stays in the fast suite. One small synthetic-image test
exercises evaluate_photo end-to-end (same fixture idea as test_pipeline.py).
"""

import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

# The battery is a QA tool, not part of the colorlab package: import it from
# cv_core/tools the same way it is run (as a standalone module).
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

import product_battery as pb

# --- D28 pin ------------------------------------------------------------------


def test_gate_threshold_is_pinned_to_d28():
    """The G2S bar is a CEO decision (D28, 2026-07-11). If it changes, it must
    change HERE too — deliberately — not drift silently in the tool."""
    assert pb.GATE_G2S_MIN == 0.70


# --- Verdict parsing (the CEO annotates by hand, Spanish or English) ----------


@pytest.mark.parametrize(
    "cell", ["yes", "YES", " y ", "si", "Sí", "ok", "**yes**", "pasa"]
)
def test_parse_verdict_yes_variants(cell):
    assert pb.parse_verdict(cell) == "yes"


@pytest.mark.parametrize("cell", ["no", "NO", "ko", "**no**", "x", "fail"])
def test_parse_verdict_no_variants(cell):
    assert pb.parse_verdict(cell) == "no"


@pytest.mark.parametrize("cell", ["", "pending", "maybe", "yes?", "duda", "—"])
def test_parse_verdict_anything_else_is_pending(cell):
    """An ambiguous cell must NEVER count toward the gate."""
    assert pb.parse_verdict(cell) == "pending"


# --- Row status (D28 requires BOTH criteria) -----------------------------------


@pytest.mark.parametrize(
    "base_ok, palette_pure, expected",
    [
        ("yes", "yes", "pass"),
        ("yes", "no", "fail"),
        ("no", "yes", "fail"),
        ("no", "no", "fail"),
        ("no", "pending", "fail"),  # one 'no' already decides the row
        ("yes", "pending", "pending"),
        ("pending", "yes", "pending"),
        ("pending", "pending", "pending"),
    ],
)
def test_row_status_requires_both_criteria(base_ok, palette_pure, expected):
    assert pb.row_status(base_ok, palette_pure) == expected


# --- Gate metric ----------------------------------------------------------------


def _rows(n_pass, n_fail, n_pending):
    return (
        [("yes", "yes")] * n_pass
        + [("yes", "no")] * n_fail
        + [("pending", "pending")] * n_pending
    )


def test_gate_passes_exactly_at_the_70pct_boundary():
    """7/10 = 70% must PASS: D28 says >= 70%, not > 70% (guards float noise)."""
    metric = pb.gate_metric(_rows(7, 3, 0))
    assert metric["verdict"] == "PASS"
    assert metric["passed"] == 7 and metric["failed"] == 3 and metric["pending"] == 0


def test_gate_fails_just_below_the_boundary():
    metric = pb.gate_metric(_rows(6, 4, 0))
    assert metric["verdict"] == "FAIL"


def test_gate_passes_when_worst_case_already_clears_the_bar():
    """7 pass + 3 pending out of 10: even if every pending row failed we are at
    70%, so the verdict is PASS without waiting for the review to finish."""
    metric = pb.gate_metric(_rows(7, 0, 3))
    assert metric["verdict"] == "PASS"
    assert metric["rate_worst"] == pytest.approx(0.7)


def test_gate_fails_when_best_case_cannot_reach_the_bar():
    """5 pass + 4 fail + 1 pending: best case 60% < 70% -> FAIL already."""
    metric = pb.gate_metric(_rows(5, 4, 1))
    assert metric["verdict"] == "FAIL"
    assert metric["rate_best"] == pytest.approx(0.6)


def test_gate_undecided_while_pending_rows_can_swing_it():
    """6 pass + 3 fail + 1 pending: worst 60%, best 70% -> UNDECIDED."""
    metric = pb.gate_metric(_rows(6, 3, 1))
    assert metric["verdict"] == "UNDECIDED"
    assert metric["pending"] == 1


def test_gate_undecided_when_nothing_reviewed_yet():
    metric = pb.gate_metric(_rows(0, 0, 5))
    assert metric["verdict"] == "UNDECIDED"


def test_gate_no_data_on_empty_set():
    assert pb.gate_metric([])["verdict"] == "NO DATA"


def test_gate_summary_mentions_verdict_and_threshold():
    text = pb.format_gate_summary(pb.gate_metric(_rows(7, 3, 0)))
    assert "PASS" in text and "70%" in text


# --- review.md round-trip --------------------------------------------------------


def _fake_results():
    ok = {
        "id": "sneaker-01",
        "file": "sneaker-01.jpg",
        "hints": [],
        "palette": [
            {"hex": "#C81E28", "weight": 0.6},
            {"hex": "#F2F2F0", "weight": 0.4},
        ],
        "base_hex": "#C81E28",
        "canvas": False,
        "bg_match_indices": [1],
        "bg_match_weight": 0.4,
        "border_bg_hex": "#F4F3F1",
        "time_s": 0.5,
        "error": None,
    }
    canvas = {
        "id": "sneaker-02",
        "file": "sneaker-02.jpg",
        "hints": ["CANVAS"],
        "palette": [{"hex": "#111112", "weight": 1.0}],
        "base_hex": "#111112",
        "canvas": True,
        "bg_match_indices": [],
        "bg_match_weight": 0.0,
        "border_bg_hex": "#F4F3F1",
        "time_s": 0.5,
        "error": None,
    }
    crash = {
        "id": "sneaker-03",
        "file": "sneaker-03.jpg",
        "hints": ["CRASH"],
        "time_s": 0.1,
        "error": "boom",
    }
    return [ok, canvas, crash]


def test_review_roundtrip_prefills_crash_and_leaves_rest_pending():
    md = pb.build_review_md(_fake_results(), Path("samples/product"))
    rows = pb.parse_review_md(md)
    assert len(rows) == 3
    by_photo = {r["photo"]: r for r in rows}
    crash = by_photo["sneaker-03.jpg"]
    assert (crash["base_ok"], crash["palette_pure"]) == ("no", "no")
    for photo in ("sneaker-01.jpg", "sneaker-02.jpg"):
        assert by_photo[photo]["base_ok"] == "pending"
        assert by_photo[photo]["palette_pure"] == "pending"


def test_review_roundtrip_scores_after_annotation():
    """Simulate the CEO annotating the generated table, then score it."""
    md = pb.build_review_md(_fake_results(), Path("samples/product"))
    md = md.replace("| pending | pending |", "| yes | yes |", 1)  # sneaker-01
    md = md.replace("| pending | pending |", "| yes | no |", 1)  # sneaker-02
    rows = pb.parse_review_md(md)
    metric = pb.gate_metric([(r["base_ok"], r["palette_pure"]) for r in rows])
    # 1 pass / 2 fail (annotated fail + CRASH auto-fail) -> 33% < 70%.
    assert metric["passed"] == 1
    assert metric["failed"] == 2
    assert metric["pending"] == 0
    assert metric["verdict"] == "FAIL"


def test_parse_review_md_fails_loudly_without_the_table():
    with pytest.raises(ValueError):
        pb.parse_review_md("# just a heading\n\nno table here\n")


# --- evaluate_photo on a synthetic product shot (fast, no real photo) -----------


def test_evaluate_photo_synthetic_product(tmp_path):
    """Gray studio background + red product. Since #84, product mode SUPPRESSES
    the multi-edge background (the gray wraps all four edges), so the base is
    the chromatic red AND the gray background no longer leaks into the palette —
    exactly the gate's 'palette 100% product' goal, so the battery reports no
    border-matching swatch."""
    arr = np.full((160, 120, 3), (205, 205, 205), dtype=np.uint8)
    arr[45:115, 40:80] = (200, 40, 40)
    path = tmp_path / "prod-red.png"
    Image.fromarray(arr).save(path)

    res = pb.evaluate_photo(path)
    assert "CRASH" not in res["hints"], res.get("error")
    base = tuple(int(res["base_hex"][j : j + 2], 16) for j in (1, 3, 5))
    assert base[0] > 150 and base[1] < 90 and base[2] < 90, (
        f"base {res['base_hex']} not red"
    )
    # The gray studio background is suppressed: it must not survive as a swatch.
    assert not res["bg_match_indices"], (
        "gray background leaked into the palette despite multi-edge suppression"
    )
