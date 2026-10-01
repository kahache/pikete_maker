# API contract — Anonymous signal ingest v1 (`/v1/signals`)

Status: **DESIGN / DRAFT** (no server exists yet — D33 amended, 2026-07-19). Living
contract (stable name; history in git). Companion to the ADR
`docs/architecture/2026-07-19_1000_F2_usage-telemetry-backend-adr.md`, which carries
the rationale, the on-device model, the privacy posture, and the stack options. This
file is the **wire contract only**: endpoint, payloads, auth, limits.

Scope reminder (D2 boundary): this API carries **anonymous aggregate signals only** —
unlinkable cohort-outcome cards with **no identifier**. No photo, no pixels, no
inference, **no per-device id, no per-device rows** ever cross it. Retention is
computed on the device; the server only counts cards.

---

## 1. Design constraints (why the shape is what it is)

- **Genuinely anonymous.** A card carries no `install_id`, no device id, no
  `event_id`, no advertising id, no precise timestamp — **nothing that links two
  sends** or builds a per-device timeline (ADR §2.2). The server cannot re-identify.
- **Fire-and-forget, offline-friendly.** The app buffers cards locally and flushes
  when online. Cards are **at-most-once** via a device-local sent-flag (never
  transmitted); on an ambiguous flush the client prefers **loss over duplication**
  (ADR §5). There is deliberately **no server-side dedup** (a dedup key would be a
  linkable id).
- **No accounts.** No login, no user credential. Auth is a write-only app key.
- **Cheap until volume.** One write endpoint; ~180 cards for all of Phase A. Reads =
  offline aggregation over a counts table (§6), no read API in Phase A.
- **Versioned.** Path-versioned `/v1/`; the card also carries `schema: "g2r/v1"`.

---

## 2. Endpoint — `POST /v1/signals`

Batched ingest of anonymous cards. The **only** endpoint required for Phase A.

### Request

```
POST /v1/signals
Content-Type: application/json
X-Api-Key: <write-only app key>            # see §4
```

```jsonc
{
  "signals": [
    { "schema": "g2r/v1", "kind": "install",
      "source": "creator_x", "cohort": "organic",
      "platform": "android", "app_version": "0.1", "locale": "es" },

    { "schema": "g2r/v1", "kind": "week1",
      "source": "creator_x", "cohort": "organic",
      "retained_w1": true, "analyses_bucket": "3-5", "mode_bucket": "mixed",
      "platform": "android", "app_version": "0.1", "locale": "es" }
  ]
}
```

Notes:
- The batch envelope carries **no** identity — it is just a transport for independent
  cards (a device usually flushes 1 card at a time; batching only matters if several
  queued while offline). Two cards in one batch are **not** implied to share a device.
- **No timestamp in the payload.** Retention windows were already decided on-device;
  the card is the *outcome*, not a raw event. The server may stamp a **day-granular**
  `received_at` for TTL only (§5/§6) — not returned, not used to link.
- Card field catalogue and semantics: ADR §2.2.

### Response

`202 Accepted` — cards counted. Body reports how many were accepted vs rejected (no
"duplicates" line — dedup is deliberately impossible, §1):

```jsonc
{ "accepted": 2, "rejected": 0 }
```

Per-card rejection (bad `schema`/`kind`, unknown `source` shape, oversized) is
**non-fatal**: valid cards in the same batch still count. The client treats any `2xx`
as "flush succeeded, clear these from the queue and set their local sent-flags".

### Status codes

| Code | Meaning | Client action |
|---|---|---|
| `202 Accepted` | cards counted (fully or partially) | clear flushed cards; set local sent-flags |
| `400 Bad Request` | malformed body / bad card schema | drop the batch (don't retry malformed); log locally |
| `401 Unauthorized` | missing/invalid `X-Api-Key` | drop; not user-recoverable |
| `413 Payload Too Large` | body over the cap (§5) | split and retry smaller |
| `429 Too Many Requests` | rate-limited (§5) | back off per `Retry-After`; keep cards queued |
| `5xx` | server/transient | **prefer dropping over blind retry** — a retry may double-count (no dedup). Retry **at most once** after backoff, then give up (accept loss, ADR §5) |

**Notice/consent gate:** the client sends **nothing** unless the telemetry notice
outcome permits it (opt-out off). See `docs/legal/`.

---

## 3. No idempotency / no ordering (by design)

- **No dedup key.** A card has no id; the server cannot and does not deduplicate.
  At-most-once is enforced **client-side** (local sent-flag), erring toward loss.
- **No ordering.** Cards are independent outcomes; there is no per-device sequence to
  order. Aggregation is pure counting (§6).

This is the deliberate cost of anonymity (ADR §5): a little counting noise in exchange
for genuine unlinkability. Coarse buckets + N≥60 absorb it.

---

## 4. Auth

- **Write-only app key** in `X-Api-Key`, shipped in the app. Honest caveat: a key
  shipped in a client **is not a real secret** — it can be extracted. It is a low bar
  against casual spam, not a determined actor. The real protections are
  **rate-limiting (§5)** and the fact that the data is **anonymous, low-cardinality,
  and low-value** (no account, no PII, no per-device rows to leak).
- No user auth, no OAuth, no tokens — there is no account model.
- **Not chosen for Phase A (over-built):** request signing / attestation. A Phase-B
  hardening step only if card-spam ever becomes real (spam can only inflate counts;
  the k-suppression + per-source sanity checks catch gross anomalies).

---

## 5. Rate-limiting & abuse basics

- **Per-IP** token bucket (there is no `install_id` to bucket on now). `429` +
  `Retry-After` on exceed; the client keeps cards queued.
- **Size caps:** body ≤ **32 KB**; ≤ **50 cards/batch** (a real device sends 1–3 over
  its lifetime; a big batch is suspicious). Over-cap ⇒ `413`.
- **Schema allow-listing:** reject cards whose `schema`/`kind` or field shapes aren't
  the known set (counted, dropped) — keeps the counts table clean and forward-compat.
- **Bucket allow-listing:** `analyses_bucket`, `mode_bucket`, `cohort`, `platform`
  must be from the fixed enums; free-form values are rejected (prevents a rare-value
  fingerprint sneaking in).
- **IP is transient:** used for the rate-limit bucket, then dropped / truncated /
  hashed — never stored as a long-lived field (ADR §6, `docs/legal/`).

---

## 6. Storage & reads (Phase A = offline aggregation, no read API)

One append-only **counts** table; each row is one anonymous card (no id column):

```
signals(
  kind            text,     -- install | week1 | week2
  source          text,     -- creator/campaign label
  cohort          text,     -- organic | paid
  retained_w1     boolean,  -- week1 cards only
  analyses_bucket text,     -- week1 cards only (coarse enum)
  mode_bucket     text,     -- week1 cards only
  returned_w2     boolean,  -- week2 cards only
  platform        text,
  app_version     text,     -- coarse (major.minor)
  locale          text,     -- coarse (language)
  received_at     date      -- DAY granularity, TTL only; NOT used to link
)
-- NO install_id, NO event_id, NO row-level identity.
-- indexes: (source, kind, cohort)
-- retention: raw card rows TTL 90-180 days, then aggregate-only (ADR §6, docs/legal/)
```

**G2-R is computed offline** from this table (ADR §2.3) — a short `GROUP BY source,
cohort` job, same pattern as `cv_core/tools/*_battery.py`. **No read/aggregation
endpoint ships in Phase A.** Per-source rates are **suppressed below k≥20** installs
at report time (ADR §2.5).

**Phase B (deferred):** an admin-authenticated read (e.g. `GET /v1/cohorts` →
per-source `{installs, rate_w1, rate_w2}` with k-suppression) behind a **separate
admin key** (never the write key). Not built now.

---

## 7. What this contract deliberately excludes

- No endpoint receives an image or any pixel data (D2).
- **No identifier of any kind** on a card (no install/device/event id) — the core
  anonymity guarantee.
- No per-device rows, no per-device timeline, no server-side dedup.
- No user/account/profile endpoints (no account model).
- No read/dashboard API in Phase A (offline aggregation).

Changes to this contract are additive within `/v1/`; a breaking change opens `/v2/`
and the app negotiates by path. The stack that serves this contract is a **D-pending**
(ADR §4) — the anonymous-card model makes a tiny webhook the cheapest fit.
