# PRD — **PiketeMaker** (previous codename: *ColorFit*)

| | |
|---|---|
| **Author** | Javi Brines (AI Product Manager) |
| **Status** | Draft v1 · **Phases 1 / 2S / 2.5 CLOSED** (G1 passed 2026-07-09 · G2S passed 2026-07-11 · **G2.5 signed 2026-07-18**) · on-device engine validated in BOTH modes (outfit + sneaker), **r14** on the CEO's device (2026-09-29: r13 = robustness, real share, inference off the UI thread, no system permissions — `docs/BACKLOG.md` §A; r14 = share the user's photo + the recommendation in both modes, D37 — §N) · **PARKED** until funding (D32) · **NEXT if funded: Phase 2** — demo → validated product via the creator-led GTM (G2 redefined, D32) |
| **Last review** | 2026-09-29 |
| **Sibling documents** | `CLAUDE.md` (technical context), `README.md` (setup) |

---

## 1. Vision

> Be the discerning mirror for people who dress to express themselves: an app
> that tells you what colors you're wearing, which ones match you, and shows
> you how the best-dressed people on the planet wear them.

**Elevator pitch:** Take a photo of yourself. PiketeMaker separates your clothes
from the background, extracts the real palette of your outfit and proposes
color combinations backed by genuine color theory — and soon, real looks from
people who already dress that way.

**Direction of travel (not v1).** Per-garment segmentation (F2.5, gate G2.5
signed 2026-07-18) is infrastructure, not an endpoint: the same masks are the
hard prerequisite for showing the user their *own* garments rendered in the
recommended palette (F12), for optional skin-tone matching (ICEBOX I4) and for
palette-based product matching (ICEBOX I5). None of those is committed to v1
or to a date; they are recorded here so the sequencing rationale is not lost —
the masks are built once and reused three times.

## 2. Problem and opportunity

**Problem:** hypebeasts and fashion victims invest time and money into
dressing well, but matching colors is a skill few master. Current tools are
either generic (palettes from *any* photo, with no understanding that there's
a person wearing clothes) or human stylists (expensive, slow, not scalable).

**Opportunity:** no app closes the full loop
*my outfit → my palette → palette that matches me → real inspiration*.
The closest competitor (Color Harmony, by Powsty) stops at the second
step and doesn't understand clothing.

## 3. Lean Canvas

| Block | Content |
|---|---|
| **Problem** | Matching colors is hard; palette apps don't understand outfits; stylists don't scale |
| **Segments** | Hypebeasts 16–30 · fashion victims · streetwear shoppers · (secondary) stylists and personal shoppers |
| **Unique value proposition** | The only app that extracts the palette of *your clothes* (not your photo) and proposes combinations with real reference looks |
| **Solution** | On-device CV: person/clothing segmentation + K-means + color theory + inspiration search |
| **Channels** | TikTok/IG (shareable content: your palette as a story), streetwear communities (Discord, Reddit), ASO |
| **Revenue** | Rewarded video ads (AdMob) + freemium premium |
| **Costs** | Development (own), stores (~€150/year), infra ~0 (on-device) |
| **Key metric** | Completed outfit analyses / week |
| **Unfair advantage** | ~0 marginal cost per analysis (on-device) + own clothing-segmentation pipeline |

## 4. Personas and Jobs-to-be-Done

### Persona 1 — "Dani the Hypebeast" (primary)
19 years old, buys drops, curates every fit, posts on IG.
- **JTBD:** *When I put together a fit to go out or post, I want to validate that the colors match, so I don't risk my image.*
- Sensitive to: speed, app aesthetics, shareability of the result.

### Persona 2 — "Laura the explorer" (secondary)
24 years old, wants to dress better without studying color theory.
- **JTBD:** *When I buy a new garment, I want to know which colors in my wardrobe it combines with, to get my money's worth.*

### Persona 3 — "Álex the stylist" (tertiary, future B2B)
- **JTBD:** *When I advise a client, I want to visually justify the palettes I propose, to close the sale.*

## 5. Metrics

**North Star Metric: completed outfit analyses per week.**
(Captures delivered value: if people analyze, the app delivers; if they share, it grows.)

AARRR funnel:

| Stage | Metric | v1 target |
|---|---|---|
| Acquisition | Installs/week | baseline → measure |
| Activation | % completing 1st analysis < 2 min after opening | > 60% |
| Retention | D7 retention | > 15% |
| Revenue | Rewarded ads watched / analysis | > 0.8 |
| Referral | % analyses shared (story/link) | > 10% |

**Guardrails:** p95 analysis time < 6 s · crash-free > 99.5% · store rating > 4.2.

## 6. Scope and prioritization

### Features (MoSCoW + RICE)

RICE = (Reach × Impact × Confidence) / Effort, quarterly scale, team of 1.

| # | Feature | MoSCoW | R | I | C | E | RICE | Notes |
|---|---|---|---|---|---|---|---|---|
| F1 | Segment person/background | Must | 10 | 2 | 100% | 1 | 20 | ✅ done (GrabCut, cascade) |
| F2 | Garment colors | Must | 10 | 3 | 90% | 2 | 13.5 | v0 done (whole photo); v1 = Phase 2.5 |
| F3 | Outfit palette | Must | 10 | 3 | 100% | 1 | 30 | ✅ done (K-means + weights) |
| F4 | Matching harmonies | Must | 10 | 3 | 100% | 1 | 30 | ✅ done (4 HSV schemes) |
| F2.5 | Clothing segmentation (ML) | Must | 8 | 3 | 70% | 3 | 5.6 | **Differentiator. Not optional.** Gate for F5. **Re-sequenced AFTER F11/Phase 2S (D24)** — the hard ML bet comes after the sneaker MVP that already works |
| F5 | Real matching looks | Should | 8 | 3 | 50% | 4 | 3 | v0 deep-links; v1 own index |
| F6 | Share palette (story) | Could | 7 | 2 | 80% | 1 | 11.2 | **Non-blocking (D25, 2026-07-10):** sharing is NOT the app's core value; parked as a roadmap concept (photo + recommendation mockups ready), does NOT gate G2. #60 downgraded |
| F7 | Analysis history | Could | 5 | 1 | 90% | 1 | 4.5 | Retention. **Re-affirmed by the CEO (2026-07-11, D27):** "save result" → "mis paletas"/"mis recomendaciones" (implies new navigation to reach saved items). Roadmap, explicitly NOT Phase 2S |
| F8 | Rewarded ad during processing | Must (for GA) | 9 | 3 | 80% | 1 | 21.6 | Main monetization |
| F9 | Virtual wardrobe | Won't (v1) | — | — | — | — | — | Future vision |
| F10 | B2B stylists | Won't (v1) | — | — | — | — | — | Explore after PMF |
| F11 | Sneaker/product mode (match STARTING FROM the sneakers) | **Must** | 8 | 3 | 90% | 2 | 10.8 | **PROMOTED from ICEBOX I1 (D24, 2026-07-10).** Split-screen Home (Zapatillas \| Tu outfit); re-sequenced **BEFORE Phase 2.5**. Reuses the current core in **product-mode (no person layers)** — the use case where the algorithm ALREADY excels (clean bg, no skin, no attribution; #56). New = the sneaker screens. **✅ shipped (Phase 2S, gate G2S passed 2026-07-11 D30; split-Home + sneaker flow live in r11)** |
| F12 | Recolor garments in the photo with the proposed palette | Won't (v1) | — | — | — | — | — | See ICEBOX I2. **Hard prerequisite (per-garment masks) is now BUILT** — gate G2.5 signed 2026-07-18; the enabler is no longer speculative, the feature still is. v1 path = classic LAB/HSV hue rotation inside the mask preserving luminance/texture (on-device, cheap); diffusion/GenAI would break the ~0 marginal cost thesis (D2). Needs a visual-quality gate before shipping. **No date committed.** "v6.0" |
| F13 | First-time onboarding tutorial (recommends a photo against a plain single-color background) | **Must** | 10 | 2 | 90% | 1 | 18 | CEO's idea. Double value: activation (guided UX) + de-risks segmentation (plain background ≈ trivial background removal). See D11 |

### Out of scope for v1
Virtual wardrobe, affiliate purchase recommendations, own social features,
photo editing, B2B. Each can be post-PMF roadmap.

## 7. Detailed roadmap

**Now / Next / Later** format mapped to phases with *gates* (measurable exit
criteria). **Demo exception (D15):** the *CV quality* gates (G0) no longer
block progress toward the MVP-demo; they are re-evaluated in Phase 2.5.
The product gate (G2) and profitability gate (G5) remain alive.

### ✅ Phase 0 · Algorithm prototype — CLOSED (D15, 2026-07-07; debt fully paid 2026-07-10)
*Original goal: prove that palettes and harmonies are good, locally.*

- [x] Python pipeline: background removal (cascade) → skin filter → K-means → harmonies
- [x] Structured `colorlab` package + 47 unit tests + CLI
- [x] Validation with 1 real photo (LV runway)
- [x] Merge perceptually close clusters (LAB space) — issue #5
- [~] Validation batch: 8/10 curated + batch-200 (automatic KO 62.5%).
      Bugs B1-B8 filed as issues #20-#29
- [x] Skin filter review with dark skin tones (adaptive filter, #20:
      samples the subject's tone in LAB instead of the universal YCbCr range)

**Gate G0 — NO LONGER BLOCKS (D15).** The 62.5% KO comes mostly from
clothing segmentation (isolating the garment), which per D1 belongs to Phase
2.5, not the MVP. The MVP uses the whole-photo palette + harmonies, which
already work and have tests.
**The quality debt that moved to the Phase 2 parallel track was fully PAID by
2026-07-10:** #21 canvas mode ✅ · #22 chroma neutrality ✅ · #29 closed as
no-go (the 3-round heuristic chapter: #29/#44 no-gos, #48 border-bg WIN) ·
#23 measured (before/after on Fashionpedia + the 31 CEO selfies, 0 regressions)
and closed by the #56 CEO review — residual error = attribution, owned by
Phase 2.5 (D21). Nothing from Phase 0 remains open.

### ✅ Phase 1 · Installable MVP demo (on-device, Dart) — CLOSED (G1 passed 2026-07-09)
*Goal: an APK the CEO installs on his Android, works 100% offline, to show
around and seek funding/partners. Color engine reimplemented in Dart
(D15) — no backend, no network.*

- [x] **On-device color core in Dart** (#32): own K-means + LAB merging
      + chromatic ranking + harmonies, with **demonstrated parity** against
      `colorlab` (golden fixtures generated from Python + mirror tests,
      43/43). 297 ms/analysis. GrabCut NOT ported (Phase 2.5, per plan)
- [x] **5-step skeleton (D12)** complete (#13): F13 first-time tutorial
      with first-launch gate, real photo (camera/gallery), analyzing state
      with ad slot (no-second-ad rule), result faithful to the mockup, E1/E3/E4
- [x] Local Android toolchain (#36) and **first release APK installed on
      the CEO's Android (2026-07-08): works offline, verdict "success"**
- [x] **Hero photo set** (#33): 31 real selfies evaluated (CEO + family,
      unstaged); hero set = **3 photos by CEO decision** (selfie01 mustard
      hoodie, selfie04 burgundy top, selfie21 blue blazer) — "no more staged
      photos, mark the ones that work and close it". Real-world buckets
      documented; the recipe lives in the tutorial (F13) and the curation
      report
- [x] APK **signed** with own keystore (#34): release signing verified
      against the keystore fingerprint; RELEASE-SIGNING.md
- [x] Production logo assets + usage manual (#31): full package incl.
      launcher icons (dot-centered per #50), story watermark, OFL fonts
- [x] Language chore done (#28/D17); formal Flutter ADR remains off the
      critical path (D4 already decides it)

**Gate G1 (demo): ✅ PASSED (2026-07-09).** The CEO installed the signed APK
(r6), completed photo→palette→harmonies repeatedly on a real device, offline,
without crashes, across 6 builds of device QA (3 bugs found and fixed in the
process); the hero photos "look good" and the visual identity was ratified
screen by screen. Evidence: docs/qa/GATE-REVIEWS.md (G1 entry).

### 🟡 NOW — Phase 2 · From demo to validated product (beta)
*Goal: turn the demo into something 10-20 hypebeasts actually use, and
decide whether there's a product. The improvement engine is the cycle: fix in
`colorlab` (canonical, with tests) → re-port to Dart via golden fixtures
(mechanics already in place from Phase 1, low marginal cost).*

- [x] **CV debt recalibrated with the CEO's ground truth AND executed
      (2026-07-09/10)**: manual review pinned the real problem = attribution,
      then the whole batch landed in Python + Dart (fixtures + parity):
      #21 canvas ✅ · #22 chroma neutrality ✅ · #57 reflection gate (D20) ✅ ·
      #25 GrabCut seed ✅ · #30 perf p95 ✅ · #48/#49 border-bg layer (both
      engines, off by default) ✅ · #29 closed no-go
- [x] **#23 · batteries re-run and MEASURED (2026-07-10, closed by #56)**:
      before/after on Fashionpedia + the 31 CEO selfies — #21/#22/#57 route
      correctly to canvas with **0 regressions**; auto-OK slice base = 18/18
      correct (CEO). Residual error = attribution (background/hair/skin),
      owned by Phase 2.5 (D21). Reports: `docs/qa/photo-eval/2026-07-10_*`
- [x] **On-device background removal v1** (person vs background): folded into
      the MediaPipe path (D21) — Selfie Multiclass gives background + skin +
      clothes classes at once, so person/bg and per-garment share one model.
      **Real on-device inference now shipped (flag ON, r11):** verified on the M33
      via the Phase 2.5 spike and the G2.5 measurement. *(Note: the flag-OFF whole-
      photo/outfit fallback still uses the GrabCut cascade by design.)*
- [~] **F6 story sharing — DOWNGRADED to non-blocking (D25)**: sharing is not
      the core value and does NOT gate G2. Export plumbing DONE (#2); **OS share
      sheet shipped in r13** (`share_plus`: a 9:16 story image of the
      recommendation card with the PiketeMaker logo below it, BACKLOG A3).
      **#60 answered by the CEO (2026-09-29):** the story must include the
      **uploaded photo** together with the recommendation — **shipped in r14**
      (D37, BACKLOG N1; builds on the July "Con foto" concept): preview sheet
      with an "Incluir mi foto" switch, outfit AND sneaker results.
      **F5-lite deep-links BUILT and shipped in r11 (#82 CLOSED)**:
      selectable harmony + "Ver looks así" → browser search by color NAMES
      (localized, url_launcher, both result screens, offline SnackBar); deep-links
      only per D3, does not gate
- [~] **Minimal instrumentation** (analyses completed, shared, reopen rate)
      + crash reporting — no backend. **Seams DONE (#4, 2026-07-10)**:
      `AnalyticsService` + `CrashReporter` with local/no-backend defaults, events
      wired (analysis_completed, story_exported, result_viewed, reopen). Real
      backend = one-line swap when a device/SDK is available
- [x] **Usage telemetry for gate G2-R (#96, D33 amended) — BUILT, activation-gated
      (D34).** Both sides shipped deploy-ready but **OFF by default** and **not yet
      live** — it goes live only when the CEO stands up the Cloudflare endpoint and
      Phase A activates (funded creator-led GTM). App side (#98): `app/lib/core/telemetry/`
      — on-device retention + anonymous cards, `kTelemetryEndpoint` EMPTY by default ⇒
      byte-identical to a no-telemetry build (34 tests). Server side (#96 CLOSED, D34):
      `backend/telemetry/` A′ anonymous-card webhook (Cloudflare Worker + KV, free tier,
      11/11 contract tests, server-side anonymity enforcement). **Blocking activation
      pre-reqs (owned by CEO):** deploy the Worker on his Cloudflare account · lawyer
      sign-off on the `docs/legal/` notice copy · reworded "your photo never leaves your
      phone (anonymous usage stats, opt-out)" copy (with #95). Design tied to the funded
      creator-led GTM (D32). **On-device retention + anonymous aggregate signals**
      (no id): the app computes W1/W2 retention locally and sends only unlinkable
      cohort-outcome cards (install + week1 + week2, coarse buckets, `source`,
      organic/paid), from which G2-R is counted per creator. Inference stays 100 %
      on-device (D2 intact). Design DONE (ADR
      `docs/architecture/2026-07-19_1000_F2_usage-telemetry-backend-adr.md` + wire
      contract `docs/api/telemetry-ingest-v1.md` + stack aid `…_1400_…pros-cons.md`);
      **build deferred, phased**: **Phase A** (~60 installs / ~180 cards) = per-creator
      deep-link/Install-Referrer attribution + a **tiny anonymous-card webhook** (do NOT
      build an analytics backend for 180 cards); **Phase B** (funded scale) = own
      serverless+Postgres for post-payment retention. App-side = a
      `NetworkAnalyticsService` swap of the existing seam (buffer-and-flush,
      offline-first preserved; at-most-once, no dedup key). **Legal surface DRAFTED**
      in `docs/legal/` (lawyer-review-required). **Blocking pre-reqs (owned by CEO):**
      stack pick (D-pending), reworded "your photo never leaves your phone" copy + a
      transparency notice/opt-out (with #95), lawyer sign-off (anonymity → likely
      notice-not-opt-in; minors largely dissolved; DPIA screening)
- [x] **E2E flow test on a real device** (#41, `integration_test`) — **DONE and
      EXECUTED on ARM (2026-07-11).** `app/integration_test/app_e2e_test.dart` covers
      what widget tests can't: real shader/rendering (the r3 blank-swatch bug was
      device-only, now pixel-level asserted), real SharedPreferences, both journeys
      (outfit + sneaker/2S), back-nav loops, #47 stack hygiene. **5/5 PASSED on the
      CEO's Galaxy M33** (binding ARM evidence) and 5/5 on an emulator; G1 time budget
      measured on-device (photo→result ~3.9–4.0 s, dominated by the deliberate #55
      window; real engine ≈450 ms AOT). Un-exercised seams (the `image_picker` plugin
      itself, the E1 camera-permission route, the signed-release runtime) are covered
      by the CEO's daily manual use, per the issue
- [x] ~~**Friends & family beta (D24)**~~ **DONE and VOID as a validation
      instrument (D32, 2026-07-18).** The F&F beta was cut (r9), distributed,
      and got **ZERO survey responses**. Diagnosis: **wrong audience** (the
      founder's network is 30-40yo, not the 16-30 hypebeast persona — he knows
      ~2 real ones) + permission-paranoia friction. So it is a **recruitment
      failure, not a product verdict**: the product was never put in front of
      the target persona. **Gate G2 as defined below is therefore VOID.**

**~~Gate G2 (F&F)~~ → REDEFINED (D32).** Old bar (≥40% of F&F testers do ≥3
analyses week-1 + ≥half "on point") is retired — the F&F sample was the wrong
audience, so it can neither pass nor fail the product. **New strategy (D32):
develop on the CEO's criterion; bring real testers only WHEN FUNDED, via a
creator-led go-to-market** (real-segment micro-influencers → paid-trial cohort
→ trap-artist/Spotify amplification), gated by a cheap **organic-retention
thermometer** BEFORE any scale spend (paid usage is a vanity metric; the real
signal is unpaid week-1/week-2 retention of the audience a creator brings in).
The redefined product gate + phased plan live in the GTM strategy doc
(private repo, growth docs). **What this pivot rests on is
already de-risked:** G2.5 (per-garment colour, 84.6%, no skin bias) and G2S
(sneaker base 73.5%) prove the product DELIVERS VALUE; what was unvalidated —
desire/retention with the *right* audience — is exactly what the creator-led
GTM is designed to measure. Also feeds fundraising: a segment-native GTM is far
stronger pitch material than "F&F beta".

### ✅ Phase 2S · Sneaker/product mode MVP — CLOSED (gate G2S passed 2026-07-11, D30)
*Goal: a second entry point where the algorithm ALREADY works. Promoted from
ICEBOX I1 (D24). Split-screen Home lets the user choose **Zapatillas** or **Tu
outfit**; the outfit flow exists, the sneaker flow = new screens on the SAME
engine run in **product-mode** (core WITHOUT the person-specific layers —
no person bg-removal, no skin filter; ICEBOX I5 addendum #2: the core stays
use-case-agnostic, outfit layers are composable on top). Why now, before 2.5:
product photos have a clean background and no skin, so the dominant
outfit-mode error (attribution, #56) simply does not occur — this validates
"the algorithm goes well" in weeks, not the months Phase 2.5 (ML) needs, and
hedges that bet.*

- [x] **[EPIC]** Sneaker/product mode — split-screen Home, sneaker flow, product-mode engine (#70/#61)
- [x] **UX** · Split-screen Home selector (Zapatillas \| Tu outfit) — mockup + spec (D7/D8 brand allowance; layout = Variant A, D26) (#71/#62)
- [x] **UX** · Sneaker flow screens (capture → analyzing → result "combina tu ropa con estas zapas") — mockups + ES copy (D27 inverted-hierarchy result) (#72/#63)
- [x] **Mobile** · Home split-screen entry point + routing (outfit = existing, sneaker = new) (#73/#64)
- [x] **Mobile** · Sneaker capture screen (reuse the camera/gallery capture component) (#74/#65)
- [x] **Mobile** · Sneaker result screen (recommendation framing: sneaker base → clothing palette that matches) — `app/lib/features/sneaker/sneaker_result_screen.dart` (#75/#66)
- [x] **Engine** · Product-mode path: run the core WITHOUT person layers (Python canonical flag + Dart parity), do-no-harm to outfit mode (#76/#67)
- [x] **Mobile** · Sneaker-mode analytics events (`mode_selected`, `sneaker_analysis_completed`) + tests (#77/#68)
- [x] **QA** · Product-photo eval battery (validate extraction on sneaker photos, commercial-safe sources) + sneaker-flow tests — `cv_core/tools/product_battery.py` (#78/#69)

**Gate G2S — PASSED 2026-07-11 (D30), on base-correctness.** Original bar (D28):
≥70% of the product-photo eval set with base correct + 100%-product palette. The
first real measurement (99 own sneaker photos; the 49-photo clean `phone` set is
the gate) taught us the **palette-purity column is capped by Phase 2.5** — the
residual errors are white-sole-vs-white-floor, skin and background, i.e. **spatial
separation, impossible by colour** (rounds: 2/57 → 21/57 after #84 background
suppression; palette stuck at 42.9% on the clean 49). **Base correctness, which is
what actually drives the recommendation** (the harmony base is never a neutral,
decision #6, and the CEO accepts the missing white), reached **73.5% ≥ 70% → gate
PASSED (D30).** Palette purity (100%-product) is re-designated a **Phase 2.5
quality target**, not a 2S blocker. Report:
`docs/qa/photo-eval/2026-07-11_1500_F2S_gate-g2s-primera-medida.md`. **Remaining
for the beta build:** Dart parity of the CV fixes (#84 multi-edge suppression +
neutral-lightness protection) so the on-device engine matches, then r9 (with the
#83 photo-source tutorial). Ships inside the same friends & family beta as outfit
mode.

### ✅ Phase 2.5 · ML clothing segmentation — v1 SHIPPED · Gate G2.5 SIGNED (2026-07-18)
*Goal: go from "photo palette" to "colors of your garments". The differentiator.
**Re-sequenced (D24) to run after the sneaker MVP (Phase 2S); both are now done.**
This was the harder, longer ML bet for OUTFIT mode. **v1 = person → top/bottom
only (footwear excluded by design, D21 → that use case is the sneaker flow).**
MediaPipe Selfie Multiclass runs on-device; per-garment analysis ("Tu pikete",
ARRIBA/ABAJO) shipped **flag ON in r11** (`kGarmentAnalysisEnabled`) once its three
enabling conditions were all met (per-ABI split #87 · gate G2.5 · M33 latency).
**Scope beyond v1 (deeper per-garment model capacity, footwear) is NOT part of
this phase and remains iceboxed;** the residual "margin" post-process bugs were
measured 2026-07-20 (one display-snap improvement a GO, #100; two NO-GO, #99 not-a-bug
+ #101) and the gate passes without them (GATE-REVIEWS: "bugs 2-4 = optional margin").*

- [x] **Model benchmark DONE (2026-07-10)**: rembg cloth_seg, MediaPipe Selfie
      Multiclass, SegFormer/ModaNet, SCHP, SAM evaluated on per-garment quality,
      size, on-device fit, license → **MediaPipe Selfie Multiclass chosen (D21)**.
      Report: `docs/architecture/2026-07-10_1500_F2.5_segmentation-benchmark.md`
- [x] Criteria applied (per-garment mask quality, model size, mobile latency,
      license). Latency de-prioritized per **D22** (the ad covers it)
- [x] **Split the palette per garment** (top/bottom; footwear excluded, D21 →
      ICEBOX I1). PROVEN in Python on the 31 CEO selfies (**27/31 improved, 0
      worse**), then **SHIPPED on-device**: canonical `colorlab/segmentation.py`
      per-garment layer (#89) + the Dart port (`app/lib/core/segmentation/`,
      `garment_segmenter.dart` / `mediapipe_garment_segmenter.dart`, 8 golden
      fixtures, Python↔device parity pinned) + the "Tu pikete" result screen (#88),
      **flag ON in r11**. Real MediaPipe Selfie Multiclass inference verified on the
      M33 (spike + G2.5 measurement).
- [x] **Own evaluation dataset — BUILT (#90, D23 amended: no new shoots)**: **69
      photos** (31 CEO selfies + 38 visually-curated Fashionpedia), all diversity
      quotas met (skin buckets 41/15/13 vs min 10; mirror-selfie 18/20), MANIFEST.csv
      with anti-anchoring pre-registration columns (`samples/segmentation`, gitignored).
      Diverse skin tones incl. dark (the YCbCr proxy's known weak spot); this is the
      set the G2.5 gate was measured on (no skin bias — dark bucket highest)
- [x] **APK size diet, stage 1 — rollout gate (#87):** bundling the model costs
      **+28.6 MB** on the universal APK (spike
      `docs/architecture/2026-07-14_2235_F2.5_mediapipe-ondevice-spike.md` §5).
      **DONE for the rollout gate:** the **per-ABI split shipped in r11** (arm64 build
      **36 MB**), satisfying the hard rule (**the model never ships in a beta/release
      APK without at least the per-ABI split**). compileSdk 36 folded into the
      Gradle/AGP chore (#79, closed). *Note: issue #87 stays open for stage 2 (full
      AAB diet at store launch — see Phases 6–7).*

*Nice-to-have noted, NOT in scope (CEO, 2026-07-11): interactive segmentation
assist ("tap your garment", Google-Photos-style) → **ICEBOX I6**. Same MediaPipe
stack, but it's a post-2.5 repair fallback (D7/D12: no friction in the default
flow), revisited once the automatic residual error is measured. Its labeling
variant (SAM/GrabCut-assisted annotation) may serve the D23 dataset NOW.*

**Gate G2.5: ✅ SIGNED (2026-07-18).** Criterion: correct per-garment colors on
≥ 80% of the evaluation set (overall and per skin bucket — the §9 bias test),
with latency < 3 s on a mid-range Android. Measured on the D23 set: **base-correct
84.6% (55/65), no skin bias** (dark 84.6 / light 84.2 / medium 85.7) after the
base-selection bug fix (Python + Dart parity); M33 latency **544 ms mean** (worst
761 ms) < 3 s (D22 holds). The three flag-ON conditions all met (#87 split ·
G2.5 · latency). Evidence: `docs/qa/photo-eval/2026-07-18_G2.5-primera-medida.md`,
`docs/qa/GATE-REVIEWS.md`. *(The first raw measurement, 76.8% overall, was a
diagnostic FAIL traced to fixable post-process bugs, not to segmentation; the
signed verdict is the post-fix base-correctness measure.)*

### 🔴 LATER — Phase 3 · Full feature 5 (4–8 weeks)
*Goal: "real people wearing your match" inside the app, legal and cheap.*

- [ ] 1-week spike: result quality via (a) queries to
      Unsplash/Pexels API vs (b) own index with palette embeddings
- [ ] Build the winning option; attribution and licenses in order
- [ ] Ranking by palette similarity (LAB distance between palettes)

**Gate G3:** 60% of searches return ≥ 5 looks the user rates as relevant
(user testing).

### 🔴 LATER — Phase 4 · Production readiness (1–2 weeks)
*The D15 pivot proved there is NO backend on the path: the full analysis
runs on-device. This phase is reduced to the bare minimum needed to publish.*
- [ ] GDPR: the photo never leaves the phone (structural on-device advantage) →
      simple privacy policy + consent copy
- [ ] Product analytics (e.g. PostHog) and crash reporting formalized
- [ ] Minimal backend ONLY if some future feature demands it (today: none)

### 🔴 LATER — Phase 5 · Monetization (2–3 weeks)
- [ ] F8: rewarded video during analysis (AdMob) — the analysis "covers" the ad
- [ ] Freemium: N free analyses/day; premium = unlimited + no ads + history
- [ ] Measure: ads/analysis, real eCPM, premium conversion

**Gate G5 (profitability):** marginal revenue per analysis > marginal cost
per analysis (with on-device, cost ≈ 0 → gate = stable effective eCPM).

### 🔴 LATER — Phases 6–7 · Launch
- [x] **Multilingual app copy (D18, AMENDED 2026-07-15 — extended from
      bilingual ca-ES to 7 locales, CEO decision):** full gen-l10n
      infrastructure landed (ARB files in `app/lib/l10n/`, device-driven
      locale with es fallback, no manual picker yet). **es = canonical**
      (pre-i18n copy verbatim, byte-identical — widget suite + es ARB pins
      are the regression net); **en/ca/fr = full voice adaptation** (hypebeast
      register per market; ca stays the hard-launch language of the original
      D18); **zh/ko/ja = complete but DRAFT quality — GATED on native review
      before launching in those markets** (each ARB carries an `@@x-status`
      DRAFT header; same gate applies to their color-vocabulary rows in
      `color_names.dart` and the CJK search-query patterns in
      `looks_search.dart`). The #82 looks query localizes both color words
      and pattern (CJK: colors first, coordination noun last). Still open for
      launch: native CJK review, growth/UX read of en/ca/fr on device, store
      listings per market, locale picker decision (device-only today)
- [ ] Google Play: ASO listing, screenshots, closed → open testing → production
- [ ] **APK size diet, stage 2 — full diet (#87):** AAB with per-device
      delivery, on-demand/deferred model delivery evaluated against D2
      (offline), fp16 model conversion decision (+re-eval vs the Python
      reference masks), asset compression audit
- [ ] iOS: Flutter build, platform tweaks, App Store ($99/year)
- [ ] Growth loop: shared palette → watermark with download link

## 8. Business model (unit economics)

The detailed unit-economics table (ad eCPM assumptions, break-even math) lives
in the private repo. Public summary: on-device inference keeps the marginal
cost per analysis at ~ EUR 0 — that is the profitability condition — and fixed
costs are of the order of store fees plus a domain. Profitability dies if
(a) inference moves to a GPU server or (b) look-search relies on pay-per-query
APIs; both are committed architecture decisions of the project (§10, D2).

## 9. Risks and mitigations

| Risk | Prob. | Impact | Mitigation |
|---|---|---|---|
| Palettes don't wow (CV quality) | Medium | Critical | For the demo: curated hero photos (D15). The G2 product gate (users) stays alive before investing in infra; CV debt is paid on the Phase 2 parallel track |
| Clothing segmentation doesn't fit on mobile | Medium | High | Benchmark with latency as a criterion from day 1 (G2.5) |
| Legal: third-party images in F5 | Medium | High | Deep-links in v0; only licensed sources (Unsplash/Pexels) in v1 |
| Skin filter bias (dark skin tones) | Medium | High (repu.) | Diverse evaluation set in Phase 0; replace heuristic with ML in 2.5 |
| Real eCPM < estimated | Medium | Medium | Freemium as second leg; measure in Phase 5 before scaling UA |
| GDPR/biometric data | Low | High | Ephemeral processing, don't store photos by default, simple DPIA |
| Single-dev dependency | High | Medium | CLAUDE.md + PRD + tests = the project can be picked up by anyone |

## 10. Recorded decisions (ADR-lite)

| # | Decision | Date | Rationale |
|---|---|---|---|
| D1 | Powsty approach as a *starting point*, not a ceiling | 2026-07-02 | Validate fast; clothing segmentation (F2.5) is the differentiator and is not discarded |
| D2 | On-device first | 2026-07-02 | ~0 marginal cost = profitability condition |
| D3 | F5 v0 = deep-links, never embed from Google | 2026-07-02 | There's no Google Images API; embedding = EU copyright risk |
| D4 | Flutter as mobile framework (formal ADR pending) | 2026-07-02 | iOS without a rewrite; the PO has no prior mobile experience |
| D5 | Harmony base = most chromatic color, never a neutral | 2026-07-02 | Validated with a real photo; with regression tests |
| D6 | Name: **PiketeMaker** | 2026-07-06 | CEO decision. Growth validation pending: registrable trademark, store collisions, handles/domain availability |
| D7 | Visual direction: white + mint + purple, radical simplicity | 2026-07-06 | Functional minimalism (extreme simplicity, little text, one action color on white). Light theme first; dark mode postponed |
| D8 | Direction A: **mint = action color**, purple = accent | 2026-07-06 | CEO's choice between mockups A/B. In tokens: `role.action` → mint |
| D9 | UI neutrals: **purple-tinted (A2)**, not pure grays | 2026-07-06 | CEO's choice between a/a2/a3. The brand permeates the whole screen without adding purple elements or competing with the user's palette. AA contrast equal to or better than pure grays |
| D10 | 100% neutral outfits → **"canvas mode"**: acknowledge the total black/white honestly and propose curated accent pops, not arbitrary-hue harmonies | 2026-07-06 | Bug B3 from G0 (3/8 photos). With neutrals any hue "works", so the proposal is fashion curation, not math. The "ask the user for the vibe" variant (C) goes to ICEBOX I3 for the future. **IMPLEMENTED 2026-07-10 (#21):** curated universal 5-accent set (Rojo/Cobalto/Mostaza/Esmeralda/Frambuesa, CEO-ratified), end-to-end (Python `CANVAS_ACCENTS` + golden fixture `lienzo_neutro_D10` + Dart `kCanvasAccents` + result-screen canvas section). Backlog follow-up (CEO-deferred): **neutral-dependent accents** (distinct sets for black vs white vs beige) |
| D11 | **Onboarding tutorial recommending a photo against a plain single-color background = Must feature (F13)** | 2026-07-06 | CEO decision. Not just an algorithm patch: it's good activation UX (less friction, consistent result from the 1st photo, aligned with D7 simplicity) that ALSO makes background removal (B4, our biggest bottleneck) nearly trivial. The specific color/framing to recommend is set with the architect's report (`docs/architecture/2026-07-06_2217_F0_algo-state-and-tradeoffs.md`) |
| D12 | **MVP skeleton = exactly 5 steps:** open app → tutorial (F13) → upload photo → loading with ad slot (F8 mockup) → palette result. Nothing else on the critical path; the product grows from there | 2026-07-07 | CEO decision. F5-lite (deep-links "ver looks") and F6 (story sharing) leave the skeleton and become post-MVP fast-follows — F6 first as the referral engine (RICE 11.2 with effort 1). The loading state with ad slot from day 1 avoids redesigning the flow when AdMob arrives (Phase 5) |
| D13 | Logo: start design WITHOUT waiting for name validation to close (#14) | 2026-07-07 | CEO decision. Accepted risk: if the EUIPO/OEPM search forces a rename, the logo is redone. Growth's verdict (viable with reservations, no direct collision) makes the risk acceptable |
| D15 | **Pivot to MVP-demo: algorithm quality stops gating progress.** Phase 0 is CLOSED; pending work becomes technical debt on a non-blocking parallel track (#29, #22, #21, #23). The demo is a Flutter APK **on-device in Dart** (no backend, offline). Non-blocking UX and Front tasks are launched in parallel. | 2026-07-07 | CEO-CPO decision. Context: this is an exercise whose real goal is an installable demo to seek funding/partners, not production. The MVP (whole-photo palette, D1) doesn't need the clothing segmentation that causes the 62.5% KO — that quality is re-evaluated in Phase 2.5. On-device Dart (vs FastAPI backend) is consistent with D2 and makes the demo offline and robust (you hand your phone to an investor and it works without network). Demo reliability = curated hero photos, not fixing the pipeline |
| D14 | **Logo APPROVED and frozen:** "P-Paleta" symbol (purple stem #6C3FD1 with closed P + turquoise bowl #17B598 + dot #1C1826), full "PiketeMaker" wordmark in the logo colors, no border, **a single turquoise at all sizes** | 2026-07-07 | CEO decision after 7 rounds (history in docs/design/logo/). #17B598 replaces the bright mint in the symbol too → the size rule disappears. Canonical spec: docs/design/logo/LOGO.md. Production assets in #31 |
| D17 | **Language chore APPROVED: the repo switches to English** (code, comments, tests and living canonical docs), together with the light refactor pass (#39). Exceptions: user-visible app strings stay in SPANISH (product language, "piquete" is the brand) and historical dated reports are NOT translated (they are immutable snapshots) | 2026-07-09 | CEO decision. Timing chosen per the PO's recommendation: at the start of post-demo growth, while the code is still small — the clean cut before volume explodes. Reverses CLAUDE.md's "code in Spanish" convention (the translation itself updates the convention) |
| D18 | **The app launches bilingual Catalan-Spanish, non-negotiable** (CEO: "por tema ideológico; la app ha de salir sí o sí bilingüe catalán-español"). Groundwork: UI literals extracted to ARB (#46, tech debt / good practice) so adding a language = filling one file. **AMENDED 2026-07-15 (CEO): extended to 7 locales NOW** — es (canonical, byte-identical), en/ca/fr (full voice adaptation) shipped; zh/ko/ja shipped as complete conservative DRAFTS **gated on native review before launching in those markets** (`@@x-status` header in each ARB). Infra = flutter gen-l10n, device locale with es fallback, no manual picker this round | 2026-07-09 | CEO decision, ideological commitment. Upgrades i18n (#45) from nice-to-have to launch requirement for ca+es. Catalan copy must keep the hypebeast voice (localization = voice adaptation, not literal translation — growth/UX involved). Further languages remain post-G2 expansion |
| D16 | **Roadmap v2 demo→production** (CEO's assignment to the PO, 2026-07-08): Phase 1 closing (real APK working); Phase 2 refocused on "demo→validated product" with the fix-in-Python→re-port-to-Dart-via-fixtures cycle, on-device background removal v1 (person/background) as the step before per-garment, and the CV debt re-prioritized with the ground truth from the CEO's manual review; Phase 4 reduced (no backend on the path: everything on-device). G2 remains the gate that decides everything | 2026-07-08 | The demo validated the on-device architecture end-to-end on a real device. The manual review of batch-200 may recalibrate the debt ("we're not that bad"): CV priorities are set with the CEO's data, not proxies. Monetization remains gated post-G2 |
| D19 | **Two-color border background model (wall+floor) ships as an optional layer** (`colorlab.borders`, off by default, CLI `--avoid-border-bg`): border colors from a wall band (top+sides) and a floor band (bottom) are demoted from harmony-BASE eligibility when their band is ≥ 85% uniform; the palette is never modified | 2026-07-09 | Issue #48 (CEO hypothesis after the #44 no-go). First heuristic in three R&D rounds (#29, #44, #48 — 36 configurations) to clear the bar: net +2 on the CEO's 50 labels with ZERO broken CEO-correct rows and zero selfie movement, stable across sim ≤ 15 × coverage ≥ 0.83. The literal 3-border variant (drop the floor from the band) was refuted — the floor is a second background color to model, not noise to remove. Evidence: `docs/architecture/2026-07-09_0815_F1_three-border-rnd.md`. Segmentation (Phase 2.5) remains the structural fix |
| D20 | **Neutral-dominant base gate** (`POP_ON_NEUTRAL_MIN = 0.10` in `harmony.py`): when the dominant (max-weight) color is a strong neutral, a chromatic patch below 10% is demoted from harmony-BASE eligibility → the photo falls to canvas mode (D10). Ported to Dart (`kPopOnNeutralMin`); base semantics change so the golden fixtures were re-checked (gate inert on all existing fixtures) | 2026-07-10 | Issue #57 (the "reflection" bug): on selfie22 a 3% blue mirror reflection led the base over an all-black outfit. Color alone cannot tell a reflection from a real accent, and the wrong answer *outscores* the right one (3% reflection sat×w = 0.023 vs a legit 5% pop = 0.011), so no absolute floor works; the gate keys off **context** (dominant neutral) instead, staying inert on chromatic-dominant outfits (Vuitton pink), so no legitimate pop is endangered. Accepted residual: a *genuine* small accent on a fully-neutral outfit also goes to canvas mode — the safe fallback; true attribution awaits Phase 2.5 segmentation. Evidence: `docs/qa/photo-eval/2026-07-10_1130_F2_reflection-attribution-57.md` |
| D21 | **Phase 2.5 segmentation v1 = person → top/bottom only, NO footwear.** Model path: **MediaPipe Selfie Multiclass** (~16 MB TFLite, Apache-2.0, real skin class — retires the YCbCr skin filter, PRD §9) + a pose hip-line top/bottom split. SegFormer-ATR (the with-footwear option) is dropped for v1 | 2026-07-10 | CEO decision. Footwear is not part of the selfie→outfit flow; its natural home is the **"sneaker-first" flow (ICEBOX I1)** — start from the sneakers and propose the outfit. Deferring footwear removes the only reason to prefer a heavier/less-clean-license model, so the on-device pick is unambiguous. Spike evidence that segmentation fixes the dominant attribution error: `docs/architecture/2026-07-10_1500_F2.5_segmentation-benchmark.md` |
| D22 | **Latency is NOT a gating criterion for the analysis** (the ~6 s / <3 s guardrails are advisory, not blocking): the rewarded ad (F8) covers processing time, so seconds spent segmenting/analyzing are "free" UX-wise. De-prioritize latency optimization (#30). Model selection weights **size (on-device budget), mask quality and license**, not speed | 2026-07-10 | CEO decision. Note: on-device (D2) still holds — it is about ~0 marginal *cost*, not latency. A battery/thermal sanity floor remains, but shaving seconds is explicitly low priority |
| D23 | **Build an own evaluation dataset** for Phase 2.5 (30–50 photos): commercial-safe licenses only (own / CC-BY / Unsplash / Pexels), diverse skin tones (incl. dark), mirror-selfie framing. Replaces Fashionpedia (CC-mixed + NC/ND, not commercial-safe) as the eval set | 2026-07-10 | CEO green-light. Two drivers surfaced this session: (a) Fashionpedia isn't commercial-safe and under-represents the MVP's mirror-selfie distribution; (b) the crude YCbCr skin proxy false-flags dark garments as skin (e.g. selfie04's burgundy top), so the eval set must include dark skin tones to measure the real bias that MediaPipe's skin class (D21) is meant to retire |
| D24 | **Sneaker/product mode PROMOTED from ICEBOX I1 to the roadmap, RE-SEQUENCED before Phase 2.5** (new Phase 2S). Product design: a **split-screen Home** where the user picks **Zapatillas** or **Tu outfit**; the outfit flow exists, the sneaker flow = new screens on the SAME engine run in **product-mode** (core WITHOUT the person-specific layers). Ships inside the friends & family beta alongside outfit mode | 2026-07-10 | CEO decision. Rationale: the CEO's priority is "the algorithm must go well", and #56 confirmed outfit mode's residual error is attribution (needs the long/hard Phase 2.5 ML). Product photos (clean bg, no skin) have NO attribution problem — the current core already nails them ("the algorithm as it stands would be perfect for the sneakers", ICEBOX I1 evidence). So sneaker mode makes "the algorithm goes well" true in weeks and hedges the 2.5 bet. Architecture per ICEBOX I5 addendum #2 (core stays use-case-agnostic; outfit layers composable on top). NOT a separate app — one more entry point of the same app (I5 addendum #3). Footwear-in-2.5 was already excluded for this exact home (D21) |
| D25 | **F6 share (story) DOWNGRADED to a non-blocking roadmap concept** (#60 lowered): sharing is not the app's core value and does NOT gate G2 — it just stays on the roadmap. The value the CEO wants foregrounded is the **color recommendation**, not a bare palette | 2026-07-10 | CEO decision. He's not convinced sharing a palette "just because" is fun; the strongest user value is the recommendation we make. Two content mockups explored anyway (Concept 1 "con foto" = user photo hero + palette; Concept 2 "combina con" = recommendation as hero), kept as roadmap-ready concepts: `docs/design/2026-07-10_2000_F2_story-content-F6-photo-concepts.md`. The designer prepares mockups; nothing ships or unblocks on F6 |
| D26 | **Split-Home layout = Variant A (50/50 vertical), tint-wash version.** The Phase 2S Home is two equal full-height tappable zones — **Mis zapas** (top, sneaker/product mode, foregrounded) and **Mi fit** (bottom, existing outfit flow) — with pale mint/purple tint washes and slang ES labels. **Ratifies a D8 exception:** a half-screen `purple.tint` wash is allowed on the Home (no user content there to compete; stays a *tint*, not a full accent). **Amended 2026-07-11 (D27):** bottom label renamed **"Mi fit" → "Mi pikete"** (CEO) — leans on the brand word; the mockup doc is an immutable snapshot, the canonical label is this one | 2026-07-10 | CEO pick on the A/B mockup ("la A sin lugar a duda"). A's dead-equal 50/50 communicates sneaker mode as a **co-equal wedge** (D24 intent; G2 reads which wedge resonates) far better than B's cards — worth rebuilding the Home and spending the D8 tint dose. Zapas placed first to foreground the newly promoted mode; slang labels ("Mis zapas"/"Mi fit") over neutral ones. Mockup: `docs/design/2026-07-10_2130_F2S_split-home-layout.md` (+ `_split-home.html`) |
| D27 | **Sneaker RESULT screen = INVERTED hierarchy: the recommendation is the protagonist**, the raw palette demotes to a secondary strip (breaks symmetry with the approved outfit result screen — accepted). Sub-decisions (UX Q2–Q6): **hero combo = the complementary** (bold opener); **keep the "tus zapas"/"tu ropa" labels** on the recommendation band; **NO share CTA** on the result (D25 holds) — instead **"save result" goes to the roadmap** (folds into F7 history: "mis paletas"/"mis recomendaciones", implies new navigation; explicitly NOT this phase); **CTA copy = full slang**; **app-bar = contextual "MIS ZAPAS"** (not the wordmark). Also renames the Home bottom label **"Mi fit" → "Mi pikete"** (amends D26) | 2026-07-11 | CEO decision (session start, PENDING-CEO-DECISIONS run-through). Inverted hierarchy is the correct reading of D25 ("the value is the recommendation") and the PM's recommendation; per-flow hierarchy may diverge when the value object differs (outfit = the palette itself, sneaker = the match). Mockup basis: `docs/design/mockups/2026-07-10_2200_F2S_sneaker-inner-flow.html` |
| D28 | **Gate G2S quantitative threshold = ≥70%** of the product-photo eval set with base correct + 100%-product palette. QA had proposed ≥80%; the CEO set 70% as the **first-measurement baseline** while the real dataset (own sneaker photos + stock, see the product-photo baseline spec) doesn't exist yet. The bar can be raised once the first number is in | 2026-07-11 | CEO decision. A first baseline should measure, not gate-keep: with zero real product photos measured so far, 70% catches genuine breakage without freezing the phase on an untested bar. The CEO's qualitative "on point" verdict on real sneaker photos remains part of G2S regardless |
| D29 | **Gate G2S scoring convention = STRICT raw palette** ("palette 100% product" means the raw palette carries NO background swatch — no border-bg discount, no as-displayed leniency), and the **D20-in-product-mode bug is deliberately left unfixed until the real-photo baseline is measured** (known issue: `POP_ON_NEUTRAL_MIN` mis-routes whole-frame product photos — always neutral-dominant — to canvas mode when a multicolor product fragments per-swatch weight below 10%; repro `prod-03-multicolor-on-white` in the harness smoke). Both were QA escalations from the harness smoke (9 synthetic fixtures: strict scoring = 0/9 even on perfect photos) | 2026-07-11 | CEO decision. Measure honest first, fix with data: the strict bar makes the first number a true statement of how much background-cleanup layer product-mode needs (rather than papering over it in the metric), consistent with D28's "baseline, not gate-keeping" framing. Expected consequence, accepted: the first gate number will come out LOW; the follow-up engine work (bg-swatch purge in product mode, D20 product behavior) is decided against that number, not against synthetic fixtures |
| D30 | **Gate G2S PASSED on base-correctness** (reframed from D28's both-columns bar): base correct on ≥70% of the clean product-photo set = 73.5% MET; palette-purity re-designated a Phase 2.5 quality target | 2026-07-11 | The strict palette column is bounded by Phase 2.5 (spatial: white-sole-vs-white-floor, skin, bg — impossible by colour); the base drives the recommendation and passes. Metric correction after learning, not goalpost-moving. Report: `docs/qa/photo-eval/2026-07-11_1500_F2S_gate-g2s-primera-medida.md` |
| D31 | **Neutral fidelity (#85): A now, B post-beta.** A = display-snap of low-chroma swatches (dark→pure black, light→white, chroma-gated); implemented in Python + Dart parity. B = illumination normalization before clustering = post-beta measured experiment | 2026-07-15 | A is display-only, zero risk to harmony/gate, fixes black-and-white in one; B changes extraction (would invalidate gate scoring) so it waits and is tuned on real tester photos. Separate to attribute the improvement and avoid B breaking A |
| D32 | GTM pivot: the F&F beta was voided (wrong audience, a recruitment failure, not a product verdict); real-audience validation moves to a creator-led plan and gate G2 is redefined around ORGANIC (unpaid) retention | 2026-07-18 | Strategy detail lives in the private repo |
| D33 | Minimal ANONYMOUS usage telemetry for gate G2-R: retention is computed ON-DEVICE and only unlinkable aggregate cards leave the phone (no identifiers, no timelines); colour inference stays 100% on-device (D2 intact) | 2026-07-19 | ADR: `docs/architecture/2026-07-19_1000_F2_usage-telemetry-backend-adr.md` · wire contract: `docs/api/telemetry-ingest-v1.md` |
| D34 | Telemetry stack: anonymous-card webhook (Cloudflare Worker + KV, free tier) for Phase A, behind the stable `/v1/signals` contract; sink built in `backend/telemetry/` with server-side anonymity enforcement | 2026-07-20 | No SDK, no APK weight; graduating to a bigger sink later keeps the same contract |
| D35 | Public showcase repo `pikete_maker` carries a curated snapshot of the project; the full development history, decision log and strategy live in a private repo (access on request from the author) | 2026-07-20 | Fresh single-commit history per snapshot; refreshed at milestones, never a live mirror |
| D36 | **Outfit result = recommendation-first** (mirrors the sneaker D27 inverted hierarchy). The old screen led with the extracted garment palette ("Tu pikete" ARRIBA/ABAJO filling the screen) — that proves the algorithm but the USER value is the colour RECOMMENDATION. New hierarchy: HERO = the recommended combo (headline **"Toma tu pikete"**, 3-segment hero band + slang why), the extracted palette demoted to a small strip labelled **"Tu fit · de aquí sale la combi"**, then **"Otras combis"** below. Canvas/neutral case: accent pops become the hero, headline **"Tu fit pide color"**. "Otras combis" reuses the sneaker slang scheme names (not the technical Análogo/Triádico...). CTAs kept (Ver looks así #82 + Súbela a tu story #6). UI-reorder + copy only, NO color-engine change | 2026-07-23 | CEO decision (caught the flaw). Shipping in **r12** pending the CEO's on-device test. Design: docs/design/2026-07-23_1620_F2.5_outfit-result-recommendation-first.md |
| D37 | **Share = the uploaded photo + the recommendation, in BOTH modes** (answers #60; block N / BACKLOG N1). The 9:16 story shows the user's WHOLE photo (face included, uncropped within 5:8–16:9) with the recommendation colour band glued under it and the full-colour PiketeMaker logo below; date, kicker, caption and the ARRIBA/ABAJO strip are dropped from the photo story. A preview sheet shows the exact image first, with an "Incluir mi foto" switch (default ON, remembered locally; OFF = the r13 card-only image) and the line "Tu foto solo sale del móvil si tú la compartes." **Supersedes D27 for sharing only:** the sneaker result now has the "Súbela a tu story" button (secondary pill; "Otras zapas" becomes a text button); sneaker photos taken from the "Captura de pantalla" source open with the switch OFF (third-party image). The story file is deleted when the share sheet closes and on app start, so "no la guardamos" stays literally true; the photo leaves the phone only through the user's own share (still no INTERNET permission) | 2026-09-29 | CEO decision (all 6 UX recommendations approved). Design: docs/design/2026-09-29_1830_F2_share-photo-story-proposal.md |
| D38 | **I2 per-region recolor "vérmelo puesto" — GO with conditions.** The user's own photo is recolored ONE region at a time (ARRIBA or ABAJO) with the colour the recommendation proposes; the other region stays as shot. Classic on-device LAB transform (PoC: 23 ms per region at 512 px, folds and texture preserved; prints look "painted" by design), no GenAI, no server (D2 intact). Conditions: **C1** mask hardening ships with it (hole fill, drop non-person clothes components, smoothed upscale, hip-line split) · **v1 scope = one person + decent light**, detected on-device and handled in the UI (never silent garbage) · **visual gate: ≥ 80 % of the 30 CEO selfies show-as-is** before any Dart work beyond a spike · UX proposal approved by the CEO before code (as with D36/D37). Unparks I2 from "v6.0" to the next block; the project otherwise stays parked (D32). **UX amendment (same day):** mockup `docs/design/mockups/2026-09-30_I2-recolor.html` approved as-is (one "Vérmelo puesto" pill under the D36 card, tip line when not applicable, no-scroll ARRIBA/ABAJO view, press-and-hold original, D37 sheet reused, single-photo story in v1); **outfit mode only** (sneaker recolor → ICEBOX I13); **no telemetry at all** for the recolor (no funding = no data collection; the proposal's event list is void). **Visual gate PASSED** (CEO, same day, on the C1 panels of the 29 selfies: *"para mí funciona TOP"* — even imperfect masks work because the recolor is read as a colour idea on your own body, not as a photo edit); waist-up single-top cuts accepted for v1. **On-device amendment (r15, CEO, same day):** function "BRUTAL"; the pill under the card was hidden below the fold, so the entry point moves into the bottom CTA block, order **1 · Vérmelo puesto · 2 · Súbela a tu story · 3 · Ver looks así**, all three mint-outlined on white (no filled primary in that block). **r17 polish (CEO, same day):** the three result CTAs become FILLED with white text, **mint · purple · mint** (the purple "Súbela a tu story" is a ratified, single-use exception to D8's accent dosing), and the split Home puts **"Mi pikete" on top** and "Mis zapas" below (supersedes D26's order: the outfit pikete + recolor is now the app's best part) | 2026-09-30 | CEO decision on the PoC panels (`docs/architecture/2026-09-30_1025_F2_I2-recolor-poc.md`) |
| D39 | **The combo the user selects is the combo the app acts on** (amends D37 and D38, which always used the hero/complementary). On the D36 outfit result, tapping an "Otras combis" row makes it the selected combo: the hero band swaps in place to it, "Vérmelo puesto" recolors with it and the story (band + recolored photo, and the card-only image) shares it; tapping it again returns to the main combo. For the 3-colour combos (triadic, split, analogous) the recolor paints the **first non-base colour in engine order** (rule b; the farthest-ΔE rule was offered and not chosen). No "back" link, no auto-scroll. To build on 2026-10-01 (BACKLOG Q1, then r18) | 2026-09-30 | CEO decision on the UX + architecture estimates |

---

*This PRD is a living document: it's updated when each gate closes, and every
new decision is added to the ADR table.*
