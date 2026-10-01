# #29 — Skin-guardrail redesign: empirical evaluation and NO-GO verdict

- **Date:** 2026-07-09 02:00 · **Phase:** F1 · **Author:** Backend/System Architect
- **Scope:** issue #29 (rewritten). The originally proposed fix (exclude skin-distance
  colors from the harmony base) was already refuted by the CEO's ground truth
  (`docs/qa/photo-eval/2026-07-09_0055_F1_analisis-groundtruth-ceo.md`) and was NOT
  implemented. This report evaluates whether any **guardrail/filter redesign** can
  improve CEO-confirmed-KO cases without breaking CEO-confirmed-OK ones.
- **Verdict up front: NO-GO.** Five redesign variants were scored against the CEO's
  50 labels + 4 real selfies. **Every variant breaks more CEO-confirmed-correct
  results than it fixes, and none rescues the two KO selfies.** No code change ships.
  Recommendation: close #29 as *waiting for clothing segmentation (Phase 2.5)*.

---

## 1. Data and harness

- **Ground truth:** 50 hand-labeled rows (CEO) from
  `docs/qa/photo-eval/2026-07-08_F1_revision-manual-bateria-200.xlsx`, sheet
  "Revisión" (col H verdict: 13 OK · 18 KO · 19 DUDA; col I observations), plus the
  QA row taxonomy from the 2026-07-09_0055 analysis (8 real-skin bases, 4 legitimate
  skin-toned garments, 11 correct-despite-flag, 20 background-attribution, 4
  skin-secondary, 3 other).
- **Selfies:** `samples/selfies/selfie01-04.jpeg` (private, never leave that folder).
  Baseline per `docs/qa/photo-eval/2026-07-08_2347_F1_selfies-eval.md`: full pipeline
  turns the two demo-KO selfies (02/03) into collapsed 1-neutral palettes; 01/04 OK.
- **Harness (scratchpad, session-local):** the pipeline is deterministic
  (`GRABCUT_RNG_SEED`, KMeans `random_state=42`), so GrabCut masks were computed
  once per photo and cached; each variant then re-runs only skin filter → K-means →
  `pick_harmony_base`. **Sanity check: the recomputed baseline reproduces the xlsx
  base hex in 50/50 rows** — the harness scores exactly what the CEO reviewed.

### Scoring rules (conservative on purpose)

| Row group | Counted as |
|---|---|
| CEO-OK rows + the 4 legit skin-garment rows | **BROKEN** if the harmony base moves (dE_Lw ≥ 10 vs baseline); we cannot re-judge a changed base without the CEO, so any change counts as damage (upper bound) |
| CEO-KO rows labeled *real skin base* (n=8) | **IMPROVED** only if the new base leaves skin distance (dE ≥ SKIN_DELTA_E) without collapsing the palette or falling back to a neutral base; a move to neutral/collapsed/still-skin is a *sidegrade*, not a fix |
| Other CEO-KO rows (background etc.) | churn only (a skin filter cannot fix attribution of background by design) |
| DUDA rows | neutral (churn reported) |
| Selfies | 02/03 improved iff base is non-skin, non-neutral, palette > 1 color; 01/04 must keep their correct baseline base |

## 2. Variants evaluated

All operate on the current adaptive filter (#20); constants named as they would ship.

- **V1 per-region guardrail** — when the mask exceeds `MAX_SKIN_FRACTION`, exempt only
  connected regions individually larger than `REGION_GARMENT_FRACTION = 0.25` of the
  fg (likely garments) and keep filtering the small ones (face/arms/legs).
- **V2 threshold 0.50 → 0.70** — same all-or-nothing guardrail, higher trip point.
- **V3 tighten radius** — when tripped, shrink `SKIN_DELTA_E` stepwise 25 → 15 → 10
  until under the cap, instead of disabling.
- **V4 face-band minimum** — when tripped, still filter mask ∩ face band (the top 30%
  where the tone was sampled — highest-confidence skin), leave everything below.
- **V5 = V1, falling back to V3** when the per-region pass yields nothing.

## 3. Results — confusion tables

Per variant, against the 50 labels (+4 selfies). "Broken" = CEO-OK or legit-garment
base changed. "Improved" = real-skin-base KO fixed per the rule above.

| Variant | Skin-KO improved (of 8) | OK/legit broken (of 17) | Net | New collapses / neutral bases | Selfies 02/03 fixed | Selfies 01/04 regressed |
|---|---|---|---|---|---|---|
| V1 per-region | **0** | 2 (rows 23, 27) | **−2** | 0 / 0 | 0/2 | no |
| V2 threshold 0.70 | 2 (15, 17) | **5** (1, 5, 10, 27, 37) | **−3** | 1 / 3 | 0/2 | no |
| V3 tighten radius | 2 (17, 32) | **6** (1, 5, 19, 23, 36, 37) | **−4** | 3 / 2 | 0/2 | no |
| V4 face-band min | **0** | 3 (1, 23, 37) | **−3** | 0 / 0 | 0/2 | no |
| V5 region+tighten | **0** | 4 (1, 5, 23, 27) | **−4** | 0 / 1 | 0/2 | no |

Every variant is net-negative. The least harmful (V1) fixes nothing; the ones that fix
anything (V2, V3) destroy the four legitimate skin-toned garments — exactly the cases
the guardrail exists to protect.

## 4. Why no colorimetric/geometric redesign can win (three separability failures)

Per-row diagnostics on the 8 real-skin bases and 4 legit garments:

| Row | Class | V0 base | raw mask fraction (V2 `skin_frac`) | dE base→skin |
|---|---|---|---|---|
| 1 | legit garment (dress) | #C59591 | 0.51 | 4.1 |
| 5 | legit garment (tights) | #8E664D | 0.55 | 7.6 |
| 10 | legit garment (sweater) | #8C7C71 | 0.67 | 14.5 |
| 27 | legit garment | #552D12 | 0.52 | 21.8 |
| 15 | real skin | #BF7147 | 0.55 | 5.1 |
| 17 | real skin | #B49584 | 0.62 | 3.6 |
| 32 | real skin | #D8B0A0 | 0.62 | 10.0 |
| 14, 18, 21, 45, 48 | real skin | — | **> 0.70** (mask never fires even at V2) | 5.0–17.8 |

1. **Color distance does not separate** (already shown by QA): real skin and legit
   garments overlap completely on `de_base_skin` (3.6–17.8 vs 4.1–21.8).
2. **Mask magnitude does not separate:** the raw adaptive mask covers 0.51–0.67 of the
   fg for the four legitimate garments and 0.55–0.62 for the fixable real-skin cases —
   the *same band*. Any threshold that lets the filter fire on real skin fires on the
   garments too (V2's 2:4 fix:break ratio is the empirical proof). Five of the eight
   real-skin cases sit above 0.70, out of reach of any sane threshold.
3. **Connectivity/geometry does not separate:** in fashion photos real skin (bare legs,
   arms + face) forms garment-sized connected blobs (V1 exempted it in 8/8 real-skin
   cases → zero fixes), while a legit garment can shed small satellite regions that get
   filtered (V1 broke row 27).

Independently, even a **perfect** skin filter would not move the demo numbers: the two
KO selfies collapse to a 1-color neutral palette once skin is removed (that is #21
canvas mode, confirmed again here — all five variants leave selfie02/03 at
`#ADA196`/`#1F1F24`, n=1), and the dominant KO cause in the CEO's block is background
attribution (40%, → #44), untouched by any skin logic. Distinguishing "this beige is a
wall / skin / a trench coat" is a semantic problem; the colorimetric information is
simply not in the pixels we compare. That capability arrives with clothing
segmentation (Phase 2.5, D1) — which is already the committed differentiator.

## 5. Decision and recommendations

- **No change to `cv_core`.** The current guardrail (`MAX_SKIN_FRACTION = 0.5`,
  all-or-nothing) stays: it is the least harmful configuration measured. Suite
  verified green on the unmodified tree: **47/47 passed** (30.8 s).
- **Close #29 as "no-go — waiting for segmentation (Phase 2.5)"**, citing this report
  and the 2026-07-09_0055 QA analysis. Do not re-open colorimetric threshold tuning
  without new *semantic* signal (person/clothes masks).
- The real improvement paths, already tracked elsewhere: **#44** (background
  discrimination, 40% of the block), **#21** (canvas mode — would convert the two
  collapsed selfies into an honest UX instead of a wrong palette), **Phase 2.5**
  (segmentation — retires the skin filter's guesswork entirely). The Dart demo engine
  has no skin filter (D15), so nothing here affects the demo path.
- **Method note for Phase 2:** the cached-mask harness used here (deterministic
  GrabCut + per-variant re-cluster, scored against CEO labels) reduced a ~50-minute
  evaluation to ~6 minutes per variant and is the template for evaluating any future
  pipeline change against ground truth before shipping it.

### Confusion-table reproduction

Harness scripts (session scratchpad, not committed): `labels.py` (xlsx → labels),
`build_cache.py` (GrabCut cache, checkpointed), `eval.py` (variants, checkpointed),
`score.py` (tables). Inputs: the xlsx (untouched), `samples/g0/raw/test/`,
`samples/selfies/` (private), `outputs/bateria-100/resultados.json` (pre-D17 keys,
used only for cross-checking). Determinism anchors: `GRABCUT_RNG_SEED = 0`,
KMeans `random_state = 42`, `SAMPLE_SEED = 42`.
