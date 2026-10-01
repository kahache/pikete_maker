# F6 shareable story — CONTENT concepts WITH PHOTO (CEO redirect) · exploration

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-07-10 |
| **Phase** | F2 · demo → validated product (F6 is a fast-follow, D12) |
| **Issue** | #60 — CONTENT of the exported 9:16 story |
| **Status** | EXPLORATION — non-blocking, roadmap-ready. Nothing ships or gates on this. Needs a CEO steer between two directions. |
| **Supersedes as the live direction** | the A/B/C options in `2026-07-10_1000_F2_story-content-F6-options.md` (kept as history; see §4) |
| **Framing decisions** | D7 (white + radical simplicity) · D8 (mint = action, purple = accent, max 2 doses; on a static story mint = **0** doses, nothing is tappable) · D9 (tinted neutrals) · D14 (logo frozen) · D5 (base = most chromatic) · Principle 2 (the user's color is the protagonist) |
| **Source of truth for values** | `docs/design/tokens.json` (v1.2) |
| **Watermark asset** | `docs/design/logo/assets/watermark-story.svg` per `logo/USAGE.md` §6 |
| **Mockups** | `docs/design/mockups/2026-07-10_2000_F2_story-content-photo-concepts.html` (both concepts, 9:16, self-contained) |

---

## 0. Why this doc exists (the CEO redirect)

The earlier brief (`_1000_`) framed F6 as a **referral engine** and recommended
Option B: a *bare palette* story with an invite line. The CEO redirected the
direction. Translating his feedback:

1. **"Lo guapo es que se vea en miniatura la foto de la persona."** The hook is
   seeing a **thumbnail of the user's own photo** on the shared story. A bare
   palette shared "just because" — he's not sure that's fun. → **The photo, not
   the palette alone, is the emotional hook.**
2. **"La recomendación que le hagamos de color"** is the strongest user value —
   the **color recommendation / matching advice** (F4 harmonies), not the raw
   extracted palette. → **If we lead with anything "smart", lead with the
   recommendation.**
3. **Sharing is explicitly NOT the app's strongest value and NOT a priority /
   NOT a blocker.** → This is unhurried. Mockups only; no build, no gate.

So this doc drops the "how hard do we push the invite" question that drove
A/B/C, and instead explores **two new content directions** that put either the
photo (Concept 1) or the recommendation (Concept 2) at the center.

---

## 1. Fixed constraints (both concepts obey)

- **9:16, full-bleed white** (`bg #FFFFFF`, D7 — no gradient, no confetti).
  Target export **1080×1920**. Mockups render at 360×640 (a 1:3 stand-in).
- **Story safe area:** top ~250 px (avatar/username) and bottom ~250 px
  (reply bar / link sticker) are covered by platform UI. All meaningful content
  and the watermark stay inside the central band. Mockups draw the two unsafe
  zones as hatched guides.
- **The user's content is the protagonist** (Principle 2). Brand colors stay in
  their allowance: **mint = 0 doses** (nothing is tappable in a static image),
  **purple ≤ 2 doses**.
- **Watermark = `watermark-story.svg`** (lockup in `textDisabled #8F87A3`, piquete
  dot in `accent #6C3FD1`, casing "PiketeMaker" — USAGE §6). Bottom-right, above
  the bottom unsafe zone.
- App copy Spanish (D17), first person on the *exported* object ("Mi fit",
  "de mi fit") — the user is talking to *their* audience, not the app talking to
  the user. This doc is English (D17).
- **No system chrome** inside the canvas. Reads standalone.

---

## 2. The two concepts

### Concept 1 — "Con foto" · the photo is the hook

**Composition (top→bottom, inside the safe band):**

- First-person title `Mi fit de hoy` + date (`display` weight, tinted meta).
- **Hero photo crop** — the user's own outfit photo, large, `radius.lg`, filling
  most of the frame. This is the deliberate center of gravity.
- **Palette filmstrip** tucked directly under the photo: the 5 extracted colors
  as a single horizontal bar, band widths **proportional to weight** (D5). It
  reads as "these are the colors the app pulled from *that* photo" — the
  extraction is the proof, sitting right below its source.
- **Base line:** a small `Base` badge (purple, tint bg) + `#E13683` + "mi color
  dominante". One compact line.
- Watermark bottom-right.

**Why this composition.** The photo and the palette are stacked and adjacent on
purpose: the eye reads *photo → its colors* as cause-and-effect, which is exactly
what the app does. The palette stays real (extracted), never mixed with synthetic
harmony colors, so there's zero "which of these am I wearing?" confusion.

**One deliberate departure from the CEO's word "miniatura".** He said
*thumbnail*, but he also said it's "lo guapo" — the coolest thing / the hook. A
literal small thumbnail buries the hook; a hero crop delivers it. I designed the
**hero-crop** reading and flag the thumbnail-size variant as an open question
(Q1) — trivial to dial the photo smaller and give the palette more room if he
prefers the literal thumbnail.

**Brand-color budget:** purple = 2 doses (Base badge + watermark piquete); mint = 0.

---

### Concept 2 — "Combina con" · the recommendation is the hero

Anchored on the CEO's insight that **the matching advice is the real value.**
Distinct from Concept 1 — not a reskin: here the palette is demoted and the
*recommendation* leads.

**Composition (top→bottom):**

- Eyebrow `PiketeMaker me dice` + hero title `Combina con` + one-line sub
  (`Mi base pega con su complementario.`).
- **Hero pairing:** two large color blocks — **`mi base` (real, from the fit)**
  `+` **`combina` (the suggested complement)** — with a neutral `+` badge between
  them and the harmony name (`Complementario`) underneath. This *is* the advice,
  rendered big: "this color, with this one."
- Hairline divider.
- **Secondary "de mi fit" footer:** a small photo **thumbnail** (this is where
  the CEO's thumbnail idea lives in Concept 2) + a thin mini-strip of the real
  extracted palette. It grounds the advice in a real outfit without competing
  with the hero.
- Watermark bottom-right.

**Why this composition.** It makes the *smart* thing visible on the viral
surface — a stranger sees "the app tells you what matches", which is a stronger
curiosity hook than a palette, and more "useful" → more save-worthy. The
labels (`mi base` vs `combina`, `de mi fit`) are load-bearing: they draw the
line between **real extracted color** and **synthetic suggested color**, which
is the failure mode Option C flagged.

**Brand-color budget:** purple = 1 dose (watermark piquete only); mint = 0. The
`+` badge and harmony label stay neutral on purpose.

**The real/synthetic tension is real** (carried over from Option C): the hero
shows a *generated* complement next to the *extracted* base. Mitigation = the
explicit `mi base` / `combina` labels + physically separating the extracted
mini-palette into its own labeled footer. If the CEO finds it still muddy, the
fallback is to show only the harmony (drop the mini-strip) or only two real
palette colors that already pair — a follow-up, not a v1 blocker.

---

## 3. Head-to-head

| | Concept 1 "Con foto" | Concept 2 "Combina con" |
|---|---|---|
| **Hero** | the user's photo | the color recommendation (F4) |
| **CEO feedback served** | #1 (photo = hook) | #2 (recommendation = value) |
| **Emotional pull** | high — it's *their* fit | medium — it's a styling tip |
| **"Smart app" signal** | low (just extraction) | high (shows matching) |
| **Real vs synthetic risk** | none (only extracted colors) | present, mitigated by labels |
| **Privacy surface** | high (photo is the hero, always embedded) | lower (photo is a small thumbnail; could be optional) |
| **Purple doses** | 2 (Base badge + watermark) | 1 (watermark) |
| **Principle-2 fit** | strong (photo + real palette own it) | good (advice leads, brand still tiny) |

**My read.** They serve two different CEO statements and aren't mutually
exclusive on the roadmap. If forced to pick one to prototype first: **Concept 1**
lands the emotional hook the CEO called out first ("lo guapo") with zero
real/synthetic risk and is the smallest step from today's `_ShareCanvas`.
Concept 2 is the stronger *differentiator* showcase and the better answer to
"what's our actual value", but carries the real/synthetic-color care cost and a
harmony-selection decision (which harmony? — see Q4). A tasteful end state could
be **Concept 1 as the default export, Concept 2 as a second "share the advice"
variant** — but that's post-decision, and sharing isn't a priority, so no need
to commit now.

---

## 4. How this relates to the earlier A/B/C brief

The `_1000_` brief's A/B/C were all **palette-first, referral-optimized** (bare
palette + how loud an invite). The CEO's redirect reprioritizes:

- **Option A/B (bare palette ± invite line):** de-prioritized — the CEO
  questioned sharing a bare palette "just because".
- **Option C (palette + one harmony):** its *insight* (show the matching, the
  differentiator) is now promoted to the spine of **Concept 2** — but as the
  **hero**, not an add-on strip, and with the real/synthetic labeling that
  Option C only warned about.
- **The invite line / handle / QR questions from `_1000_` are parked.** Sharing
  is explicitly not a priority; we don't burn referral copy decisions now. If
  F6 is ever prioritized, revisit `_1000_` §5 Q2–Q4 then.

Both docs stay as immutable point-in-time snapshots (naming convention). This
one is the current *direction*; neither ships yet.

---

## 5. Privacy / consent note (flag, not a full spec)

Both concepts **embed a real user photo** into an image the user then posts
publicly — Concept 1 makes it the hero, Concept 2 a thumbnail. That's a
meaningfully different privacy surface from the bare-palette object, which
carried no personal image. Things the share flow (a future mobile/PM task, not
this doc) must handle:

- **Explicit, per-share intent.** Exporting a story with the photo baked in
  should be a deliberate action the user takes ("Súbela a tu story"), never
  automatic. The user must see the exact framed image before it leaves the app.
- **The photo never leaves the device except by the user's own share.** The
  MVP is 100% offline (D15) — keep it that way; the RepaintBoundary→PNG is
  composed locally and handed to the OS share sheet only on tap. No upload, no
  analytics payload with the image.
- **Faces / bystanders.** Outfit photos can include the user's face or other
  people. v1 has no face handling; worth a one-line consideration of whether the
  default crop should bias toward the outfit (torso) rather than the face — which
  Concept 1's crop framing can encourage, and which also happens to make the
  *fit* (not the person) the subject, on-brand.
- **A no-photo fallback exists.** Because sharing isn't core and some users won't
  want their photo out, the bare-palette object (today's `_ShareCanvas` / A/B)
  should remain available as the privacy-safe default. Concept-with-photo is
  opt-in on top.

This is a flag for PM/mobile to scope when/if F6 is prioritized — not a blocker
for this exploration.

---

## 6. Open questions for the CEO

1. **Photo size in Concept 1 — hero crop (as drawn) or a literal small
   thumbnail?** I designed the hero crop because you said it's "lo guapo" (the
   hook). Say the word and I'll show a thumbnail-size variant with a taller
   palette.
2. **Which direction leads?** Concept 1 (photo = hook) or Concept 2
   (recommendation = value)? Or "prototype both, Concept 1 as default"? Given
   sharing isn't a priority, "park both as roadmap concepts" is a valid answer.
3. **Concept 2 real/synthetic clarity — do the `mi base` / `combina` /
   `de mi fit` labels read clearly to you, or does the generated complement next
   to the real base still feel confusing?** If confusing, I'll drop the mini-strip
   or restrict the pairing to two colors already in the fit.
4. **Concept 2 harmony choice.** Which harmony do we feature — always the
   complementary (cleanest 2-color "combina con"), or the one the user last
   tapped on the result screen? Needs a default.
5. **First-person copy on the export** (`Mi fit de hoy`, `de mi fit`) vs the
   in-app second person (`Tu paleta`) — OK to diverge on the exported object?

---

## 7. Product tension escalated (per remit)

No PRD decision is challenged — F6 is a post-MVP fast-follow (D12), and both
concepts fit inside D7/D8/D9 and Principle 2. Two things to surface to PM/CEO:

- **New privacy surface.** Embedding a real photo (esp. as the hero) is a
  genuinely new consideration vs the bare-palette object; §5 should be scoped by
  PM/mobile before F6 is built, and the no-photo fallback kept.
- **The referral-metric framing of `_1000_` is now decoupled from content.** The
  CEO's "sharing is not a priority" means we should **not** treat the ≥10%-shared
  target (PRD §5) as a driver of these mockups. If growth still wants that loop,
  that's a separate prioritization conversation — flagging so the two docs aren't
  read as contradictory.
