# Sneaker/product-mode inner flow — Captura → Analizando → Resultado (F2S)

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-07-10 |
| **Phase / feature** | Phase 2S · F11 (sneaker/product mode) |
| **Follows** | Split-Home = Variant A, tint-wash (D26). This is the inner flow behind the **Mis zapas** zone. |
| **Mockup (review surface)** | `docs/design/mockups/2026-07-10_2200_F2S_sneaker-inner-flow.html` (3 phone frames side by side) |
| **Scope** | The 3 inner screens of the sneaker flow only. NOT the Home (locked, D26), NOT the F5-lite deep-link target. |
| **Constraints obeyed** | D5 (base = most chromatic), D7 (radical simplicity), D8 (mint = action, purple = accent ≤2 doses), D9 (tinted neutrals), D14 (logo frozen), D25 (recommendation is the value, F6 non-blocking), Principle 2 (user's colors are the protagonist) |

---

## 1. The framing that drives everything (D25 inversion)

Outfit mode answers **"what colours am I wearing?"** → the extracted **palette is
the hero**, harmonies are a secondary section below.

Sneaker mode is the **inverse**: the sneakers are a fixed input, and the value the
CEO wants foregrounded (D25) is the **recommendation** — *"these are your
sneakers' colours, wear THIS with them."* So on the result screen the
**recommended combo is the protagonist** (biggest, most colourful element,
Principle 2) and the **raw sneaker palette drops to a small secondary strip**
(still carrying the BASE badge, D5). Same shell, inverted hierarchy. That
inversion is the whole design; the other two screens are near-verbatim reuse.

Product-mode also means the engine runs **without the person layers** (D24): no
skin filter, no attribution problem, clean background — the case the algorithm
already nails (#56). That lets the copy be confident and the wait be short.

---

## 2. Screen 1 — Captura (confirm)

**Reuse:** the existing outfit capture path verbatim — `photo_source_sheet.dart`
(camera/gallery bottom sheet) + `capture_screen.dart` (confirm preview). The
mockup renders the **confirm** state because that is where the product-mode
guidance lives; the source sheet is identical structure with swapped copy.

**Only product-mode changes = copy** (ES, Dani voice, consistent with "Mis zapas"):
- Mode kicker in the app bar: **"MIS ZAPAS"** (neutral `textTertiary`, spends **no**
  brand colour — the mode signal is text, not a tint; the tint washes stay on the
  Home per D26).
- Source sheet title: **"¿De dónde sacamos las zapas?"** · privacy line unchanged
  ("Tu foto no sale del móvil…").
- Source options captions: cámara → *"Las zapas, fondo liso"*; galería → *"Una que
  ya tengas"*.
- Confirm title: **"¿Se ven bien tus zapas?"**
- Guidance hint (kept light, D7): **"Fondo liso y bien iluminadas = colores más
  finos."** This hint matters **more** here than in outfit mode — a product shot is
  already a clean scene, so a plain background is the single biggest quality lever.
- Primary CTA: **"Sacar la combi"** (already primes the recommendation frame),
  secondary **"Repetir"**.

No in-app camera overlay (system `image_picker`, same as outfit) — guidance rides
in copy only.

## 3. Screen 2 — Analizando

**Reuse:** the existing analyzing screen with the F8 rewarded-ad slot, unchanged
layout. **Only copy changes:**
- Headline: **"Sacando los colores de tus zapas…"**
- Step line: **"Aislando las zapas del fondo"**
- Skip note: **"Tu combi aparece en cuanto termine — ya casi"**

Everything else identical: progress bar in mint (tint track + bright fill, non-
textual), % in mint ink, one purple signature ("ya casi"), ad slot in
`surfaceSubtle` with progress always visible above it. Per D22 the segmentation
latency does **not** apply in product-mode (no person layers), so this wait is
even shorter — the ad still covers it; nothing about the slot needs to change.

## 4. Screen 3 — Resultado / recomendación (the hero)

Reuses the `share-canvas` shell and the harmony rows, with **inverted hierarchy**:

**A. Protagonist — the recommended combo (big).** Title **"Combina tu ropa con
estas zapas"**, then a large combo band (≈150px) = the **complementary** scheme
applied, split into labelled segments: **`tus zapas`** (the sneaker base, red) +
**`tu ropa`** (the recommended complement, teal) + a neutral (`+ crema`). A one-
line caption explains the pick in Dani voice: *"El verde-azulado hace saltar el
rojo de tus zapas. Súmale crema o negro y vas fino."* This is the most colourful,
largest element on screen (Principle 2) and reads as advice, not data.

**B. Secondary — the raw sneaker palette (small).** A compact horizontal strip of
the extracted sneaker colours with the **BASE badge (D5)** — *"Base · rojo… el rojo
manda la combi"*. This is the palette that in outfit mode would be the hero;
here it is demoted to a supporting caption-sized strip.

**C. "Otras combis"** — the 4 engine harmonies reused as `_HarmonyRow` strips,
relabelled to product-mode voice (Contraste / Tono sobre tono / Equilibrada /
Contraste con matiz), each `base + matching colours` + a mint chevron. *"Toca una y
mira looks reales con esos colores."*

**CTAs (thumb zone):** primary **"Ver looks así"** = F5-lite deep-link with the
selected combo; secondary **"Otras zapas"** returns to capture. F6 story export is
**not** foregrounded (D25 downgraded it) — the `share-canvas` shell stays
exportable via the same `RepaintBoundary`, so a "Súbela a tu story" CTA is a
zero-cost option if the CEO wants it, but it is deliberately off the hero.

**Brand discipline (D8):** mint only on tappable (back, chevrons, CTAs); purple in
exactly 2 doses (BASE badge + watermark); neutrals tinted (D9). Same budget as the
canonical outfit result — the inner screens do **not** inherit the Home's D26 tint
exception.

---

## 5. Reuse vs new — what mobile-dev can lift

| Piece | Reuse / new | Note |
|---|---|---|
| Photo source sheet (camera/gallery) | **Reuse** | `photo_source_sheet.dart` — parameterise title + option captions + hint per mode |
| Confirm capture screen | **Reuse** | `capture_screen.dart` — parameterise title + hint + primary CTA label; add a mode kicker |
| Analyzing + F8 ad slot | **Reuse** | `analyzing` feature — parameterise headline + step copy only |
| `share-canvas` shell / `RepaintBoundary` | **Reuse** | Same exportable card container; content differs |
| Harmony rows (`_HarmonyRow`, `_SwatchStrip`) | **Reuse** | Relabel section to "Otras combis"; same widget |
| BASE badge + palette strip | **Reuse (restyled small)** | `_BaseLine`/`_Palette` logic; rendered compact/secondary |
| Watermark | **Reuse** | `_Watermark` unchanged |
| **Combo hero band (labelled `tus zapas`/`tu ropa`)** | **NEW** | The one genuinely new widget — a large 2–3 segment band with role tags + caption. Small, self-contained |
| Mode-aware copy strings | **NEW** | A copy map keyed by mode (outfit/sneaker); no new screens |
| Product-mode engine call (no person layers) | **NEW (not UX)** | Mobile/ML seam per D24; UX-agnostic |

Net: **one new UI widget** (the combo hero band) + a copy map + a product-mode
engine flag. Everything else is reuse or a copy swap. Low engineering risk.

---

## 6. ES copy inventory (Dani voice)

- Mode kicker: **MIS ZAPAS**
- Sheet: **¿De dónde sacamos las zapas?** / *Tu foto no sale del móvil: se analiza aquí mismo.*
- Confirm: **¿Se ven bien tus zapas?** · hint *Fondo liso y bien iluminadas = colores más finos.* · **Sacar la combi** / **Repetir**
- Analizando: **Sacando los colores de tus zapas…** · *Aislando las zapas del fondo* · *Tu combi aparece en cuanto termine — ya casi*
- Resultado: **Combina tu ropa con estas zapas** · *El verde-azulado hace saltar el rojo de tus zapas. Súmale crema o negro y vas fino.* · **Base · rojo** / *La paleta de tus zapas. El rojo manda la combi.* · **Otras combis** / *Toca una y mira looks reales con esos colores.* · **Ver looks así** / **Otras zapas**

---

## 7. Open questions for the CEO

1. **Recommendation-first hierarchy:** confirmed that the result leads with the
   **combo** (protagonist) and demotes the raw sneaker palette to a small strip?
   This is the D25 intent, but it is a real departure from the outfit result the CEO
   already ratified — worth an explicit yes.
2. **The one recommended combo:** the hero features **one** curated combo
   (complementary). Is one hero pick + "Otras combis" below the right dosage, or do
   you want the hero to rotate/pick differently (e.g. lead with the analogous/safe
   combo instead of the boldest contrast)?
3. **Combo segment labels** ("tus zapas" / "tu ropa"): do these labels make the
   recommendation legible, or do they read as clutter against D7's minimalism? The
   alternative is an unlabelled band + caption only.
4. **F6 story CTA:** keep it **off** the sneaker result (D25 posture), or add a
   discreet "Súbela a tu story" secondary since the shell is already exportable?
5. **CTA copy:** **"Sacar la combi"** (capture) and **"Ver looks así"** (result) —
   Dani-enough, or push further into slang?
6. **Result app-bar kicker:** show **"MIS ZAPAS"** as the mode label, or keep the
   plain **"PiketeMaker"** wordmark used on the outfit result for brand consistency?

**Downstream unblocked once ratified:** mobile-dev builds the sneaker flow (capture
copy map + product-mode engine call + combo hero widget + result relabel); QA runs
the product-photo eval battery (G2S). No blockers on other roles.
