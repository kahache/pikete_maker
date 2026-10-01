# F2 — Usage-telemetry (ADR) — on-device retention + anonymous aggregates for G2-R

Date: 2026-07-19 · Phase: F2 (product gate) · Author role: Backend/System Architect
Status: **DESIGN ONLY** — no server is stood up, no code shipped. Records decision
**D33** (CEO, 2026-07-19) **as amended the same day** to a **minimal, genuinely
anonymous, on-device-retention** model (replacing the earlier pseudonymous
persistent-`install_id` design — see §9 for what changed and why). Wire contract:
`docs/api/telemetry-ingest-v1.md`. Legal scaffolding: `docs/legal/`.

> **Sibling documents:** `docs/PRD.md` (§5 AARRR, §8 unit economics, §9 risks,
> §10 D2/D7/D32/D33) · `docs/growth/2026-07-18_1400_F2_go-to-market-creator-led.md`
> (the redefined gate **G2-R**) ·
> `app/lib/core/analytics/analytics_service.dart` + `.../crash/crash_reporter.dart`
> (the local seams, #4) · issue #96 / #95 (permission & consent copy) ·
> `docs/architecture/2026-07-19_1400_F2_telemetry-stack-pros-cons.md` (stack aid).

---

## 1. Context

The GTM pivot (**D32**) replaced the F&F gate with **G2-R**, measured on the
**organic (unpaid) retention of a real-audience cohort** seeded by micro-creators:

> **G2-R:** of the **organic, non-paid** installers from creator seeding (Phase A),
> **≥ 25 % complete ≥ 3 analyses in week-1 AND ≥ 15 % return in week-2**, with a
> **minimum of ~60 organic installers across ≥ 3 creators**, reported **per
> creator/source** and aggregate.

The app is on-device first (D2) and privacy-forward; the local analytics seams (#4)
fire the right events but store nothing and call nobody, so they cannot answer G2-R.
The CEO's decision **D33** adds telemetry — **but amended the same day** to the
strongest privacy posture that still measures G2-R:

> **D33 (amended):** compute retention **on the device**, and send only **anonymous
> aggregate, fire-and-forget signals** that carry **no identifier able to link two
> sends or to build a per-device timeline.** The server genuinely cannot re-identify
> a device. Colour inference stays 100 % on-device (D2 intact).

### 1.1 The boundary (state this precisely)

| Stays exactly as before (D2 intact) | What D33 adds |
|---|---|
| **Colour inference is 100 % on-device.** Photo, pixels, K-means, segmentation — none of it leaves the phone. | A handful of **anonymous aggregate signals** per install (install + week-1 outcome + week-2 outcome), carrying coarse booleans/buckets and a campaign tag — **no id.** |
| **~0 marginal cost per analysis** (PRD §8). | A **fixed, near-zero** cost for a tiny signal volume (~3 signals × ~60 installs ≈ 180 signals in all of Phase A). Not per-analysis. |
| **The app works fully offline.** | Signals **queue locally and flush when online**; an always-offline user gets the full product and simply contributes no signal. |

Moving inference to a server would break D2 — **we are not doing that.** Only tiny
anonymous aggregates are sent.

---

## 2. The model: on-device retention, anonymous outcome cards

### 2.1 On-device state (never leaves as an identifier)

The app keeps, in **local storage only**, a small retention record:
- `first_open_date` (day-0 anchor),
- `analyses_week1` counter (analyses in `[day0, day0+7)`), with a `mode` split
  (outfit / zapas),
- `returned_week2` flag (any app-open in `[day0+7, day0+14)`),
- `source` (creator/campaign tag captured once at first run, §3) and `cohort_kind`
  (organic / paid).

This is ordinary **local app state** — the same class of thing as "onboarding seen".
It is **used on-device to decide the retention booleans**; it is **never transmitted
as a key** and never leaves the phone.

### 2.2 The signals (unlinkable anonymous cards)

The device emits up to **three independent cards** over an install's first 14 days.
Each card is **self-contained, carries no id, and cannot be linked to the others or
to any device**:

**Card 1 — `install`** (fires at/after first open; establishes the denominator):
```jsonc
{ "schema": "g2r/v1", "kind": "install",
  "source": "creator_x", "cohort": "organic",
  "platform": "android", "app_version": "0.1", "locale": "es" }
```

**Card 2 — `week1`** (fires at end of the week-1 window, ~day 7):
```jsonc
{ "schema": "g2r/v1", "kind": "week1",
  "source": "creator_x", "cohort": "organic",
  "retained_w1": true,            // did ≥3 analyses in week 1
  "analyses_bucket": "3-5",       // COARSE bucket, never a raw count
  "mode_bucket": "mixed",         // "outfit" | "zapas" | "mixed"
  "platform": "android", "app_version": "0.1", "locale": "es" }
```

**Card 3 — `week2`** (fires at end of the week-2 window, ~day 14):
```jsonc
{ "schema": "g2r/v1", "kind": "week2",
  "source": "creator_x", "cohort": "organic",
  "returned_w2": true,
  "platform": "android", "app_version": "0.1", "locale": "es" }
```

Deliberate properties that make re-identification impossible by construction:
- **No `install_id`, no device id, no `event_id`, no advertising id, no precise
  timestamp.** Nothing links card 1 to card 2 to card 3, or any card to a device.
- **Coarse buckets, not raw values:** `analyses_bucket ∈ {"0","1-2","3-5","6-10","10+"}`,
  `app_version` = major.minor, `locale` = language only. Low-cardinality → no
  fingerprint.
- **Staged, not single-shot:** three cards rather than one day-14 card **on purpose**
  — it removes survivorship bias (see §2.4). Staging does **not** re-introduce
  linkage: the cards are still anonymous singletons; only their *aggregate counts* per
  `source` are used.
- **Fire-and-forget:** the server returns `202` and stores the card as an anonymous
  row in a counts table. No acknowledgement is tied to a device.

Everything the local seams already fire (`mode_selected`, `harmony_selected`,
`result_viewed`, `segmentation_degraded`, …) **stays on-device only** for local
debugging — it is **not** shipped as per-device rows. If a future need arises, those
can become additional anonymous aggregate counters, but they are out of scope here.

### 2.3 How G2-R is computed — from counts, not per-device rows

Per `source` S and `cohort` C, over pure counts of anonymous cards:
```
installs(S,C)  = COUNT(cards WHERE kind='install' AND source=S AND cohort=C)
w1(S,C)        = COUNT(cards WHERE kind='week1'   AND source=S AND cohort=C AND retained_w1=true)
w2(S,C)        = COUNT(cards WHERE kind='week2'   AND source=S AND cohort=C AND returned_w2=true)

rate_w1(S) = w1(S,'organic') / installs(S,'organic')
rate_w2(S) = w2(S,'organic') / installs(S,'organic')

G2-R passes iff, over the ORGANIC cohort aggregate:
   rate_w1 ≥ 0.25  AND  rate_w2 ≥ 0.15,
   with installs ≥ 60 across ≥ 3 sources (per-source read suppressed below k, §2.5).
```
Organic vs paid never mix (the `cohort` field). This is a handful of `GROUP BY`
lines over a counts table — **no per-device timeline is ever reconstructed**, and
none is needed. Same offline-aggregation spirit as the `cv_core/tools/*_battery.py`
harnesses: counts in, gate number out.

### 2.4 Why an install card + staged outcome cards (the bias fix)

If we shipped **only** a single day-14 card, every device that churned before day 14
would send nothing → the denominator would miss all early churners and retention
would read **artificially high**. So:
- The **install card** (card 1) counts every install → the honest denominator per
  source, including devices that later churn.
- The **week1 card** fires at day 7 (captures W1 even for devices that uninstall
  between day 7 and 14); the **week2 card** at day 14.
- A device that uninstalls on day 3 sent only its install card → correctly in the
  denominator, absent from both numerators. Bias reduced to the residual noise in §5.

### 2.5 k-anonymity / minimum-cohort suppression (read-side)

- **Client keeps buckets coarse** (above) so no card is a rare combination.
- **Read/report side suppresses** any per-source rate whose `installs(S) < k`
  (recommend **k ≥ 20**, and the gate already demands ≥60 across ≥3 sources). A source
  with a handful of installs is reported only inside the aggregate, never on its own.
- Optional client hardening: a small **random flush jitter** so send-time can't be
  used to cluster cards; strip any precise timing. (Server may keep a **day-granular**
  `received_at` solely for TTL, not in the card and not used to link.)

---

## 3. Source attribution (per-creator, no PII)

Each card carries the `source` (creator/campaign) captured once at first run:
- **Android — Play Install Referrer API:** a per-creator Play link carries a
  `referrer` label (e.g. `utm_source=creator_x`); the app reads it once, stores it
  locally, and stamps it on each card. No PII — it's the label the *link* carried.
- **Fallback / iOS:** a per-creator code / deep-link, or a coarse per-link TestFlight
  campaign. `cohort` is derived from the campaign naming convention (`organic:*` vs
  `paid:*`), keeping the paid/organic split structural.

The creator-link → `source` map is a tiny static table growth keeps; it never holds
follower identities.

---

## 4. Ingest options (CEO D-pending — the anonymous model widens the cheap end)

Because the payload is now **~180 anonymous cards for all of Phase A** (not a
per-device event stream), the cheap options widen. Detailed table:
`docs/architecture/2026-07-19_1400_F2_telemetry-stack-pros-cons.md`. Shapes:

- **A′ — Tiny webhook / form sink (NEW, cheapest).** A single serverless function
  (Cloudflare Worker / Vercel) appending cards to a cheap store (KV, a flat file, a
  Google Sheet via Apps Script, Airtable, or a Formspree-style form). At ~180 cards
  this is ample, **€0**, no analytics SDK (zero APK weight), and there is **no
  per-device store to secure** because there are no per-device rows. **Recommended
  Phase-A sink.**
- **B — Own serverless + managed Postgres (EU).** The §-contract endpoint into
  Supabase/Neon. Worth it only if Phase B wants richer anonymous counters + SQL;
  still no per-device rows.
- **A — Managed analytics tool (PostHog/Umami EU).** Still works (each card = one
  anonymous event) but is now **overkill** for a counts table — its per-user
  machinery is unused. Fine if the CEO wants its dashboards.

**Architect's framing (not a decision):** for **Phase A**, prefer **A′ (a tiny
anonymous-card webhook)** — the anonymous-aggregate model makes a full analytics
backend unnecessary. **Phase B** can graduate to **B** if scale/queries justify it.
The pick stays a **D-pending** for the CEO.

---

## 5. The one real limitation (be explicit)

Anonymous aggregates buy privacy by **giving up two things**, permanently:
1. **No per-user funnels / no per-user debugging.** You cannot follow one user across
   steps, reproduce one user's path, or segment beyond the coarse card fields. G2-R
   does not need this; deep funnel analysis would.
2. **No exact dedup.** With no `event_id`/id, the server **cannot** tell whether two
   `install` cards came from the same device (a reinstall, or a flush that sent twice
   on an ambiguous network result). We therefore **accept residual counting noise:**
   - The client fires each card **at-most-once** using a **local sent-flag** (stored
     on-device, **never transmitted**) and, on an ambiguous flush, errs toward **not
     resending** — i.e. it prefers a small **under**-count (loss) over a **double**
     count. Under-count is roughly uniform across sources, so it barely moves a *rate*.
   - **Coarse buckets** mean small miscounts don't flip a bucket; **N ≥ 60** means a
     few stray cards don't move the percentage past a gate threshold.
   Net: expect low-single-digit % noise on the counts, immaterial to a 25 %/15 % gate
   read. If a source's number sits *right on* a threshold, treat it as MARGINAL and
   re-measure (the GTM already prescribes "repeat Phase A" for marginal reads).

This is the honest trade: **we keep cohort retention (all G2-R needs) and lose
fine-grained per-user analytics + precise dedup.**

---

## 6. Privacy posture (summary — full drafts + lawyer flags in `docs/legal/`)

The amendment **materially lowers** the legal exposure versus the persistent-id design:
- **Transmitted data is genuinely anonymous** (Recital 26 territory): unlinkable
  coarse aggregates, no identifier, no per-device timeline → strong argument it is
  **outside RGPD scope** as personal data (lawyer confirms).
- **On-device counters** are local functional app state (like "onboarding seen"), not
  a tracking identifier shared with third parties.
- **Likely posture shifts from opt-in toward NOTICE (transparency)** — a clear privacy
  notice rather than a hard consent gate — **pending lawyer confirmation** (see
  `docs/legal/rgpd-lite-checklist.md`). We still recommend keeping an **opt-out toggle**
  as good practice and for the trust narrative.
- **Minors blocker is largely dissolved** (the single biggest win): no profiling of
  identifiable minors, no persistent id, no identifiable personal data leaving the
  device (`docs/legal/minors-handling.md`).
- **Copy still changes:** the unqualified "nothing leaves your phone" is replaced by
  the honest split — *"Your photo never leaves your phone; we send anonymous usage
  stats to improve the app, and you can turn it off"* — coordinated with **#95**.

We are **not lawyers**; the drafts state the *likely* posture and keep the "lawyer
must confirm" label throughout.

---

## 7. App-side contract (interface only — mobile-dev owns the code)

- A `NetworkAnalyticsService`-style sink implementing the existing seam
  (`app/lib/core/analytics/analytics_service.dart`) that: (a) maintains the §2.1
  on-device retention record, (b) at the window boundaries composes the anonymous
  cards, (c) **buffers them and flushes fire-and-forget when online**, at-most-once via
  a local sent-flag. It **must never throw and never block a user flow** (the seam's
  existing contract). Notice/consent-gated per the legal outcome.
- Injected exactly like `LogAnalyticsService` today (`app.dart`) — a one-line swap;
  call sites are untouched. Offline-first preserved: an empty/failing queue never
  affects the product.

This ADR defines the interface and the wire contract; it does not choose the Flutter
storage/HTTP libraries (mobile-dev) nor any ML model (ml-engineer).

---

## 8. Consequences

- **Positive:** G2-R is measurable from **anonymous counts**; re-identification is
  impossible by construction (no id, no per-device rows); the legal surface shrinks
  (likely notice-not-consent; minors blocker largely gone); the cheapest ingest is now
  a **tiny webhook** with no per-device store to secure and zero APK SDK weight;
  offline-first and D2's cost model are preserved; the app change stays a one-line seam
  swap.
- **Negative / trade-off (§5):** **no** per-user funnels/debugging and **no** exact
  dedup — accepted, mitigated by coarse buckets + at-most-once client sends + N≥60.
- **Copy/legal (smaller than before):** still reword "nothing leaves your phone"
  (with #95) and publish a telemetry **notice**; keep an opt-out toggle. Lawyer
  confirms the notice-vs-consent posture and the (now much lighter) minors handling.
- **Deferred:** any richer anonymous counters and a Phase-B store are not built now.

---

## 9. What changed from the first D33 draft (and why)

| First draft (superseded) | Amended design (this doc) |
|---|---|
| Persistent **`install_id`** (UUID) on every event | **No id at all** — nothing links two sends |
| **Per-device event rows**, server rebuilds each install's timeline | **On-device** timeline; server sees only **anonymous aggregate cards** |
| `event_id` idempotency key for exact dedup | **No dedup key** (it would be a linkable id); accept residual noise (§5) |
| Rich per-device event stream shipped server-side | Only 3 coarse **cohort-outcome cards**; other events stay **local-only** |
| Pseudonymous personal data → **opt-in consent + minors blocker** | Genuinely anonymous → **likely notice**; **minors blocker largely dissolved** |
| Analytics tool / own backend needed | A **tiny webhook** suffices at Phase A |

Why: the CEO chose the strongest privacy posture that still answers G2-R. Cohort
retention only needs **counts per source**, which anonymous cards provide — so the
persistent identifier (and its legal weight) was unnecessary cost. We keep exactly
what the gate needs and drop what created the RGPD/minors exposure.

---

*Design snapshot (immutable). The decision is D33 (amended) in PRD §10; the stack
pick is a CEO D-pending. Wire contract: `docs/api/telemetry-ingest-v1.md`.*
