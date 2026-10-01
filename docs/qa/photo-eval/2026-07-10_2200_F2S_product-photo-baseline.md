# F2S / D24 — Product-photo evaluation battery (baseline start)

**Date:** 2026-07-10 22:00 · **Role:** QA · **Phase:** 2S (sneaker/product mode)
**Premise under test:** the current color core already extracts palettes *well*
on sneaker/product photos (clean background, no skin) — the rationale for
promoting sneaker mode *before* Phase 2.5, because #56 showed outfit-mode's
residual error is **attribution** (garment vs background/skin), which a clean
product photo does not have.

**Verdict on the battery itself: STARTED but NOT a real baseline yet.** The repo
contains **zero real product/sneaker photos**. What follows is (a) a reality
check, (b) a mechanical *floor* on 9 synthetic controls run through the real
harness, and (c) a precise dataset-to-source spec so the CEO can assemble the
real set. **The premise is NOT yet validated on real photos.**

---

## 1. Reality check — what product photos actually exist: NONE

Every image under `samples/` is a **person wearing an outfit**. There is no
clean-background, no-person product shot anywhere.

| Location | Count | What it is | Product photo? |
|---|---|---|---|
| `samples/g0/raw/test/` | 3200 | Fashionpedia val/test-2020 — people on runway / street / red carpet (verified on a random contact sheet of 12) | No — people |
| `samples/g0/*.jpg` | 8 | G0 outfit cases (multicolor, total-black, dark skin, several people…) | No — people |
| `samples/selfies/*.jpeg` | 31 | CEO selfies | No — people |
| `samples/test_outfit*.png` | 3 | Synthetic stick-figure fixture **with a skin-colored head** + two rendered result panels | No — synthetic person / panels |
| `samples/vuitton2006lr.jpg` | 1 | Runway photo (person on cobblestones; multicolor LV sneakers *are* in it, but on a person, on a busy street bg) | No — person |

Consequence: I could not measure the premise on real product photos, because
none exist. Sourcing a commercial-safe set is network/manual work the sandbox
cannot do (no curl, unreliable API access) — that is the CEO deliverable in §4.

---

## 2. Mechanical floor — 9 synthetic controls through the real harness

To at least exercise the **reusable harness** on product-shaped inputs and to
flush out mechanical risks, I generated 9 obviously-synthetic "product on clean
background, no person" images and ran the existing battery tool on them.

- Generator (new, QA-only, does **not** touch `cv_core/src/`):
  `cv_core/tools/make_product_fixtures.py` → writes to `samples/product-synth/`.
- Harness (unchanged, reused as-is): `cv_core/tools/mass_battery.py --dir samples/product-synth`.
- Preserved output (gitignored): `outputs/product-synth-eval/` (9 `prod-*_panel.png`,
  `index.html`, `results.json`).
- Backend: **rembg / u2net** (this PC is Py3.12). On the CEO's device / GrabCut
  the segmentation behaves differently — see the caveat in §3.

> **These are flat solid blobs.** They have no texture, studio shadow, gloss,
> white sole, lace, logo or multi-material upper — i.e. none of the things that
> actually make real product photos hard. **9/9 correct here is a floor, not
> evidence the premise holds on real photos.** Do not quote it as a pass.

### Extraction result (the real question: is the base the product's true dominant color? is the palette all product, no background?)

| Fixture | Ground truth | Base extracted | Extraction | Auto-flags | Note |
|---|---|---|---|---|---|
| prod-01-red-on-white | red `#C81E28` | `#C71E27` | ✅ exact | COLLAPSED_PALETTE | mono-color product → 1 swatch; flag is a **false-KO** for products |
| prod-02-blue-on-gray | blue | `#1E3CA9` | ✅ exact | — (clean) | tiny 3% gray bleed, harmless |
| prod-03-multicolor-on-white | red+blue+yellow | base `#C71E27` (most chromatic) | ✅ all 3 captured, **no bg swatch** | — (clean) | textbook |
| prod-04-black-on-white | black (neutral) | `#101012` | ✅ → canvas mode (correct) | NEUTRAL_BASE + COLLAPSED_PALETTE | canvas correct; COLLAPSED is a **false-KO** |
| prod-05-white-on-gray | white (neutral) | `#ECEBE7` | ✅ → canvas mode (correct) | NEUTRAL_BASE (canvas, ok) | correct |
| prod-06-beige-on-white | beige `#D6B896` | `#D5B795` | ✅ exact | **BASE_IS_SKIN** (dE=0.0) | color right, but flagged skin — see risk below |
| prod-07-brown-on-white | brown `#784E32` | `#774E32` | ✅ exact | **BASE_IS_SKIN** (dE=0.0) | color right, but flagged skin |
| prod-08-green-on-black | green | `#289F46` | ✅ exact (even on black studio bg) | — (clean) | u2net handled dark bg |
| prod-09-pastel-multi-on-white | pastel blue + coral | `#C1D3EA` + `#E47859` | ✅ both captured | — (clean) | sneaker-ish colorway |

**Extraction correctness: 9/9** — every base equals the product's true
dominant/most-chromatic color and no palette carries a spurious background
swatch (only ≤3% edge bleed). **The harness's KO flags, however, mis-fire on
4/9** because they are tuned for the *person* pipeline (summary line printed
`KO 44.4%` — all four are false positives in a product context).

### Two concrete risks this surfaced (the actual QA value here)

1. **Skin filter eats warm-neutral products (beige / tan / nude / brown).**
   On prod-06 and prod-07 the skin-tone estimator sampled the *product itself*
   as "skin" (base dE to skin = 0.0), and the log shows
   `skin filter would cover 99% of the foreground (> 50%): ... -> not filtering`
   — the skin filter tried to strip the **entire** product and was saved only by
   the 50% guardrail. On a **partial** beige/nude sneaker (beige upper + colored
   sole/accent), that guardrail may not trigger and the pipeline would
   **over-filter the main material**, corrupting the palette. This is the #1
   thing `--product-mode` must handle: **there is no person, so the skin filter
   should be disabled entirely for product photos.** (Nude/beige/tan sneakers
   are extremely common — Yeezy, "sand", "gum sole" colorways.)

2. **Mono-color and neutral products trip KO flags that aren't failures.**
   `COLLAPSED_PALETTE` fires on any single-color product (solid red, solid
   black) and `NEUTRAL_BASE`→canvas is the *correct* outcome for black/white
   products. The current KO metric would score a perfectly-extracted solid
   sneaker as a failure. Product-mode / the product battery needs a **KO
   definition that treats mono-color and neutral products as valid**, or the
   "number" will be wrong in the pessimistic direction.

Visual evidence (panels): `outputs/product-synth-eval/prod-06-beige-on-white_panel.png`
(correct beige base, red BASE_IS_SKIN banner) and
`prod-03-multicolor-on-white_panel.png` (clean 3-color product palette, no bg).

---

## 3. Caveats (read before quoting any number)

- **Synthetic ≠ real.** Flat blobs are trivial for palette extraction. The
  9/9 floor says the plumbing works and flushed out the skin/collapsed-palette
  flag mis-fires; it says **nothing** about real studio shadows, reflections,
  soles, laces, logos, or angled/3-D product shots.
- **Backend divergence.** This run used rembg/u2net (Py3.12). u2net segmented
  even a product-on-black cleanly. On the CEO's device the engine uses
  **GrabCut**, which assumes a *centered subject* — a product on a full-frame
  white background may confuse GrabCut's border-is-background prior differently.
  Any product-mode number must be re-measured on the target backend.
- **`--product-mode` is landing in parallel** (engine agent owns
  `cv_core/src/colorlab/`). This baseline is **CURRENT pipeline only**. A re-run
  with `--product-mode` is the immediate follow-up once that flag lands — and it
  should confirm risk #1 (skin filter off) and #2 (neutral/mono not KO) are
  handled. I did not edit `src/`.

---

## 4. Dataset-to-source spec (for the CEO to assemble the real set)

The synthetic controls cannot replace real photos. To put a **real** number on
the premise, source a commercial-safe product set with this shape:

**Size:** **≥ 30 photos** to start (a first read; 60–100 for a defensible
number). Mirror the G0 bar spirit: aim for **≥ 24/30 (80%) with a correct base +
all-product palette** as the product-mode gate proposal (escalate the exact
threshold to PM/CEO — do not let me set it unilaterally).

**Framing (must-have):** single product (sneaker first — it's the D24 wedge),
**centered**, on a **clean, plain background** (white / light-grey / seamless
studio sweep), **no person, no skin, no hands**, product fills ~30–60% of frame.
Both the classic e-commerce "product on white with soft shadow" and the flat-lay
top-down variant are fine — include some of each.

**Diversity (deliberately include the hard cases):**
- **Colorway spread:** mono-color chromatic (all-red, all-blue), true multicolor
  (3+ panels), **total-black** and **all-white** (must route to canvas mode, not
  score as KO), and — critically — **beige / tan / nude / "gum"/brown** colorways
  (the skin-filter risk; ≥ 5 of these).
- **Material/finish:** matte, leather, glossy patent, mesh, suede, metallic
  (reflections and specular highlights are the real palette hazard).
- **Sole contrast:** white sole under a colored upper (does the white sole
  wrongly win the base or dilute the palette?).
- **Shadow:** soft studio shadow vs hard shadow vs no shadow (does the shadow
  bleed into the palette?).
- A few **non-white backgrounds** (light grey, black seamless) to test the
  segmentation prior.

**License bar (D23 — commercial-safe only):** own photos (best — the CEO can
shoot 20–30 of his own sneakers on a white sheet in 20 min), **Unsplash /
Pexels** (their license permits commercial use), or **CC BY** with attribution
recorded in a MANIFEST. **No CC-NC / CC-ND** (the G0 manifest already flags 3
NC/ND photos as a public-repo risk — don't repeat that). Record per-photo
id / source URL / license / author in a `MANIFEST.md` next to the images, same
as `samples/g0/MANIFEST.md`.

**Where it goes:** `samples/product/` (gitignored raw, like `samples/g0/raw/`),
then run the exact harness already proven here:
`python cv_core/tools/mass_battery.py --dir samples/product` — plus the
`--product-mode` re-run once the engine flag lands.

**Fastest path:** the CEO shoots ~25 of his own sneakers on a white sheet
(zero licensing questions, real material/shadow/sole hazards) + ~10 Unsplash/
Pexels for colorway coverage he doesn't own (nude/metallic/patent). That
30–35 set is enough for a first honest read.

---

## 5. What I did / did not touch

- **New (QA-owned):** `cv_core/tools/make_product_fixtures.py`,
  `samples/product-synth/` (9 synthetic jpg), this report,
  `outputs/product-synth-eval/` (preserved panels, gitignored).
- **Reused unmodified:** `cv_core/tools/mass_battery.py --dir`.
- **NOT touched:** `cv_core/src/colorlab/` and `app/lib/core/color_engine/`
  (engine agent owns them; `--product-mode` lands there in parallel). I restored
  the pre-existing `outputs/mass-battery/results.json` after my run so the other
  agent's battery is untouched.
- **No commits** (CEO commits by hand).
