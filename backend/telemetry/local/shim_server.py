"""Local shim of the PiketeMaker telemetry Worker (no node/wrangler needed).

MIRROR of ``backend/telemetry/worker/src/worker.js`` — same wire contract
(``POST /v1/signals``, docs/api/telemetry-ingest-v1.md), same validation
rules, same counter-key format, same status codes. It exists because this PC
has no node toolchain: it lets ``test_ingest.py`` exercise the exact ingest
logic with the stdlib only. KEEP IN SYNC with worker.js; the shared test
suite is the sync check.

Differences vs the Worker (deliberate, local-only):
- Counters persist to a JSON file (``{counter_key: n}``) instead of KV; the
  file is directly consumable by ``backend/telemetry/report/g2r_report.py``.
- Rate-limit state is in-memory (per-process), no TTLs (a run is short-lived).
- The API key comes from ``--api-key`` instead of a Worker secret.

Usage (any Python >= 3.10, stdlib only):
    python backend/telemetry/local/shim_server.py --port 8787 \
        --counts-file outputs/telemetry-local/counts.json --api-key test-key
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import time
from collections import Counter
from datetime import UTC, date, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

log = logging.getLogger("telemetry.shim")

# --- Wire-contract constants (docs/api/telemetry-ingest-v1.md) — mirror worker.js

SIGNALS_PATH = "/v1/signals"
CARD_SCHEMA = "g2r/v1"
MAX_BODY_BYTES = 32 * 1024  # contract §5 body cap -> 413
MAX_CARDS_PER_BATCH = 50  # contract §5 batch cap -> 413
RATE_LIMIT_PER_MIN = 30  # generous NAT allowance, kills naive floods

# Fixed enums (ADR §2.2) — free-form values are rejected, never stored.
KINDS = frozenset({"install", "week1", "week2"})
COHORTS = frozenset({"organic", "paid"})
PLATFORMS = frozenset({"android", "ios"})
ANALYSES_BUCKETS = frozenset({"0", "1-2", "3-5", "6-10", "10+"})
MODE_BUCKETS = frozenset({"outfit", "zapas", "mixed"})

COMMON_FIELDS = (
    "schema",
    "kind",
    "source",
    "cohort",
    "platform",
    "app_version",
    "locale",
)
KIND_FIELDS = {
    "install": (),
    "week1": ("retained_w1", "analyses_bucket", "mode_bucket"),
    "week2": ("returned_w2",),
}

# Id-shaped field-NAME detector (refines the rejection reason only; ANY
# unknown field is refused regardless). Never logs the value.
ID_SHAPED_RE = re.compile(
    r"(^|[_-])(id|uid|uuid|guid|token|key|secret|hash|email|user|device|session"
    r"|ts|time|timestamp|date|referrer)([_-]|$)",
    re.IGNORECASE,
)

_SOURCE_RE = re.compile(r"^[a-z0-9_.:-]{1,64}$")
_APP_VERSION_RE = re.compile(r"^\d{1,3}\.\d{1,3}$")  # major.minor only (coarse)
_LOCALE_RE = re.compile(r"^[a-z]{2,3}$")  # language only (coarse)

FIELD_RULES = {
    "schema": lambda v: v == CARD_SCHEMA,
    "kind": lambda v: v in KINDS,
    "source": lambda v: isinstance(v, str) and bool(_SOURCE_RE.match(v)),
    "cohort": lambda v: v in COHORTS,
    "platform": lambda v: v in PLATFORMS,
    "app_version": lambda v: isinstance(v, str) and bool(_APP_VERSION_RE.match(v)),
    "locale": lambda v: isinstance(v, str) and bool(_LOCALE_RE.match(v)),
    "retained_w1": lambda v: isinstance(v, bool),
    "returned_w2": lambda v: isinstance(v, bool),
    "analyses_bucket": lambda v: v in ANALYSES_BUCKETS,
    "mode_bucket": lambda v: v in MODE_BUCKETS,
}


# --- Pure functions (unit-exercised by test_ingest.py) ------------------------


def validate_card(card: object) -> tuple[bool, str]:
    """Validates one card. Returns (ok, reason) — reason is '' when ok."""
    if not isinstance(card, dict):
        return False, "not_an_object"
    kind = card.get("kind")
    if kind not in KINDS:
        return False, "bad_kind"
    allowed = set(COMMON_FIELDS) | set(KIND_FIELDS[kind])
    for field in card:
        if field not in allowed:
            # The privacy rule, enforced server-side: refuse potential identifiers.
            if isinstance(field, str) and ID_SHAPED_RE.search(field):
                return False, "identifier_refused"
            return False, "unknown_field"
    for field in allowed:
        if field not in card:
            return False, f"missing_field:{field}"
        if not FIELD_RULES[field](card[field]):
            return False, f"bad_value:{field}"
    return True, ""


def counter_key(card: dict, week: str) -> str:
    """Canonical counter key — same format as worker.js counterKey()."""
    head = ["c", "v1", card["kind"], card["source"], card["cohort"]]
    if card["kind"] == "week1":
        head += [
            "t" if card["retained_w1"] else "f",
            card["analyses_bucket"],
            card["mode_bucket"],
        ]
    elif card["kind"] == "week2":
        head.append("t" if card["returned_w2"] else "f")
    return "|".join(
        [*head, card["platform"], card["app_version"], card["locale"], week]
    )


def iso_week(d: date) -> str:
    """ISO-8601 year-week ('2026W29') — same output as worker.js isoWeek()."""
    year, week, _ = d.isocalendar()
    return f"{year}W{week:02d}"


# --- HTTP server --------------------------------------------------------------


class SignalsHandler(BaseHTTPRequestHandler):
    """One instance per request; shared state hangs off the server object."""

    server_version = "PiketemakerShim/1.0"

    # -- helpers

    def _json(self, status: int, obj: dict, extra_headers: dict | None = None) -> None:
        payload = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        for name, value in (extra_headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt: str, *args) -> None:  # route stdlib chatter to logging
        log.debug(fmt, *args)

    # -- methods

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Allow", "POST")
        self.end_headers()

    def do_GET(self) -> None:
        if self.path != SIGNALS_PATH:
            self._json(404, {"error": "not_found"})
        else:
            self._json(405, {"error": "method_not_allowed"}, {"Allow": "POST"})

    def do_POST(self) -> None:
        if self.path != SIGNALS_PATH:
            self._json(404, {"error": "not_found"})
            return
        if self.headers.get("X-Api-Key") != self.server.api_key:  # fail closed
            self._json(401, {"error": "unauthorized"})
            return

        # Rate limit: per-client-IP counter per wall-clock minute (in-memory).
        bucket = (self.client_address[0], int(time.time() // 60))
        self.server.rate_hits[bucket] += 1
        if self.server.rate_hits[bucket] > RATE_LIMIT_PER_MIN:
            self._json(429, {"error": "rate_limited"}, {"Retry-After": "60"})
            return

        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY_BYTES:
            self._json(413, {"error": "payload_too_large"})
            return
        raw = self.rfile.read(length)

        try:
            body = json.loads(raw)
        except (json.JSONDecodeError, UnicodeDecodeError):
            self._json(400, {"error": "malformed_json"})
            return
        if (
            not isinstance(body, dict)
            or set(body) != {"signals"}
            or not isinstance(body["signals"], list)
        ):
            self._json(400, {"error": "bad_envelope"})
            return
        if len(body["signals"]) > MAX_CARDS_PER_BATCH:
            self._json(413, {"error": "too_many_cards"})
            return

        # Per-card validation is NON-FATAL (§2); NO dedup by design (§3) — a
        # re-sent card increments again (accepted counting noise, ADR §5).
        week = iso_week(datetime.now(UTC).date())
        accepted = rejected = 0
        for card in body["signals"]:
            ok, reason = validate_card(card)
            if not ok:
                rejected += 1
                log.info(
                    "card_rejected reason=%s", reason
                )  # reason only, never the payload
                continue
            self.server.counts[counter_key(card, week)] += 1
            accepted += 1
        self.server.persist_counts()
        self._json(202, {"accepted": accepted, "rejected": rejected})


class ShimServer(ThreadingHTTPServer):
    """HTTP server + counter store persisted as a plain {key: n} JSON file."""

    def __init__(self, addr: tuple[str, int], api_key: str, counts_file: Path):
        super().__init__(addr, SignalsHandler)
        self.api_key = api_key
        self.counts_file = counts_file
        self.rate_hits: Counter = Counter()
        self.counts: Counter = Counter()
        if counts_file.exists():
            self.counts.update(json.loads(counts_file.read_text(encoding="utf-8")))

    def persist_counts(self) -> None:
        self.counts_file.parent.mkdir(parents=True, exist_ok=True)
        self.counts_file.write_text(
            json.dumps(dict(self.counts), indent=1), encoding="utf-8"
        )


def main() -> None:
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--port",
        type=int,
        default=8787,
        help="listen port (default 8787, like wrangler dev)",
    )
    parser.add_argument(
        "--api-key", default="test-key", help="expected X-Api-Key value"
    )
    parser.add_argument(
        "--counts-file",
        type=Path,
        default=repo / "outputs" / "telemetry-local" / "counts.json",
        help="JSON counter store (default outputs/telemetry-local/counts.json, gitignored)",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO, format="%(levelname)s %(name)s: %(message)s"
    )
    server = ShimServer(("127.0.0.1", args.port), args.api_key, args.counts_file)
    log.info(
        "shim listening on http://127.0.0.1:%d%s (counts -> %s)",
        args.port,
        SIGNALS_PATH,
        args.counts_file,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
