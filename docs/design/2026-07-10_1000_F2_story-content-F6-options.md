# F6 shareable story — CONTENT options (referral engine) · decision brief

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-07-10 |
| **Phase** | F2 · demo → validated product (F6 is the first fast-follow, D12) |
| **Issue** | #60 — decide the CONTENT of the exported 9:16 story |
| **Scope** | WHAT goes on the exported story object. NOT the export/share plumbing (mobile), NOT the in-app result screen redesign. No new features. |
| **Framing decisions** | D7 (white + mint + purple, radical simplicity) · D8 (mint = action, purple = accent, max 2 doses) · D9 (tinted neutrals) · D12 (F6 = referral fast-follow) · D14 (logo frozen) · D5 (base = most chromatic) |
| **Source of truth for values** | `docs/design/tokens.json` (v1.2) |
| **Base docs (do not re-litigate)** | `DESIGN_SYSTEM.md` §5 · `logo/USAGE.md` §6 (story watermark) · `mockups/result.html` (canonical) · `result_screen.dart` `_ShareCanvas` (today's object) |
| **Status** | OPEN — needs CEO pick (options A / B / C + 4 open questions) |

---

## 0. What this is and what it is NOT

This brief decides the **content** of the image the user exports and drops into
their IG/TikTok story. It gives the CEO 2–3 concrete options with wireframes, a
recommendation, and the open questions only he can close (brand handle, how hard
to push the invite).

It does **not** redesign the result screen, invent features, or spec the export
mechanics (that's a mobile task once content is picked). Copy shown is Spanish
(product language, D17); this doc is English (living design doc, D17).

---

## 1. The decision and why it matters

Today the shareable object is the `_ShareCanvas` card on the result screen: a
white card with **`Tu paleta`** + date + palette bands (hex/%) + the `BASE`
line + the `piketemaker.` watermark. It was designed to "survive as a 9:16
crop" (DESIGN_SYSTEM §5), but it was never designed **as a 9:16 canvas**, and —
this is the crux — it was never designed **as a referral engine**.

**Why the referral framing changes the content.** F6 is on the roadmap because
it is the cheapest growth loop we have (RICE 11.2, effort 1) and the Referral
metric target is **≥ 10% of analyses shared** (PRD §5). A share only pays off
if a *stranger* who sees it in someone's story can: **(a)** understand what
they're looking at, **(b)** want it, **(c)** find out how to get it. The
current card nails aesthetics but is weak on all three for a cold viewer:

- No line says *what the app does* — a stranger sees pretty colored bands and
  a wordmark, not "this is the palette of an outfit".
- The only brand cue is a tiny bottom-right watermark → low recall, no invite.
- Hex codes read as "designer stuff", great for credibility, meaningless to a
  casual viewer.

So #60 is really: **how much of the invite do we bake into the image, without
betraying D7 (radical simplicity) and Principle 2 (the user's color is the
protagonist, not our brand)?** Too little and it's a pretty dead-end; too much
and it's a spammy ad the user is embarrassed to reshare.

**One load-bearing platform note (informs, but does not replace, the decision).**
On IG/TikTok, the *tappable* path to the app is the **link sticker**, added at
share time and living **outside** the image (the app can pre-fill it). So the
image itself does **not** need a burned-in URL or a scannable QR to be
tappable. What the image must do is make the brand **recognizable and
memorable** so the link sticker (and word-of-mouth) converts. This is why my
recommendation leans on a *legible wordmark + one line of intent* rather than a
QR code (see §4). QR stays a CEO option for the print/screenshot path.

---

## 2. Fixed constraints (all options obey these)

- **9:16, full-bleed white** (`bg #FFFFFF`, D7 — no gradient, no confetti).
  Target export 1080×1920.
- **Story safe area:** keep all meaningful content inside the central band.
  Top ~250 px (avatar/username) and bottom ~250 px (reply bar / link sticker)
  are covered by platform UI on IG. Watermark sits *above* the bottom unsafe
  zone, never in it.
- **The palette is the protagonist** (Principle 2, DESIGN_SYSTEM §2.1). Brand
  colors stay in their allowance: **mint = 0 doses** here (nothing is tappable
  in a static image), **purple ≤ 2 doses** (the watermark piquete is one).
- **Watermark = `logo/assets/watermark-story.svg`** (lockup in `textDisabled
  #8F87A3`, piquete dot in `accent #6C3FD1`, casing "PiketeMaker" per USAGE §6).
- **No system chrome** (no app bars, no buttons) inside the canvas.
- **Reads standalone** — survives with zero app context around it.

---

## 3. The three content options

Legend for wireframes (each box is the full 9:16 frame; dashed = platform-unsafe
zone you should keep clear; `▓` = a proportional palette band):

### Option A — "El objeto puro" (what we have, reflowed to 9:16)

Ship today's `_ShareCanvas` content, reflowed to fill a 9:16 white frame. No
invite beyond the watermark. Maximum aesthetic restraint.

```
┌───────────────────────────┐  9:16 · white full-bleed
┊     (avatar / handle)      ┊  ← platform-unsafe (keep clear)
├───────────────────────────┤
│                           │
│  Tu paleta                │  display 800
│  Fit de hoy · 10 jul 2026 │  caption, tinted tertiary
│                           │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓  #E13683 36%│
│  ▓▓▓▓▓▓▓▓▓▓▓▓   #F856A4 31%│  bands proportional
│  ▓▓▓▓▓▓▓▓       #B21E5E 20%│  to weight, hex/% mono
│  ▓▓▓▓           #652234  9%│
│  ▓▓             #9CA6C6  3%│
│                           │
│  ● BASE                   │  purple badge (dose 1)
│  Tu color dominante.      │
│                           │
│              PiketeMaker. │  watermark (dose 2)
├───────────────────────────┤
┊     (reply · link sticker)┊  ← platform-unsafe
└───────────────────────────┘
```

- **Optimizes for:** purity, D7 discipline, **zero new build** (content already
  exists), zero risk of looking like an ad. The user is never embarrassed to
  post it.
- **Tradeoffs:** weakest referral of the three. A cold viewer gets no "what is
  this" and no invite; the loop leans entirely on the watermark + the (external)
  link sticker + curiosity. Likely under-performs the ≥10% share→install target.
- **When it wins:** if the CEO wants F6 shipped this week as literally the
  current crop and treats referral copy as a later iteration.

---

### Option B — "La paleta que invita" (RECOMMENDED)

Palette stays the hero and fills most of the frame; add **one** classy footer
line that does double duty — *names what this is* and *invites* — sitting with
the watermark. This is the smallest change that turns the object into a referral
engine.

```
┌───────────────────────────┐  9:16 · white full-bleed
┊     (avatar / handle)      ┊
├───────────────────────────┤
│  Mi paleta de hoy         │  display 800
│  10 jul 2026              │  caption tertiary
│                           │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓  #E13683 36%│
│  ▓▓▓▓▓▓▓▓▓▓▓▓   #F856A4 31%│  TALL bands — the
│  ▓▓▓▓▓▓▓▓       #B21E5E 20%│  vertical format lets
│  ▓▓▓▓           #652234  9%│  them breathe, thumb-
│  ▓▓             #9CA6C6  3%│  stopping
│                           │
│  ● BASE · Tu color        │  purple badge (dose 1)
│    dominante              │
│  ─────────────────────────│  hairline (tinted border)
│  Saca la paleta de tu fit │  ← the invite line (1 line)
│  PiketeMaker.             │  watermark (dose 2)
├───────────────────────────┤
┊     (reply · link sticker)┊
└───────────────────────────┘
```

- **The invite line** is the whole point. It must *explain + invite* in one
  breath, in Dani's voice, without an imperative that reads like an ad. Copy
  candidates (CEO/growth to pick — Open Q3):
  - `Saca la paleta de tu fit` (invites; implies "you can do this too")
  - `¿Qué colores llevas hoy?` (curiosity hook, softest)
  - `Tu fit tiene una paleta. Sácala.` (two beats, more explicit)
  - handle variant: `@piketemaker` under the wordmark instead of a sentence
- **Optimizes for:** referral **without** losing purity. Palette still owns the
  frame; the brand footer is one hairline-separated block a viewer's eye lands
  on last. Explains, invites, and stays postable-with-pride. Best
  effort/impact ratio.
- **Tradeoffs:** adds exactly one text element (still within "little text").
  Forces two sub-decisions: the exact invite copy (Q3) and whether to show an
  `@handle` (depends on the handle being secured — Q2, growth owns per D6).
- **Note on the title:** I'd shift `Tu paleta` → **`Mi paleta de hoy`** for the
  *exported* object. On the in-app screen "Tu" (the app talking to the user) is
  right; on a story the user is talking to *their* audience, so "Mi" reads
  natural in first person. Small but it makes the object feel authored, not
  screenshotted. (In-app card keeps "Tu paleta".)

---

### Option C — "La tarjeta con consejo" (palette + one harmony + invite)

Add proof of the app's *smarts*: below the palette, show **one** hero harmony
strip (the matching advice, F4 — the differentiator vs a generic palette app),
then the invite footer.

```
┌───────────────────────────┐  9:16 · white full-bleed
┊     (avatar / handle)      ┊
├───────────────────────────┤
│  Mi paleta de hoy         │
│  10 jul 2026              │
│                           │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓  #E13683 36%│  palette (shorter than B
│  ▓▓▓▓▓▓▓▓▓▓▓▓   #F856A4 31%│  to make room)
│  ▓▓▓▓▓▓▓▓       #B21E5E 20%│
│  ▓▓▓▓           #652234  9%│
│                           │
│  Combina con · Triádico   │  heading
│  ▓▓▓▓ ▓▓▓▓ ▓▓▓▓            │  ← ONE harmony strip
│                           │     (synthetic colors)
│  ● BASE · Tu color domin. │  purple badge (dose 1)
│  ─────────────────────────│
│  Saca la paleta de tu fit │  invite
│  PiketeMaker.             │  watermark (dose 2)
├───────────────────────────┤
┊     (reply · link sticker)┊
└───────────────────────────┘
```

- **Optimizes for:** showing what makes us *not* a generic palette ripper — the
  story now carries a mini styling tip, which is more "useful" → more likely to
  be **saved** and reshared, and a stronger curiosity hook ("wait, it tells you
  what matches?").
- **Tradeoffs (real, and they bite):**
  1. **More color on screen = tension with Principle 2.** The harmony strip adds
     *synthetic* colors (generated, not from the outfit) next to the *real*
     extracted palette. On one shared frame this risks the confusion "which of
     these am I actually wearing?" — muddying the app's core promise.
  2. **More elements = tension with D7.** We'd carry a title, palette, a harmony
     block *with its own label*, base, and the invite — that's a lot for
     "radical simplicity".
  3. **Which harmony?** We'd have to pick one (the complementary? the user's last
     tapped?) — a product decision with no obvious default.
- **When it wins:** if the CEO decides the differentiator (matching, not just
  extracting) must be visible in the viral surface *now*, and accepts the extra
  complexity + the real/synthetic-color risk.

---

## 4. Recommendation — **Option B**, plus 3 rules

**Ship Option B.** It is the smallest edit that fixes the actual gap (the object
is beautiful but a referral dead-end) while staying true to the two principles
that define the brand: **the user's color is the protagonist** and **radical
simplicity**. It adds exactly one line of intent and keeps the palette owning
the frame. Option A leaves growth on the table for no design gain; Option C buys
"differentiator visibility" at the cost of clutter and a real/synthetic-color
confusion on the one surface where clarity matters most.

Three rules I'd lock with Option B:

1. **The invite lives in the image; the link lives in the sticker.** Do **not**
   burn a URL or QR into the canvas (noisy, not tappable on IG anyway, ages
   badly). The image earns brand recall; the tappable link is the platform link
   sticker the app pre-fills. QR only if the CEO wants the screenshot/print path
   (Q4) — and then bottom-corner, small, `textDisabled`, never dominant.
2. **Keep the hex/% — small.** They are the "discerning / real data"
   personality (DESIGN_SYSTEM §1) and read as *credible* even to someone who
   doesn't parse them. They cost little vertical space and they're on-brand.
   (Open to dropping them if the CEO finds them too technical — Q1.)
3. **Purple stays at 2 doses**, mint at 0. On the story the only brand color is
   the `BASE` badge + the watermark piquete. Everything else is the user's
   palette and tinted neutrals. If we ever add the harmony strip (Option C),
   the mint-vs-logo-turquoise and 2-dose rules must be re-checked.

**Migration note (for mobile, not this doc's job to spec):** Option B is close
to today's `_ShareCanvas`; the real work is (a) a dedicated 1080×1920 *export*
layout (full-bleed white, safe-area-aware) distinct from the on-screen card,
and (b) the invite footer + first-person title on the *export path only*. The
in-app card can stay as-is.

---

## 5. Open questions for the CEO

1. **Hex/% on the shared story — keep or drop?** I recommend **keep, small**
   (credibility, brand personality). Your call if it feels too technical for a
   story aimed at non-designers.
2. **Handle vs plain wordmark in the footer.** If a real `@handle` is secured
   (growth owns this — D6 handle validation is still pending), an `@piketemaker`
   line converts better than a sentence. If not yet secured, ship the wordmark +
   invite sentence and add the handle later. **Which is it today?**
3. **Invite copy — pick one** (from §3 Option B): `Saca la paleta de tu fit` /
   `¿Qué colores llevas hoy?` / `Tu fit tiene una paleta. Sácala.` My default:
   **`Saca la paleta de tu fit`** (invites + implies "you too"). Growth should
   sanity-check voice.
4. **QR yes/no?** Recommend **no** for the IG/TikTok path (link sticker covers
   tap-through). Say yes only if you specifically want the screenshot/DM/print
   path covered — then it's a small bottom-corner mark.
5. **Title:** OK to switch the *exported* object to first person
   **`Mi paleta de hoy`** (in-app card keeps `Tu paleta`)?

---

## 6. Product tension escalated (per my remit)

None of these options require changing a PRD decision — F6 is explicitly a
post-MVP fast-follow (D12) and everything here fits inside D7/D8/D9. The only
thing worth flagging to PM/growth: **the referral metric (≥10% shared, PRD §5)
depends on content we haven't validated with a single real user.** Whichever
option ships, we should treat the invite copy + whether-to-show-a-handle as
things to A/B or at least eyeball in the closed beta (Phase 2), not freeze
forever now. The handle question (Q2) is also a **growth dependency**: it's
blocked on the D6 name/handle validation that's still open.
