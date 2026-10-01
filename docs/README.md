# Documentation tour

This directory is the project's written record: what we decided, why, and what
the evidence was. It is large because decisions are documented as they happen
and never rewritten — so start here rather than browsing the file list.

## Start here

| If you want to understand… | Read |
| --- | --- |
| The product, the phases, the gates | [`PRD.md`](PRD.md) — the single canonical spec |
| Whether the algorithm actually works | [`qa/GATE-REVIEWS.md`](qa/GATE-REVIEWS.md) — every gate, its threshold, and the measurement that passed or failed it |
| How the color engine works | [`architecture/2026-07-06_2217_F0_algo-state-and-tradeoffs.md`](architecture/2026-07-06_2217_F0_algo-state-and-tradeoffs.md), then the `colorlab` package docstring in `cv_core/src/colorlab/__init__.py` |
| The differentiator (per-garment segmentation) | [`architecture/2026-07-10_1500_F2.5_segmentation-benchmark.md`](architecture/2026-07-10_1500_F2.5_segmentation-benchmark.md) → [`…_1700_F2.5_mediapipe-prototype.md`](architecture/2026-07-10_1700_F2.5_mediapipe-prototype.md) → [`…_2235_F2.5_mediapipe-ondevice-spike.md`](architecture/2026-07-14_2235_F2.5_mediapipe-ondevice-spike.md) |
| What the app looks like and why | [`design/DESIGN_SYSTEM.md`](design/DESIGN_SYSTEM.md) + [`design/user-flows.md`](design/user-flows.md) |

## How this directory is organized

**Two kinds of document, distinguishable by filename.**

*Living documents* keep a stable name and are edited in place; their history is
in git. These are the ones to trust as current:

- [`PRD.md`](PRD.md) — product requirements, roadmap phases, gate definitions,
  and the ADR table (§10) indexing every architectural decision (D1, D2, …).
- [`qa/GATE-REVIEWS.md`](qa/GATE-REVIEWS.md) — the ledger of gate outcomes.
- [`design/DESIGN_SYSTEM.md`](design/DESIGN_SYSTEM.md),
  [`design/tokens.json`](design/tokens.json),
  [`design/user-flows.md`](design/user-flows.md),
  [`design/logo/LOGO.md`](design/logo/LOGO.md) — the visual system.

*Dated reports* are named `YYYY-MM-DD_HHMM_FN_slug.md`, where `FN` is the
roadmap phase (`F0`, `F1`, `F2`, `F2.5`, `F2S`). They are **immutable
snapshots**: a measurement or analysis as it stood on that date. They are never
edited or re-run in place — a later finding gets a new file. So a report may
describe a state the project has since moved past; read them as history, and
take the current position from the living documents above.

## The directories

| Directory | What is in it |
| --- | --- |
| [`architecture/`](architecture/) | ADRs, benchmarks and spikes — why the engine is built the way it is. Model selection, performance investigations, the segmentation chapter, the telemetry design. |
| [`qa/`](qa/) | The evidence base. `GATE-REVIEWS.md` plus [`qa/photo-eval/`](qa/photo-eval/), the batch evaluations over real photos that produced the numbers the gates are judged on. |
| [`design/`](design/) | Design system, tokens, logo package, screen specs and mockups (some as standalone HTML). |
| [`api/`](api/) | Wire contracts for the network surface — currently [`telemetry-ingest-v1.md`](api/telemetry-ingest-v1.md), the anonymous-signal endpoint. Pairs with `backend/telemetry/`. |

## Reading the engineering story in order

The CV work has a narrative arc; these are the load-bearing documents, in
sequence:

1. **Baseline and trade-offs** — `architecture/2026-07-06_2217_F0_algo-state-and-tradeoffs.md`
2. **The heuristics chapter, and why it closed** — the three border/skin R&D
   rounds (`architecture/2026-07-09_*`). Two no-gos and one win; the conclusion
   was that the dominant error is *semantic* (is this pixel a garment or the
   wall?) and cannot be fixed with color heuristics.
3. **Ground truth** — `qa/photo-eval/2026-07-09_0055_F1_analisis-groundtruth-ceo.md`
   and `qa/photo-eval/2026-07-10_1930_F2_ceo-review-issue56.md`, where hand
   review re-scoped the real error rate and split it into background / hair /
   skin buckets.
4. **The answer: segmentation** — the `F2.5` architecture reports, which pick an
   on-device model and prove it collapses all three buckets.
5. **The measurement** — `qa/photo-eval/2026-07-18_G2.5-primera-medida.md`, the
   gate G2.5 result, checked for skin-tone bias across buckets.

## Conventions

- Code, comments and canonical docs are in **English**. User-facing app copy is
  localized with **Spanish as the canonical source** (the ARB files under
  `app/lib/l10n/`), which is why Spanish strings appear inside the engine where
  they are product-facing names.
- Decisions are numbered (`D1`, `D2`, …) and indexed in PRD §10. Code comments
  cite them directly, so a `# D24` in the source resolves to a row in that
  table.
- Issue numbers (`#56`, `#84`, …) in comments and filenames refer to the
  project's issue tracker and are used as stable shorthand for a bug or
  investigation.
