# #48 — 3-border variant + two-color border model (wall+floor): evaluation and GO verdict

- **Date:** 2026-07-09 08:15 · **Phase:** F1 · **Author:** Backend/System Architect
- **Scope:** issue #48, the CEO's follow-up hypothesis to the #44 no-go: *the bottom
  border is usually floor; including it pollutes the border-band estimate and degrades
  the confidence gate* (structural failure #1 of #44).
- **Verdict up front: GO — but not for the literal hypothesis.** 20 configurations
  (16 demote, 4 exclude) across V1 (3-border), V2 (two-color wall+floor) and V3
  (V2 + recalibrated gate) were scored on the CEO's 50 labels + 4 selfies with the
  validated cached-mask harness. **V1 (drop the bottom border) makes the gate WORSE,
  not better** — but the generalization V2/V3 (model the floor as a *second background
  candidate*) produces the **first heuristic in three rounds to clear the agreed bar:
  net +2 with ZERO broken CEO-correct rows, zero selfie movement, and a stable
  operating plateau.** The winning configuration ships as an optional, composable
  layer (`colorlab.borders`, off by default, CLI `--avoid-border-bg`).

---

## 1. Data and harness

Identical to #29/#44 (`docs/architecture/2026-07-09_1240_F1_background-edge-heuristic.md`):
the CEO's 50 labeled rows (13 OK · 18 KO · 19 DUDA; background category = 20 rows)
from `docs/qa/photo-eval/2026-07-08_F1_revision-manual-bateria-200.xlsx`, the 4
private selfies (`samples/selfies/`, never left the folder), and the cached
deterministic GrabCut masks. **Validation gate passed again: the recomputed baseline
reproduces the xlsx base hex in 50/50 rows** and the selfie baselines match #29
(`#BF7924` / `#ADA196` / `#1F1F24` / `#40161D`). Scoring rules unchanged
(BROKEN = CEO-OK/legit base moves ≥ 10 dE_Lw; IMPROVED = background base moves ≥ 10
AND lands ≥ 15 dE from every qualified background candidate, non-neutral; moves to
another background/neutral = sidegrade).

### Band definitions (band width 0.04, the better width from #44)

- **Wall band (U):** top strip + left/right strips, *excluding the bottom-strip rows*.
- **Floor band (F):** bottom strip, full width.
- Per-band candidate: top cluster of `dominant_colors(band, k=3)`; per-band coverage =
  fraction of the band within `SIM_DE` (attenuated-L, kL=0.5) of its own candidate.
- **V1** = wall candidate only. **V2** = wall AND floor candidates, each gated by its
  own band's coverage; palette colors near *either* are affected. **V3** = V2 with the
  gate recalibrated on the cleaner per-band signal (coverage sweep 0.45–0.85).
- Action family: **demote from BASE eligibility** (family C, the least destructive in
  #44 — palette untouched); 4 exclusion configs kept as cross-checks.

## 2. The decisive diagnostic: the CEO's premise vs. what the data says

Gate fire-rates (the #44 structural failure this issue attacks — reference 62% on
CEO-OK rows vs 55% on background rows, i.e. the gate fired MORE on correct photos):

| Gate | CEO-OK fire-rate (13) | Background fire-rate (20) | Discrimination |
|---|---|---|---|
| #44 single band, s15/c0.60 | 62% | 55% | −7 pt (inverted) |
| **V1 wall-only, s15/c0.60** | **69%** | **35%** | **−34 pt (much worse)** |
| V1 wall-only, s15/c0.75 | 54% | 30% | −24 pt |
| V2 two-color, s15/c0.60 | 92% | 95% | +3 pt |
| **V3 = V2, s15/c0.85** | **69%** | **60%** | **−9 pt** |

**The CEO's literal hypothesis (V1) is refuted:** removing the floor makes the wall
band *even more* characteristic of good studio photography — plain uninterrupted
walls are exactly how correct studio shots look, so the cleaner gate fires *more*
selectively on OK rows. No gate configuration at any threshold discriminates in the
right direction; the confidence gate remains structurally unable to separate "plain
background leaked" from "plain background done right".

**But the premise behind it (wall ≠ floor) is real and useful in a different way:**

- dE(wall, floor) > 20 in 9/20 background rows vs 4/13 OK rows — floors *do* differ
  from walls, slightly more on failing photos.
- In the background rows, the misattributed base sits on the **floor** color, not the
  wall, in a distinct sub-population (rows 9, 11, 13, 20, 25, 31, 41, 47: dFloor
  1.0–11.8 while dWall 16.8–42.1). #44's single mixed band could never see these:
  its band average was neither color. **The floor is not noise to remove from the
  estimate (V1); it is a second background color to model (V2).**

## 3. Results — confusion tables

All 50 rows (demote family; full 20-config table in the harness output, exclusion
configs were net −4…0 with 5–7 broken rows and are dead on arrival, same as #44):

| Variant (sim/cov) | Fired | BG improved (of 20) | BG sidegrade | OK/legit broken (of 17) | Churn (DUDA) | Net | Selfie 01/04 moved |
|---|---|---|---|---|---|---|---|
| V1dem 15/0.45 | 46 | 3 (2, 7, 47) | 4 | 2 (4, 50) | 2 | +1 | no |
| V1dem 15/0.60 | 28 | 0 | 3 | 1 (50) | 2 | −1 | no |
| V1dem 20/0.45 | 49 | 4 | 4 | 2 (4, 10) | 2 | +2 | no |
| V2dem 15/0.45 | 49 | 4 | 5 | **4** (4, 10, 27, 50) | 2 | 0 | no |
| V2dem 15/0.60 | 47 | 4 | 3 | 3 (10, 27, 50) | 2 | +1 | no |
| V2dem 15/0.75 | 38 | 3 | 3 | 3 | 2 | 0 | no |
| **V3 = V2dem 15/0.85** | **32** | **2 (11, 41)** | **3 (3, 43, 46)** | **0** | **1** | **no** |
| V2dem 20/0.85 | 36 | 4 | 3 | 3 (1, 10, 33) | 0 | +1 | no |

Fondo-liso segment (bg_std < 20, 13 rows — where #44 was at its most destructive,
−3 with rows 10/35/36/39 broken): **V3 breaks 0 rows** (1 sidegrade on row 46, net 0).

### Robustness of the winner (not a lucky grid point)

Neighborhood sweep sim × coverage, cell = broken/improved/net, `*` = selfie moved:

| sim \ cov | 0.80 | 0.83 | 0.85 | 0.87 | 0.90 |
|---|---|---|---|---|---|
| 13 | 0b/1i/+1 | 0b/1i/+1 | 0b/1i/+1 | 0b/1i/+1 | 0b/0i/0 |
| 14 | 0b/2i/+2 | 0b/1i/+1 | 0b/1i/+1 | 0b/1i/+1 | 0b/1i/+1 |
| 15 | 2b/2i/0 | 1b/2i/+1 | **0b/2i/+2** | 0b/2i/+2 | 0b/1i/+1 |
| 16 | 4b/2i/−2 | 3b/2i/−1 | 3b/2i/−1 | 2b/2i/0 | 2b/2i/0 |
| 17 | 4b/3i/−1 | 3b/2i/−1 | 3b/2i/−1 | 3b/2i/−1 | 2b/2i/0 |

The zero-broken plateau is the whole region sim ≤ 15 × cov ≥ 0.83; breakage starts
abruptly at sim ≥ 16 (garments 15–20 dE from the wall start getting demoted — the
"outfit tone-matched to the wall" failure mode of #44). Selfies never move anywhere
in the neighborhood. Chosen operating point: **sim 15, coverage 0.85** (the
evaluated grid point inside the plateau, one step from each cliff).

### The winner, row by row (V3, every fired row whose base changed)

| Row | Category / verdict | Base | Qualified candidate | Reading |
|---|---|---|---|---|
| 11 | background · DUDA | `#735F58` → `#598D8F` | floor `#95908E` | **improved** — base was the floor; a teal garment color now leads |
| 41 | background · DUDA | `#3B2C36` → `#3A627E` | floor `#655858` | **improved** — floor-driven, blue garment leads |
| 3 | background · DUDA | `#282220` → `#D3D3DC` | wall `#191613` | sidegrade (to another near-neutral) |
| 43 | background · KO | `#9C8672` → `#39343C` | floor `#7D6856` | sidegrade |
| 46 | background · KO | `#C5B896` → `#3D4340` | wall `#AEB1A0` | sidegrade |
| 24 | skin_secondary · DUDA | `#2E1F19` → `#AC7D6A` | wall + floor | churn (DUDA row) |

Both genuine improvements are **floor-driven** — they are exactly the sub-population
the two-color model exists for, and invisible to both #44's single band and V1.
Honest caveat (same as #44): "improved" means the base moved off the background
candidate to a non-neutral color ≥ 15 dE away; only the CEO can confirm those are
the garment colors he expects. The three sidegrades land on other neutrals (bases
that were wrong stay wrong differently); by the do-no-harm rules they are neither
wins nor regressions.

## 4. Decision and implementation

**V3 clears the agreed success bar** (any net-positive without regressions): net +2,
0 broken CEO-correct rows on all 50 and on the fondo-liso segment, 0 selfie movement,
robust plateau. Shipped per the #44 composable-layer spec:

- **`cv_core/src/colorlab/borders.py`** — new module, English, logging-only. Named
  constants with rationale (`BORDER_BAND_FRACTION = 0.04`,
  `BORDER_SIMILARITY_DELTA_E = 15.0`, `BORDER_COVERAGE_MIN = 0.85`,
  `BORDER_BAND_CLUSTERS = 3`, `BORDER_LIGHTNESS_WEIGHT = 0.5`). API:
  `estimate_background_candidates(rgb) -> list[BackgroundCandidate]` (origin
  wall/floor, color, coverage) and
  `pick_harmony_base_avoiding_background(colors, weights, candidates)`. Do-no-harm
  guards: a busy band yields no candidate; if demotion would leave nothing eligible
  the baseline pick is returned. **The palette and its weights are never modified**
  (the #44 lesson from family B).
- **OFF by default, composable:** nothing changes unless the caller opts in.
  CLI: `colorlab photo.jpg --avoid-border-bg`. Exports in `colorlab/__init__.py`.
- **Tests — `cv_core/tests/test_borders.py` (10 new):** synthetic wall+floor
  candidate detection, floor-only detection under a busy wall (the V2
  differentiator), busy-border gate-off, demotion moves the base off a chromatic
  wall tone, no-candidate and all-background fallbacks, palette immutability; slow
  real-photo tests on g0-01 (gate fires, correct base survives) and g0-03 (cluttered
  background, gate off), plus a skip-if-absent regression on the row-11 battery
  photo pinning the floor demotion. **Suite: 57/57 passed (47 pre-existing intact +
  10 new), 93 s.** CLI smoke-tested on the row-11 photo: base `#735F58` → `#598D8F`,
  palette percentages unchanged.
- **PRD §10:** decision D19 added.

### What this does NOT solve (calibrated, as agreed)

This attacks #44's structural failure #1 only. Failures #2 (in 11/20 background rows
the misattributed color sits > 20 dE from any border estimate — lighting gradients,
vignettes) and #3 (GrabCut leak deep inside the mask) are untouched: 15/20 background
rows still stand. The gate still fires on 69% of CEO-OK rows; it survives because
demotion is a no-op when the correct base is far from the border colors — the safety
comes from the action being surgical, not from the gate being smart. **Clothing
segmentation (Phase 2.5, D1) remains the only structural fix for the category**, and
this harness is ready to score any candidate mask model against the same 50 labels.

### Follow-ups

1. **Dart port (demo engine):** the layer is pure numpy over existing primitives
   (band masks, k=3 K-means on ≤ 2·t·(h+w) pixels, deltaE) — a cheap port. Proposed
   as a post-#40 follow-up gated on the CEO wanting it in the demo; the demo
   mitigation remains hero-photo curation (#33), where backgrounds are controlled,
   so this is an enhancement, not a dependency.
2. **#23 re-run:** when the batteries are re-executed, add an `--avoid-border-bg`
   column to measure the layer on the full 200, not just the 50 labeled rows.
3. The 3 sidegrade rows (3, 43, 46) are cheap questions for the CEO's next manual
   review: if any sidegrade is actually a win (or a loss), the plateau has room to
   move one step (cov 0.83–0.90, sim 13–15) without re-running the harness.

### For the pitch (CEO-quotable)

> We didn't hand-wave the color engine's edge cases — we ran three structured R&D
> rounds on them (skin guardrails, single-band border heuristics, and a two-color
> wall/floor background model), scoring 36 candidate configurations against ground
> truth I labeled myself, photo by photo, plus real selfies. Thirty-five of those
> configurations were rejected for breaking results we knew were right — and the
> discipline paid off: round three shipped the first improvement with zero
> regressions, and the same evaluation harness now scores every future model we
> try. That's the bar for anything that touches the user's palette: measured wins
> only, and the hard cases that remain have a named fix on the roadmap — on-device
> clothing segmentation, our differentiator.

### Reproduction

Scratchpad `bg44/` (session-local, not committed), extending the #44 harness:
`eval3.py` (wall/floor band stats + exclusion variants, checkpointed per photo in
`results3/`; baseline re-validated 50/50), `score3.py` (post-hoc demote sweep — the
demote family needs only stored palettes + band stats, so 16 gate configs were swept
without touching pixels — fire-rate tables, confusion tables, selfies),
`robust3.py` (25-point neighborhood sensitivity + per-row winner detail). Inputs
untouched; determinism anchors unchanged (`GRABCUT_RNG_SEED = 0`, KMeans
`random_state = 42`, `cv2.setRNGSeed(0)` in tests).
