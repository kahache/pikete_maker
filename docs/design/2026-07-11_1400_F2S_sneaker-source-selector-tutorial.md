# Sneaker "photo source selector" + mini-tutorials — spec (F2S · #83)

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-07-11 |
| **Phase / feature** | Phase 2S · F11 (sneaker/product mode) · issue **#83** |
| **Status** | **Ready for mobile-dev** — one CEO decision open (§7, flow-merge). |
| **Mockup (canonical)** | `docs/design/mockups/2026-07-11_1400_F2S_sneaker-source-selector.html` (chooser + 3 mini-tutorials + a thumbnail-brief panel) |
| **Builds on** | `docs/design/2026-07-11_1030_F2S_sneaker-flow-final-spec.md` (the sneaker inner flow) — this inserts one screen **before** its §3 Captura |
| **Constraints obeyed** | D7 (radical simplicity), D8 (mint = action, purple ≤2 doses/screen), D9 (tinted neutrals), D12 (tutorial pattern, reused), D24 (product-mode = whole-frame, no person layers), D27 (sneaker slang, «MIS ZAPAS» kicker) |

---

## 1. Why this exists (the product fix, not an algorithm fix)

Today's gate **G2S** eval (99 photos) showed the sneaker/product engine (D24:
analyzes the **whole frame**, no person layers) is accurate **only when the
sneaker fills the frame on a simple background**. It degrades in exactly three
capture situations:

| Situation | Failure mode | Product fix (this spec) |
|---|---|---|
| **Web screenshot** (StockX / shop) | sneaker is a small thumbnail in a white browser UI → white dominates → ~90% route to **canvas mode** wrongly | coach: **crop** to leave only the sneaker |
| **Store shelf shot** | background clutter (boxes, shelves, other kicks) pollutes the palette | coach: put/hold them **on the floor**, top-down, "as if they were yours" (replicate the phone case that already works) |
| **Phone floor shot, too far** | floor + surroundings intrude, sneaker doesn't fill the frame | coach: **center**, fill the frame |

So before capture we ask **where** the photo comes from and hand back a tiny,
situation-specific tip. It mirrors the outfit tutorial (D12): coach the user
into the easy case instead of fighting it in the pipeline.

This is **UX + copy + 3 illustrations only.** No engine change.

---

## 2. Where it slots in the flow

```
Home  ──tap "Mis zapas"──►  [NEW] Source selector  ──tap a card──►  [REUSED] Mini-tutorial  ──CTA──►  camera / gallery picker  ──►  Confirm (spec 1030 §3) ──► Analizando ──► Resultado
```

- The **source selector** replaces the current camera/gallery source sheet in
  **sneaker mode only** (see §7 — the card already implies the source, so the
  two-question stack collapses to one). The outfit flow is untouched.
- Each card opens **one** mini-tutorial screen whose primary CTA **is** the
  capture trigger — it is a launch pad, not a detour (one screen between choice
  and camera).
- `casa` / `tienda` cards → **camera**; `web` card → **gallery** (a screenshot
  already lives on the phone).

---

## 3. Screen A — Source selector (NEW, but built from reused parts)

Anatomy = the existing `photo_source_sheet.dart` option row (`_SourceOption`),
promoted to a full screen with 3 rows. No new layout primitive.

| Element | Token / spec | Value / copy |
|---|---|---|
| App bar | reuse spec-1030 §3: back 48×48 `action` (mint.ink); centered kicker `label` (11/14/700, 0.08em, uppercase) `textTertiary` | Kicker: **MIS ZAPAS** |
| Heading | `display` (32/38/800) `textPrimary`, margin-top `sm` | **¿Desde dónde haces la foto?** |
| Sub | `body` (15/22) `textSecondary`, margin-top `sm` | *Cada sitio tiene su truco. Elige el tuyo.* |
| 3 cards | stack, gap `md` (12), min-height 72 each, radius `md`, 1px `border`, padding-h `lg` | see below |
| — emoji tile | 44×44, `surfaceSubtle` fill, radius `sm`, emoji 24px centered (**neutral tile — mint budget spent only on the chevron**, D8) | 🏠 / 🏬 / 💻 |
| — card title | `heading` (16/22/600) `textPrimary` | see below |
| — card hint | `caption` (13/18) `textTertiary`, 1 line | see below |
| — chevron | `chevron_right` 24 in `action` (mint.ink) | the only mint on the screen |
| Privacy footer | `caption` `textTertiary`, centered, margin-top `lg` (carried over from the source sheet so we don't lose the reassurance) | *Tu foto no sale del móvil: se analiza aquí mismo.* |

**Cards (title · hint):**

| Card | Emoji | Title | Hint (1 line) |
|---|---|---|---|
| `casa` | 🏠 | **Casa o calle** | Las zapas, en el centro y llenando la foto |
| `tienda` | 🏬 | **En una tienda** | Ponlas en el suelo, como si fueran tuyas |
| `web` | 💻 | **Captura de pantalla** | Recórtala hasta dejar solo la zapa |

**Brand budget (D8):** mint appears only on tappables (back + 3 chevrons);
**zero purple** on this screen. Emoji are the only color — acceptable: no user
palette is present on a chooser screen, and they read as pictograms, not decor.

---

## 4. Screen B — Mini-tutorial (REUSED tutorial screen, 1 page)

**Reuse target:** the onboarding pro-tip page anatomy
(`onboarding_screen.dart` → `_ProTipPage`): badge → `display` headline →
illustration card → short caption → `PkPrimaryButton`. Same paddings, same
type ramp, same button. **Do NOT redesign it.** The only genuinely new asset is
**one thumbnail illustration per case** (§5).

| Element | Token / spec | Value |
|---|---|---|
| App bar | back `action` + kicker **MIS ZAPAS** | (reused) |
| Badge | reuse `_ProTipBadge`, relabelled: `label` on `accentTint`, text `accent` (purple.ink) — **1 (of ≤2) purple dose** | **EL TRUCO** |
| Headline | `display` (32/38/800) `textPrimary` | per case (§6) |
| Illustration | card, `surfaceSubtle` fill, radius `md`, 1px `border`, scene ~160×120 (same footprint as `TipIllustration`) | **NEW per case** (§5) |
| Body | `body` (15/22) `textSecondary`, max ~2 lines (D7) | per case (§6) |
| Primary CTA | `PkPrimaryButton`, pill h56, `action` fill, white `cta` text | per case (§6) |

No secondary CTA and no "Saltar" here: the card choice was already the opt-in,
and the CTA **is** the capture launch. Back arrow returns to the selector.

**Progressive-disclosure note (future, non-blocking):** we could remember a
per-source "truco visto" flag and, on later captures, let the selector card jump
straight to the picker with a small "ver el truco" affordance — mirroring the
once-only onboarding gate. Kept out of v1 to stay simple; flagged for the
backlog.

---

## 5. Thumbnail illustration briefs (the 3 new assets)

Style = **exactly `TipIllustration`** (`app/lib/features/onboarding/tip_illustrations.dart`):
flat, token-color shapes on a `surfaceSubtle` scene, `border` floor band,
objects in `textSecondary`, brand tints (`actionTint` / `accentTint`) in tiny
doses, mint (`action`) reserved for the "do this" marker. **Reuse the app's own
sneaker glyph** (the `mode_glyphs.dart` / split-Home sneaker outline) as the
sneaker in all three, so the illustrations feel native. 160×120 master viewBox.
Clean inline SVGs are rendered in the mockup — port them as `CustomPainter`
like `TipIllustration` (no raster, no `flutter_svg`; gate G1).

1. **`casa` — center-frame / fill the frame.** One large sneaker glyph
   (`textSecondary`), centered, deliberately **big enough to nearly touch** four
   **mint corner brackets** (`action`, the "fill it" marker). Reads: get close,
   sneaker fills the frame.

2. **`tienda` — floor-place, top-down.** Sneaker glyph resting on a `border`
   **floor band** with a soft `borderStrong` shadow; above it a small phone
   pictogram and a **downward mint chevron** (`action`) = shoot from above.
   Reads: put them on the floor and shoot down, as if they were yours.

3. **`web` — crop the screenshot.** A browser window (white `surface`, top bar
   `surfaceSubtle` with 3 `borderStrong` dots) holding a small sneaker plus a
   couple of faux **UI/price lines** (`border`); a **dashed mint crop rectangle**
   (`action`) hugs just the sneaker, the area outside it dimmed. Reads: cut away
   the web UI, keep only the zapa.

---

## 6. Copy inventory — FINAL ES (source of truth for the copy map)

Voice: sneaker slang (`zapas`, `pikete`, `combi`), tú-form, radical simplicity
(D7/D27). Extends `SneakerStrings` — same file, same keys style.

| Key | String |
|---|---|
| `sneaker.source.title` | ¿Desde dónde haces la foto? |
| `sneaker.source.sub` | Cada sitio tiene su truco. Elige el tuyo. |
| `sneaker.source.privacy` | Tu foto no sale del móvil: se analiza aquí mismo. |
| `sneaker.source.casa.title` | Casa o calle |
| `sneaker.source.casa.hint` | Las zapas, en el centro y llenando la foto |
| `sneaker.source.tienda.title` | En una tienda |
| `sneaker.source.tienda.hint` | Ponlas en el suelo, como si fueran tuyas |
| `sneaker.source.web.title` | Captura de pantalla |
| `sneaker.source.web.hint` | Recórtala hasta dejar solo la zapa |
| `sneaker.tip.badge` | EL TRUCO |
| **`sneaker.tip.casa.title`** | Zapas en el centro, llenando la foto |
| **`sneaker.tip.casa.body`** | Acércate hasta que las zapas ocupen casi toda la pantalla. Fondo liso (suelo o pared) y buena luz. |
| **`sneaker.tip.casa.cta`** | Hacer la foto |
| **`sneaker.tip.tienda.title`** | Ponlas en el suelo, como tuyas |
| **`sneaker.tip.tienda.body`** | Baja las zapas al suelo y dispara desde arriba, como si ya fueran tuyas. Así el fondo no se cuela en los colores. |
| **`sneaker.tip.tienda.cta`** | Hacer la foto |
| **`sneaker.tip.web.title`** | Recorta hasta dejar solo la zapa |
| **`sneaker.tip.web.body`** | Antes de subirla, recorta la captura: fuera el navegador, el precio y todo lo blanco. Solo la zapa. |
| **`sneaker.tip.web.cta`** | Elegir la captura |

---

## 7. Reuse vs new — mobile hand-off

| Piece | Reuse / new | Note |
|---|---|---|
| **Source selector screen** | **NEW (thin)** | 3× the existing `_SourceOption` row promoted to a full screen; emoji tile in `surfaceSubtle` (not `actionTint`) + mint chevron. Reuse app bar from spec-1030 §3. |
| **Mini-tutorial screen** | **REUSE** | The onboarding pro-tip page anatomy (`_ProTipPage`): badge + `display` + illustration card + caption + `PkPrimaryButton`. Do NOT redesign. Relabel badge → «EL TRUCO». |
| **3 thumbnail illustrations** | **NEW (the real new art)** | Port as `CustomPainter` like `TipIllustration`; reuse the `mode_glyphs` sneaker path. |
| Camera/gallery picker | **REUSE** | `photo_picker.dart` — the card picks the source: `casa`/`tienda` → camera, `web` → gallery. |
| Confirm / Analizando / Resultado | **REUSE** | unchanged from spec-1030 §3–§5. |

**Analytics (extends `AnalyticsEvents`):**
`sneaker_source_selected` — fired when a selector card is tapped, param
`{'source': 'casa' | 'tienda' | 'web'}`. Answers "which capture situation do
sneaker users actually shoot from?" — the read that tells us whether the coach
is working (fewer canvas-mode misroutes after web-crop coaching) and where the
G2S error concentrates. Fires **before** the mini-tutorial, once per selection.

---

## 8. Open question for the CEO (1, non-blocking)

**Flow merge — does the selector replace the camera/gallery source sheet in
sneaker mode?** Recommended: **yes.** The card already determines the source
(`casa`/`tienda` = camera, `web` = gallery), so keeping both would be two
"where from?" questions back-to-back — against D7. This spec assumes the merge
and carries the privacy line onto the selector so nothing is lost. If the CEO
prefers the absolute-minimum-diff path instead, we keep the existing source
sheet and show it after the mini-tutorial (one extra tap); copy is unchanged
either way. Everything else here needs no decision.
</content>
</invoke>
