# Split-Home layout — A/B for the CEO to pick (F2S · D24)

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-07-10 |
| **Phase / feature** | Phase 2S · F11 (sneaker/product mode), D24 |
| **Decision needed** | CEO picks Variant **A** (50/50 split) or **B** (two cards) on device |
| **Mockup (review surface)** | `docs/design/mockups/2026-07-10_2130_F2S_split-home.html` (both variants side by side) |
| **Scope** | ONLY the split-Home layout that offers the two entry points. NOT the sneaker inner screens (capture/result) — separate follow-up UX task once this is picked. |
| **Constraints obeyed** | D7 (white + mint + purple, radical simplicity), D8 (mint = action, purple = accent, max 2 doses/screen), D9 (tinted neutrals), D14 (logo frozen), Principle 2 (brand must not compete with content) |

---

## 1. The problem this layout solves

D24 promoted sneaker/product mode to the roadmap. The Home, which today asks
**one** question ("Analiza tu fit" → one CTA), must now offer **two** first-class
entry points:

- **Zapatillas** — the new sneaker/product flow (start from a shoe, get the
  clothing palette that matches).
- **Tu outfit** — the existing analyze-fit flow, untouched downstream.

The user picks one, then continues into that flow. Everything the current Home
carries must survive the redesign:

- the discreet **brand lockup** (top-left, LOGO color, not UI color, D14);
- the **tutorial re-entry** help icon (top-right, `help_outline` 28px, out of
  the thumb path — the app still has no Settings screen, so the F13 re-entry
  lives here per `onboarding-tutorial.md` §1.3);
- the first-launch onboarding gate (unchanged; pushes the tutorial on top on
  first run).

The genuine design tension is **D8's "ONE action color, one per app"** vs. a
Home that now has **two co-equal primary actions**. Each variant resolves it
differently; that is most of what the CEO is choosing between.

---

## 2. Variant A — "50/50 vertical" (bold, equal-weight)

**Layout.** A slim transparent top bar (lockup left, help icon right) sits over
a full-bleed vertical split: the screen body divides into two equal, full-height
tappable zones — **Zapatillas on top, Tu outfit below** — separated by a hairline
divider. Each zone is one big target: a large line glyph (sneaker / t-shirt), the
mode label in `display`, a one-line caption, and a mint chevron affordance. No
hero logo, no central headline — the two zones ARE the screen.

**Colour treatment.** To make the two zones read as equal-weight without a color
carnival, each zone carries a **very pale tint wash**: `mint.tint` (#DFF7F1) on
Zapatillas, `purple.tint` (#EFEAFB) on Tu outfit. Glyphs and labels are `ink`
(mint.ink / purple.ink respectively). This uses the `tint` variant exactly as the
tokens intend ("soft backgrounds, ink text on top") and gives the two modes
symmetric, obviously-different halves.

**Why it's good**
- **Maximum equal weight.** Two halves of the screen = the two modes are
  co-equal products. This best serves D24's strategic intent and G2's goal of
  "reading which wedge resonates" — neither mode is visually subordinate.
- **Bold, thumb-obvious, one-handed.** Two enormous targets; you can't miss
  either. Very "big buttons, zero ambiguity".
- **Distinctly its own thing** vs. the calm current Home — a real A/B.

**Tradeoffs / what it spends**
- **Sheds the current hero + air.** The 120px LogoMark hero and the generous
  white breathing room of today's Home go away. The identity now lives only in
  the small top lockup. This is the biggest departure from D7's "lots of air".
- **Pushes D8.** Two half-screen tint washes = a large mint dose AND a large
  purple dose on one screen. Purple is meant to be "accent, minimal doses"; a
  half-screen purple wash is not minimal. It stays legal (tint, non-textual,
  no user content on this screen to compete with) but it is the loosest reading
  of D8 of the two variants. **Fallback if the CEO finds it too much: run both
  zones all-white with only the hairline divider + a mint chevron each** (shown
  as note in the mockup) — still 50/50 and bold, but token-strict.
- **Two mint-adjacent affordances.** Both chevrons are mint; the "one action"
  rule is stretched by design (both zones are actions).

---

## 3. Variant B — "dos tarjetas" (calm, keeps the hero)

**Layout.** Today's Home structure is preserved: top row (lockup left, help
right), then a compact hero (LogoMark shrunk to ~64px + a single short headline
"¿Qué combinamos?"), lots of air, then **two large stacked cards** in the hero
area — **Zapatillas** then **Tu outfit** — each card ~104px tall: leading line
glyph, label in `heading`, caption in `caption`, trailing mint chevron. Cards are
white `surface` with `border` + `shadow-sm` (the established card language from
`result.html`). Bottom thumb zone stays clear.

**Colour treatment.** White canvas, neutral cards. Brand color appears only as
the **two mint chevrons** (the tappable affordance) — well within D8's 2-dose
budget. Purple stays reserved for its usual accent role (none needed here). The
logo mark keeps its LOGO purple/turquoise, as today.

**Why it's good**
- **Keeps D7 calm and the brand hero.** Minimal change to the established Home;
  the logo, the air, and the card language all carry over. Lowest identity risk.
- **Token-strict on D8/D9.** White canvas, one action color used sparingly
  (two mint chevrons), tinted-neutral cards. Nothing pushes any rule.
- **Cheapest to build & lowest regression risk** for mobile-dev (it's the
  current Home with the CTA swapped for two cards + routing).

**Tradeoffs**
- **Weights the two modes slightly less symmetrically.** Stacked cards imply a
  reading order (top card reads as "first"); it's equal-ish, not the dead-equal
  of 50/50. Whichever card is on top gets a subtle primacy — we'd put
  **Zapatillas on top** to signal the newly-promoted mode.
- **Less bold.** It's evolutionary, not a statement. If the CEO wants the beta
  to shout "two products", B undersells that.
- The shrunk hero logo (~64px) is a visible step down from the #58a-ratified
  120px hero — a small identity concession (documented, not re-litigated).

---

## 4. Copy (ES, D17)

Default labels from D24 are clear and I recommend keeping them as the labels;
Dani's slang lives in the captions, not the labels (labels stay legible/obvious):

| Mode | Label (recommended) | Caption (recommended) | Slang alt (label) |
|---|---|---|---|
| Sneaker | **Zapatillas** | "Monta el fit desde tus zapas" | "Mis zapas" |
| Outfit | **Tu outfit** | "Saca la paleta de tu fit" | "Mi fit" |

Rationale: keep the two labels **parallel and neutral** so the choice reads at a
glance; the personality ("zapas", "fit") rides in the caption. Both mockup
variants use these. Open to the CEO swapping to the slang labels if he wants more
Dani-voice up front.

---

## 5. Recommendation

**Recommend Variant B (two cards)** as the default, for three reasons:
1. It keeps D7 calm, the brand hero and the card language — lowest identity and
   engineering risk on a beta that also has to validate the algorithm, not the UI.
2. It is token-strict on D8/D9 (no oversized purple dose).
3. Stacking with **Zapatillas on top** already signals the promoted mode without
   abandoning the established Home.

**But flag the strategic counter-argument for A:** D24's whole point is that
sneaker mode is a **co-equal wedge** and the beta should read "which wedge
resonates" (G2). Variant A's dead-equal 50/50 communicates "two products" far
more strongly than stacked cards do. If the CEO's intent is to present the two
modes as genuine equals (not "outfit, plus also sneakers"), **A is the better
strategic fit** — at the cost of the hero, the air, and a looser D8 reading.

So: **B for identity/calm/safety; A if the goal is to make co-equality the
message.** This is a product-weight call, which is why it goes to the CEO.

---

## 6. Open questions for the CEO

1. **Pick A or B** (on device, in the mockup).
2. **If A:** tint washes (mint.tint / purple.tint zones) or the token-strict
   all-white fallback? The washes are what make A bold; the fallback is safer on
   D8 but closer to B in feel.
3. **Order / primacy:** confirm **Zapatillas first** (top zone in A / top card in
   B) to foreground the newly-promoted mode — or keep **Tu outfit** first since
   it's the proven flow?
4. **Labels:** keep neutral **"Zapatillas" / "Tu outfit"**, or go Dani-slang
   **"Mis zapas" / "Mi fit"** on the labels themselves?
5. **B only:** OK to shrink the hero LogoMark from the ratified 120px to ~64px to
   make room for two cards + air? (Or drop the hero mark entirely and lean on the
   top lockup, like A does.)

Downstream unblocked once picked: the sneaker capture/analyzing/result screens
(separate UX task) and mobile-dev's Home routing (outfit = existing, sneaker =
new).
