"""Telemetry sink test suite — local, no cloud account, no node needed.

Spins the Python shim (shim_server.py, the in-sync mirror of worker.js)
in-process and asserts the wire contract (docs/api/telemetry-ingest-v1.md):

- valid cards -> 202 and the right counters increment;
- id-bearing cards (install_id / device_id / event_id / timestamp...) are
  REJECTED — the server-side anonymity guarantee;
- malformed bodies / bad enums / free-form buckets rejected;
- a duplicate (same card re-sent) just increments — documented noise (ADR §5,
  no dedup by design);
- auth / method / size / rate-limit hygiene;
- the G2-R report (report/g2r_report.py) aggregates and issues
  PASS / MARGINAL / FAIL correctly.

Usage (from the repo root, stdlib only):
    python backend/telemetry/local/test_ingest.py
    python backend/telemetry/local/test_ingest.py --url http://127.0.0.1:8787 --api-key XXX
        # target a running wrangler dev / deployed worker instead of the shim;
        # server-internal assertions (counter file, rate limit) are skipped.
        # Cards use source "test_smoke", which g2r_report.py excludes from the
        # gate — but note each run still writes test_* counters to that store.
"""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
import threading
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))  # shim_server
sys.path.insert(0, str(HERE.parent / "report"))  # g2r_report

import g2r_report  # noqa: E402
import shim_server  # noqa: E402

API_KEY = "test-key"
TEST_SOURCE = "test_smoke"  # excluded from the gate by g2r_report.TEST_SOURCE_RE


def make_card(kind: str = "install", **overrides) -> dict:
    """A valid card of the given kind; overrides may add/replace fields."""
    card = {
        "schema": "g2r/v1",
        "kind": kind,
        "source": TEST_SOURCE,
        "cohort": "organic",
        "platform": "android",
        "app_version": "0.1",
        "locale": "es",
    }
    if kind == "week1":
        card |= {"retained_w1": True, "analyses_bucket": "3-5", "mode_bucket": "mixed"}
    elif kind == "week2":
        card |= {"returned_w2": True}
    card |= overrides
    return card


def post(
    url: str, body: object, api_key: str | None = API_KEY, raw: bytes | None = None
):
    """POSTs a batch; returns (status, parsed_json, headers)."""
    data = raw if raw is not None else json.dumps(body).encode()
    req = urllib.request.Request(
        f"{url}/v1/signals",
        data=data,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    if api_key is not None:
        req.add_header("X-Api-Key", api_key)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read() or b"{}"), dict(resp.headers)
    except urllib.error.HTTPError as err:
        return err.code, json.loads(err.read() or b"{}"), dict(err.headers)


# --- Test cases ---------------------------------------------------------------
# Each returns None on success, raises AssertionError on failure. `ctx` carries
# url/api_key and, in local mode, the live server object + counts file.


def test_valid_batch_counts(ctx):
    status, body, _ = post(
        ctx.url, {"signals": [make_card("install"), make_card("week1")]}, ctx.api_key
    )
    assert status == 202 and body == {"accepted": 2, "rejected": 0}, (status, body)
    if ctx.server:
        counts = json.loads(ctx.counts_file.read_text())
        install_keys = [k for k in counts if "|install|" in k and TEST_SOURCE in k]
        week1_keys = [k for k in counts if "|week1|" in k and TEST_SOURCE in k]
        assert len(install_keys) == 1 and counts[install_keys[0]] == 1, counts
        assert len(week1_keys) == 1 and counts[week1_keys[0]] == 1, counts
        assert "|t|3-5|mixed|" in week1_keys[0], (
            week1_keys
        )  # outcome encoded in the key


def test_duplicate_just_increments(ctx):
    # NO dedup by design (contract §3): the same card re-sent counts again.
    card = make_card("week2")
    for _ in range(2):
        status, body, _ = post(ctx.url, {"signals": [card]}, ctx.api_key)
        assert status == 202 and body["accepted"] == 1, (status, body)
    if ctx.server:
        counts = json.loads(ctx.counts_file.read_text())
        week2_keys = [k for k in counts if "|week2|" in k and TEST_SOURCE in k]
        assert len(week2_keys) == 1 and counts[week2_keys[0]] == 2, counts


def test_id_bearing_cards_rejected(ctx):
    # THE privacy rule: any id-shaped field is refused server-side.
    id_fields = [
        {"install_id": "abc"},
        {"device_id": "abc"},
        {"event_id": "abc"},
        {"uuid": "abc"},
        {"timestamp": 1699999999},
        {"sent_at_ts": 1},
        {"user_email": "a@b.c"},
    ]
    for extra in id_fields:
        status, body, _ = post(
            ctx.url, {"signals": [make_card("install", **extra)]}, ctx.api_key
        )
        assert status == 202 and body == {"accepted": 0, "rejected": 1}, (
            extra,
            status,
            body,
        )


def test_unknown_field_rejected_others_count(ctx):
    # Per-card rejection is non-fatal (§2): the valid sibling still counts.
    batch = {
        "signals": [make_card("install", favourite_colour="mint"), make_card("install")]
    }
    status, body, _ = post(ctx.url, batch, ctx.api_key)
    assert status == 202 and body == {"accepted": 1, "rejected": 1}, (status, body)


def test_bad_values_rejected(ctx):
    bad_cards = [
        make_card("install", schema="g2r/v2"),  # unknown schema
        make_card("install", cohort="friends"),  # free-form cohort
        make_card("week1", analyses_bucket="7"),  # raw count, not a bucket
        make_card("week1", mode_bucket="sneaker"),  # unknown enum
        make_card("install", app_version="0.1.0+10"),  # too precise (fingerprint)
        make_card("install", locale="es-ES"),  # region leaks -> language only
        make_card("install", source="Creator X!"),  # bad source shape
        make_card("week2", returned_w2="yes"),  # wrong type
        {
            "schema": "g2r/v1",
            "kind": "day30",
            "source": TEST_SOURCE,
            "cohort": "organic",
            "platform": "android",
            "app_version": "0.1",
            "locale": "es",
        },  # unknown kind
        {
            k: v for k, v in make_card("week1").items() if k != "analyses_bucket"
        },  # missing field
        "not-an-object",
    ]
    status, body, _ = post(ctx.url, {"signals": bad_cards}, ctx.api_key)
    assert status == 202 and body == {"accepted": 0, "rejected": len(bad_cards)}, (
        status,
        body,
    )


def test_malformed_body_400(ctx):
    status, body, _ = post(ctx.url, None, ctx.api_key, raw=b"{not json")
    assert status == 400 and body["error"] == "malformed_json", (status, body)
    for envelope in (
        {"signals": [], "extra": 1},
        {"cards": []},
        [],
        {"signals": "nope"},
    ):
        status, body, _ = post(ctx.url, envelope, ctx.api_key)
        assert status == 400 and body["error"] == "bad_envelope", (
            envelope,
            status,
            body,
        )


def test_auth_401(ctx):
    for key in (None, "wrong-key"):
        status, body, _ = post(ctx.url, {"signals": []}, key)
        assert status == 401, (key, status, body)


def test_method_and_path_hygiene(ctx):
    req = urllib.request.Request(f"{ctx.url}/v1/signals", method="GET")
    try:
        with urllib.request.urlopen(req) as resp:
            status = resp.status
    except urllib.error.HTTPError as err:
        status = err.code
    assert status == 405, status
    # wrong path
    req = urllib.request.Request(
        f"{ctx.url}/v2/signals",
        data=b"{}",
        method="POST",
        headers={"X-Api-Key": ctx.api_key},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            status = resp.status
    except urllib.error.HTTPError as err:
        status = err.code
    assert status == 404, status


def test_size_caps_413(ctx):
    too_many = {"signals": [make_card("install")] * 51}
    status, body, _ = post(ctx.url, too_many, ctx.api_key)
    assert status == 413, (status, body)


def test_rate_limit_429(ctx):
    # Local-only (would pollute/trip a shared deployment). Runs LAST: it
    # exhausts the per-IP budget on purpose, then clears it.
    ctx.server.rate_hits.clear()
    saw_429 = retry_after = None
    for _ in range(shim_server.RATE_LIMIT_PER_MIN * 2 + 5):
        status, _, headers = post(ctx.url, {"signals": []}, ctx.api_key)
        if status == 429:
            saw_429, retry_after = True, headers.get("Retry-After")
            break
    assert saw_429 and retry_after == "60", (saw_429, retry_after)
    ctx.server.rate_hits.clear()


def test_g2r_report_aggregation_and_verdicts(ctx):
    # Pure-function checks on the report (no HTTP): counts in, verdict out.
    week = "2026W29"
    mk = shim_server.counter_key

    def install(source, n):  # n install cards for a source (organic)
        return {mk(make_card("install", source=source), week): n}

    def week1(source, n_true, n_false=0):
        return {
            mk(make_card("week1", source=source, retained_w1=True), week): n_true,
            mk(
                make_card(
                    "week1", source=source, retained_w1=False, analyses_bucket="1-2"
                ),
                week,
            ): n_false,
        }

    def week2(source, n_true):
        return {mk(make_card("week2", source=source, returned_w2=True), week): n_true}

    # PASS: 3 sources, 70 organic installs, 28% W1, 17% W2. Sources must not
    # match test_* (that prefix is excluded from the gate) — checked below too.
    counts: dict[str, int] = {"rl|127.0.0.0|123": 9}  # stray non-card key -> ignored
    for source, n_inst, n_w1, n_w2 in (
        ("creator_a", 30, 9, 5),
        ("creator_b", 25, 7, 4),
        ("creator_c", 15, 4, 3),
    ):
        for chunk in (
            install(source, n_inst),
            week1(source, n_w1, 2),
            week2(source, n_w2),
        ):
            for k, v in chunk.items():
                counts[k] = counts.get(k, 0) + v
    counts |= install("test_smoke", 500)  # smoke traffic must NOT enter the gate
    report = g2r_report.build_report(counts)
    assert "VERDICT: PASS" in report, report
    assert "test_smoke" not in report, report
    assert "k<20" in report, (
        report
    )  # creator_c has 15 installs -> rate suppressed (ADR §2.5)

    # MARGINAL: N short (only 2 sources / 40 installs).
    verdict, _ = g2r_report.gate_verdict(
        installs=40, sources=2, rate_w1=0.30, rate_w2=0.20
    )
    assert verdict == "MARGINAL", verdict
    # MARGINAL: one threshold missed ("uno sí, otro no").
    verdict, _ = g2r_report.gate_verdict(
        installs=80, sources=3, rate_w1=0.30, rate_w2=0.10
    )
    assert verdict == "MARGINAL", verdict
    verdict, _ = g2r_report.gate_verdict(
        installs=80, sources=3, rate_w1=0.15, rate_w2=0.20
    )
    assert verdict == "MARGINAL", verdict
    # FAIL: W1 far below the floor with sufficient N -> product signal.
    verdict, _ = g2r_report.gate_verdict(
        installs=80, sources=3, rate_w1=0.05, rate_w2=0.02
    )
    assert verdict == "FAIL", verdict


# --- Runner -------------------------------------------------------------------


class Ctx:
    def __init__(self, url, api_key, server=None, counts_file=None):
        self.url, self.api_key, self.server, self.counts_file = (
            url,
            api_key,
            server,
            counts_file,
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--url",
        help="target an external sink (wrangler dev / deployed) instead of the shim",
    )
    parser.add_argument("--api-key", default=API_KEY)
    args = parser.parse_args()

    server = None
    if args.url:
        ctx = Ctx(args.url.rstrip("/"), args.api_key)
    else:
        tmp = Path(tempfile.mkdtemp(prefix="telemetry-test-")) / "counts.json"
        server = shim_server.ShimServer(("127.0.0.1", 0), args.api_key, tmp)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        ctx = Ctx(
            f"http://127.0.0.1:{server.server_address[1]}", args.api_key, server, tmp
        )

    local_only = {"test_rate_limit_429"}
    tests = [
        test_valid_batch_counts,
        test_duplicate_just_increments,
        test_id_bearing_cards_rejected,
        test_unknown_field_rejected_others_count,
        test_bad_values_rejected,
        test_malformed_body_400,
        test_auth_401,
        test_method_and_path_hygiene,
        test_size_caps_413,
        test_g2r_report_aggregation_and_verdicts,
        test_rate_limit_429,  # keep LAST (exhausts the rate budget)
    ]
    passed = failed = skipped = 0
    for test in tests:
        name = test.__name__
        if server is None and name in local_only:
            print(f"[skip] {name} (external target)")
            skipped += 1
            continue
        try:
            test(ctx)
            print(f"[ok]   {name}")
            passed += 1
        except AssertionError as err:
            print(f"[FAIL] {name}: {err}")
            failed += 1
    if server:
        server.shutdown()
    print(f"\n{passed} passed, {failed} failed, {skipped} skipped")
    print("VERDICT:", "ALL PASS" if failed == 0 else "FAIL")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
