# Brand-block sizing — #58 & #59 (propose → CEO picks → implement)

> Phase 2 visual debt, low priority. **Design-only spec.** A dev changes the
> named constants from the numbers below; zero further design questions.
> Same flow as the r5-visual-decisions sheet: the CEO approves or adjusts the
> numbers on device, then the mobile-dev lands them and syncs the mockups.
>
> Origin: CEO device feedback on build r6 (2026-07-09). Both items are
> "make it a bit bigger" nudges, directional and without numbers. This spec
> turns them into concrete, clearspace-checked values.

---

## #58 · Grow the brand blocks (Home hero + onboarding block)

CEO on both H2 (Home hero) and E3 (ONB-1 block): confirmed good, but
"incluso yo la aumentaría algo más". A small, tasteful bump — not a redesign.

### 58a · Home hero symbol (`_heroLogoSize`)

- **File / constant:** `app/lib/features/home/home_screen.dart` →
  `static const double _heroLogoSize` (currently `96`).
- **CURRENT:** `96` px (H2, the +50% pick from the r5 sheet).
- **PROPOSED (recommended):** **96 → 112 px** (+17%).
  - Rationale: 112 px is the canonical brand-symbol height already used by the
    splash (USAGE §7, "112 dp"). Reusing it makes Home and splash read as the
    same brand height, answers "algo más" without shouting, and stays clearly
    below the 32 px text headline the CEO wants as the hero.
- **Upper option (only if the CEO wants the maximum):** **120 px** (the old H3
  from the r5 sheet, then not chosen). See the clearspace note — 120 needs one
  extra tweak; 112 does not.

**Clearspace check (USAGE §3 = piquete diameter ≈ 21% of symbol height):**
- At **112 px** → clearspace needed = 0.21 × 112 ≈ **24 px** per side. The gap
  below the hero to the headline is `Space.xl` = **24 px** → meets the minimum
  exactly. Above: `Spacer(flex: 2)` → far more. Sides: `Center` inside a 390 px
  width with 20 px margins → ~139 px each side. **PASS, no other change.**
- At **120 px** → needs ≈ **25.2 px**, which is > `Space.xl` (24). To use 120,
  bump the below-hero gap from `Space.xl` (24) to `Space.xxl` (32). Flag for
  the dev; don't ship 120 with the 24 px gap.
- Does NOT dethrone the text headline: the symbol is silent (no wordmark on
  Home), the headline "Analiza tu fit" stays the only display-size type. Growing
  a wordless mark does not add competing text hierarchy.

### 58b · Onboarding ONB-1 brand block (`_symbolSize` + wordmark + gap)

- **File:** `app/lib/features/onboarding/onboarding_screen.dart` →
  `_WelcomePage`: `_symbolSize` (112), `_wordmarkFontSize` (27),
  `_brandGap` (18).
- **CURRENT:** symbol `112` px · wordmark `27` px · internal gap `18` px (E3).
- **PROPOSED (recommended):** scale the whole block by ×1.143 so its internal
  proportions stay frozen (USAGE §4: wordmark cap-height = 61% of symbol
  content height — must scale together, not independently):
  - symbol **112 → 128 px** (+14%).
  - wordmark **27 → 31 px** (keeps the 61% ratio; stays *just under* the 32 px
    headline, so it does not dethrone the text hero).
  - internal gap **18 → 20 px** (proportional).
  - Rationale: ONB-1 is the app's single most brand-forward surface (the one
    screen where "solo logo y bien grande" is the point). +14% gives the "algo
    más" presence while the headline "Los colores de tu fit, con criterio."
    stays the text hero (CEO's word, r5 sheet §2a).

**Clearspace check:**
- At **128 px** symbol → clearspace needed = 0.21 × 128 ≈ **27 px** around the
  stacked block. The block sits between `Spacer()` above and `Spacer()` below
  (and the headline is another `Spacer()` away) → each provides well over 27 px.
  **PASS.**
- The 20 px internal gap is *inside* the composition (symbol↔wordmark), not the
  external clearspace; the block is treated as one unit for §3, as today.
- Headline not dethroned: wordmark 31 px < headline 32 px, and the two are
  separated by a full `Spacer()`.

**Rule kept:** USAGE §9 — no `action.bright` mint accent may be added near the
lockup on ONB-1. This bump changes size only; add no new graphic detail.

---

## #59 · Tutorial re-entry icon on Home — too small

CEO: the "Cómo hacer la foto" help icon on Home "se ve muy pequeñito". This is
about the **visual glyph**, not the touch target (which already holds).

- **File:** `app/lib/features/home/home_screen.dart`, the top-row `IconButton`
  (`Icons.help_outline`, `tooltip: 'Cómo hacer la foto'`,
  `color: c.textTertiary`).
- **CURRENT glyph:** **24 px** — the Material `IconButton` default (no `size:`
  passed today). Touch target = 44/48 px (IconButton min constraint). Confirmed
  the 44 px target already holds; only the glyph reads small.
- **PROPOSED:** glyph **24 → 28 px** (+17%). Pass `size: 28` to the `Icon`;
  leave the IconButton touch target untouched.
  - Rationale: matches the +17% we give the Home hero, restores discoverability
    of the *only* way back into the tutorial (there is no Settings screen yet —
    onboarding-tutorial §1.3), and stays discreet: still `textTertiary`, still
    top-right, still out of the thumb's path. 28 px sits comfortably inside the
    44 px target (8 px padding per side).
  - Clearspace: N/A — this is a Material UI glyph, not a logo; USAGE §3 governs
    the mark only.

**Icon-only vs. text label — recommendation: KEEP ICON-ONLY.**
- Rationale: D7 is radical simplicity / minimal text. A "Cómo hacer la foto"
  label in the top bar would add clutter and compete with the discreet lockup
  on the left. The `tooltip` already carries the label for a11y/long-press, and
  bumping the glyph to 28 px solves the "pequeñito" complaint directly. Adding
  text would over-solve a size problem.
- **Fallback (Option B, only if 28 px still reads too weak on device):** add a
  subtle circular background behind the glyph — `surfaceSubtle` fill, 44 px
  circle — for presence without any text. Keep the glyph at 24–28 px. This is a
  visual-weight lever, not a text one; it preserves icon-only.

---

## Summary of numbers (for the CEO to approve or adjust)

| # | Element | Current | Proposed | Upper option |
|---|---|---|---|---|
| 58a | Home hero symbol | 96 px | **112 px** | 120 px (needs gap → `Space.xxl`) |
| 58b | ONB-1 symbol | 112 px | **128 px** | — |
| 58b | ONB-1 wordmark | 27 px | **31 px** | — |
| 58b | ONB-1 internal gap | 18 px | **20 px** | — |
| 59 | Tutorial icon glyph | 24 px | **28 px** | +circular bg (Option B) |
| 59 | Tutorial icon label | none | **keep none** | — |

## Device-validation note

This is a propose → CEO-picks → implement flow. Nothing lands until the CEO
sees the numbers on device (r6 build in hand) and confirms. The CEO may:
- take the recommended column as-is (safe, all clearspace-checked), or
- pick 120 px for the Home hero (then the dev must bump the below-hero gap to
  `Space.xxl`), or
- adjust any single number — the constants are independent, changing one does
  not force the others (except the ONB-1 trio, which scale together to keep the
  61% wordmark ratio frozen — treat 128/31/20 as one choice).

## Mockup sync (do when the code lands)

`docs/design/mockups/home.html` and `.../onboarding.html` reflect the CURRENT
sizes and must be re-synced once the CEO's picks ship:
- `home.html`: hero `<svg width/height>` (currently 64 in the mockup — note the
  mockup is behind the live 96; sync to the approved value) and the help-icon
  `<svg>` (currently 24 → approved glyph).
- `onboarding.html`: ONB-1 symbol + wordmark sizes → approved values.
Mockups are the CEO's browser-review surface; keep them equal to shipped code.
