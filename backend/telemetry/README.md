# Telemetry sink — anonymous G2-R cards (D33 amended · stack A′)

The Phase-A sink for the anonymous outcome cards that measure gate **G2-R**
(organic W1/W2 retention per creator source, D32). One Cloudflare Worker +
Workers KV, **free tier, €0 at Phase-A volume** (~180 cards total vs free
limits of 100k requests/day and 1k KV writes/day — headroom of orders of
magnitude; the only way this ever costs money is a sustained flood, which the
rate limit caps first).

- Wire contract (the law): `docs/api/telemetry-ingest-v1.md`
- Rationale / privacy model: `docs/architecture/2026-07-19_1000_F2_usage-telemetry-backend-adr.md`
- Stack choice (A′ ratified by the CEO 2026-07-20): `docs/architecture/2026-07-19_1400_F2_telemetry-stack-pros-cons.md`

```
backend/telemetry/
├── worker/               # the deployable Cloudflare Worker
│   ├── wrangler.toml     #   config (KV binding placeholder)
│   └── src/worker.js     #   POST /v1/signals — validate, rate-limit, count
├── report/
│   └── g2r_report.py     # gate table + PASS/MARGINAL/FAIL verdict
└── local/                # node-less test path (this PC has no node)
    ├── shim_server.py    #   Python mirror of worker.js (keep in sync!)
    └── test_ingest.py    #   contract test suite (11 tests, stdlib only)
```

## How anonymity is enforced server-side

The server is designed so it **cannot** hold identifying data even if a client
tries to send it:

1. **Strict per-kind field allow-list.** A card may contain exactly the
   contract's fields for its `kind` — nothing more, nothing less. Any extra
   field ⇒ the card is rejected; id-shaped names (`*_id`, `uuid`, `token`,
   `timestamp`, `device*`, …) are flagged `identifier_refused` explicitly.
2. **Enum/pattern allow-listing of values.** `cohort`, `platform`,
   `analyses_bucket`, `mode_bucket` are fixed enums; `app_version` must be
   `major.minor`; `locale` language-only; `source` a short lowercase slug. A
   rare free-form value can't become a fingerprint.
3. **Pure counters, no rows.** Storage is `{card-field-tuple + ISO week}` → n.
   No row per card, no receipt time finer than the ISO **week** (coarser than
   the contract's day-granular allowance). Counters expire after 180 days
   (contract §6 retention).
4. **No dedup key, by design.** A re-sent card just increments (documented
   noise, ADR §5). IPs are only touched as a truncated (/24 or /48)
   rate-limit bucket that self-expires in 120 s.

KV vs D1: KV chosen — zero schema/migrations, one command to create. Its
read-modify-write increments are not atomic, but at Phase-A volume the
collision probability is negligible and the ADR already accepts
low-single-digit counting noise. Phase B graduates to D1/Postgres (stack
option B) behind the same contract if concurrency/SQL ever matter.

## Local testing (no cloud account, no node)

```powershell
# From the repo root — full contract suite against the Python shim:
.venv\Scripts\python.exe backend\telemetry\local\test_ingest.py
# -> 11 passed ... VERDICT: ALL PASS

# Or run the shim as a live local endpoint (e.g. for the app pointing at
# http://10.0.2.2:8787 from an emulator):
.venv\Scripts\python.exe backend\telemetry\local\shim_server.py --port 8787 --api-key test-key
```

The shim mirrors `worker.js` rule-for-rule. Once node exists, the same suite
runs against the real Worker: `npx wrangler dev` in `backend/telemetry/worker/`,
then `python backend\telemetry\local\test_ingest.py --url http://127.0.0.1:8787 --api-key <key>`.

## Deploy (CEO, one time, ~15 min)

Prereqs: install Node.js LTS (nodejs.org) — it brings `npx`. Everything below
runs from `backend/telemetry/worker/`.

1. **Create a free Cloudflare account** (dash.cloudflare.com — free plan, no
   card needed). Workers + KV free tier is enough for all of Phase A.
2. **Login:** `npx wrangler login` (opens the browser).
3. **Create the counters namespace:** `npx wrangler kv namespace create SIGNALS`
   → paste the printed `id` into `wrangler.toml` (replacing
   `REPLACE_WITH_NAMESPACE_ID`).
4. **Set the write-only app key:** `npx wrangler secret put API_KEY` — invent a
   long random string and keep it (the app ships the same value; it is a
   spam bar, not a real secret — contract §4).
5. **Deploy:** `npx wrangler deploy` → prints the URL, e.g.
   `https://piketemaker-telemetry.<account>.workers.dev`.
6. **Hand to mobile-dev:** that URL (goes into the app's `kTelemetryEndpoint`;
   the client appends `/v1/signals`) + the API key. Nothing else changes
   app-side (one-line seam swap, ADR §7).

Optional smoke test against the deployed URL (uses `source=test_smoke`, which
the report excludes from the gate, but it does write `test_*` counters):
`python backend\telemetry\local\test_ingest.py --url https://... --api-key <key>`.

## Reading the gate (G2-R report)

```powershell
# Pull live counters + print the gate table (needs node + wrangler login):
.venv\Scripts\python.exe backend\telemetry\report\g2r_report.py --from-wrangler --namespace-id <id>

# Or from any exported {key: count} JSON (the shim's counts file works as-is):
.venv\Scripts\python.exe backend\telemetry\report\g2r_report.py --counts outputs\telemetry-local\counts.json
```

Output: per source+cohort → installs, w1_retained, w2_returned, rate_w1,
rate_w2 (rates suppressed below k=20 installs, ADR §2.5), the organic
aggregate, and `VERDICT: PASS / MARGINAL / FAIL` per the GTM thresholds
(≥25% W1 AND ≥15% W2, N≥60 across ≥3 sources; W1 <10% with sufficient N =
FAIL/pivot; anything else MARGINAL = repeat Phase A).

## Costs, honestly

- Phase A (~180 cards): **€0.** Workers free plan: 100k requests/day; KV free:
  1k writes/day, 100k reads/day, 1 GB — all thousands of times above need.
- The `workers.dev` URL is free (no domain needed).
- Phase B at real scale: still ~€0 on this design; if richer SQL cohorting is
  wanted, D1/Postgres (stack option B) is also free-tier at that volume.
