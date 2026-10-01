# #57 — "Reflection" attribution bug: analysis + GO/NO-GO

- **Date:** 2026-07-10 11:30
- **Phase:** F2 (demo → validated product)
- **Author role:** Backend & System Architect
- **Type:** Investigation (read-only on source). No code changed. Deliverable = this report.
- **Scope:** `colorlab.harmony.pick_harmony_base_index` base selection.
- **Verdict (TL;DR):** **GO**, with a color-only **dominant-neutral context gate**
  that routes selfie22 to canvas mode (D10). Zero regressions on the current
  suite. Clean, portable to Dart. Its one residual limitation (a *genuine* small
  accent on a fully-neutral outfit is also routed to canvas mode) is a product
  tradeoff, not a bug, and is only *fully* resolved by Phase 2.5 segmentation.

---

## 1. The bug

On selfie22 (all-black outfit shot in a mirror), a **blue door reflection**
covering ~3% of the pixels is extracted as a genuine palette color and **wins
the harmony base** over the black outfit. The reflection is a real chromatic
blue (not a neutrality edge case), so #22's chroma-based `is_neutral`
(`NEUTRAL_CHROMA = 13`) does **not** fix it: the blue has high chroma and passes
the neutral filter, then wins `saturation × weight` because black is (correctly)
excluded as neutral.

selfie22 is not in `samples/` (no selfies committed). The analysis below uses a
synthetic repro that reproduces the exact scoring path of
`pick_harmony_base_index`.

## 2. Synthetic reproduction (real engine, real numbers)

Colors characterized through the actual `rgb_to_hsv` / `lab_chroma` / `is_neutral`:

| color | RGB | HSV sat | LAB chroma | `is_neutral` |
|---|---|---|---|---|
| black outfit | (18,18,20) | 0.100 | 1.3 | **True** (excluded) |
| lavender pop (Vuitton) | (156,166,198) | 0.212 | 17.8 | False |
| blue reflection — vivid | (45,90,205) | 0.780 | 69.1 | False |
| blue reflection — muted | (70,110,180) | 0.611 | 42.1 | False |
| blue reflection — pale | (120,150,200) | 0.400 | 29.2 | False |

Synthetic selfie22 palette `{black 70%, gray 17%, wall 10%, blue 3%}` →
`pick_harmony_base_index` returns the **blue (idx 3)** for all three blue
variants. **Bug reproduced.**

### 2.1 The decisive number: the wrong answer *outscores* the right one

Current score = `HSV_sat × weight`:

| candidate | weight | score |
|---|---|---|
| blue reflection — vivid | 3% | **0.0234** |
| blue reflection — muted | 3% | 0.0183 |
| blue reflection — pale | 3% | 0.0120 |
| **lavender pop (legit)** | 5% | **0.0106** |

The 3% reflection scores **more than 2× the legitimate 5% lavender pop**, because
a door reflection is far more saturated per-pixel than pastel sneakers. This
kills the most obvious idea up front: **no absolute score threshold can separate
them — the wrong answer has the higher score.** Any fix must use a signal *other
than the score magnitude*.

## 3. Re-framing the collision (important correction to the premise)

The brief states the 5% lavender "must **win** the base." Inspecting the real
fixture (`app/test/core/fixtures/vuitton_pop_lavanda.json`) and running the
engine: in the Vuitton case the palette collapses to **pink 95% + lavender 5%**,
and the base is the **pink** (chromatic, dominant) — the lavender does **not**
win the base. The lavender's job is to **survive in the palette** (via
`min_weight = 0.02` in `dominant_colors`), which is a **separate mechanism** from
base selection and is untouched by anything discussed here.

Consequence: **a base-eligibility change never endangers Vuitton**, because
Vuitton's dominant color is chromatic. The genuine collision for #57 is narrower
and harder:

> A **small chromatic patch on a neutral-dominant outfit**. Here a 3% blue door
> reflection (wrong, it is *background*) is **color-indistinguishable** from a
> hypothetical 3% lavender-sneaker-on-a-black-outfit (right, it is *garment*).
> Same dominant (neutral), same patch size, both chromatic.

The two things color can see are identical; only **space** (is the patch on the
person or in the mirror/wall?) tells them apart. That is the segmentation signal.

There is one hard data point that a naive weight floor cannot survive: the
regression fixture `sombras_lavanda_reunificadas` — the real Vuitton sneakers,
split by shading into two ~1.7% fragments, **reunite at ~3.4%**. So a *legitimate*
pop can be as small as **3.4%**, essentially the same size as the 3% reflection.

## 4. Candidate color-only fixes, scored

Each candidate is scored against the two anchors it must separate — the **3%
reflection (must lose)** and a **legit small pop (must win)** — plus the ~3.4%
reunited-sneaker reality and the existing test suite.

| # | Candidate | Reflection 3% | Legit 5% pop | 3.4% reunited pop | Breaks? | Verdict |
|---|---|---|---|---|---|---|
| A | **Absolute score floor** (ignore score < X) | 0.0234 | 0.0106 | lower still | wrong answer scores **higher** than right — impossible to place a threshold between them | **FAIL** |
| B | **Global weight floor** (ignore w < X in base eligibility) | killed only if X>3% | survives if X<5% | **killed if X≥3.5%** | any X in the only working band (3.5–5%) also kills the real 3.4% reunited sneaker pop | **FAIL** |
| C | **chroma × weight** score | 2.072 | 0.892 | ~0.6 | reflection wins by an even wider margin (chroma amplifies the vivid blue) | **FAIL (worse)** |
| D | **sat × weight^p** (steep weight exponent) | p≥3 needed to flip vs 5% (2e-5 vs 3e-5, razor-thin) | — | at 3.4% pop the blue **still wins** (2.1e-5 > 8.3e-6); also distorts the intended sat/weight tradeoff (`test_pick_harmony_base_weighs_saturation_and_frequency`) | fragile + wrong on the real 3.4% case | **FAIL** |
| E | **Dominant-neutral context gate** — demote a chromatic candidate below `POP_ON_NEUTRAL_MIN` **only when the dominant (max-weight) color is a strong neutral** | **demoted → canvas mode** (dominant black neutral, 3% < 10%) | **safe** — Vuitton dominant is chromatic pink, gate inactive | **safe** — same, chromatic dominant | 0/17 harmony tests break (8/8 base-selection tests pass patched) | **PASS** |

### 4.1 Why E works where B/D fail

B and D try to separate reflection-vs-pop by the **pop's own weight**, but a real
pop (3.4%) and the reflection (3%) are the same size — there is no separating
value. E instead keys off the **context**: it only fires when the *dominant*
color is a strong neutral, which is exactly what distinguishes selfie22
(dominant = black) from Vuitton (dominant = pink). Because the gate is inert on
chromatic-dominant photos, it can afford a **generous** threshold
(`POP_ON_NEUTRAL_MIN = 0.10`) with a wide safety margin, instead of the
impossible 3.5–5% needle B requires.

### 4.2 Gate behavior, verified end-to-end

Proposed gate simulated through the real engine:

| scenario | dominant | result | correct? |
|---|---|---|---|
| selfie22 (blue reflection 3% on black) | black (neutral) | **canvas mode (-1)** | ✅ yes — all-black outfit belongs in canvas mode (D10) |
| Vuitton (lavender 5% on pink) | pink (chromatic) | base = pink | ✅ unchanged |
| Vuitton reunited sneakers (3.4% on pink) | pink (chromatic) | base = pink | ✅ unchanged |
| black coat + real red scarf 20% | black (neutral) | base = red @20% | ✅ substantial accent still leads |
| beige wall + navy garment 30% | beige (neutral) | base = navy @30% | ✅ unchanged (`test_pick_harmony_base_skips_dominant_neutral`) |
| near-black + red cardigan 25% (B8) | near-black (neutral) | base = red @25% | ✅ unchanged |
| black coat + tiny red pin 4% | black (neutral) | **canvas mode (-1)** | ⚠️ residual (see §5) |

Regression check: the 8 base-selection tests in `test_harmony.py`
(`test_pick_harmony_base*`, `test_near_black_*`, `test_canvas_*`) all pass with
the gate monkey-patched in — **0 failures**.

## 5. The residual limitation (and where it is paid off)

The gate makes one **product choice**: on a *fully neutral-dominant* outfit, a
**genuine** small chromatic accent (<10%) is routed to **canvas mode** instead of
leading the harmonies (last row above). This is unavoidable by color alone —
that accent is pixel-for-pixel indistinguishable from the reflection. Canvas mode
is the **safe** fallback here: it offers curated, valid accents (D10) instead of
building an entire harmony scheme off a 3% patch that is *as likely to be a
mirror/wall as a garment detail*. Given that #57 is precisely a case where the
patch **was** background, defaulting neutral-dominant + tiny-chromatic to canvas
mode is the correct bias.

**Full resolution requires Phase 2.5 segmentation.** Once person/background
(or garment) masks exist (bg-removal-v1 → segmentation), the reflection can be
**attributed to a background region** and dropped *before* palette extraction,
while a genuine on-garment accent is kept — no weight/context heuristic needed.
Until then, the gate is the correct on-device, color-only approximation.

## 6. Recommendation: **GO** (dominant-neutral context gate)

Ship the gate as the fix for #57. It is on-device, portable to Dart, testable,
regression-free, and philosophically aligned with the existing canvas mode.
It does **not** claim to distinguish a reflection from a real accent (that is
NO-GO without segmentation) — it makes the **safe** call for neutral-dominant
photos, which is exactly the selfie22 class.

### 6.1 Exact change (do NOT apply — for the implementing session)

In `cv_core/src/colorlab/harmony.py`:

1. New module constant (with rationale comment):
   ```
   # On a neutral-dominant outfit (all black/white/gray) a small chromatic patch
   # is as likely to be background (a mirror reflection, a wall) as a real garment
   # accent — color alone cannot tell them apart (#57). Below this weight we do NOT
   # let such a patch lead the harmonies; with no eligible base the photo falls to
   # canvas mode (D10), the safe curated fallback. Chosen at 0.10 (generous): the
   # gate is inert whenever the dominant color is chromatic (e.g. Vuitton pink),
   # so a wide margin never endangers a legitimate pop. Full attribution
   # (garment vs background) awaits Phase 2.5 segmentation.
   POP_ON_NEUTRAL_MIN = 0.10
   ```
2. In `pick_harmony_base_index`, before the loop compute
   `dominant_is_neutral = is_neutral(<max-weight color>)`; inside the loop, after
   the existing `if is_neutral(c): continue`, add
   `if dominant_is_neutral and w < POP_ON_NEUTRAL_MIN: continue`.
3. **Dart parity:** mirror the same gate in `app/lib/core/color_engine`'s
   `pickHarmonyBase`, and **regenerate golden fixtures**
   (`cv_core/tools/gen_fixtures_dart.py`) — base selection changes for
   neutral-dominant-with-tiny-chromatic photos, so the parity fixtures must be
   re-emitted and the Dart suite re-synced (adjacent to #49).

### 6.2 Tests to add (`cv_core/tests/test_harmony.py`)

- `test_tiny_chromatic_on_neutral_outfit_goes_to_canvas_57`:
  `{black 70%, gray 17%, wall 10%, blue(45,90,205) 3%}` →
  `pick_harmony_base_index == -1` (the selfie22 repro).
- `test_substantial_accent_on_neutral_outfit_still_leads`:
  `{black 62%, gray 18%, red(200,40,45) 20%}` → base == red (gate must not
  over-fire on real accents).
- `test_gate_inactive_when_dominant_is_chromatic`:
  `{pink 95%, lavender 5%}` → base == pink and the gate does not change the
  result (guards Vuitton / chromatic-dominant).

### 6.3 Governance

If the CEO approves GO, this warrants a new ADR (`docs/adr/NNN-neutral-dominant-base-gate.md`)
and one line in PRD §10, since it changes base-selection semantics. Not written
here (investigation only). This report is the evidence backing that ADR.

---

## Appendix — reproduction

Synthetic scripts (throwaway, run against the repo venv, not committed):
`scratchpad/repro57.py` (characterization + score tables),
`scratchpad/repro57b.py` (gate behavior across scenarios),
`scratchpad/verify_gate.py` (8/8 base-selection tests pass with the gate).
Run with
`env -u PYTHONPATH -u PIP_PREFIX -u PIP_BREAK_SYSTEM_PACKAGES .venv/bin/python <script>`.
All numbers in this report are engine outputs, not hand estimates.
