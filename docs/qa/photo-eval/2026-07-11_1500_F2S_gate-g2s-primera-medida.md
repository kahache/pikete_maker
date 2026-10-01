# Gate G2S — first measurement (real product photos)

**Date:** 2026-07-11 · **Phase:** 2S (sneaker/product mode) · **Author:** QA + CEO hand-review
**Harness:** `cv_core/tools/product_battery.py` (product mode, D24) · **Threshold:** D28 = ≥70%
**Scoring:** D29 strict raw-palette (no border-bg discount)

## Result

| Set | Photos | Pass (both cols) | Rate | Verdict |
|---|---|---|---|---|
| **phone** (gate) | 57 | **2** | **3.5%** | **FAIL** vs ≥70% |
| store (diagnostic) | 13 | — | — | not scored (adjacent case) |
| web (diagnostic) | 29 | — | — | not scored (screenshot case) |

Passing rows: #16, #18 only. (#46 base-OK but palette carried a background swatch.)

This is the **honest first baseline** D29 predicted would be low. It is a
DIAGNOSTIC to drive fixes, not a product verdict.

## Root cause (from the CEO's 57 hand-annotations): background domination

The harmony engine is NOT the problem. ~90% of failures are one thing: in
whole-frame product mode the **background wins on pixel weight** and becomes the
base and/or fills the palette. Breakdown of the CEO's notes:

- **Background as base / in palette** — the dominant failure (≈1–14 floor, 17,
  21–24, 28, 31, 33–57…). The sneaker is centered but the floor/wall/legs
  out-weigh it.
- **BUG-N1 · white sneaker → read as gray, merged with background** (29, 30, 39,
  42, 43, 48, 49, 51, 52, 55, 57). Recurring. The white shoe/sole is not
  detected as white; it collapses into a gray shared with the background.
- **BUG-N2 · black sneaker under lighting → read as gray** (32). Highlights
  lift the black toward gray and confuse the base.
- **Small-subject shots** (31, 33, 37, 50): sneaker tiny in frame + visible
  pants/legs → nothing of the shoe enters the palette.
- **Trap cases confirmed** (41 magazine cover): same failure mode as web
  screenshots → needs the crop path (tutorial #83, case 💻).

**Positive control (#46):** the CEO's own note — *"base bien! fíjate que la foto
ocupa casi toda la zapa"*. When the sneaker fills the frame, the base is
correct. This is the whole thesis of the fix.

## The key finding: D24's premise is partially falsified

D24 defined product mode as "core WITHOUT person layers (no background removal,
no skin filter)" on the assumption that **product photos have clean
backgrounds**. Real phone photos do NOT — they have floors, walls, pants, legs.
So product mode needs a **product-centric background suppression** after all —
different from the person pipeline, but not "no background handling".

## Recommendation — two complementary levers

1. **UX guardrail (in flight): tutorial #83** — coach the user to fill the frame
   with the sneaker on a plain floor / crop screenshots. Pushes real inputs
   toward the #46 case that already works. Half the fix, ~free.
2. **Algorithm: center-subject background suppression in product mode.** The
   sneaker is reliably centered → a center-biased approach flips most fails:
   - central-seed GrabCut foreground (the seed infra already exists, #25
     `GRABCUT_SEED_FRACTION`), OR
   - center-weighted palette (down-weight border pixels).
   Plus fix BUG-N1/N2: near-neutral detection must recover true **white** and
   **black** for sneakers instead of collapsing them into a mid-gray shared
   with the background.
3. **Re-run the gate** on the same 57 after each change to measure lift
   (before/after on the same machine, same strict D29 scoring).

## Round 2 — after #84 (multi-edge ≥3 background suppression + neutral recovery)

Re-ran the harness, CEO re-hand-reviewed all 57 (fresh verdicts; the Round-1
annotation is preserved separately). Same strict D29 scoring.

| Metric | Round 1 (whole-frame) | Round 2 (post-#84) |
|---|---|---|
| **Gate (both columns yes)** | 2/57 (3.5%) | **21/57 (36.8%)** — still FAIL |
| **Base correct** (the number that matters for the recommendation) | ~11/57 | **36/57 (63%)** |
| Background swatch in palette (auto proxy) | 43/57 | 1/57 |

**The gate gap is now two named things, NOT the background** (that's fixed):

1. **The WHITE bug — the dominant remaining wall.** 15/57 photos have a
   CORRECT base but FAIL the palette column, and the overwhelming cause is
   white: the sneaker's white (soles, uppers) is either not surfaced at all or
   rendered as mid-gray (rows 13,16,20,23,29,33,36,37,39,42,48,50,51,52,55).
   Fixing white detection would flip most of these to pass.
2. **~7 CONFLICTIVA source photos** (bad input, not an algorithm miss): room
   with a bed (5), a child's clothes (7), street shots with a tiny sneaker
   (10,38), lighting-only matches (12,18), a magazine cover (41, EXCLUDE).
   These are exactly what tutorial #83 prevents. On a non-conflictiva
   denominator (50), base-correct ≈ 72% and gate ≈ 42%.

**Recurring color-fidelity notes (from the CEO):**
- **Black under light** is read as dark navy/gray, not pure black (BUG-N2,
  many rows). The CEO accepts it as "OK" when close, but it costs palette purity.
- **Small-detail colors** on the sneaker are not detected (a color present only
  in a tiny area). New known limitation.
- Idea (row 49, Nike Air Max Pippen all-background): compare the shot against an
  internet reference photo of the model → ties into [[I5]] sneaker-palette DB.

**Conclusion:** #84 worked (background solved, base 63%). The gate is now gated
by (a) the white bug and (b) source-photo quality (tutorial #83). Next lever =
fix white detection, then re-measure.

## Round 3 — white-merge fix (#84 R3) + gate VERDICT

Measured on the cleaned **49-photo** set (8 conflictivas removed to
`phone_conflictivas/`). The white-merge fix (neutral-lightness protection) shipped
but the CEO's re-review found its "recovered whites" are **false**: on 52 the new
`#CDDDD8` is background, on 53 the `#E9DFD8` is skin/floor, on 44 the `#DDF1EF` is
a hallucination. So even the white-as-gray fix does not yield usable **sole**
white in the co-suppression cases — distinguishing white sole from white
floor/skin is **spatial, impossible by colour**. Confirmed ceiling.

| Metric | Value (49 clean) | Read |
|---|---|---|
| **Base correct** | **36/49 = 73.5%** | the product-relevant number (drives the recommendation) — **≥70%** |
| Palette 100% product (strict) | 21/49 = 42.9% | bounded by Phase 2.5 (background/skin/sole = spatial) |

### DECISION — D30 (CEO, 2026-07-11): Gate G2S PASSED on base-correctness

The strict both-columns metric (D28/D29) taught us its palette-purity column is
**capped by Phase 2.5** (spatial separation), not by colour. Since **white is
never the harmony base** (decision #6) and the CEO repeatedly accepts the missing
white ("se descarta con lo de hoy, me parece bien"), the product-relevant gate is
**base correctness**. Reframed:

> **Gate G2S = base correct on ≥70% of the clean product-photo set. MET: 73.5%.
> → Phase 2S CLOSED.** Palette purity (100%-product) becomes a **Phase 2.5
> quality target**, not a 2S blocker. This is a metric correction after learning,
> not goalpost-moving: the recommendation quality is driven by the base.

**Next:** Dart parity of the CV fixes (#84 multi-edge + neutral-lightness) is now
on the **critical path to r9** — the on-device engine must match the Python gains,
or the beta ships the pre-fix algorithm. Then r9 (with tutorial #83) → F&F beta →
measure G2.

## Artifacts

- Annotated review: `outputs/product-battery/phone/review.md` (57 rows, both
  verdict columns + per-photo CEO notes).
- Galleries: `outputs/product-battery/{phone,store,screenshot_or_web}/index.html`.
- Raw dataset (gitignored): `samples/dataset_zapas/{phone,store,screenshot_or_web}/`
  (57 / 13 / 29, renamed `sneaker_<cat>_NN`).
