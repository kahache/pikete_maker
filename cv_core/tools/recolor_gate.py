"""I2 visual-quality gate harness (condition C3; ML tool, not shipped).

Runs the per-region recolor WITH the C1 mask hardening on every photo of the
CEO selfie set (both regions, the hero combo of D36), writes one panel per
photo to ``outputs/i2-gate/<label>/`` and a ``results.csv`` with ONE ROW PER
PHOTO x REGION whose ``verdict`` column is EMPTY: the CEO fills it in
(``OK`` = show-as-is quality, ``MEH`` = credible but not shareable, ``BAD``).
The harness never judges; the ``agent_note`` column carries a one-line
observation from looking at the panel. The applicability reason of
:func:`colorlab.segmentation.check_applicability` is printed per photo and
stored per row (a not-applicable photo still gets a panel so the CEO sees
what the UI would hide).

``--summarize`` reads the verdicts back and prints the pass rate against
:data:`GATE_I2_MIN` (decision 2026-09-30: 80 % of the selfies must be
show-as-is). Two denominators are printed — applicable photos only (the
product gates the feature on applicability, so this is the gate figure) and
all judged photos — plus the per-region rate; a photo passes when EVERY
judged region of it is ``OK``.

Usage (from the repo root, venv active):
    python cv_core/tools/recolor_gate.py                       # label = c1
    python cv_core/tools/recolor_gate.py --label c1-check --stems selfie31 selfie05
    python cv_core/tools/recolor_gate.py --summarize           # after the CEO review
"""

from __future__ import annotations

import argparse
import csv
import logging
import sys
from collections import defaultdict
from pathlib import Path

# Sibling tool (same directory) — the recolor + panel composition.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from recolor_poc import (
    DEFAULT_MASKS_DIR,
    DEFAULT_PHOTOS_DIR,
    MASK_SUFFIX,
    compose_panel,
    prepare_photo,
    recolor_photo,
)

from colorlab.harmony import hexstr
from colorlab.segmentation import (
    REGION_LOWER,
    REGION_UPPER,
    NoPersonError,
)

logger = logging.getLogger("recolor_gate")

REPO = Path(__file__).resolve().parents[2]
DEFAULT_OUT_ROOT = REPO / "outputs" / "i2-gate"
DEFAULT_LABEL = "c1"
RESULTS_CSV = "results.csv"

# Gate threshold (CEO, 2026-09-30): fraction of the selfies whose recolor is
# show-as-is quality, judged on the per-region panels.
GATE_I2_MIN = 0.80

VERDICT_OK = "OK"
VERDICTS = (VERDICT_OK, "MEH", "BAD")
REASON_NO_MASK = "no_mask"
REASON_NO_PERSON = "no_person"

FIELDS = (
    "photo",
    "region",
    "applicable",
    "reason",
    "region_reason",
    "source_hex",
    "target_hex",
    "combo",
    "panel",
    "split_from_waist",
    "split_row",
    "person_component_ratio",
    "frame_median_l",
    "person_p90_l",
    "hole_fraction",
    "speckle_fraction",
    "detached_fraction",
    "region_fraction",
    "recolor_ms",
    "agent_note",
    "verdict",
)


def _fmt(value: float | None, digits: int = 3) -> str:
    return "" if value is None else f"{value:.{digits}f}"


def run(
    photos: list[Path], masks_dir: Path, out_dir: Path, *, notes: dict[str, str]
) -> list[dict[str, str]]:
    out_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, str]] = []
    for index, photo in enumerate(photos):
        stem = photo.stem
        mask_path = masks_dir / f"{stem}{MASK_SUFFIX}"
        if not mask_path.exists():
            print(f"{stem}: {REASON_NO_MASK}")
            rows.append({"photo": stem, "region": "", "reason": REASON_NO_MASK})
            continue
        try:
            prepared = prepare_photo(photo, masks_dir)
            result = recolor_photo(prepared, target=None, stem_index=index)
        except NoPersonError as exc:
            print(f"{stem}: {REASON_NO_PERSON} ({exc})")
            rows.append({"photo": stem, "region": "", "reason": REASON_NO_PERSON})
            continue
        panel_name = f"{stem}_panel.png"
        compose_panel(prepared, result, stem).save(out_dir / panel_name)
        app = prepared.applicability
        m = app.metrics
        print(
            f"{stem}: {'applicable' if app.applicable else 'NOT applicable: ' + str(app.reason)}"
            f"  (regions {', '.join(result['outputs']) or 'none'}; "
            f"split {'waist' if prepared.split_from_waist else 'mid-row'})"
        )
        for region in (REGION_UPPER, REGION_LOWER):
            if region not in result["outputs"]:
                continue
            key = f"{stem}:{region}"
            rows.append(
                {
                    "photo": stem,
                    "region": region,
                    "applicable": "yes" if app.applicable else "no",
                    "reason": app.reason or "",
                    "region_reason": app.regions.get(region) or "",
                    "source_hex": hexstr(result["sources"][region]),
                    "target_hex": hexstr(result["target"]),
                    "combo": result["combo"],
                    "panel": panel_name,
                    "split_from_waist": "yes" if prepared.split_from_waist else "no",
                    "split_row": str(prepared.split_row),
                    "person_component_ratio": _fmt(m.get("person_component_ratio")),
                    "frame_median_l": _fmt(m.get("frame_median_l"), 1),
                    "person_p90_l": _fmt(m.get("person_p90_l"), 1),
                    "hole_fraction": _fmt(m.get("hole_fraction")),
                    "speckle_fraction": _fmt(m.get("speckle_fraction")),
                    "detached_fraction": _fmt(m.get("detached_fraction")),
                    "region_fraction": _fmt(m.get(f"{region}_fraction")),
                    "recolor_ms": f"{result['timings'][region] * 1000:.0f}",
                    "agent_note": notes.get(key, notes.get(stem, "")),
                    "verdict": "",
                }
            )
    return rows


def write_results(rows: list[dict[str, str]], path: Path) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in FIELDS})


def load_notes(path: Path | None) -> dict[str, str]:
    """Optional ``photo[:region],note`` CSV (no header) -> agent_note column."""
    if path is None or not path.exists():
        return {}
    notes: dict[str, str] = {}
    with path.open(newline="", encoding="utf-8") as fh:
        for row in csv.reader(fh):
            if len(row) >= 2 and row[0].strip():
                notes[row[0].strip()] = row[1].strip()
    return notes


def summarize(path: Path) -> int:
    with path.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    judged = [r for r in rows if r["region"] and r["verdict"].strip()]
    unjudged = [r for r in rows if r["region"] and not r["verdict"].strip()]
    skipped = [r for r in rows if not r["region"]]
    bad_values = sorted({r["verdict"].strip().upper() for r in judged} - set(VERDICTS))
    if bad_values:
        print(f"unknown verdict values {bad_values}: use one of {VERDICTS}")
        return 2

    per_photo: dict[str, list[str]] = defaultdict(list)
    applicable: dict[str, bool] = {}
    for r in judged:
        per_photo[r["photo"]].append(r["verdict"].strip().upper())
        applicable[r["photo"]] = r["applicable"] == "yes"
    photo_pass = {p: all(v == VERDICT_OK for v in vs) for p, vs in per_photo.items()}
    app_photos = [p for p in photo_pass if applicable[p]]
    app_rate = (
        sum(photo_pass[p] for p in app_photos) / len(app_photos) if app_photos else 0.0
    )
    all_rate = sum(photo_pass.values()) / len(photo_pass) if photo_pass else 0.0
    region_ok = sum(r["verdict"].strip().upper() == VERDICT_OK for r in judged)
    region_rate = region_ok / len(judged) if judged else 0.0

    print(f"results: {path}")
    print(
        f"rows: {len(judged)} judged, {len(unjudged)} unjudged, "
        f"{len(skipped)} photos skipped ({', '.join(r['photo'] + ':' + r['reason'] for r in skipped) or '-'})"
    )
    print(
        f"per region: {region_ok}/{len(judged)} OK = {region_rate:.1%}  "
        f"(MEH {sum(r['verdict'].strip().upper() == 'MEH' for r in judged)}, "
        f"BAD {sum(r['verdict'].strip().upper() == 'BAD' for r in judged)})"
    )
    print(
        f"per photo, all judged: {sum(photo_pass.values())}/{len(photo_pass)} = {all_rate:.1%}"
    )
    not_app = [p for p in photo_pass if not applicable[p]]
    print(
        f"per photo, APPLICABLE only (gate figure): "
        f"{sum(photo_pass[p] for p in app_photos)}/{len(app_photos)} = {app_rate:.1%} "
        f"vs GATE_I2_MIN {GATE_I2_MIN:.0%} -> {'PASS' if app_rate >= GATE_I2_MIN else 'FAIL'}"
        f"  (not applicable, excluded: {', '.join(not_app) or '-'})"
    )
    if unjudged:
        print("NOTE: unjudged rows are excluded; the figure is partial.")
    return 0 if app_rate >= GATE_I2_MIN else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--label", default=DEFAULT_LABEL, help="outputs/i2-gate/<label>/"
    )
    parser.add_argument("--out-root", type=Path, default=DEFAULT_OUT_ROOT)
    parser.add_argument("--photos-dir", type=Path, default=DEFAULT_PHOTOS_DIR)
    parser.add_argument("--masks-dir", type=Path, default=DEFAULT_MASKS_DIR)
    parser.add_argument(
        "--stems", nargs="*", help="subset of photo stems (default: every photo)"
    )
    parser.add_argument(
        "--notes",
        type=Path,
        help="CSV of 'photo[:region],note' lines for the agent_note column",
    )
    parser.add_argument(
        "--summarize",
        action="store_true",
        help="read the verdicts of outputs/i2-gate/<label>/results.csv",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)
    logging.basicConfig(
        level=logging.INFO if args.verbose else logging.WARNING,
        format="%(levelname)s %(name)s: %(message)s",
    )
    out_dir = args.out_root / args.label
    results = out_dir / RESULTS_CSV
    if args.summarize:
        if not results.exists():
            print(f"no {results}: run the harness first")
            return 2
        return summarize(results)

    photos = sorted(args.photos_dir.glob("*.jpeg")) + sorted(
        args.photos_dir.glob("*.jpg")
    )
    if args.stems:
        wanted = set(args.stems)
        photos = [p for p in photos if p.stem in wanted]
    if not photos:
        parser.error(f"no photos under {args.photos_dir}")
    rows = run(photos, args.masks_dir, out_dir, notes=load_notes(args.notes))
    write_results(rows, results)
    n_photos = len({r["photo"] for r in rows if r.get("region")})
    n_not_app = len({r["photo"] for r in rows if r.get("applicable") == "no"})
    print(
        f"\n{n_photos} photos with panels ({n_not_app} not applicable), "
        f"{sum(1 for r in rows if r.get('region'))} region rows -> {results}"
    )
    print("Fill the 'verdict' column (OK / MEH / BAD) and run --summarize.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
