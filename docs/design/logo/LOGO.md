# PiketeMaker logo — canonical specification (FROZEN)

> Approved by the CEO on 2026-07-07 ("LO TENEMOS"). This file is the source
> of truth for the logo. The full evolution (rounds r1-r7) lives in the dated
> sheets in this folder; this is the final result. Changes here = a new
> CEO decision.

## Symbol — "P-Paleta"

The P built from the app's raw material: stem + annular swatch bowl
with the dot (the "piquete") in the eye.

```svg
<svg viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(6,0)">
    <!-- bowl: turquoise annular swatch, drawn FIRST (beneath the stem),
         shifted -0.4 so it tucks 0.4u under the stem (anti-hairline) -->
    <path d="M37.6,12 A26,26 0 0 1 37.6,64 L37.6,48 A10,10 0 0 0 37.6,28 Z" fill="#17B598"/>
    <!-- stem: purple, flat top terminal (closed P), rounded bottom; on top -->
    <path d="M20,12 L38,12 L38,75 A9,9 0 0 1 29,84 A9,9 0 0 1 20,75 Z" fill="#6C3FD1"/>
    <!-- piquete: black dot, centered on the bowl's eye (follows the -0.4 shift) -->
    <circle cx="37.6" cy="38" r="10" fill="#1C1826"/>
  </g>
</svg>
```

**Geometry note — anti-hairline overlap (approved, CEO 2026-07-09):** the
r4 flush joint (bowl starting exactly at the stem edge, x=38) leaves a white
antialiasing hairline in rasterizers. Fix: the bowl (and its dot, to keep the
piquete centered in the eye) is shifted **−0.4 u** and drawn **beneath** the
stem. The overlap is purely technical: the purple stem stays visually intact
(it covers the strip — no mint ever shows over purple, verified at 512 px and
48 px). Visible geometry is unchanged; this is not a redesign.

## Colors (these three, not one more)

| Element | Color | Name |
|---|---|---|
| Stem / "Pikete" | `#6C3FD1` | purple (accent.ink from tokens) |
| Bowl / "Maker" | `#17B598` | **brand turquoise** (new — NOT the UI's action.bright) |
| Dot / details | `#1C1826` | ink (text.primary) |

## Wordmark and lockup

- **Full "PiketeMaker"** (never "Pikete" alone — locks in the canonical
  K spelling; mitigation from the growth report).
- `Pikete` in purple `#6C3FD1` + `Maker` in turquoise `#17B598`. **No border.**
- **Typography (FINAL, CEO 2026-07-09, r8):** **Inter Display ExtraBold**
  (`opsz 32 / wght 800`, OFL), tracking −0.02 em, shipped as paths in the
  assets. Archivo Black stays in `assets/fonts/` as documented runner-up.
- **On dark backgrounds (CEO 2026-07-09, r8 option A):** the wordmark keeps
  the frozen colors — `Pikete` stays `#6C3FD1`. No light-purple variant.

## Usage rules (decided by the CEO, r5-r7)

1. **A single turquoise at all sizes.** There is no mini variant or size
   rule: `#17B598` works from 15px to 512px (verified in r7).
2. **No border on the text.** Tried (r5) and discarded: the clean version wins.
3. **Monochrome (1 ink):** everything `#1C1826` with the dot in white (the
   P's eye stays hollow). For embroidery/screen printing/merch.
4. WCAG: logos are exempt from the contrast requirement; the UI's AA tokens
   are not affected by the logo.
5. App icon: symbol on a white tile, launcher corners (~22.5%).
6. **Wordmark casing (CEO, 2026-07-09): always "PiketeMaker", never
   all-caps** — in app bars, store listings, marketing, everywhere. (Reverses
   the uppercase-kicker proposal from the #9 UX audit.)

## Pending (assets round, issue #31 — does not block using the logo)

- Definitive licensed display face + optical adjustment of the lockup.
- Dark-background variant: evaluate `Pikete` in light purple `#A78BFA`
  (the `#6C3FD1` loses strength on black — detected in r5).
- Splash, story watermark, favicon, negative on purple.
- Exports: master SVG + PNG 48/72/96/144/192/512.
- Coexistence review of the brand turquoise `#17B598` with the
  `action.bright #43E5C2` from tokens.json (UI color).

## Production assets (issue #31, 2026-07-09)

The pending list above is delivered. Master SVGs, PNG exports, fonts (OFL),
watermark, favicon and the tutorial illustrations live in `assets/`; the
usage manual (variant per background, clearspace, minimum sizes, don'ts,
splash spec, tokens-coexistence proposal) is **`USAGE.md`** in this folder.
Review sheet for the open calls (display face, dark-background `Pikete`):
`2026-07-09_F1_logo-r8-assets.html`. **Both calls closed by the CEO on
2026-07-09** (Inter Display ExtraBold; frozen colors on dark) — addendum:
`2026-07-09_F1_logo-r9-cierre-decisiones.html`. Geometry and colors remain
frozen; the only geometry change ever since is the technical anti-hairline
overlap documented above (same date).

## History

r1 (4 directions) → CEO picks A · r2 (purple stem, black dot, closed P) →
r3 (attached bowl) → r4 (exact joint + wordmark in the logo colors) →
r5 (border trial: discarded) → r6 (size rule + deep mint ramp) →
r7 (#17B598 everywhere as the only one: **APPROVED**) →
r8 (production assets + two open calls) → r9 (CEO closes: Inter Display
ExtraBold, frozen colors on dark, anti-hairline overlap, logo token ratified).
