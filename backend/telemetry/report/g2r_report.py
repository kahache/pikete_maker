"""Gate G2-R report — organic W1/W2 retention per creator source (D32/D33).

Reads the anonymous-card COUNTERS produced by the telemetry sink
(backend/telemetry/worker/src/worker.js, or its local shim) and prints the
gate table: per source+cohort -> installs, w1_retained, w2_returned, rate_w1,
rate_w2, plus the PASS / MARGINAL / FAIL verdict per the GTM thresholds
(docs/growth/2026-07-18_1400_F2_go-to-market-creator-led.md §5). Same
offline-aggregation pattern as cv_core/tools/*_battery.py: counts in, gate
number out — no per-device rows exist anywhere (ADR §2.3).

Inputs (either):
    --counts counts.json          {counter_key: n} map — the shim writes this
                                  format directly; a KV export works too.
    --from-wrangler --namespace-id XXX
                                  shells out to `npx wrangler kv ...` to pull
                                  the live counters (needs node + wrangler
                                  login; fine for ~200 keys).

Usage (from the repo root, any Python >= 3.10, stdlib only):
    python backend/telemetry/report/g2r_report.py --counts outputs/telemetry-local/counts.json
    python backend/telemetry/report/g2r_report.py --from-wrangler --namespace-id XXX
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

log = logging.getLogger("telemetry.g2r_report")

# --- Gate G2-R parameters (GTM §5, D32; ADR §2.3/§2.5) ------------------------

# >=25% of organic installers complete >=3 analyses in week 1...
GATE_G2R_W1_MIN = 0.25
# ...AND >=15% return in week 2...
GATE_G2R_W2_MIN = 0.15
# ...over >=60 organic installers spread across >=3 creators/sources.
GATE_G2R_MIN_INSTALLS = 60
GATE_G2R_MIN_SOURCES = 3
# GTM "NO PASA" branch: "muy por debajo, p. ej. <10% W1" -> product signal, not
# channel. Anything between the floor and the thresholds reads MARGINAL.
GATE_G2R_FAIL_W1_FLOOR = 0.10
# k-anonymity read-side suppression (ADR §2.5): a source with fewer installs is
# reported only inside the aggregate — its RATES are never shown on their own.
K_ANON_MIN_INSTALLS = 20
# Smoke/test traffic is kept out of the gate (README documents the convention:
# local/CI tests always use a source named test_*).
TEST_SOURCE_RE = re.compile(r"^test_")

# The gate is measured on the ORGANIC cohort only (paid never mixes, ADR §2.3).
GATE_COHORT = "organic"


# --- Counter-key parsing (format defined in worker.js counterKey()) -----------


def parse_key(key: str) -> dict | None:
    """Parses one counter key into card fields; None for non-card keys.

    Formats (part count disambiguates the kind):
      c|v1|install|src|cohort|platform|appver|locale|week              (9)
      c|v1|week1|src|cohort|t/f|abucket|mbucket|platform|appver|locale|week (12)
      c|v1|week2|src|cohort|t/f|platform|appver|locale|week            (10)
    """
    parts = key.split("|")
    if len(parts) < 3 or parts[0] != "c" or parts[1] != "v1":
        return None  # e.g. an "rl|..." rate-limit key that leaked into an export
    kind = parts[2]
    if kind == "install" and len(parts) == 9:
        return {"kind": kind, "source": parts[3], "cohort": parts[4]}
    if kind == "week1" and len(parts) == 12:
        return {
            "kind": kind,
            "source": parts[3],
            "cohort": parts[4],
            "retained_w1": parts[5] == "t",
        }
    if kind == "week2" and len(parts) == 10:
        return {
            "kind": kind,
            "source": parts[3],
            "cohort": parts[4],
            "returned_w2": parts[5] == "t",
        }
    return None


def aggregate(counts: dict[str, int]) -> tuple[dict, int]:
    """Rolls counters up per (source, cohort). Returns (table, skipped_keys).

    table[(source, cohort)] = {installs, w1_retained, w2_returned}
    """
    table: dict[tuple[str, str], dict[str, int]] = defaultdict(
        lambda: {"installs": 0, "w1_retained": 0, "w2_returned": 0}
    )
    skipped = 0
    for key, n in counts.items():
        card = parse_key(key)
        if card is None:
            skipped += 1
            continue
        if TEST_SOURCE_RE.match(card["source"]):
            continue  # smoke traffic never enters the gate
        row = table[(card["source"], card["cohort"])]
        if card["kind"] == "install":
            row["installs"] += n
        elif card["kind"] == "week1" and card["retained_w1"]:
            row["w1_retained"] += n
        elif card["kind"] == "week2" and card["returned_w2"]:
            row["w2_returned"] += n
    return dict(table), skipped


def gate_verdict(
    installs: int, sources: int, rate_w1: float, rate_w2: float
) -> tuple[str, str]:
    """G2-R verdict per GTM §5. Returns (verdict, reason).

    - PASS:     both rates over threshold AND N>=60 across >=3 sources.
    - FAIL:     N is sufficient but W1 is far below (<10%) — product signal.
    - MARGINAL: everything else (one threshold missed, or N short) — the GTM
      prescribes repeating Phase A, not scaling.
    """
    n_ok = installs >= GATE_G2R_MIN_INSTALLS and sources >= GATE_G2R_MIN_SOURCES
    w1_ok = rate_w1 >= GATE_G2R_W1_MIN
    w2_ok = rate_w2 >= GATE_G2R_W2_MIN
    if n_ok and w1_ok and w2_ok:
        return "PASS", "both thresholds met with sufficient N -> scale to Phase B"
    if n_ok and rate_w1 < GATE_G2R_FAIL_W1_FLOOR:
        return (
            "FAIL",
            f"W1 far below threshold (<{GATE_G2R_FAIL_W1_FLOOR:.0%}) -> product signal, pivot (do not buy distribution)",
        )
    if not n_ok:
        return "MARGINAL", (
            f"N short (installs {installs}/{GATE_G2R_MIN_INSTALLS}, sources {sources}/{GATE_G2R_MIN_SOURCES}) -> repeat Phase A"
        )
    missed = " and ".join(t for t, ok in (("W1", w1_ok), ("W2", w2_ok)) if not ok)
    return (
        "MARGINAL",
        f"{missed} below threshold -> repeat Phase A with better creator fit",
    )


# --- Counter sources ----------------------------------------------------------


def load_counts_file(path: Path) -> dict[str, int]:
    # utf-8-sig: tolerates the BOM that PowerShell's Out-File prepends on Windows.
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: expected a {{key: count}} JSON object")
    return {str(k): int(v) for k, v in data.items()}


def load_counts_wrangler(namespace_id: str) -> dict[str, int]:
    """Pulls live counters via wrangler (node required). ~200 keys -> fine."""

    def wrangler(*args: str) -> str:
        cmd = ["npx", "wrangler", *args]
        result = subprocess.run(
            cmd, capture_output=True, text=True, shell=sys.platform == "win32"
        )
        if result.returncode != 0:
            raise SystemExit(f"wrangler failed ({' '.join(args)}):\n{result.stderr}")
        return result.stdout

    listing = json.loads(
        wrangler(
            "kv",
            "key",
            "list",
            f"--namespace-id={namespace_id}",
            "--prefix=c|v1|",
            "--remote",
        )
    )
    counts: dict[str, int] = {}
    for entry in listing:
        name = entry["name"]
        counts[name] = int(
            wrangler(
                "kv", "key", "get", name, f"--namespace-id={namespace_id}", "--remote"
            ).strip()
        )
    return counts


# --- Report -------------------------------------------------------------------


def build_report(counts: dict[str, int]) -> str:
    """Renders the gate table + verdict as text (pure; unit-tested)."""
    table, skipped = aggregate(counts)
    lines: list[str] = []
    lines.append("Gate G2-R — organic W1/W2 retention per source (D32/D33)")
    lines.append(
        f"thresholds: W1 >= {GATE_G2R_W1_MIN:.0%} AND W2 >= {GATE_G2R_W2_MIN:.0%}, "
        f"N >= {GATE_G2R_MIN_INSTALLS} installs across >= {GATE_G2R_MIN_SOURCES} sources; "
        f"per-source rates suppressed below k = {K_ANON_MIN_INSTALLS}"
    )
    lines.append("")
    header = f"{'source':<20} {'cohort':<8} {'installs':>8} {'w1_ret':>7} {'w2_ret':>7} {'rate_w1':>8} {'rate_w2':>8}"
    lines.append(header)
    lines.append("-" * len(header))

    def fmt_rate(numerator: int, installs: int) -> str:
        if installs < K_ANON_MIN_INSTALLS:
            return "k<20"  # ADR §2.5: never report a small source's rate alone
        return f"{numerator / installs:.1%}" if installs else "-"

    for (source, cohort), row in sorted(table.items()):
        lines.append(
            f"{source:<20} {cohort:<8} {row['installs']:>8} {row['w1_retained']:>7} {row['w2_returned']:>7} "
            f"{fmt_rate(row['w1_retained'], row['installs']):>8} {fmt_rate(row['w2_returned'], row['installs']):>8}"
        )
    if not table:
        lines.append("(no card counters found)")

    # Aggregate over the ORGANIC cohort only — the gate cohort (paid rows above
    # are informational and never mix in, ADR §2.3).
    organic = {
        src: row for (src, cohort), row in table.items() if cohort == GATE_COHORT
    }
    installs = sum(r["installs"] for r in organic.values())
    w1 = sum(r["w1_retained"] for r in organic.values())
    w2 = sum(r["w2_returned"] for r in organic.values())
    sources = sum(1 for r in organic.values() if r["installs"] > 0)
    rate_w1 = w1 / installs if installs else 0.0
    rate_w2 = w2 / installs if installs else 0.0

    lines.append("-" * len(header))
    lines.append(
        f"{'AGGREGATE':<20} {GATE_COHORT:<8} {installs:>8} {w1:>7} {w2:>7} "
        f"{(f'{rate_w1:.1%}' if installs else '-'):>8} {(f'{rate_w2:.1%}' if installs else '-'):>8}"
        f"   ({sources} sources)"
    )
    if skipped:
        lines.append(f"note: {skipped} non-card key(s) ignored")
    verdict, reason = gate_verdict(installs, sources, rate_w1, rate_w2)
    lines.append("")
    lines.append(f"VERDICT: {verdict} — {reason}")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument(
        "--counts", type=Path, help="{key: count} JSON file (shim output or KV export)"
    )
    source.add_argument(
        "--from-wrangler",
        action="store_true",
        help="pull live counters via npx wrangler",
    )
    parser.add_argument(
        "--namespace-id", help="KV namespace id (required with --from-wrangler)"
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO, format="%(levelname)s %(name)s: %(message)s"
    )
    if args.from_wrangler:
        if not args.namespace_id:
            parser.error("--from-wrangler requires --namespace-id")
        counts = load_counts_wrangler(args.namespace_id)
    else:
        counts = load_counts_file(args.counts)
    print(build_report(counts))


if __name__ == "__main__":
    main()
