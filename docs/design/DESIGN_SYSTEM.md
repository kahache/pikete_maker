# PiketeMaker — Design System v1 (short version)

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-07-06 |
| **Framing decisions** | D7 — white + mint + purple, radical simplicity · D8 — mint = action, purple = accent · D9 — purple-tinted neutrals |
| **Source of truth for values** | `docs/design/tokens.json` |
| **Canonical mockup** | `docs/design/mockups/result.html` (discarded explorations in `mockups/archive/`) |
| **Status** | v1.2 — visual direction closed (D7+D8+D9) |

---

## 1. Brand personality

**Simple · Discerning · Street.**

The language is functional minimalism: **little text, lots of air, big and
obvious buttons, crystal-clear hierarchy, zero gratuitous decoration.** We copy
the discipline, not the identity: none of their green, their logo or their icons.

- **Simple:** every screen answers one question and offers one primary
  action. If an element doesn't help decide or share, it goes.
- **Discerning:** we show real data (hex, weights, schemes) in mono, as data.
  The credibility is that there's color theory behind it — without jargon.
- **Street:** the tone speaks Dani's language (fit, story, look) naturally.
  It shows in the copy, not in the decoration.

**What we are NOT:** a carnival (zero brand gradients, zero confetti — if the
UI competes in color with the user's palette, we've failed), a beauty app
(we have opinions about clothes, never about bodies), nor a paper ("triadic"
yes; "120° hue rotation in HSV" no).

## 2. Color usage rules

### The strict hierarchy: action vs accent

PiketeMaker has **ONE action color**, one for the whole app. The second brand
color is **accent** and appears in minimal doses. They are never
interchangeable within a single version of the app.

| Role | What it does | Where it appears | How much |
|---|---|---|---|
| **Action** (`role.action`) | Everything important that's tappable | Primary CTA, links, active states, progress bar | The only functional color; even so, in moderation |
| **Accent** (`role.accent`) | Brand signature, never action | `BASE` badge, one detail of the "analyzing" state, story watermark | Max. 2 appearances per screen |

**Final (D8): mint = action, purple = accent.** Mint (`#0B7C6C`,
5.10:1 AA) lives in everything tappable: CTAs, links, back, chevrons, progress.
Purple (`#6C3FD1`, 6.42:1) is the premium signature in minimal doses. Brand
read: fresh, sporty, "go".

### The tinted-neutrals rule (D9)

The app uses no pure grays: **all neutrals are tinted with purple**
(hue ~258, saturation 8–14%) — secondary/tertiary text, borders, dividers,
soft backgrounds, shadows and scrim. Effect: the whole app "feels" purple
without adding a single functional purple element. Two non-negotiable
conditions:

- **Contrast:** every tinted neutral must **match or exceed** the contrast
  of its pure-gray equivalent (validated by script; values in `tokens.json`,
  `neutral` ramp). E.g.: secondary `#544E68` = 7.88:1, tertiary `#6B6383`
  = 5.62:1.
- **Low chroma:** if a neutral starts reading as "color", the saturation has
  gone too far. The functional purple remains the accent's alone.

General rules:

1. **The user's color is the protagonist.** The extracted palette and its
   harmonies must be the most colorful thing on screen. The UI lives in white
   and neutrals; the 2 brand colors are seasoning, not the dish.
2. **Only the `ink` variant carries text.** `bright` is for non-text elements
   (progress, details) and `tint` for soft backgrounds with `ink` text on
   top. All three pairs are AA-validated in `tokens.json`.
3. **Extracted colors never become UI.** Tinting buttons or backgrounds with
   the user's palette is forbidden: only samples (bands, swatches, strips).
4. **The base color rules (D5).** The harmony base is the most chromatic
   color, never a neutral. In the UI it always carries the `BASE` badge (in
   accent color) and superior visual hierarchy.
5. **Text on a swatch:** black or white depending on the swatch's own
   luminance, never theme grays or brand colors.
6. **Light theme first.** Dark mode postponed; the app consumes
   `themes.{light|dark}.*` from day 1 so it arrives without a refactor.

## 3. Typographic hierarchy

System fonts (zero cost, zero loading — consistent with on-device, D2).

| Role | Token | Use |
|---|---|---|
| Display 32/38 · 800 | `display` | Single screen headline ("Tu paleta") |
| Title 20/26 · 700 | `title` | Sections ("Combina con") |
| Heading 16/22 · 600 | `heading` | Name of each harmony |
| Body 15/22 · 400 | `body` | Supporting phrases — max. 2 consecutive lines |
| Caption 13/18 · 400 | `caption` | Metadata, helper text |
| Label 11/14 · 700 · UPPERCASE | `label` | `BASE`, scheme chips |
| Data 13/18 · mono | `dataMono` | Hex and percentages, always in mono |
| CTA 16/22 · 700 | `cta` | Buttons (56 px tall: big and obvious) |

Minimalism rule: **a single `display` piece per screen** and, when in doubt,
remove text. If everything shouts, nothing stands out and the palette stops
being the protagonist.

## 4. Copy tone

Direct, second person, short sentences. A friend with good taste, not an
assistant or a professor. Words from Dani's world when they come naturally
(fit, story, look); technical jargon never without translation. No double
exclamation marks, no emojis in system UI.

**3 real microcopy examples** (app copy is in Spanish, the product's language):

1. **"Analyzing" state (where the rewarded ad lives, F8):**
   - ✅ "Leyendo los colores de tu fit…"
   - ❌ "Procesando imagen, por favor espere" (cold, office-scanner vibe)

2. **Result — presenting the base color (D5):**
   - ✅ "Tu color dominante. Todo conjunta alrededor de él."
   - ❌ "Color con mayor producto saturación×peso" (jargon)

3. **Capture error:**
   - ✅ "No pillamos bien tu fit. Prueba con más luz o aléjate un paso."
   - ❌ "Error 422: segmentación fallida" (blames the machine, doesn't help)

Bonus — result CTAs: **"Ver looks así"** (F5-lite, the user's verb) and
**"Súbela a tu story"** (F6) beat "Buscar imágenes" or "Exportar".

## 5. The result as a shareable object (F6)

- The palette+base card on the result screen **is** the crop exported as a
  9:16 story: it's designed to survive without the surrounding UI.
- The shared 9:16 story (F6/N1, outfit and sneaker) carries **the user's whole
  uploaded photo with the hero combo band under it** (switch "Incluir mi foto",
  default ON; OFF shares the result card) and is signed with the **full-colour
  lockup** below the content, inside the story-safe band (logo/USAGE.md §6).
  The on-screen cards keep a discreet `textDisabled` text watermark that never
  reaches the export.
- No system chrome (buttons, tabs) inside the shareable area.

## 6. The wait is monetization (F8)

The rewarded ad slot is part of the "analyzing" state layout from v1:
`surfaceSubtle` surface, `lg` radius, and **the progress always visible and
advancing above it**. The user never feels a toll: they feel their palette is
on its way and the ad rides along.
