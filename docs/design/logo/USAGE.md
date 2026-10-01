# PiketeMaker logo — usage manual (canonical)

> Companion to `LOGO.md` (the frozen geometry/color spec). This manual covers
> the production assets in `assets/`, which variant goes on which background,
> sizes, clearspace and the don'ts. Owner: ux-designer. Issue #31.

> **Icon centering rule (CEO decision, 2026-07-09, r5-visual-decisions
> sheet):** app-icon rasters center the **black dot** (the piquete, the
> mark's focal point) **horizontally**; vertical stays bbox-centered. The
> dot-centered masters live in `assets/variants-dot-centered/` and are the
> wired ones. Rationale: with the bbox centered, the dot reads 4.4% left of
> canvas center — the eye anchors on the dot (#50).

## 1 · Asset index (`docs/design/logo/assets/`)

| File | What | Use it for |
|---|---|---|
| `symbol.svg` | Isotype, full color | Any use of the mark alone, on light **and** dark backgrounds |
| `symbol-mono.svg` | Isotype, 1 ink `#1C1826` (hollow eye) | Embroidery, screen printing, merch, fax-grade contexts |
| `symbol-negative.svg` | Isotype, all white (hollow eye) | On brand purple `#6C3FD1` or any dark/saturated flood |
| `wordmark.svg` | "PiketeMaker" text, brand colors | Any background, light or dark (see §2) |
| `wordmark-ondark.svg` | Identical to `wordmark.svg` (CEO r8-A: frozen colors on dark) | Kept only for naming stability |
| `wordmark-mono.svg` / `wordmark-negative.svg` | 1-ink / all-white text | Same rules as the symbol equivalents |
| `lockup-horizontal.svg` (+ `-ondark`, `-mono`, `-negative`) | Symbol + wordmark, optically spaced | Headers, store listing, pitch decks |
| `watermark-story.svg` | Lockup in `textDisabled` + purple piquete | Retired from shared stories (§6); low-emphasis in-app use only |
| `app-icon.svg` + `png/app-icon-{48,72,96,144,192,512}.png` | Symbol at 62% on a white square tile | Launcher / store icon (§5) |
| `android/ic_launcher_foreground.{svg,png}` + `ic_launcher_background.{svg,png}` | Adaptive icon layers, 432 px (108 dp @4x) | Android adaptive icon |
| `png/favicon-32.png`, `png/favicon-16.png` | Symbol alone, transparent | Web/landing favicon |
| `illus-tip-bien.svg`, `illus-tip-mal.svg` | Tutorial card miniatures (F-2, audit #9) | ONB-2 BIEN/MAL cards (app integration = mobile task) |
| `fonts/` | Archivo Black + Inter variable, with OFL licenses | Source faces for the wordmark (§4) |

All SVGs are self-contained (text converted to paths — no font needed to
render them) and use only frozen logo colors or token values.

**Anti-hairline overlap (all masters, CEO 2026-07-09):** every symbol
instance draws the bowl first, shifted −0.4 u, tucked **under** the purple
stem (dot shifted with it to stay centered in the eye). This kills the white
antialiasing hairline at the stem/bowl joint reported by the CEO, without
changing the visible geometry — no mint ever shows over purple. Verified on
the rasters at 512 px and 48 px (pixel scan: 0 near-white pixels in the
joint band). Spec in `LOGO.md` (geometry note).

## 2 · Which variant on which background

| Background | Symbol | Wordmark / lockup |
|---|---|---|
| White / light neutrals (`bg`, `surfaceSubtle`) | `symbol.svg` | `lockup-horizontal.svg` |
| Dark (photos, dark walls, story over image) | `symbol.svg` (unchanged) | `lockup-horizontal.svg` (frozen colors — CEO r8-A) |
| Brand purple `#6C3FD1` flood | `symbol-negative.svg` | `lockup-horizontal-negative.svg` |
| Busy photography where color fights | `symbol-negative.svg` on a scrim, or mono | negative |
| 1-color reproduction (merch) | `symbol-mono.svg` | `lockup-horizontal-mono.svg` |

**Dark-background rule (DECIDED — CEO 2026-07-09, r8 option A):** on dark,
the wordmark keeps its **frozen colors**: `Pikete` stays `#6C3FD1`. The
designer's `#A78BFA` proposal (option B) was reviewed and not chosen. For the
record, measured on the app's dark bench `#141119`: `#6C3FD1` = 2.9:1 vs
`#A78BFA` = 6.9:1 — the CEO saw both and preferred the frozen purple (logos
are WCAG-exempt; LOGO.md rule 4). Practical consequence: prefer the lockup on
**light or mid grounds/scrims** when legibility matters at small sizes; on
truly dark floods, `-negative` remains available. The `-ondark` files are
kept, now identical to the standard ones, so no integration breaks. The
**symbol keeps its frozen colors everywhere**, as always.

## 3 · Clearspace and minimum sizes

- **Clearspace:** keep a margin equal to the piquete's diameter (the dot,
  ~21% of symbol height) free around symbol, wordmark and lockup on all sides.
- **Minimum sizes:** symbol 16 px (favicon floor); wordmark 15 px cap-height
  ≈ 20 px total (the watermark size verified in r7); lockup 24 px tall.
  Below these, use the symbol alone.
- One turquoise at all sizes (LOGO.md rule 1). No mini variants.

## 4 · Typography of the wordmark

- **Display face: Inter Display ExtraBold** (`opsz 32 / wght 800` instance of
  `fonts/Inter-Variable.ttf`, OFL 1.1, `fonts/OFL-Inter.txt`). **FINAL — CEO
  decision, 2026-07-09 (r8, option B):** "se ve mejor". The designer's
  recommendation was Archivo Black (kept in `fonts/` with its OFL as the
  documented runner-up); the CEO reviewed both and chose Inter. Side benefit:
  the lockup is ~19% shorter (438.5 vs 523 u), which helps app bars and the
  story watermark. The brand-vs-UI-text distinction now leans on color and
  weight (the UI never sets system-800 in brand colors).
- **Optical adjustment baked into the assets:** tracking −0.02 em, real
  kerning from the font (HarfBuzz-shaped), lockup gap 14/96 units between
  bowl and text, wordmark cap height = 61% of symbol content height, text
  optically centered on the symbol.
- The wordmark ships as **paths**; the app never needs to bundle the font.
  Only bundle Inter if display-size brand headlines appear later
  (store graphics, landing) — UI text stays on the system stack (tokens).

## 5 · App icon decisions

- **Square PNGs, no baked corner radius.** Launchers and stores apply their
  own masks (Android adaptive shapes, iOS superellipse); baking ~22.5%
  corners causes double-masking artifacts. The rounded look in mockups is
  applied by the surface, never by the asset.
- **Android adaptive:** `ic_launcher_foreground` keeps the symbol inside the
  72/108 dp safe zone; background is flat white (the white tile IS the brand
  surface — D7). Content survives circle, squircle and rounded-square masks.
- 512 px is the Play Store listing size; 48–192 cover legacy `mipmap-*`.
- **Centering rule (bugfix 2026-07-09, CEO report "la P no sale centrada"):**
  every icon raster centers the symbol's **content bbox** (x 26–69.6, y 12–84
  in symbol units — center 47.8, 48), not the 96×96 viewBox. Verified by pixel
  scan: left/right and top/bottom glyph margins equal within **±1 px** at every
  size, with and without a simulated round mask. Root cause of the bug: the
  shipped `ic_launcher_foreground.png` did not match its SVG master — the
  symbol was rasterized **+33.5 px right of center** (432 px canvas; margins
  184/117 instead of 150/150), which read clearly off-center under circular
  launcher masks and even poked outside the 66 dp safe circle. All rasters were
  regenerated from the frozen geometry (anti-hairline −0.4 overlap and colors
  intact; joint-band scan: 0 near-white px). No optical-centering shift is
  applied: with the bbox centered, the mark's measured center of ink mass sits
  only ~2% of glyph width left of center (stem mass balances the bowl), below
  the threshold where an optical correction helps.

## 6 · Story signature (shared 9:16 image)

**Decided 2026-09-29 (N1/N4, CEO):** the shared story, outfit and sneaker,
with or without the user's photo, is signed with the **full-colour
`lockup-horizontal.svg`**, not a grey watermark. Centred horizontally,
**below** all content, never over the user's photo or the colour band, on the
plain white ground. Size: **28 logical px tall in the 432 × 768 story frame
(70 px in the 1080 × 1920 export)** on the photo story; the card-only story
keeps 32 / 80 px. Its bottom edge stays **inside the story-safe band** (≥ 80
logical / 200 px from the bottom edge, where Instagram/TikTok overlay their
reply bar). Clearspace per §3. Casing "PiketeMaker" (rule 6). Logo turquoise
here is not a UI mint dose (§9).

`watermark-story.svg` (lockup in `textDisabled #8F87A3` + purple piquete) is
**retired from shared stories**: after platform recompression it is not
legible. It remains available for low-emphasis in-app uses only. The on-screen
result cards keep their small text watermark (`BrandWatermark`), which never
appears in an exported image.

## 7 · Splash spec

- Pure white `#FFFFFF` full-bleed (no gradient, no pattern — D7).
- `symbol.svg` centered, **112 dp** tall (96–128 dp acceptable range),
  optically centered: geometric center minus 4% of screen height.
- No wordmark, no spinner on the static splash; if the engine shows it >800 ms,
  the app may fade in the wordmark at `caption` size below the symbol.
- Works as `flutter_native_splash` config: white background + `app-icon`-less
  plain symbol PNG (rasterize `symbol.svg` at 4x when the mobile task needs it).

## 8 · Don'ts

- Don't add a border or outline (tried in r5, discarded).
- Don't set the wordmark in all-caps — **always "PiketeMaker"** (rule 6).
- Don't use "Pikete" alone.
- Don't swap, tint or gradient the three logo colors; no drop shadows.
- Don't recolor the symbol with the user's extracted palette.
- Don't recolor the wordmark on dark backgrounds — frozen colors everywhere
  (CEO r8-A); if it fights the background, use `-negative` or a scrim.
- Don't bake corner radius into icon exports (§5).
- Don't use logo turquoise `#17B598` as a UI color, or UI mint as a logo color (§9).

## 9 · Brand turquoise `#17B598` vs `action.bright #43E5C2` — analysis & proposal

> **RATIFIED by the CEO on 2026-07-09** ("perfecto"). `brand.logo.turquoise
> = #17B598` is now in `docs/design/tokens.json`. The never-in-the-same-
> component rule below stands as written.

**Facts.** Same family: hue 169° vs 166°, so they never clash as "two brands";
but 1.63:1 apart in luminance, so side by side they read as a mistake (a
faded/wrong version of each other). `#17B598` on white is 2.6:1 — not a text
color, so it can never replace `mint.ink #0B7C6C` in the action role.

**Where they could actually meet.** The logo appears on splash, onboarding
ONB-1, and the story watermark (which is gray + purple, no turquoise). The
progress bar (`action.bright`) lives in the analyzing screen — no logo there.
Real collision surface: **ONB-1 only**, if a bright-mint graphic detail is
ever added under the lockup.

**Proposal (as ratified):**
1. `brand.logo.turquoise = #17B598` added to tokens.json (2026-07-09) so
   mobile-dev never eyedrops the SVGs. It lives outside the mint action ramp
   on purpose. (`logo.purple`/`logo.ink` need no own token: they equal
   `brand.purple.ink` and `neutral.textPrimary` — the tokens.json entry says so.)
2. Keep the mint ramp exactly as is — `#43E5C2` stays the UI's non-textual
   mint. Re-deriving the ramp from `#17B598` would break the validated AA
   pairs for zero user benefit.
3. One written rule (this manual + DESIGN_SYSTEM): **logo turquoise and
   `action.bright` never appear in the same component.** On screens with the
   lockup (splash, ONB-1), non-textual mint accents use nothing or `mint.tint`.

## 10 · Provenance / licensing

Fonts fetched 2026-07-09 from google/fonts (GitHub, `ofl/` tree):
Archivo Black © The Archivo Black Project Authors — SIL OFL 1.1;
Inter © The Inter Project Authors — SIL OFL 1.1 (variable; the wordmark
comparison used the `opsz 32 / wght 800` = Display ExtraBold instance).
OFL permits app/merch embedding and modification; it only forbids selling the
fonts alone and reusing the reserved font names for derivatives. License
files must travel with the font files — they do, in `assets/fonts/`.
