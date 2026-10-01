# F2 — Telemetry stack: pros/cons decision aid (CEO D-pending)

Date: 2026-07-19 · Phase: F2 · Author role: Backend/System Architect
Status: **DECISION AID — the pick is a CEO D-pending, this doc does NOT lock it.**
Extracted from the ADR
`docs/architecture/2026-07-19_1000_F2_usage-telemetry-backend-adr.md` (§4), **updated
for the amended anonymous-aggregate model** (D33 amended). Wire contract:
`docs/api/telemetry-ingest-v1.md`.

> **Why this exists:** the telemetry sink (D33) is a **pre-requisite of the D32
> Phase-A creator seeding** — you cannot measure gate **G2-R** (organic W1/W2
> retention per creator) without it. This is the side-by-side so the CEO can pick.
> Constraint from D2/§8: **~0 marginal cost until real volume, no lock-in,
> EU/RGPD-friendly, minimal ops.** Inference stays on-device regardless of the pick —
> this only concerns where the **anonymous aggregate cards** land.
>
> **What changed:** the amended design sends **~180 anonymous, unlinkable cards for all
> of Phase A** (not a per-device event stream). That **widens the cheap end** — a tiny
> webhook now beats a full analytics tool, and there is **no per-device store to
> secure** in any option.

---

## 1. The options (one line each)

- **A′ — Tiny webhook / form sink (NEW, cheapest).** A single serverless function
  (Cloudflare Worker / Vercel) — or even a form/webhook to a Google Sheet (Apps
  Script), Airtable, or a KV — that appends anonymous cards to a counts table. No
  analytics SDK.
- **A — Managed EU privacy-first tool.** PostHog Cloud EU / Umami / Plausible. Each
  card = one anonymous event in their store + dashboards.
- **B — Own serverless ingest + managed Postgres (EU).** The `POST /v1/signals`
  endpoint into Supabase or Neon (free tier, EU). You own the counts table + SQL.
- **C — Self-hosted OSS analytics / tiny FastAPI on a VPS.** Umami/Plausible
  self-hosted or a minimal FastAPI on a ~€5/mo VPS.

---

## 2. Comparison table

| Criterion | **A′ — Tiny webhook/form** | **A — Managed EU tool** | **B — Own serverless + Postgres** | **C — Self-host / VPS** |
|---|---|---|---|---|
| **Build effort** | **Lowest** — one tiny handler, or a no-code form | Low — drop in SDK/endpoint | Low-medium — one function + the counts schema | Medium — stand up + configure |
| **Ops effort** | **Minimal** — serverless/no-code, nothing to run | None (vendor runs it) | Low (serverless + managed DB) | **Highest** — patch/back up/monitor |
| **€ at Phase-A (~180 cards)** | **€0** | **€0** (free tier) | **€0** (free tiers) | **~€5/mo** (VPS not €0) |
| **€ at Phase-B scale** | €0–low (still tiny volume: aggregates, not events) | €0 → paid past big free tiers | **≈€0–low** | Flat ~€5–20/mo |
| **Data ownership** | **Full** (your sheet/KV/file) | Vendor holds raw; export available | **Full** — your Postgres | **Full** — your disk |
| **Lock-in** | **Lowest** — trivial to move a counts table | Medium (dashboards/event model theirs); OSS lower | **Lowest** — plain SQL | Low (OSS), tied to your box |
| **EU / RGPD posture** | **Best-simple** — **no third-party analytics processor**; anonymous cards, EU host | **Good** if EU region + DPA; **avoid GA4/Firebase** (US transfer) | **Good** — you're the only processor; simplest DPA story | **Best on paper** — no third party |
| **Time-to-first-data** | **Fastest** (an hour) | Fast (hours) | Days (write + deploy) | Days-plus (provision + harden) |
| **APK weight** | **Tiny** (plain HTTPS POST, no SDK) | Heavier if a full SDK (PostHog); Umami/Plausible tiny | **Tiny** (plain POST) | Tiny (plain POST) |
| **Fit for the anonymous-card model** | **Ideal** — it's just a counts table | **Overkill** — per-user machinery unused | Good — SQL over counts | Overkill unless scale |
| **Migration path** | Export CSV → import to B | Export → import to B | **Is** the Phase-B target | Rehome container/DB |

---

## 3. Migration path (why starting on A′ is not a trap)

The app talks to **our own wire contract** (`POST /v1/signals`, anonymous cards)
through a single seam (`NetworkAnalyticsService`-style). The card shape is
**sink-agnostic** (ADR §2.2): the same anonymous card maps to a Sheet row, a KV entry,
a PostHog event, or a Postgres row. So:
- **A′ now, B later:** if Phase B wants SQL cohorting, stand up B behind the *same*
  `/v1/signals` shape and flip the seam's base URL — **one line in `app.dart`**, call
  sites untouched. Export the Phase-A counts table (CSV) and import once.
- The only switching cost is re-homing a **counts table** — trivial at ~180 rows.

No option bends the schema toward a vendor, because there's no vendor-specific identity
model to bend (there's no id at all).

---

## 4. Ranked recommendation (per phase — CEO decides, NOT locked)

**Phase A (thermometer, ~60 installs / ~180 anonymous cards — measure G2-R):**
1. **A′ — Tiny webhook / form sink.** €0, fastest, **no third-party analytics
   processor** (cleanest RGPD story), no APK SDK weight, no per-device store to secure.
   The anonymous-card model makes a full analytics backend unnecessary. **Recommended.**
2. **A — Managed EU tool** — fine if the CEO wants ready-made dashboards; its per-user
   machinery is unused, so it's overkill but harmless (EU region, no GA4/Firebase).
3. B / C — **over-built for 180 cards.** Don't.

**Phase B (funded scale — paid cohort, post-payment retention, control group):**
1. **B — Own serverless + Postgres (EU).** Worth it when you want richer anonymous
   counters + SQL cohorting + a control-group comparison; no lock-in; still ~€0 until
   real volume; tiny APK cost. (Still **no per-device rows** — anonymity holds.)
2. A′ — may still suffice if Phase-B analysis stays simple counts.
3. C — only for a strong data-sovereignty reason; otherwise the ops tax isn't worth it.

**Net:** lean **A′ for Phase A, B for Phase B**, one-line seam swap between them. This
is a **D-pending** for the CEO — pick the Phase-A sink (and whether Phase B graduates
to B) and I'll pin the wire adapter to it.

---

*Design snapshot. The stack decision, once made, is recorded as a new D-number in
PRD §10; until then D33 explicitly leaves it open.*
