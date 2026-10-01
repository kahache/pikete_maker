# Sneaker flow FINAL spec — Home + Captura → Analizando → Resultado (F2S · D26+D27)

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-07-11 |
| **Phase / feature** | Phase 2S · F11 (sneaker/product mode) |
| **Status** | **FINAL — implementation reference for mobile-dev.** Applies D26 (as amended) and D27 (both ratified by the CEO, PRD §10). |
| **Mockup (canonical)** | `docs/design/mockups/2026-07-11_1030_F2S_sneaker-inner-flow-final.html` (4 phone frames: Home + 3 inner screens) |
| **Supersedes (as implementation reference)** | `docs/design/mockups/2026-07-10_2130_F2S_split-home.html` and `docs/design/mockups/2026-07-10_2200_F2S_sneaker-inner-flow.html` + their docs — those remain **immutable exploration snapshots**; do not implement from them |
| **Constraints obeyed** | D5 (base = most chromatic), D7 (radical simplicity), D8 (mint = action, purple ≤2 doses — Home tint exception per D26 only), D9 (tinted neutrals), D10 (canvas mode), D14 (logo frozen), D25 (no share CTA), D26 (split Home, Variant A), D27 (inverted result hierarchy) |

---

## 1. What changed vs the 2026-07-10 mockups (delta summary)

| # | Change | Decision |
|---|---|---|
| 1 | Home bottom-zone label **«Mi fit» → «Mi pikete»** (top stays «Mis zapas») | D27 amends D26 |
| 2 | Result inverted hierarchy (recommendation = hero, palette = secondary strip) is now **ratified**, not a proposal | D27 |
| 3 | Hero combo explicitly = the **complementary** scheme; a new **hero kicker** line names it («La combi · Contraste») | D27 (Q2) |
| 4 | «Otras combis» drops from 4 rows to **3 rows** — the complementary is the hero, so it is not repeated below (Tono sobre tono · Equilibrada · Contraste con matiz) | Consequence of D27 hero pick |
| 5 | Micro-labels «tus zapas» / «tu ropa» on the hero band **confirmed kept** | D27 (Q3) |
| 6 | **No share CTA and no save/bookmark UI** anywhere on the result. Saving folds into F7 (history, «mis paletas»/«mis recomendaciones») — explicitly NOT this phase | D25 holds; D27 (Q4) + F7 note |
| 7 | CTA copy pushed to **full slang**: capture «Sacar la combi» → **«Dame la combi»**, «Repetir» → **«Otra foto»**; result «Ver looks así» → **«Enséñame fits así»** («Otras zapas» unchanged) | D27 (Q5) |
| 8 | App-bar kicker = contextual **«MIS ZAPAS»** confirmed (not the PiketeMaker wordmark) | D27 (Q6) |
| 9 | Result-screen dead calendar copy refreshed to the mock date (cosmetic) | — |

Everything else (layout, tokens, reuse strategy, analyzing screen) is unchanged
from the 07-10 exploration.

---

## 2. Screen 0 — Home (split 50/50, D26 as amended)

Layout is D26 Variant A verbatim; only the bottom label changes.

| Element | Spec (token) | Value / copy |
|---|---|---|
| Top bar | overlaid, transparent; lockup left (symbol 18px + word 12/800), help icon right (28px glyph in 44px target, `textTertiary`) | Tutorial re-entry unchanged (F13) |
| Zone: top («Mis zapas») | flex 1, background `mint.tint` #DFF7F1 | Glyph 84px sneaker outline in `mint.ink`; label `display` (32/38/800) `textPrimary`; caption `body` (15/22) `textSecondary` |
| Zone: bottom («Mi pikete») | flex 1, background `purple.tint` #EFEAFB (**Home-only D8 exception, D26**) | Glyph 84px tee outline in `purple.ink`; same type specs |
| Divider | 1px `rgba(28,24,38,0.10)` | — |
| Go affordance | `caption`-size 13/700, chevron 16px; `mint.ink` on top zone, `purple.ink` on bottom zone | «Empezar» |
| Copy | top: **Mis zapas** / *Monta el fit desde tus zapas* · bottom: **Mi pikete** / *Saca la paleta de tu fit* | |

Routing: top zone → sneaker flow (this spec §3–§5); bottom zone → existing
outfit flow, untouched. First-launch onboarding gate unchanged.

---

## 3. Screen 1 — Captura (source sheet + confirm)

**Reuse:** `photo_source_sheet.dart` + `capture_screen.dart`, parameterised by
mode (copy map). No new layout. System camera via `image_picker`, no overlay.

| Element | Spec (token) | Value / copy |
|---|---|---|
| App bar | height 52; back 48×48 in `mint.ink`; centered kicker in `label` style (11/14/700, tracking 0.08em, uppercase) `textTertiary` | Kicker: **MIS ZAPAS** (D27) |
| Source sheet title | `title` (20/26/700) | **¿De dónde sacamos las zapas?** |
| Privacy line | `caption` `textSecondary` | *Tu foto no sale del móvil: se analiza aquí mismo.* |
| Option captions | `caption` | cámara → *Las zapas, fondo liso* · galería → *Una que ya tengas* |
| Confirm title | `title` | **¿Se ven bien tus zapas?** |
| Photo preview | flex-fill, radius `lg` (20) | — |
| Hint row | icon 16px `mint.ink` + `caption` `textSecondary`, centered | *Fondo liso y bien iluminadas = colores más finos.* |
| Primary CTA | pill, h 56 (`ctaHeight`), fill `role.action` #0B7C6C, text `cta` (16/700) white | **Dame la combi** |
| Secondary CTA | pill h 56, white fill, 1.5px `borderStrong`, text `mint.ink` | **Otra foto** |
| Spacing | `xl` (24) above primary, `md` (12) between CTAs, ≥24 to bottom edge (`thumbZoneCTA`) | |

---

## 4. Screen 2 — Analizando

**Reuse:** existing analyzing screen + F8 ad slot, layout untouched. Copy only:

| Element | Copy |
|---|---|
| Headline (`title`) | **Sacando los colores de tus zapas…** |
| Step line (`caption` `textSecondary`) | *Aislando las zapas del fondo* |
| Skip note (`caption` `textTertiary`; «ya casi» in `purple.ink` 700) | *Tu combi aparece en cuanto termine — **ya casi*** |

Progress: track 6px `mint.tint`, fill `mint.bright`, % in `mint.ink` `dataMono`.
Ad slot: `surfaceSubtle`, radius `lg`, max 4:5, progress always visible above it
(tokens.json `adSlot` rules). Per D22 latency is non-gating; product-mode skips
the person layers so this wait is shorter — no layout change needed.

---

## 5. Screen 3 — Resultado (INVERTED hierarchy, D27)

**Shell reuse:** `share-canvas` card (`RepaintBoundary` container), harmony rows
(`_HarmonyRow`/`_SwatchStrip`), BASE badge, watermark. **One genuinely new
widget:** the hero combo band.

Order inside the scroll:

1. **App bar** — back (mint.ink) + kicker **MIS ZAPAS** (same spec as §3).
2. **Share-canvas card** (margin `screenMargin` 20, padding 24/24/16, radius
   `lg`, `border` + `shadow-sm`):
   - Meta line (`caption` `textTertiary`): *Tus zapas · {fecha}*.
   - Title (`display` 32/36/800): **Combina tu ropa con estas zapas**.
   - **Hero kicker** (NEW, `label` style 11/14/700 uppercase `textTertiary`,
     margin-top `lg`): **La combi · Contraste**. Names the hero scheme and ties
     to the «Otras combis» section.
   - **Hero combo band** (NEW widget): height **150**, radius `md` (14),
     hairline ring (`border`), margin-top `sm`. Segments = complementary combo:
     `tus zapas` (sneaker BASE color, flex ≈1.15) + `tu ropa` (complement,
     flex ≈1.55) + one neutral suggestion (`+ crema`/`+ negro`, flex ≈0.9).
     Segment micro-labels (D27 keeps them): 10/700 uppercase pills,
     bottom-left inside each segment, white text on `rgba(0,0,0,0.22)` for
     dark segments / `#3A3730` on `rgba(255,255,255,0.55)` for light segments
     (pick by segment luminance; threshold as in the outfit swatch text rule).
   - **Caption** (`caption` `textSecondary`, lead phrase 600 `textPrimary`):
     *«El verde-azulado hace saltar el rojo de tus zapas. Súmale crema o negro
     y vas fino.»* — template: *«El {complement} hace saltar el {base} de tus
     zapas. Súmale {neutral1} o {neutral2} y vas fino.»* Color names come from
     the engine's existing ES color-naming map.
   - **Secondary palette strip** (demoted raw palette): separated by a 1px
     `border` rule, padding-top `lg`. Strip 108×30, radius `sm`, up to 5
     swatches, BASE swatch marked with the white dot + `purple.ink` ring
     (existing pattern). Right side: **BASE badge** (`label` on `purple.tint`,
     text `purple.ink`): **Base · {color}**; desc (`caption`): *La **paleta de
     tus zapas**. El {color} manda la combi (D5).*
   - **Watermark** (`textDisabled`, dot in `purple.ink`): *piketemaker.*
3. **Section «Otras combis»** (`title` + sub `caption`): *Toca una y mira looks
   reales con esos colores.* — **3 rows** (complementary NOT repeated):
   | Row (`heading`) | Sub (`caption` tertiary) | Engine scheme |
   |---|---|---|
   | Tono sobre tono | Cálidos, suave | analogous |
   | Equilibrada | 3 colores, atrevida | triadic |
   | Contraste con matiz | Punch, más fino | split-complementary |
   Row anatomy unchanged from outfit result: name left, 132×44 strip, mint
   chevron, 1px separators, min-height 44. Tap → same deep-link action as the
   primary CTA but with that scheme.
4. **CTA block** (padding-top `2xl`, gap `md`, thumb zone):
   - Primary: **Enséñame fits así** → F5-lite deep-link with the hero combo.
   - Secondary: **Otras zapas** → pops back to capture (source sheet).
   - **No share CTA, no save/bookmark icon or CTA** (D25 holds; save = F7
     roadmap «mis paletas»/«mis recomendaciones», new navigation, NOT Phase 2S).

**Brand budget check (D8):** mint only on tappables (back, chevrons, 2 CTAs);
purple exactly 2 doses (BASE badge, watermark). The hero kicker and segment
labels are neutral. Inner screens do NOT inherit the Home tint exception.

### States

| State | Behavior |
|---|---|
| Normal | As above. Palette reveal uses `motion.reveal` (600ms) — same moment as outfit. |
| **Canvas mode (D10)** — 100% neutral sneakers (white/black/grey kicks) | The hero combo band is replaced by the **canvas accents strip** (the 5 curated `kCanvasAccents` pops, same component as the outfit result's canvas section). Title stays; hero kicker becomes **La combi · Lienzo**; caption: *«Zapas neutras = lienzo total. Cualquiera de estos cinco pops les sienta de lujo.»* Secondary palette strip + BASE badge render as usual (base will be a neutral; badge shows **Base · {neutro}**). «Otras combis» section is hidden (no chromatic base → no harmonies), CTAs unchanged. |
| Analysis failed | Reuse the outfit error state (`ugly-states.html` pattern), copy: title **No hemos pillado los colores** · body *Prueba con más luz o con un fondo liso.* · CTA **Otra foto**. |
| Permission denied / offline | Identical reuse of outfit ugly states; no sneaker-specific variants. |
| Loading (analyzing) | §4. Progress must keep advancing above the ad (adSlot rule). |

---

## 6. Copy inventory — FINAL ES strings (source of truth for the mode copy map)

| Key | String |
|---|---|
| `home.sneaker.label` | Mis zapas |
| `home.sneaker.caption` | Monta el fit desde tus zapas |
| `home.outfit.label` | **Mi pikete** |
| `home.outfit.caption` | Saca la paleta de tu fit |
| `home.zone.go` | Empezar |
| `sneaker.appbar.kicker` | MIS ZAPAS |
| `sneaker.sheet.title` | ¿De dónde sacamos las zapas? |
| `sneaker.sheet.privacy` | Tu foto no sale del móvil: se analiza aquí mismo. |
| `sneaker.sheet.camera.caption` | Las zapas, fondo liso |
| `sneaker.sheet.gallery.caption` | Una que ya tengas |
| `sneaker.confirm.title` | ¿Se ven bien tus zapas? |
| `sneaker.confirm.hint` | Fondo liso y bien iluminadas = colores más finos. |
| `sneaker.confirm.cta.primary` | **Dame la combi** |
| `sneaker.confirm.cta.secondary` | **Otra foto** |
| `sneaker.analyzing.headline` | Sacando los colores de tus zapas… |
| `sneaker.analyzing.step` | Aislando las zapas del fondo |
| `sneaker.analyzing.skipNote` | Tu combi aparece en cuanto termine — ya casi |
| `sneaker.result.meta` | Tus zapas · {fecha} |
| `sneaker.result.title` | Combina tu ropa con estas zapas |
| `sneaker.result.heroKicker` | La combi · Contraste |
| `sneaker.result.tag.zapas` | tus zapas |
| `sneaker.result.tag.ropa` | tu ropa |
| `sneaker.result.tag.neutral` | + {neutro} |
| `sneaker.result.caption` | El {complemento} hace saltar el {base} de tus zapas. Súmale {neutro1} o {neutro2} y vas fino. |
| `sneaker.result.base.badge` | Base · {color} |
| `sneaker.result.base.desc` | La paleta de tus zapas. El {color} manda la combi. |
| `sneaker.result.section.title` | Otras combis |
| `sneaker.result.section.sub` | Toca una y mira looks reales con esos colores. |
| `sneaker.result.harmony.analogous` | Tono sobre tono · Cálidos, suave |
| `sneaker.result.harmony.triadic` | Equilibrada · 3 colores, atrevida |
| `sneaker.result.harmony.splitComp` | Contraste con matiz · Punch, más fino |
| `sneaker.result.cta.primary` | **Enséñame fits así** |
| `sneaker.result.cta.secondary` | **Otras zapas** |
| `sneaker.result.canvas.kicker` | La combi · Lienzo |
| `sneaker.result.canvas.caption` | Zapas neutras = lienzo total. Cualquiera de estos cinco pops les sienta de lujo. |
| `sneaker.error.title` | No hemos pillado los colores |
| `sneaker.error.body` | Prueba con más luz o con un fondo liso. |
| `sneaker.error.cta` | Otra foto |

Strings go through the ARB extraction (#46, D18 groundwork); Catalan versions
are a growth/UX localization pass (voice adaptation, not literal — D18), out of
this spec's scope.

---

## 7. Reuse vs new — mobile hand-off

| Piece | Reuse / new | Note |
|---|---|---|
| Home split zones | **NEW (per D26)** | Two full-height tappable zones + overlaid top bar; labels per §2 |
| Photo source sheet | **Reuse** | `photo_source_sheet.dart`, copy map keyed by mode |
| Confirm capture screen | **Reuse** | `capture_screen.dart`, copy map + mode kicker |
| Analyzing + F8 ad slot | **Reuse** | copy map only |
| `share-canvas` shell / `RepaintBoundary` | **Reuse** | container unchanged; content per §5 |
| **Hero combo band + hero kicker** | **NEW** | The one new widget: 150px band, 2–3 segments with role tags + caption; luminance-picked tag colors |
| Palette strip + BASE badge (compact) | **Reuse (restyled small)** | 108×30 strip variant |
| Harmony rows | **Reuse** | 3 rows, relabelled; complementary excluded |
| Canvas accents strip | **Reuse** | same component as outfit canvas section (D10/#21) |
| Watermark | **Reuse** | unchanged |
| Product-mode engine call | **NEW (not UX)** | per D24 / I5 addendum #2 |

---

## 8. Open questions for the CEO

None blocking. All D27 sub-decisions are applied as ratified. Two FYIs (no
action needed unless he disagrees on device):

1. The full-slang CTA strings chosen under D27-Q5 are **«Dame la combi»**,
   **«Otra foto»**, **«Enséñame fits así»** — reviewable live in the r7 build;
   changing a string later is copy-map-only, zero layout risk.
2. With the complementary promoted to hero, «Otras combis» shows 3 rows instead
   of 4 (the hero is not repeated). This is the internally consistent reading of
   D27; flagging it because the 07-10 snapshot showed 4.
