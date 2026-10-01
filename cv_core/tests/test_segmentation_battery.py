"""Unit tests for the Gate G2.5 segmentation battery
(cv_core/tools/segmentation_battery.py).

Covers the gate-metric math (>= 80% overall AND per skin-tone bucket — the
PRD SS9 bias rule), the verdict parsing (now with `n/a`), the consumption of
the canonical colorlab.segmentation split (the split semantics themselves are
owned by test_segmentation.py), the review.md round-trip and synthetic
end-to-end evaluate_photo — all on synthetic data, no real photos, so
everything stays in the fast suite (same style as test_product_battery.py).
"""

import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

# The battery is a QA tool, not part of the colorlab package: import it from
# cv_core/tools the same way it is run (as a standalone module).
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

import segmentation_battery as sb

# --- Gate parameters pinned (PRD gate G2.5 + SS9 bias test) --------------------


def test_gate_threshold_is_pinned_to_the_prd():
    """The G2.5 bar comes from the PRD gate sentence (>= 80%). If it changes,
    it must change HERE too — deliberately — not drift silently."""
    assert sb.GATE_G25_MIN == 0.80


def test_bias_test_parameters_are_pinned():
    """The bias test's power floor and buckets come from the D23 dataset spec
    (docs/qa/photo-eval/2026-07-14_2330_F2.5_D23-eval-dataset-spec.md)."""
    assert sb.MIN_BUCKET_N == 10
    assert sb.SKIN_BUCKETS == ("light", "medium", "dark")


def test_mask_filename_contract_matches_generate_masks():
    """The handoff filename contract is shared with
    cv_core/tools/generate_masks.py (`<stem>.mask.png`). Changing one side
    silently orphans every mask on disk — change both, deliberately."""
    assert sb.MASK_SUFFIX == ".mask.png"


# --- Verdict parsing (adds n/a on top of the product-battery tokens) -----------


@pytest.mark.parametrize(
    "cell", ["yes", "YES", " y ", "si", "Sí", "ok", "**yes**", "pasa"]
)
def test_parse_verdict_yes_variants(cell):
    assert sb.parse_verdict(cell) == "yes"


@pytest.mark.parametrize("cell", ["no", "NO", "ko", "**no**", "x", "fail"])
def test_parse_verdict_no_variants(cell):
    assert sb.parse_verdict(cell) == "no"


@pytest.mark.parametrize("cell", ["n/a", "N/A", "na", "n.a.", "no aplica", "**n/a**"])
def test_parse_verdict_na_variants(cell):
    """n/a = that garment is legitimately out of frame (waist-up shots)."""
    assert sb.parse_verdict(cell) == "na"


@pytest.mark.parametrize("cell", ["", "pending", "maybe", "yes?", "duda", "—", "-"])
def test_parse_verdict_anything_else_is_pending(cell):
    """An ambiguous cell must NEVER count toward the gate (note: a bare dash
    is pending, not n/a — n/a must be explicit)."""
    assert sb.parse_verdict(cell) == "pending"


# --- Row status ------------------------------------------------------------------


@pytest.mark.parametrize(
    "top, bottom, expected",
    [
        ("yes", "yes", "pass"),
        ("yes", "no", "fail"),
        ("no", "yes", "fail"),
        ("no", "na", "fail"),
        ("no", "pending", "fail"),  # one 'no' already decides the row
        ("yes", "na", "pass"),  # waist-up shot: only the top applies
        ("na", "yes", "pass"),
        ("na", "na", "excluded"),  # no judgeable garment: not a valid eval row
        ("yes", "pending", "pending"),
        ("na", "pending", "pending"),
        ("pending", "pending", "pending"),
    ],
)
def test_row_status(top, bottom, expected):
    assert sb.row_status(top, bottom) == expected


# --- Gate metric: overall + the SS9 bias rule -------------------------------------


def _rows(bucket, n_pass, n_fail, n_pending=0, n_na=0):
    return (
        [(bucket, "yes", "yes")] * n_pass
        + [(bucket, "yes", "no")] * n_fail
        + [(bucket, "pending", "pending")] * n_pending
        + [(bucket, "na", "na")] * n_na
    )


def _balanced(per_bucket_pass, per_bucket_fail, n_pending=0):
    rows = []
    for b in sb.SKIN_BUCKETS:
        rows += _rows(b, per_bucket_pass, per_bucket_fail, n_pending)
    return rows


def test_gate_passes_at_the_80pct_boundary_everywhere():
    """8/10 per bucket = exactly 80% overall and per bucket -> PASS
    (>= 80%, not > 80%; guards float noise)."""
    metric = sb.gate_metric(_balanced(8, 2))
    assert metric["verdict"] == "PASS"
    assert metric["overall"]["rate_worst"] == pytest.approx(0.8)
    for b in sb.SKIN_BUCKETS:
        assert metric["buckets"][b]["verdict"] == "PASS"


def test_gate_overall_pass_but_one_bucket_fail_is_FAIL():
    """THE SS9 RULE: light 10/10 + medium 10/10 + dark 5/10 = 83% overall
    (>= 80%) but the dark bucket fails its own bar -> gate FAIL."""
    rows = _rows("light", 10, 0) + _rows("medium", 10, 0) + _rows("dark", 5, 5)
    metric = sb.gate_metric(rows)
    assert metric["overall"]["verdict"] == "PASS"  # overall rate passes...
    assert metric["buckets"]["dark"]["verdict"] == "FAIL"  # ...but the bucket fails
    assert metric["verdict"] == "FAIL"  # -> gate FAIL


def test_gate_underpowered_bucket_caps_the_verdict_at_UNDECIDED():
    """A bucket below MIN_BUCKET_N photos = bias test underpowered: even a
    perfect score can never silently PASS."""
    rows = _rows("light", 12, 0) + _rows("medium", 12, 0) + _rows("dark", 9, 0)
    metric = sb.gate_metric(rows)
    assert metric["buckets"]["dark"]["verdict"] == "INSUFFICIENT"
    assert metric["verdict"] == "UNDECIDED"


def test_gate_unbucketed_rows_block_PASS():
    """Rows without a manifest skin bucket leave the bias table incomplete."""
    rows = [*_balanced(10, 0), (sb.UNKNOWN_BUCKET, "yes", "yes")]
    metric = sb.gate_metric(rows)
    assert metric["unknown_bucket_rows"] == 1
    assert metric["verdict"] == "UNDECIDED"


def test_gate_overall_fail_is_FAIL_regardless_of_buckets():
    metric = sb.gate_metric(_balanced(7, 3))  # 70% everywhere < 80%
    assert metric["verdict"] == "FAIL"


def test_gate_pending_rows_bracket_worst_and_best_case():
    """10 pass + 2 pending per bucket: worst case 10/12 (83%) already clears
    the bar everywhere -> PASS without waiting for the review to finish."""
    metric = sb.gate_metric(_balanced(10, 0, n_pending=2))
    assert metric["verdict"] == "PASS"


def test_gate_pending_rows_keep_it_UNDECIDED_when_they_can_swing_it():
    """9 pass + 1 fail + 2 pending per bucket: worst 75%, best 91% -> UNDECIDED."""
    metric = sb.gate_metric(_balanced(9, 1, n_pending=2))
    assert metric["verdict"] == "UNDECIDED"


def test_gate_fully_na_rows_are_excluded_from_every_denominator():
    rows = _balanced(8, 2) + _rows("light", 0, 0, n_na=3)
    metric = sb.gate_metric(rows)
    assert metric["overall"]["excluded"] == 3
    assert metric["overall"]["n"] == 30  # the 3 n/a rows don't count
    assert metric["buckets"]["light"]["n"] == 10
    assert metric["verdict"] == "PASS"


def test_gate_no_data_on_empty_set():
    assert sb.gate_metric([])["verdict"] == "NO DATA"


def test_gate_summary_mentions_verdict_buckets_and_latency_leg():
    text = sb.format_gate_summary(sb.gate_metric(_balanced(8, 2)))
    assert "PASS" in text and "80%" in text
    for b in sb.SKIN_BUCKETS:
        assert b in text
    assert "Latency leg" in text  # the <3s half of G2.5 is measured on-device


# --- Canonical-layer consumption (split semantics owned by test_segmentation) --


def test_region_palette_handles_absent_and_empty_regions():
    """split_garment_masks drops guarded-out regions from its dict; the
    harness turns that (None) — or an all-false mask — into 'no palette'."""
    rgb = np.zeros((50, 50, 3), dtype=np.uint8)
    assert sb.region_palette(rgb, None) is None
    assert sb.region_palette(rgb, np.zeros((50, 50), dtype=bool)) is None


# --- review.md round-trip ---------------------------------------------------------


def _fake_results():
    region_red = {
        "palette": [
            {"hex": "#C81E28", "display_hex": "#C81E28", "weight": 1.0, "is_base": True}
        ],
        "base_hex": "#C81E28",
        "display_base_hex": "#C81E28",
        "px": 5000,
    }
    region_blue = {
        "palette": [
            {"hex": "#1E3CA9", "display_hex": "#1E3CA9", "weight": 1.0, "is_base": True}
        ],
        "base_hex": "#1E3CA9",
        "display_base_hex": "#1E3CA9",
        "px": 4000,
    }
    ok = {
        "id": "seg-01",
        "file": "seg-01.jpg",
        "skin": "light",
        "expected_top": "rojo",
        "expected_bottom": "azul",
        "hints": [],
        "upper": region_red,
        "lower": region_blue,
        "time_s": 0.5,
        "error": None,
    }
    missing = {
        "id": "seg-02",
        "file": "seg-02.jpg",
        "skin": "dark",
        "expected_top": "",
        "expected_bottom": "",
        "hints": ["MISSING_MASK"],
        "upper": None,
        "lower": None,
        "time_s": 0.0,
        "error": None,
    }
    no_person = {
        "id": "seg-03",
        "file": "seg-03.jpg",
        "skin": "medium",
        "expected_top": "verde",
        "expected_bottom": "negro",
        "hints": ["NO_PERSON"],
        "upper": None,
        "lower": None,
        "time_s": 0.2,
        "error": None,
    }
    return [ok, missing, no_person]


def test_review_roundtrip_prefills_no_person_and_leaves_rest_pending():
    md = sb.build_review_md(_fake_results(), Path("samples/segmentation/photos"))
    rows = sb.parse_review_md(md)
    assert len(rows) == 3
    by_photo = {r["photo"]: r for r in rows}
    assert (by_photo["seg-03.jpg"]["top_ok"], by_photo["seg-03.jpg"]["bottom_ok"]) == (
        "no",
        "no",
    )
    for photo in ("seg-01.jpg", "seg-02.jpg"):
        assert by_photo[photo]["top_ok"] == "pending"
        assert by_photo[photo]["bottom_ok"] == "pending"


def test_review_roundtrip_carries_the_skin_bucket_into_scoring():
    md = sb.build_review_md(_fake_results(), Path("samples/segmentation/photos"))
    rows = sb.parse_review_md(md)
    assert {r["photo"]: r["skin"] for r in rows} == {
        "seg-01.jpg": "light",
        "seg-02.jpg": "dark",
        "seg-03.jpg": "medium",
    }


def test_review_roundtrip_scores_after_annotation():
    """Simulate the CEO annotating the generated table, then score it."""
    md = sb.build_review_md(_fake_results(), Path("samples/segmentation/photos"))
    md = md.replace("| pending | pending |", "| yes | yes |", 1)  # seg-01
    md = md.replace("| pending | pending |", "| yes | n/a |", 1)  # seg-02
    rows = sb.parse_review_md(md)
    metric = sb.gate_metric([(r["skin"], r["top_ok"], r["bottom_ok"]) for r in rows])
    # 2 pass (one via n/a bottom) / 1 fail (NO_PERSON auto-fail) = 66% < 80%.
    assert metric["overall"]["passed"] == 2
    assert metric["overall"]["failed"] == 1
    assert metric["verdict"] == "FAIL"


def test_parse_review_md_fails_loudly_without_the_table():
    with pytest.raises(ValueError):
        sb.parse_review_md("# just a heading\n\nno table here\n")


# --- evaluate_photo end-to-end on a synthetic photo + classmap ------------------


def _write_synthetic_case(tmp_path):
    """120x80 photo: red 'top' band, blue 'bottom' band, gray background —
    plus the matching class map (clothes over both bands, skin above)."""
    h, w = 120, 80
    rgb = np.full((h, w, 3), (200, 200, 200), dtype=np.uint8)
    rgb[30:70, 20:60] = (200, 30, 30)  # top garment: red
    rgb[70:110, 20:60] = (20, 40, 180)  # bottom garment: blue
    photo = tmp_path / "seg-synth.png"
    Image.fromarray(rgb).save(photo)

    cm = np.zeros((h, w), dtype=np.uint8)
    cm[30:110, 20:60] = sb.CLASS_CLOTHES
    cm[10:28, 30:50] = sb.CLASS_FACE_SKIN  # irrelevant to the split
    classmap = tmp_path / f"seg-synth{sb.MASK_SUFFIX}"
    Image.fromarray(cm, mode="L").save(classmap)
    return photo, classmap


def test_evaluate_photo_synthetic_two_garments(tmp_path):
    photo, classmap = _write_synthetic_case(tmp_path)
    res = sb.evaluate_photo(
        photo,
        classmap,
        {"skin": "dark", "expected_top": "rojo", "expected_bottom": "azul"},
    )
    assert "CRASH" not in res["hints"], res.get("error")
    assert res["skin"] == "dark"
    top = tuple(int(res["upper"]["base_hex"][j : j + 2], 16) for j in (1, 3, 5))
    bottom = tuple(int(res["lower"]["base_hex"][j : j + 2], 16) for j in (1, 3, 5))
    assert top[0] > 150 and top[2] < 90, (
        f"upper base {res['upper']['base_hex']} not red"
    )
    assert bottom[2] > 120 and bottom[0] < 90, (
        f"lower base {res['lower']['base_hex']} not blue"
    )
    # The gray background must not appear in either garment palette.
    for region in (res["upper"], res["lower"]):
        for entry in region["palette"]:
            rgb = tuple(int(entry["hex"][j : j + 2], 16) for j in (1, 3, 5))
            assert not (
                abs(rgb[0] - 200) < 25
                and abs(rgb[1] - 200) < 25
                and abs(rgb[2] - 200) < 25
            ), f"background leaked: {entry['hex']}"


def test_evaluate_photo_missing_mask_is_flagged_not_crashed(tmp_path):
    photo, _ = _write_synthetic_case(tmp_path)
    res = sb.evaluate_photo(photo, tmp_path / f"nope{sb.MASK_SUFFIX}", None)
    assert "MISSING_MASK" in res["hints"]
    assert "NO_BUCKET" in res["hints"]  # no manifest row either
    assert res["upper"] is None and res["lower"] is None


def test_evaluate_photo_no_person_mask_gets_the_auto_fail_hint(tmp_path):
    """Clothes coverage below the canonical threshold -> NO_PERSON hint
    (pre-filled no/no in the review: every eval photo has a dressed person)."""
    photo, classmap = _write_synthetic_case(tmp_path)
    cm = np.zeros((120, 80), dtype=np.uint8)
    cm[0:5, 0:5] = sb.CLASS_CLOTHES  # 25 px of 9600 = 0.26% < 1%
    Image.fromarray(cm, mode="L").save(classmap)
    res = sb.evaluate_photo(photo, classmap, {"skin": "medium"})
    assert "NO_PERSON" in res["hints"]
    assert res["upper"] is None and res["lower"] is None


def test_evaluate_photo_dropped_region_becomes_empty_hint(tmp_path):
    """A stray clothes sliver far below the main garment: the canonical
    min-region guard drops the lower region -> EMPTY_LOWER, upper intact."""
    h, w = 200, 150
    rgb = np.full((h, w, 3), (200, 200, 200), dtype=np.uint8)
    rgb[20:100, 30:120] = (200, 30, 30)
    photo = tmp_path / "seg-sliver.png"
    Image.fromarray(rgb).save(photo)
    cm = np.zeros((h, w), dtype=np.uint8)
    cm[20:100, 30:120] = sb.CLASS_CLOTHES  # main garment (upper half)
    cm[190, 30:40] = sb.CLASS_CLOTHES  # 10-px sliver -> eroded away
    classmap = tmp_path / f"seg-sliver{sb.MASK_SUFFIX}"
    Image.fromarray(cm, mode="L").save(classmap)
    res = sb.evaluate_photo(photo, classmap, {"skin": "light"})
    assert "CRASH" not in res["hints"], res.get("error")
    assert "EMPTY_LOWER" in res["hints"]
    assert res["lower"] is None
    assert res["upper"] is not None
    top = tuple(int(res["upper"]["base_hex"][j : j + 2], 16) for j in (1, 3, 5))
    assert top[0] > 150, f"upper base {res['upper']['base_hex']} not red"


def test_evaluate_photo_aligns_photo_to_classmap_dimensions(tmp_path):
    """Device classmaps come at the decode-capped size; the harness must
    resize its full-res photo copy to match instead of crashing."""
    photo, classmap = _write_synthetic_case(tmp_path)
    big = Image.open(photo).resize((160, 240), Image.BILINEAR)  # 2x photo
    big.save(photo)
    res = sb.evaluate_photo(photo, classmap, {"skin": "light"})
    assert "CRASH" not in res["hints"], res.get("error")
    top = tuple(int(res["upper"]["base_hex"][j : j + 2], 16) for j in (1, 3, 5))
    assert top[0] > 140, f"upper base {res['upper']['base_hex']} not red after resize"


def test_evaluate_photo_flags_a_non_contract_mask_as_crash(tmp_path):
    """A scaled/visualization PNG (values > 5) violates the contract:
    load_class_mask fails loudly and the row becomes a CRASH (auto-fail),
    never a silently misread mask."""
    photo, classmap = _write_synthetic_case(tmp_path)
    Image.fromarray(np.full((120, 80), 200, dtype=np.uint8), mode="L").save(classmap)
    res = sb.evaluate_photo(photo, classmap, {"skin": "light"})
    assert "CRASH" in res["hints"]
    assert "class" in (res["error"] or "").lower()
