# r10 UX polish — 3 tweaks for CEO yes/no (issue #94)

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-07-18 |
| **Phase / feature** | Post-r10 polish (Home + result screens) |
| **Source** | CEO flags after testing r10 on the Galaxy M33 (Catalan device) |
| **Decision needed** | A yes/no on each of the 3 (item 3 has a recommendation to confirm) |
| **Mockup (review surface)** | `docs/design/mockups/2026-07-18_1645_F2_r10-ux-polish.html` |
| **Constraints obeyed** | D7 (white + mint + purple, radical simplicity), D8 (mint = action / purple = accent, ≤2 doses), Principle 1 (the user's color is the protagonist) |
| **Status** | PROPOSAL — no code written. Token/widget-level changes only, for mobile-dev once approved. |

This is a light polish pass: three small, surgical changes. No new components,
no new tokens, no copy changes. Nothing touches the analysis engine or a gate.

---

## Item 1 — Home logo slightly bigger

**Current state.** The top-left brand lockup renders at `_lockupHeight = 18`
(`app/lib/features/home/home_screen.dart:72`). That drives the whole lockup:
the `LogoMark` symbol is **18 px** tall and the "PiketeMaker" wordmark is
`18 × 0.62 ≈ 11 px`. It sits in a slim top bar next to the `help_outline`
tutorial icon, which is **28 px** — so today the brand mark is actually
*smaller* than the help glyph across from it. That inversion is likely what
reads as "too timid" to the CEO.

**Proposed change.** Bump `_lockupHeight` from **18 → 22 px**
(symbol 22, wordmark ≈ 14). One constant.

- Alternative if the CEO wants it more assertive: **24 px** (wordmark ≈ 15).
- I recommend **22**: it lifts the mark to roughly match the 28 px help icon's
  visual weight without the lockup starting to compete with the two mode zones
  (Principle 1 — brand identity stays discreet, the zones are the screen).

**Why this is safe.** Even at 24 the lockup is still shorter than the 28 px
help icon, so the top-bar row height (driven by the taller of the two) does
**not** change — the logo just grows into space that already exists. No layout
shift, no reflow of the zones below.

**Note for mobile-dev (not a CEO concern):** one test pins the current value —
`app/test/features/r5_visual_decisions_test.dart:73` asserts
`LogoLockup.height == 18`. It updates to the new value in the same change.

---

## Item 2 — "Les meves bambes" block: more air above the divider

**Current state.** The split Home has two full-height zones mirrored around a
center hairline (#81 pulled each block *toward* the divider so they read as a
matched pair). The gap between each content block and the divider is
`_ModeZone._dividerGap = Space.xl` = **24 px**
(`app/lib/features/home/home_screen.dart:252`). The top zone (sneaker —
"Les meves bambes" in Catalan) bottom-aligns to that 24 px gap; the block is
glyph + label + caption + the "Comença ›" pill, and the pill's bottom edge ends
24 px above the line. On the M33 that reads as the sneaker block crowding the
divider.

**Proposed change.** Increase `_dividerGap` from **`Space.xl` (24) →
`Space.xxl` (32 px)**. One constant.

- This is symmetric by design: it pushes the **top** block up (away from the
  divider — exactly the CEO's "move them up a bit") *and* the bottom block down
  by the same amount, so the #81 mirror is preserved. It does not single out one
  zone and re-introduce the old "Mi pikete hugs the bottom" imbalance.
- More dramatic option if 32 still feels tight on device: `Space.xxxl` (48).
  I'd land on **32** first — it's +8 px, clearly more air, and low-risk; we can
  go to 48 if the CEO wants it looser after seeing it.

**Why this respects the system.** "When in doubt, more air" is the stated
layout rule (tokens.json `space.layout`, DESIGN_SYSTEM §1). This is purely
whitespace — no color, no new element.

---

## Item 3 — the "dead" `›` chevron at the end of each suggested palette

### What it actually is (investigated in code)

The `›` the CEO saw is `Icon(Icons.chevron_right, color: c.action)` (mint),
rendered at the **end of every harmony/combi row**:

- Outfit result — `_HarmonyRow`, `app/lib/features/result/result_screen.dart:753`
- Sneaker result — `_ComboRow`,
  `app/lib/features/sneaker/sneaker_result_screen.dart:808`

It is **not** the #82 "Ver looks així" affordance. That feature is the big
primary CTA button at the bottom of the screen ("Ver looks así" / "Enséñame
otros piketes"), which deep-links the browser. The per-row chevron is a
separate, older visual cue.

**What tapping it does: nothing distinct.** Each row is one big `InkWell` whose
`onTap` *selects* that harmony (radio/toggle behaviour, #82) so the bottom CTA
searches for it. The chevron has no gesture of its own — tapping the chevron is
just tapping the row, i.e. it selects. It never navigates anywhere. So the CEO
is right: the `›` is a **navigation affordance that doesn't navigate.** It's a
leftover from the pre-#82 row design (when each row was imagined to drill into
its own detail); once #82 turned the rows into a radio group + one shared CTA,
the chevron lost its meaning but stayed on screen.

There's also a small D8 cost: it's one **mint** dose per row (3–4 rows), on a
screen where mint should be sparing and the *palette* should be the loudest
thing (Principle 1).

### Recommendation: **remove it** (both screens)

Delete the trailing `Icon(Icons.chevron_right …)` (and the `SizedBox(width:
Space.md)` before it) from `_HarmonyRow` and `_ComboRow`. Two ~2-line deletions.

Rationale:
- The row's real job is **selection**, and selection is already signalled
  clearly — the scheme name chip fills with the action color and flips to white
  ink when selected (`SchemeNameChip`). The chevron adds a *wrong* signal on top
  of a *correct* one.
- Removing it declutters the row, drops a stray mint dose (D8), and lets the
  swatch strip — the actual color — sit at the visual end of the row (Principle
  1). This is the D7 "if an element doesn't help decide or share, it goes" rule
  applied literally.

**Honest alternative (only if the CEO wants a stronger selected-state):** swap
the chevron for a selection indicator that appears **only on the selected row**
(a mint check). That keeps a trailing glyph but makes its meaning truthful
(state, not navigation). It's a bigger change than a deletion and adds an
element back, so I'd only do it if, on device, the filled-chip selected state
feels too subtle. My first choice is the plain removal.

**What I did NOT propose:** wiring the chevron to open the deep-link per row.
That would duplicate the primary CTA and create two competing "go" actions on
the same screen — worse for D7/D8, not better.

---

## Summary — for a quick pass

| # | Item | Current | Proposed | Type |
|---|---|---|---|---|
| 1 | Home logo | `_lockupHeight` = 18 (symbol 18, mark smaller than the 28 px help icon) | **22** (alt 24) | 1 constant |
| 2 | Sneaker block air | `_dividerGap` = `Space.xl` (24) | **`Space.xxl`** (32) (alt 48) | 1 constant |
| 3 | Dead `›` chevron | `chevron_right` (mint) on every harmony/combi row; a navigation cue that only *selects* | **Remove** both screens (alt: turn into a selected-only check) | 2 small deletions |

All three are token/widget-level, reversible, and touch no gate, engine, or
copy. Awaiting a yes/no on each (and, for #3, confirm remove vs. the
selected-check alternative).
