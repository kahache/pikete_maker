# #44 — Border-heuristic background discrimination: empirical evaluation and NO-GO verdict

- **Date:** 2026-07-09 12:40 · **Phase:** F1 · **Author:** Backend/System Architect
- **Scope:** issue #44. Hypothesis: a plain background touches the image borders while a
  centered person does not, so the dominant border-band color can be excluded, penalized
  or demoted before/around K-means, gated by a "plain background confidence" signal.
- **Verdict up front: NO-GO.** Eleven variant configurations across four heuristic
  families were scored against the CEO's 50 labels (+4 selfies) with the #29 harness.
  **Every family is net-negative, hollow, or marginal-with-regressions.** The blocking
  finding is structural: *the plain-border confidence gate fires MORE often on
  CEO-confirmed-correct photos (8/13, 62%) than on the background-KO photos it exists to
  fix (11/20, 55%)* — because studio/plain-background photography is exactly where
  fashion outfits are deliberately tone-matched to the wall. No code change ships.

---

## 1. Data and harness

Identical to #29 (`docs/architecture/2026-07-09_0200_F1_skin-guardrail-redesign.md`):

- **Ground truth:** the CEO's 50 labeled rows (13 OK · 18 KO · 19 DUDA) from
  `docs/qa/photo-eval/2026-07-08_F1_revision-manual-bateria-200.xlsx` + the QA taxonomy
  (2026-07-09_0055 analysis). Target category: **background misattribution, 20 rows**
  (2, 3, 6, 7, 9, 11, 12, 13, 16, 20, 25, 26, 30, 31, 41, 43, 44, 46, 47, 49).
- **Fondo-liso segment:** the xlsx "Fondo" column turns out to be exactly
  `bg_std < 20` from the old `outputs/bateria-100/resultados.json` → **13 plain rows**
  (10, 15, 16, 24, 30, 35, 36, 39, 40, 42, 44, 46, 48), of which only **4** are in the
  background category (16, 30, 44, 46). Most background KOs have bg_std 20–36.
- **Selfies:** `samples/selfies/selfie01-04.jpeg` (private). 01/04 must not regress.
- **Harness:** cached deterministic GrabCut masks (scratchpad `bg44/`), then per-variant
  skin filter → border stats → K-means → `pick_harmony_base`. **Validation gate passed:
  the recomputed baseline reproduces the xlsx base hex in 50/50 rows**, and the selfie
  baselines match #29 (`#BF7924` / `#ADA196` / `#1F1F24` / `#40161D`). ~6 min/variant.

### Border-band signal definition

- Band: frame of width `BAND_FRAC × min(h, w)` around the image (0.04 and 0.08 tested).
- Border color: top cluster of `dominant_colors(band, k=3)`.
- **Plain-background confidence gate:** fraction of band pixels within `SIM_DE`
  (attenuated-L deltaE, repo convention kL=0.5) of the border color; act only if
  coverage ≥ `COVER_MIN` (0.45 / 0.60 tested; SIM_DE 15 / 20). Busy border → heuristic
  switches itself off (the #29 do-no-harm lesson).

### Scoring rules (same conservatism as #29)

| Row group | Counted as |
|---|---|
| CEO-OK rows + 4 legit skin-garments (17) | **BROKEN** if the harmony base moves (dE_Lw ≥ 10 vs baseline) |
| Background rows (20) | **IMPROVED** only if the base moves ≥ 10 off the baseline AND lands ≥ 15 dE away from the border color, non-neutral, palette > 1; a move to another background/neutral color is a *sidegrade* |
| DUDA rows | churn only |
| Selfies | 01/04 regressed if base moves; 02/03 reported |

## 2. Variant families

- **A — exclude pre-K-means:** drop pixels within `SIM_DE` of the border color from the
  (fg ∧ ¬skin) set before clustering; do-nothing guard if < 15% of pixels would remain.
- **B — weight-penalize:** keep clusters, multiply border-like cluster weights by 0.25,
  renormalize.
- **C — demote from BASE eligibility only:** palette untouched; border-like colors
  cannot lead harmonies (fallback to baseline pick if nothing remains).
- **D — location-aware exclude** (designed after A/B/C failed): drop border-colored
  pixels only *outside* the eroded foreground core (`cv2.distanceTransform` > 3% / 6%
  of min side), so a centered garment matching the wall is protected.

## 3. Results — confusion tables (all 50 rows)

| Variant (band/simdE/cover) | Fired | BG improved (of 20) | BG sidegrade | OK/legit broken (of 17) | Net | Selfie 01/04 regressed |
|---|---|---|---|---|---|---|
| A 0.04/15/0.60 | 29 | 2 (3, 43) | 0 | 4 (10, 35, 36, 37) | **−2** | no |
| A 0.04/20/0.60 | 36 | 5 (3, 11, 20, 43, 46) | 0 | **8** (4, 10, 33, 35, 36, 37, 39, 50) | **−3** | no |
| A 0.04/15/0.45 | 42 | 3 (3, 13, 43) | 1 | 5 (4, 10, 35, 36, 37) | **−2** | no |
| A 0.08/15/0.60 | 27 | 2 (3, 43) | 0 | 5 (10, 35, 36, 37, 50) | **−3** | no |
| B 0.04/15/0.60 | 31 | **0** | 0 | 0 | **0** (hollow, see §4) | no |
| C 0.04/15/0.60 | 31 | **0** | 4 | 1 (10) | **−1** | no |
| C 0.04/20/0.45 | 47 | 3 (11, 13, 47) | 4 | 2 (10, 50) | **+1** | **yes: selfie01 #BF7924 → #504137** |
| D 15/0.60/e0.03 | 31 | 0 | 0 | 1 (37) | **−1** | no |
| D 15/0.60/e0.06 | 31 | 0 | 0 | 1 (37) | **−1** | no |
| D 20/0.60/e0.06 | 40 | 1 (20) | 0 | **7** (10, 19, 33, 35, 36, 37, 50) | **−6** | no |
| D 20/0.45/e0.06 | 47 | 1 (20) | 0 | 7 | **−6** | no |

The only positive-net configuration (C 0.04/20/0.45, +1) regresses selfie01 (a
CEO-correct result), produces 4 sidegrades (base hops to *another* background/neutral
color), and its 3 "improvements" cannot be confirmed as garment colors without the CEO.
That is a marginal win we do not force (#29 rule).

### Fondo-liso segment (bg_std < 20, 13 rows — the segment #44 targets)

| Variant | BG improved (of 4) | OK/legit broken | Net |
|---|---|---|---|
| A 0.04/15/0.60 | 0 | 3 (10, 35, 36) | −3 |
| A 0.04/20/0.60 | 1 (46) | 4 (10, 35, 36, 39) | −3 |
| B 0.04/15/0.60 | 0 | 0 | 0 |
| C (both) | 0 | 1 (10) | −1 |
| D (best) | 0 | 0 | 0 |

**The heuristic is at its most destructive precisely in the plain-background segment**:
rows 10, 35, 36, 39 are plain-studio photos where the CEO confirmed the palette is
correct and the garment tone blends with the backdrop — the exact photos the gate
cannot tell apart from a background leak.

## 4. Why the border heuristic cannot win (three measured failures)

1. **The confidence gate does not discriminate.** At cov15 ≥ 0.60 it fires on 8/13
   CEO-OK rows (62%) and 8/11 correct-despite-flag rows (73%) vs 11/20 background rows
   (55%). Plain, uniform borders are a property of *good studio photography*, not of
   background-attribution failures. Five CEO-OK/legit rows sit within 20 dE of their
   own border color (10, 36, 37, 39, 50; row 35 at 8.9, row 22 at 4.9): the
   "garment matches the wall" case is not an edge case in fashion — it is the look.
2. **The border band is not the leaked background.** In 11/20 background rows the
   misattributed base sits > 20 dE from the border-band color (up to 51): lighting
   gradients, vignettes, floor-vs-wall splits and window light mean the background that
   leaks *around the subject* is a different color from the image frame. Exclusion by
   border color removes the wrong pixels or nothing.
3. **The leak is not spatially peripheral either (D's failure).** With GrabCut the
   background contamination lives *deep inside* the fg mask (between legs, around the
   torso), not at the mask boundary: eroding the core and excluding border-colored
   outer pixels removed 13–39% of pixels yet moved the base < 2 dE in 13/16 fired
   background rows, and border-like palette weight only fell 0.41 → 0.35.

**B (weight-penalize) deserves a note because it looks safe (0 broken bases) but is
hollow:** it never fixes a base (0/20), and on fired CEO-OK rows it silently corrupts
the displayed percentages — row 10's correct sweater drops from 74% to 42% of the
palette while on background rows the mean border-like weight only moves 0.40 → 0.24.
It damages the very number (the weight) the CEO's complaint is about, on the photos
that were right.

The underlying blocker is the same one #29 hit from the skin side: "is this beige a
wall, skin, or a trench coat" is a **semantic** question. Border position and border
color are weak proxies that correlate as strongly with correct studio shots as with
background leaks. The information is not in the pixels we can compare — it arrives
with clothing/person segmentation (Phase 2.5, D1, the committed differentiator).

## 5. Decision and recommendations

- **No change to `cv_core`.** No variant meets the do-no-harm bar. Suite verified on
  the unmodified tree: **47/47 passed** (46.8 s).
- **Close #44 as "no-go — waiting for segmentation (Phase 2.5)"**, citing this report.
  Do not port any border heuristic to the Dart demo engine either (#40 context): the
  demo mitigation remains hero-photo curation (#33), where backgrounds are controlled.
- **What WOULD move this category** (for Phase 2/2.5 planning):
  1. **Person/clothing segmentation (Phase 2.5)** retires the whole category (40% of
     the reviewed KO block) — this evaluation is further evidence it is the only
     robust fix, and the harness here is ready to score any candidate mask model
     against the same 50 labels.
  2. **ICEBOX I1 (product/sneaker mode):** for product photos the object *is* the
     non-border blob and there is no tone-matched-outfit failure mode — the same
     heuristic evaluated here would likely work there. If I1 is promoted, re-run this
     harness on a product-photo battery before assuming it; do not reuse these labels.
  3. **UX honesty over silent fixing (with ux-designer):** since colors are extracted
     correctly in ~70% of reviewed rows and only attribution fails, labeling the
     palette "colors of your photo" (already the D15 MVP contract) remains the honest
     framing until 2.5.
- **Architecture note (ICEBOX I5 addendum honored):** had a variant won, it would have
  shipped as an optional, composable outfit-mode layer with a CLI toggle. The
  evaluation code stays out of the package by the same principle: nothing in
  `colorlab` was use-case-specialized by this work.

### Reproduction

Scratchpad `bg44/` (session-local, not committed): `labels.py` (xlsx + taxonomy +
old-JSON cross-check → labels.json), `build_cache.py` (deterministic GrabCut cache,
checkpointed npz), `eval.py` / `eval2.py` (variant grids A–C / D, checkpointed JSON),
`score.py` / `score2.py` (confusion tables). Inputs untouched: the xlsx,
`samples/g0/raw/test/`, `samples/selfies/` (never left the folder),
`outputs/bateria-100/resultados.json` (pre-D17 Spanish keys, read-only cross-check).
Determinism anchors: `GRABCUT_RNG_SEED = 0`, KMeans `random_state = 42`.
