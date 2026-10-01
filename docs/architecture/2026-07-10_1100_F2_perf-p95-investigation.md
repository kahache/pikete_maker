# Pipeline latency investigation (issue #30) — p95 11.2s vs 6s guardrail

- **Phase:** F2 (CV technical debt, parallel track — does NOT block the demo)
- **Date:** 2026-07-10
- **Author:** backend-architect
- **Scope:** read-only investigation of the `colorlab` pipeline. No source
  changed. Deliverable = this report + a recommended (un-applied) patch plan.
- **Issue:** #30 — batch-200 measured p95 = 11.2s, guardrail = 6s.

## TL;DR

**The hotspot is background removal.** It is 72–85% of pipeline time on both
backends and is the p95 driver. Everything downstream (skin filter, K-means,
LAB merge, harmonies) is a rounding error by comparison, with one caveat:
K-means is a distant, bursty #2 that can spike under load.

- The **p95 baseline (11.2s) was almost certainly a GrabCut number**, not
  rembg: the batch ran on the local Python 3.14 box where `onnxruntime` has no
  wheel, so `remove_background()` falls through to GrabCut (see CLAUDE.md
  "Known technical constraints"). GrabCut has a **heavy right tail** — it runs
  at full working resolution (600 px) for `GRABCUT_ITERS = 5`, and on a large
  full-body frame it hit **10.2s** in this profiling. That tail is exactly what
  a p95 surfaces.
- Top recommendation: for the GrabCut path (the one the p95 reflects), **cap
  the working resolution for mask computation and/or reduce `GRABCUT_ITERS`**;
  for the rembg path, **cache the session and consider the lightweight
  `u2netp` model**. Both are localized to `background.py`, do not touch the
  palette math, and directly attack the dominant stage.

## Method and caveats (read this before trusting absolute numbers)

- Profiled the real pipeline stages with `time.perf_counter()` around each
  stage, warm (rembg model pre-loaded), over the **9 available samples**
  (`samples/*.jpg` + `samples/g0/*.jpg`). The 200-image battery is not present
  in this checkout.
- Stages timed match the battery's timed region
  (`tools/mass_battery.py`: `load_image → remove_background → gather_pixels →
  dominant_colors → harmony`, render excluded).
- **This machine runs rembg** (Python 3.12 venv, `onnxruntime 1.27.0`,
  `rembg` OK). I profiled **both** backends by calling `_remove_bg_rembg` and
  `_remove_bg_grabcut` directly, to separate the u2net cost from the rest and
  to reconstruct what the Mac/GrabCut baseline looks like.
- **Sample size is 9, not 200** — treat the tail as indicative, not a true p95.
- **The sandbox is noisy.** onnxruntime falls back to CPU (GPU discovery
  denied), joblib is forced serial (`/dev/shm` locked), numba can't take its
  lock. Concretely: g0-08's K-means measured **5.5s inside the full sequential
  run** but **0.44s when run in isolation** — i.e. ~5s of that was thread
  contention between onnxruntime's leftover threads and sklearn's OpenMP pool,
  not algorithmic cost. **Absolute numbers are soft; the stage ranking and the
  relative shares are robust.**

## Per-stage timing table

Times: `load` = decode+resize, `bg` = background removal, `gather` = skin
filter + LAB, `kmeans` = over-cluster + LAB merge, `harm` = base+harmonies.
`borders` = the optional `--avoid-border-bg` layer (off by default; measured
for reference, not in the total). Working size is the post-`load_image` size
(MAX_SIDE = 600). "m" = milliseconds, "s" = seconds.

### Backend: rembg u2net (this machine, warm — model already loaded)

| sample | size | fg px | load | bg | gather | kmeans | harm | TOTAL |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| vuitton2006lr | 400×600 | 51.7k | 25m | 2.53s | 73m | 337m | 0m | 2.96s |
| g0-01 multicolor | 399×600 | 91.1k | 11m | 2.52s | 71m | 382m | 0m | 2.98s |
| g0-02 total-black | 400×600 | 49.4k | 11m | 2.64s | 71m | 199m | 0m | 2.92s |
| g0-03 fondo-recargado | 600×600 | 99.7k | 17m | 2.88s | 113m | 2494m* | 0m | 5.50s |
| g0-04 cuerpo-lejos | 600×399 | 4.4k | 12m | 3.97s | 104m | 88m | 0m | 4.17s |
| g0-05 piel-oscura | 399×600 | 120.9k | 11m | 5.88s | 64m | 648m | 0m | 6.61s |
| g0-06 varias-personas | 397×600 | 50.0k | 15m | 2.87s | 89m | 262m | 0m | 3.24s |
| g0-07 rayas | 399×600 | 125.4k | 12m | 2.90s | 70m | 1004m* | 0m | 3.99s |
| g0-08 print-piel-oscura | 400×600 | 99.3k | 41m | 3.98s | 92m | 5507m* | 0m | 9.62s |

*K-means values marked `*` are inflated by sandbox thread contention (see
caveats): isolated re-runs put g0-08 at ~0.44s, g0-03 at ~0.65s, g0-07 at
~0.85s. Read them as ~0.5–1.0s.

Stage shares (mean over the 9): **bg 71.8%**, kmeans 26.0% (overstated by the
contention spikes), gather 1.8%, load 0.4%, harm ~0%.

### Backend: GrabCut (what the Mac/Py3.14 p95 baseline reflects)

| sample | size | bg | kmeans | TOTAL |
|---|---|---:|---:|---:|
| vuitton2006lr | 400×600 | 0.83s | 195m | 1.11s |
| g0-01 multicolor | 399×600 | 0.62s | 183m | 0.91s |
| g0-02 total-black | 400×600 | 2.93s | 686m | 3.74s |
| g0-03 fondo-recargado | 600×600 | 2.51s | 834m | 3.48s |
| **g0-04 cuerpo-lejos** | **600×399** | **10.16s** | 308m | **10.50s** |
| g0-05 piel-oscura | 399×600 | 3.98s | 580m | 4.64s |
| g0-06 varias-personas | 397×600 | 2.23s | 443m | 2.78s |
| g0-07 rayas | 399×600 | 2.49s | 368m | 2.93s |
| g0-08 print-piel-oscura | 400×600 | 1.66s | 353m | 2.11s |

Stage shares (mean over the 9): **bg 85.0%**, kmeans 12.3%, rest <3%.

**The GrabCut tail is the story.** Mean bg ≈ 3.0s but the max is **10.2s** on a
single wide full-body frame. Across 200 images this kind of tail is precisely
what pushes p95 to ~11s. GrabCut cost scales with (working pixels × iterations),
so large frames and the fixed `GRABCUT_ITERS = 5` compound.

### One-time cost, not per-image

- **rembg model load: 3.48s** on the first call. It is cached module-side for
  the rest of the process, so in a 200-image battery it is amortized to ~0. But
  a **cold FastAPI request** (Phase 1 plan-B) would eat the full 3.48s unless
  the session is warmed at startup.

## Where the time actually goes (mechanism)

- **rembg u2net** runs its forward pass at a fixed 320×320 internally, so the
  MAX_SIDE=600 resize barely changes its cost — the ~2.5–5.9s is the CPU
  forward pass + alpha post-processing. Feeding it a smaller image does **not**
  help; changing the **model** or the **thread count** does.
- **GrabCut** runs at the full working resolution (600 px here) for 5
  iterations. Unlike u2net, it **is** resolution- and iteration-sensitive, so
  downscaling the mask computation and/or fewer iterations cut its cost close
  to linearly.
- **K-means** (`palette.py`): `n_clusters = k·OVERSEGMENT_FACTOR = 10`,
  `n_init = 4`, no `max_iter` override (sklearn default 300), and **no pixel
  cap** — it clusters the entire foreground (up to ~125k px here). Cost ≈
  `n_init × n_iter × N_pixels × k`. It converges in ~17 iters, so the lever is
  `N_pixels` (subsampling) and `n_init`, not `max_iter`. Typical ~0.4–1.0s;
  it only becomes a headline number under thread contention.
- **gather/skin filter, LAB merge, harmonies**: negligible (<0.12s combined).
  The LAB merge loop is O(clusters²) over ≤10 clusters — nothing to optimize.
- **borders layer** (`--avoid-border-bg`, off by default): 50–600ms. It runs
  K-means twice more (3 clusters per band). Not on the default path; only
  relevant if that flag is turned on by default later.

## Ranked optimization proposals

Ranked by (latency impact ÷ effort), with the quality/fixture risk called out.
**Critical constraint:** `palette.py` and `harmony.py` feed the **Dart golden
fixtures** (D15 on-device parity). Any change that alters the emitted palette
forces a fixture regeneration + Dart re-sync. Background-removal changes do
**not** cross that boundary (the Dart app does its own segmentation on-device),
so they are the cleaner place to spend effort.

### 1. GrabCut: cap working resolution + fewer iterations — **top pick for p95**
- **What:** compute the GrabCut mask at a smaller side (e.g. 400 px) and
  upscale the boolean mask back; and/or lower `GRABCUT_ITERS` 5 → 3.
- **Latency:** attacks the exact tail that sets p95. Resolution 600→400 is
  ~2.2× fewer pixels (~0.45× time); iters 5→3 is ~0.6× time. Combined, the
  10.2s worst case plausibly drops under ~4s. **Highest p95 leverage.**
- **Quality risk:** low–moderate. Mask gets slightly coarser at edges; the
  palette is computed from interior pixels so the color mix barely moves. Does
  NOT touch fixtures (Dart doesn't use GrabCut). Needs a mask-quality spot
  check on g0 (attribution is already the known weak point, #23).
- **Effort:** low. Localized to `_remove_bg_grabcut` in `background.py`.

### 2. rembg: warm the session + offer `u2netp` — **for the rembg/server path**
- **What:** (a) create the rembg session once at startup and reuse it
  (kills the 3.48s cold-start on a FastAPI request); (b) allow selecting the
  lightweight `u2netp` model.
- **Latency:** (a) removes a one-time 3.48s from cold requests. (b) `u2netp` is
  materially faster than `u2net` on CPU (smaller net) — a per-image win on the
  dominant stage.
- **Quality risk:** (a) none. (b) `u2netp` masks are a bit coarser than
  `u2net`; needs the same mask spot-check. No fixture impact.
- **Effort:** low–moderate (`background.py` gains a session/model parameter).

### 3. K-means: cap pixels via random subsample (seeded) — **battery throughput**
- **What:** if `N_pixels > CAP` (e.g. 40k), cluster a seeded random subsample.
- **Latency:** 4–10× on the K-means stage (measured: g0-07 847ms→51ms at 10k;
  g0-08 590ms→70ms). Meaningful for battery throughput and the contention
  tail, small on the median end-to-end (bg still dominates).
- **Quality risk:** **moderate — and it crosses the fixture boundary.** Measured
  palettes are stable on clean cases (g0-07 max LAB shift 0.7), but **near the
  `MIN_WEIGHT`/merge margins the sample flips which clusters survive**: g0-08 at
  cap 40k/20k dropped from 5 to 4 colors (a cluster crossed the 2% threshold)
  and only recovered at cap 10k. So a naive cap can change the palette. Requires
  regenerating the Dart golden fixtures and a parity re-check. Do NOT bundle
  with #1/#2 — sequence it with the #23 re-run and the palette work already in
  flight.
- **Effort:** moderate (change + fixture regen + Dart sync + tests).

### 4. K-means: reduce `n_init` 4 → 1–2 — do NOT do standalone
- **Latency:** ~2–4× on the K-means stage.
- **Quality risk:** high relative to payoff. Fewer restarts = worse/less-stable
  local optimum → different palette → fixture churn. The stage isn't the
  bottleneck. **Not recommended.**

### 5. onnxruntime thread tuning — environment, not code
- **What:** set intra-op threads / avoid oversubscription so u2net and sklearn
  don't fight for cores (the source of the 5.5s contention spike here).
- **Latency:** removes the pathological spikes seen in-sandbox; likely a no-op
  on a clean box.
- **Risk:** none to output. **Effort:** low, but it's ops config, and the real
  target machine (Mac) runs GrabCut anyway.

## Recommended patch plan (NOT applied)

Do the background-removal wins first — they hit the dominant stage and never
touch the palette/fixture contract. Defer the K-means cap into the palette
work that's already open.

1. **`cv_core/src/colorlab/background.py` — GrabCut working-resolution cap +
   iteration knob (proposal #1).**
   - Add module constants: `GRABCUT_MAX_SIDE` (e.g. 400) and keep
     `GRABCUT_ITERS` but lower default 5 → 3 after the spot-check. Named
     constants with a comment on why the value (repo convention).
   - In `_remove_bg_grabcut`: downscale to `GRABCUT_MAX_SIDE`, run GrabCut,
     `cv2.resize` the mask back to full size with nearest-neighbor. Keep
     `setRNGSeed` for determinism.
   - Preserve the existing centered-rect + seed logic.

2. **`cv_core/src/colorlab/background.py` — rembg session reuse + model choice
   (proposal #2).**
   - Add a cached `new_session(model_name)` (module-level, lazy) and a
     `REMBG_MODEL` constant defaulting to `"u2net"`; expose an opt-in for
     `"u2netp"`. `_remove_bg_rembg` uses the cached session.
   - For the future FastAPI wrapper: warm the session at app startup.

3. **Guardrail / test to add (`cv_core/tests/`):**
   - A `slow`-marked regression that runs `remove_background` over the g0
     samples and asserts **per-image bg time < a named budget** (e.g.
     `MAX_BG_SECONDS`), so the tail can't silently regress. Mark `slow` (real
     CV), consistent with the existing suite split.
   - A mask-quality assertion (foreground fraction within a tolerance of the
     current baseline) on 2–3 g0 samples, so the resolution/model change can't
     silently degrade segmentation.
   - Re-run `tools/mass_battery.py` (seed 42) to get a real post-change p95 for
     the #23 battery re-run; add a p95 column to that report.

4. **Deferred (sequence with the open palette work + #23):** proposal #3
   (seeded K-means pixel cap). Land it *with* a golden-fixture regeneration and
   Dart parity re-check, never on its own.

## Consequences / notes for the roadmap

- On-device (the demo) is unaffected: the Dart engine does its own
  segmentation; this is the canonical Python pipeline (batteries) and the
  Phase-1 FastAPI plan-B. Per "on-device first", right-size the effort — steps
  1–2 are cheap and high-leverage; step 3 is only worth it bundled with work
  that already pays the fixture-regen cost.
- The p95 is a GrabCut-tail problem. If the canonical battery moves to a box
  with rembg (Py 3.12), the tail shrinks and the guardrail conversation
  changes — worth stating which backend any future p95 number was measured on.
- Full profiling scripts were throwaway (scratchpad), not added to the repo.
