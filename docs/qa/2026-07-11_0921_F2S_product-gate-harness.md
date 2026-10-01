# F2S — Gate G2S evaluation harness READY (D28 threshold wired)

**Date:** 2026-07-11 09:21 · **Role:** QA · **Phase:** 2S (sneaker/product mode)
**Scope:** the harness that measures Gate G2S the day the CEO delivers the real
product-photo set (~25 own sneaker photos on a white sheet + ~10 stock; spec in
`docs/qa/photo-eval/2026-07-10_2200_F2S_product-photo-baseline.md` §4).

## How to run the gate when the photos arrive

Photos go to `samples/product/` (gitignored raw + a `MANIFEST.md` with
per-photo license, per the baseline spec / D23 bar). Then, from the repo root
(venv active, or prefix with `.venv/Scripts/python` on Windows /
`.venv/bin/python` on Unix):

```bash
# 1. Run the battery (product mode D24, whole set, deterministic order)
python cv_core/tools/product_battery.py --dir samples/product

# 2. CEO annotates the two verdict columns (yes/no; si/ok/ko also accepted) in
#    outputs/product-battery/product/review.md
#    (panels + index.html gallery in the same folder support the review)

# 3. Compute the gate verdict against the D28 threshold
python cv_core/tools/product_battery.py --score
```

`--score` prints `pass-count / n (rate)` and **PASS / FAIL / UNDECIDED** against
`GATE_G2S_MIN = 0.70` (D28, named constant in the tool, pinned by a test). It
handles partial reviews honestly: it computes the worst-case / best-case
bracket and only declares PASS/FAIL early when the bracket already decides it;
otherwise it stays UNDECIDED and says how many rows are pending. A `review.md`
that already carries hand verdicts is never overwritten without `--force`.

## What is auto vs hand-reviewed

| Judgment | Who | How |
|---|---|---|
| CRASH | auto | pipeline exception → row pre-filled `no`/`no` (auto-fail) |
| Canvas routing signal | auto hint | `CANVAS` = neutral base → canvas mode (D10); **valid** for black/white products — the human confirms it is the right call |
| Mono-palette signal | auto hint | `MONO_PALETTE`; **valid** for solid-color products (per the baseline report, the person-pipeline `COLLAPSED_PALETTE` KO would be a false-KO here) |
| Background-swatch signal | auto hint | `BG_MATCH[i]` = swatch within ΔE(LAB) < 12 of the image **border ring** median (`BORDER_RING_FRACTION = 0.04`); marked `*` in the review table and `(bg?)` in the panels |
| **base OK?** (gate criterion a) | **hand (CEO)** | is the highlighted base the product's true dominant/most-chromatic color (or a correct canvas routing for an all-neutral product)? |
| **palette 100% product?** (gate criterion b) | **hand (CEO)** | attribution (product vs background vs shadow vs white sole) is exactly what automation cannot judge — same rationale as the #56 review |

Design decision: a **dedicated tool** (`cv_core/tools/product_battery.py`)
instead of a `--product-mode` flag on `mass_battery.py`. The baseline report
already showed mass_battery's KO flags are person-pipeline proxies that
mis-fire on products (4/9 false KOs: `BASE_IS_SKIN`, `COLLAPSED_PALETTE`,
`NEUTRAL_BASE`); the gate metric is structurally different (hand-review pass
rate vs threshold, not auto-KO %); and the product tool calls the CANONICAL
`analyze_palette(product_mode=True)` instead of hand-replicating stages.
Conventions reused from mass_battery: `--dir`, `results.json`, per-photo
panels, `index.html` gallery. Outputs are **per-dataset**
(`outputs/product-battery/<dirname>/`, gitignored) so smoke runs never clobber
the real gate run.

## Smoke test (mechanics proven; NOT a gate measurement)

No real product photos exist in the repo yet (baseline report §1), so the
smoke ran on the 9 **synthetic** product fixtures in `samples/product-synth/`
(flat blobs — trivial inputs, quoted only as plumbing evidence). Full loop
exercised end-to-end on this PC (Py3.14, GrabCut-irrelevant: product mode does
no bg removal): battery → panels/gallery/review.md → hand annotation → `--score`
→ verdict. Evidence preserved in `outputs/product-battery/product-synth/`.
Suite: cv_core fast **63 → 104 passed** (+41 in
`cv_core/tests/test_product_battery.py`: metric math, verdict parsing incl.
ES/EN tokens, review round-trip, D28 pin, synthetic `evaluate_photo`).

## Two findings the smoke surfaced (report, not fixed — engine owner decides)

**F1 — BUG (medium, hits real sneaker photos): the D20 `POP_ON_NEUTRAL_MIN`
gate mis-routes small/multicolor products to canvas mode in product mode.**
Repro: `python cv_core/tools/product_battery.py --dir samples/product-synth` →
`prod-03-multicolor-on-white` (red+yellow+blue product, 24% of frame total)
comes out base = `#FFFFFF` → canvas. Expected: base = the red (most chromatic).
Cause: product mode analyzes the whole frame, so the neutral background is
always the dominant swatch; D20 then demotes every chromatic swatch whose
individual weight < 0.10 — a multicolor product fragments its weight below the
bar (10%+8%+5%), and `prod-09` (2% coral accent) falls the same way. D20's
premise ("a tiny chromatic patch on a neutral-dominant *outfit* is probably a
reflection") does not transfer to product photos, where a clean background
guarantees neutral dominance. Mitigation already in the dataset spec (product
fills 30–60% of frame), but colorful multi-panel sneakers on white are the
core use case — this can sink the real gate number. Options for the engine
owner (NOT decided here): disable/rescale the D20 gate in product mode, or
compute weights over non-border pixels.

**F2 — ESCALATION to PM/CEO: the "100%-product palette" criterion needs one
convention pinned before the real review.** Product mode analyzes the whole
frame **by design** (D24), so the raw palette contains a background swatch on
essentially every clean product photo (9/9 in the smoke carry `BG_MATCH`).
Read strictly against the raw palette, criterion (b) fails ~always (smoke
scored 0/9) — the gate would measure the design, not the algorithm. The review
header therefore instructs to judge **the palette as the app displays it**;
what the sneaker result screen actually displays (does it strip the border-bg
swatch?) is mobile-agent work in progress. Before annotating the real set, PM/
CEO must pin: (i) strict raw palette, (ii) palette minus border-bg swatch, or
(iii) as-displayed. The harness supports any of them — it is the *verdict
convention* that changes, not the tool.

## Files

- Tool: `cv_core/tools/product_battery.py` (QA-owned; `cv_core/src/` untouched)
- Tests: `cv_core/tests/test_product_battery.py` (41, all fast)
- Smoke evidence: `outputs/product-battery/product-synth/` (gitignored)
- This note. No commits (CEO commits by hand).
