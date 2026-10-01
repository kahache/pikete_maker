# N1: share the photo together with the combo (+ N4 logo, N3 wrap): UX proposal

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-09-29 |
| **Phase** | F2 · next development block (BACKLOG §N: N1 + N4 + N3) |
| **Status** | FINAL PROPOSAL with the CEO's decisions of 2026-09-29 applied (whole photo incl. face · preview sheet with "Incluir mi foto" default ON · sneaker mode IN). **Still for the CEO:** N4 logo, N3 fix, copy (§9). No production code, no commit. |
| **The ask (CEO, verbatim)** | *"yo no quiero compartir la paleta, quiero compartir la foto que he subido junto a la paleta. sinó no tiene gracia."* |
| **Builds on** | Concept 1 "Con foto" (`2026-07-10_2000_F2_story-content-F6-photo-concepts.md`) + the D36 recommendation card (`2026-07-23_1620_F2.5_outfit-result-recommendation-first.md`) + r13's `OutfitStoryFrame` / `renderWidgetToPng` |
| **Framing decisions** | D2 (on-device) · D7 (white, radical simplicity) · D8 (mint = action; on a static story mint = 0 doses) · D10 (canvas pops) · D25/D27 (sneaker share, **superseded for sharing by the CEO 2026-09-29**, §5) · D36 (recommendation-first) · Principle 2 (the user's colour is the protagonist) · Principle 3 (the result is a shareable object) |
| **Mockup** | `docs/design/mockups/2026-09-29_1830_F2_share-photo-story.html` (self-contained: whole-photo stories at 3:4 / 9:16 / 4:3 + canvas mode, preview sheet ON/OFF/loading, sneaker story + sneaker result CTA stack, N4 logo comparison, interactive N3 width demo) |
| **Privacy of this doc** | `docs/design/**` is exported to the public repo. The mockup uses a **drawn placeholder figure**; no real photo appears anywhere in it. |

---

## 0. TL;DR

- **The story becomes "your whole photo, with its combo underneath":** headline, then one card (the uncropped photo with the hero band glued under it), then the logo. Nothing is drawn over the photo, so the combo and the logo are readable whatever the photo looks like.
- The photo is **never cropped** for any aspect between 5:8 and 16:9. The card takes the photo's shape inside a 392 × 415 box.
- The ARRIBA/ABAJO strip, the caption and the date are gone from the photo story, because **the photo itself is the evidence now**.
- **One-step preview sheet**: the exact PNG, an "Incluir mi foto" switch (default ON; OFF = r13's card byte for byte), one privacy line, one "Compartir" button, then the OS share sheet.
- **Sneaker mode ships too.** Same frame, same sheet. On the sneaker result, "Súbela a tu story" takes the secondary pill slot (as on outfit) and "Otras zapas" becomes a text button under it.
- **N4 (recommendation): keep the full-colour lockup** below the card (28 logical px) and rewrite USAGE §6 (exact text in §6).
- **N3 (recommendation): tags never wrap.** Content-aware segment widths, one-line tags, a 0.8× shrink floor. Needed on screen *and* on the story, where the band can be as narrow as 236. Shorter **sneaker** tags in en/ca/fr are now required (§7.3).

---

## 1. What changes vs r13

| | r13 (today) | N1 (proposed) |
|---|---|---|
| What's shared (outfit) | The D36 card (headline, band 154 tall, caption, "tu fit" strip, BASE) + a full-colour lockup below it | **The whole uploaded photo, with the hero band under it** + headline + lockup |
| What's shared (sneaker) | nothing: no share CTA (D27) | the same photo story with the sneaker copy |
| How | Tapping "Súbela a tu story" goes straight to the OS sheet | Tapping it opens a **preview sheet**, then "Compartir" opens the OS sheet |
| Privacy fallback | n/a (no photo) | Switch "Incluir mi foto" OFF shares exactly the card-only image |
| Outfit result screen | unchanged | unchanged (CTA label, layout and selection logic all stay) |
| Sneaker result screen | CTAs: "Enséñame otros piketes" + "Otras zapas" | + **"Súbela a tu story"** as the secondary pill; "Otras zapas" becomes a text button (§5.2) |

---

## 2. The photo story (9:16)

### 2.1 Frame and layout (logical px in r13's 432 × 768 frame; × 2.5 = 1080 × 1920)

Same frame and pixel ratio as r13 (`OutfitStoryFrame.logicalSize` / `pixelRatio`), so nothing in the export pipeline changes size.

| Element | Spec |
|---|---|
| Background | `bg #FFFFFF` full bleed (D7) |
| Unsafe zones | top **0–80**, bottom **688–768** (10.4% each; r13's `safeInsetV = 80`). No text, band or logo in them. |
| Headline | `display` 32/38, weight 800, `textPrimary`, **centred**, top **92**. One line, scaled down to fit (floor 24 px). If it still doesn't fit (the sneaker title always does this), **2 lines**: the card moves to top 184 and the photo box max height drops to 377. |
| Photo box (max) | **392 × 415** (1-line headline) or **392 × 377** (2-line headline) |
| Photo size rule | Aspect `a = w/h` of the oriented photo, clamped to **[5:8, 16:9]**. If `a ≥ maxW/maxH`, width = 392 and height = 392/a; otherwise height = maxH and width = maxH·a. **The photo is scaled, never cropped**, inside that range. Outside it (only photos taller than 5:8, i.e. full-screen 9:16 captures and screenshots, or wider than 16:9), the excess is cut **evenly from both ends** (centred). |
| Card | centred horizontally, `radius.lg` 20, hairline `border` ring + `shadow.sm`, clip. **One object**: the photo on top, the band flush under it. Card width = photo width. |
| Hero band | **card width × 72**, the shared `HeroComboBand` (same per-mode flex, same tags, same luminance-picked tag ink), including the N3 fix (§7). |
| Logo | full-colour `lockup-horizontal`, **28 tall** (≈128 wide), centred, **20 below the card** (at max photo height: top 653, bottom 681, 7 above the safe line). Clearspace ≥ the dot diameter (USAGE §3). |
| Group placement | headline + card + logo form one group. At max height it spans 92 → 681. When the photo is shorter (landscape, square), the group is **vertically centred** in the safe band 80–688, like r13 centres its card. |

Worked examples (outfit, 1-line headline):

| Photo | Photo box | Card x | Notes |
|---|---|---|---|
| 3:4 (phone camera default) | **311 × 415** | 60.5 | uncropped, head to shoes |
| 4:5 (IG download) | 332 × 415 | 50 | uncropped |
| 9:16 (full-screen capture) | **259 × 415** (clamped to 5:8) | 86.5 | ~5% cut top + ~5% bottom |
| 1:1 | 392 × 392 | 20 | group centred |
| 4:3 landscape | **392 × 294** | 20 | group centred: headline 150, card 204, logo 590 |

**Why the 5:8 clamp:** below ~259 wide, the band is too narrow for its three tags (N3). A 9:16 photo loses about 10% of its height, a phone screenshot (9:20) about 20%. Normal camera photos (3:4), IG downloads (4:5), squares and landscapes lose nothing.

**Why nothing is overlaid on the photo** (the CEO asked that the card and logo stay readable "next to/over" a full photo): putting the band or logo over an arbitrary photo would need a scrim, and readability would depend on the photo. Beside the photo, on white, it is readable by construction, and it keeps D7's white ground. Full-bleed (photo filling the 9:16 frame) was rejected: it crops every non-9:16 photo heavily (a 3:4 photo would lose ~58% of its width), which contradicts "the whole photo".

**What's deliberately NOT on the photo story** (all kept on screen and in the OFF card):
- the date meta (IG timestamps the story anyway);
- the hero kicker "LA COMBI · CONTRASTE";
- the caption one-liner (the tags already say it, and it's the longest string in 7 locales);
- the "tu fit" ARRIBA/ABAJO strip and the BASE badge (outfit) / the palette strip (sneaker). **The photo IS the evidence now.**

**Brand budget on the image:** UI mint 0, UI purple 0. The only brand colours are the logo's own (logo turquoise ≠ action mint, USAGE §9). The photo and the band are the most colourful things in the frame (Principle 2) ✓.

### 2.2 Canvas mode (100% neutral fit or kicks, D10)

- Headline `resultCanvasHeadline` ("Tu fit pide color") for outfit; `sneakerResultTitle` for sneakers.
- The band shows the **5 curated pops**, equal widths, no tags.
- If the user picked a pop on screen (#82): that pop takes **40%** of the band and carries the `resultTagAdd` tag ("súmale"); the other four share the remaining 60%. What you picked is what you share (same principle as r13's `selectedAccentIndex`).

### 2.3 Which combo is shown

The **hero combo (complementary)**, exactly like r13, even if the user tapped another "Otras combis" row. Unchanged behaviour; the preview shows it before sharing anyway.

### 2.4 Degraded / edge paths

| Path | Story |
|---|---|
| S3 / S4 (segmentation degraded) | unchanged: the whole photo never depended on segmentation |
| Legacy outfit (`segmentationLayout == null`, fixtures only) | Toggle hidden, card-only (r13's legacy card) |
| Photo bytes missing (defensive) | Toggle hidden, card-only |
| Photo render throws | Sheet silently falls back to card-only with the toggle hidden (no new error string) |
| Card render also throws | Sheet closes, then the existing `storyFailedSnack` ("No se pudo generar la story. Prueba otra vez.") |

---

## 3. The preview sheet (shared by outfit and sneaker)

### 3.1 Flow

```mermaid
flowchart TD
  R[Result outfit or sneaker · tap "Súbela a tu story"] --> S[Preview sheet opens<br/>render ON-PNG]
  S -->|PNG ready| P[Preview = the exact PNG<br/>Compartir enabled]
  P -->|toggle OFF / ON| P2[Swap to the other PNG<br/>rendered once, cached]
  P2 --> P
  P -->|Compartir| OS[OS share sheet]
  OS -->|success / unavailable| X[Sheet closes · back on Result]
  OS -->|dismissed| P
  P -->|swipe down / scrim / back| X
  S -->|photo render fails| C[Card-only preview, toggle hidden]
  C --> P
  S -->|card render fails too| E[Sheet closes + storyFailedSnack]
```

### 3.2 Layout (390 × 844 reference, modal bottom sheet)

| Element | Spec |
|---|---|
| Sheet | modal bottom sheet, `radius.lg` top corners, `bg`, `shadow.lg`, scrim `rgba(28,24,38,.40)`; top at ~112 (it covers most of the screen, the result peeks behind) |
| Handle | 36 × 4, `borderStrong`, 8 from the top |
| Preview | **the rendered PNG itself** (`Image.memory` of the bytes that will be shared, decoded at preview size), 9:16, height **480** (flexes down to a min of 280 on short phones), centred, `radius.md`, hairline ring + `shadow.md`. Semantics label `storyPreviewLabel`. |
| Toggle row | 56 tall, the whole row is tappable (≥ 44): label **"Incluir mi foto"** (`heading` 16/600, `textPrimary`) + a switch on the right. ON = `action` track; OFF = `borderStrong` track; white thumb. |
| Privacy line | `caption` 13/18, `textTertiary`: **"Tu foto solo sale del móvil si tú la compartes."** Always visible (no layout jump on toggle). |
| CTA | `PkPrimaryButton` **"Compartir"**, 56 tall pill, 24 from the bottom (thumb zone) |
| Nothing else | no title, no secondary button, no icons. Close = swipe down, scrim tap or system back. |

**Mint budget:** the switch's active state + the CTA, both actionable (D8 allows mint on action and active states). Purple: 0.

### 3.3 States

| State | Preview | Toggle | CTA |
|---|---|---|---|
| Loading (first open, ~0.3–0.6 s) | plain 9:16 `surfaceSubtle` box, no spinner | enabled | **disabled** (`surfaceSubtle` / `textDisabled`) |
| Ready | the PNG | enabled | enabled |
| Switching (first time to the other state) | keeps the current PNG, crossfades (`motion.base` 200 ms) when the other is ready | enabled | disabled until ready |
| No photo available | card PNG | **hidden** | enabled |
| Sharing (OS sheet open) | unchanged | n/a | double-tap guarded (r13 `_exportingStory`) |

### 3.4 Behaviours

- **Default ON** (CEO decision). **Recommended: remember the last choice** locally (`shared_preferences`, key `story_include_photo`, default `true`; one key for both modes). A user who turned it off for privacy should not have to do it again on every share. Nothing is sent anywhere.
- **What you see is what you share:** the preview decodes the same `Uint8List` that is written and handed to share_plus. Test: the shared bytes are `identical()` to the previewed ones.
- The CTA on both results reads **"Súbela a tu story"** (`resultCtaStory`, reused on sneaker).

---

## 4. Copy (es canonical) and ARB keys

### 4.1 First person vs second person (July open question Q5). Recommendation

**Keep the second person on the story, i.e. reuse the on-screen strings** ("Toma tu pikete", "tu fit / súmale / + crema", "Tu fit pide color", "Combina tu ropa con estas zapas", "tus zapas / tu ropa").
- **The shared object reads as the app's verdict on me.** That is the Spotify Wrapped pattern ("Your top songs"), which people share happily, and it is implicit brand advertising ("PiketeMaker told me this").
- **Zero drift** between what the user saw on the result, the preview and the story.
- **No new strings** for the story itself, and nothing new for the 7-locale i18n round.
- The one argument for first person (the user is talking to their followers) is weaker here, because the story is a screenshot-like verdict, not a caption. The user adds their own caption in IG.

If the CEO prefers first person, these keys would be added, used only on the photo story (outfit; the sneaker title has no natural first-person form, so it stays):
```json
"storyHeadlineMine": "Mi pikete",
"storyCanvasHeadlineMine": "Mi fit pide color",
"storyTagFitMine": "mi fit"
```

### 4.2 New keys, add to `app_es.arb` first (D18)

```json
"storyIncludePhoto": "Incluir mi foto",
"@storyIncludePhoto": {
  "description": "N1 preview sheet (outfit + sneaker): label of the switch that puts the user's own uploaded photo in the shared 9:16 story. Default ON. Keep it first person and short (one line at 390 dp next to a switch)."
},
"storyPhotoPrivacy": "Tu foto solo sale del móvil si tú la compartes.",
"@storyPhotoPrivacy": {
  "description": "N1 preview sheet: privacy line under the switch. Must stay literally true: the photo only leaves the device through the user's own OS share. Echoes onbWelcomePrivacy / privacyNote ('Tu foto no sale del móvil'). Keep 'del móvil': a bare 'sale' would read as 'appears (in the story)'."
},
"storyShareCta": "Compartir",
"@storyShareCta": {
  "description": "N1 preview sheet: primary CTA that opens the OS share sheet with the previewed image."
},
"storyPreviewLabel": "Vista previa de tu story",
"@storyPreviewLabel": {
  "description": "N1 preview sheet: accessibility (semantics) label of the preview image. Not visible."
}
```

The CEO's suggested wording "Tu foto solo sale si tú la compartes" was lengthened by two words on purpose: "sale" alone is ambiguous in a story context ("appears"). "del móvil" makes it the privacy promise, consistent with ONB-1.

### 4.3 Changed keys (non-es only, N3 §7.3): sneaker band tags

es is unchanged. These are width fixes for the i18n owner to voice-check:

| Key | en | ca | fr |
|---|---|---|---|
| `sneakerTagZapas` | `your kicks` (unchanged) | ~~les teves bambes~~ → **`bambes`** | ~~tes sneakers~~ → **`baskets`** |
| `sneakerTagRopa` | ~~your clothes~~ → **`your fit`** | ~~la teva roba~~ → **`roba`** | ~~tes vêtements~~ → **`fringues`** |

zh/ko/ja: covered by the widget-test matrix (§7.3); adjust only if a test fails.

**Reused unchanged:** `resultCtaStory` (now also on the sneaker result), `sneakerResultCtaSecondary` ("Otras zapas", restyled as a text button), `resultRecoHeadline`, `resultCanvasHeadline`, `sneakerResultTitle`, all hero tags, `storyFailedSnack`. N2 (removing the dead `storySavedSnack`) is independent and compatible.

---

## 5. Sneaker mode (IN, CEO decision 2026-09-29)

### 5.1 The sneaker story

Same frame and rules as §2. The sneaker title `sneakerResultTitle` "Combina tu ropa con estas zapas" always takes **2 lines**, so the card sits at 184 and the photo box max is 392 × **377**. A 3:4 product photo gives **283 × 377**, uncropped, floor and all. The band keeps the sneaker spec (flex 115 : 155 : 90) with "tus zapas / tu ropa / + {neutro}". Canvas kicks: the 5 pops (§2.2).

**OFF (card-only):** the sneaker result card (`SneakerShareCanvas`, watermark off) inside the same story frame with the lockup under it, i.e. the exact sneaker analogue of r13's outfit story.

### 5.2 Where the share button goes on the sneaker result

Today: primary **"Enséñame otros piketes"** + secondary pill **"Otras zapas"**. Proposed:

1. primary pill **"Enséñame otros piketes"** (unchanged)
2. secondary pill **"Súbela a tu story"** (**new**, `resultCtaStory`)
3. text button **"Otras zapas"** (`sneakerResultCtaSecondary`): `cta` 16/700 in `action` ink, 44 tall, centred, 4 below the secondary pill

Why:
- **Same two pills, same order as the outfit result** (looks, then story): both modes build the same muscle memory.
- **"Otras zapas" stays in the thumb zone.** In a store it's the "scan the next pair" action, frequent enough that it must not move to the app bar. A text button keeps it one tap away without a third competing pill.
- Cost: the CTA zone grows from 56 + 12 + 56 to 56 + 12 + 56 + 4 + 44 (+48 px). The scroll area absorbs it.

Alternatives rejected: share as an app-bar icon (out of thumb reach, low discoverability, and an icon is decoration D7 discourages); three stacked pills (a wall of buttons, against radical simplicity).

Brand budget on the sneaker result: mint only on tappables (unchanged rule, now 3 tappables in the CTA zone); purple unchanged.

### 5.3 Risk: shop screenshots (needs a CEO OK)

One of the three sneaker sources is **"Captura de pantalla"**: a **web shop's product image**. A public story with it republishes a third party's copyrighted photo, the same EU risk behind decision #3 (never embed third-party images).
- **Recommendation:** for that source only, the sheet opens with **"Incluir mi foto" OFF** (the user can still turn it on; the preview shows exactly what goes out). Camera photos ("Casa o calle", "En una tienda") keep default ON.
- **Needs:** the selector's chosen situation threaded to the result (today `SneakerSourceSelectorScreen` pops only a `PhotoSource`, so gallery = screenshot = own photo). Small change: pop `(situation, source)` and carry it in `SneakerResultArgs`.
- The remembered choice (§3.4) is **not** applied to screenshot-sourced photos: they always open OFF.

### 5.4 Decision record (for PM)

This supersedes D27's "NO share CTA" (and D25's downgrade) **for sharing only**. The recommendation-first hierarchy of D27 stands. Suggest recording it as a new decision (next free D-number) in PRD + CLAUDE.md: *"N1 (2026-09-29): 'Súbela a tu story' shares the user's whole uploaded photo with the hero combo, behind a preview sheet with 'Incluir mi foto' (default ON). It ships in outfit AND sneaker mode; the sneaker result gains the share CTA (secondary pill), 'Otras zapas' becomes a text button."*

---

## 6. N4: the logo on the story. Recommendation

**Keep r13's full-colour lockup below the content**, at 28 logical px (70 px in the export) on the photo story, centred, inside the safe band. Do **not** use the §6 grey watermark on shared stories.
- The grey watermark was specified when the card filled the whole story as a quiet corner signature. At `textDisabled` (3.4:1) and 15 px cap height it dissolves after Instagram's recompression, and bottom-right pulls the eye off-centre in a centred composition.
- A shared story is the one surface where **brand recall** is the goal. The real lockup, on white and outside the photo, is legible without competing with the photo or the band (it is much smaller and quieter).
- It doesn't break the "mint = 0 doses on a static story" rule: logo turquoise `#17B598` is a **logo** colour, not the action mint (USAGE §9).
- The on-screen cards keep their in-card text watermark (`BrandWatermark`), unchanged.

**Exact replacement for `docs/design/logo/USAGE.md` §6** (apply after CEO approval):

> ## 6 · Story signature (shared 9:16 image)
>
> **Decided 2026-09-29 (N1/N4, CEO):** the shared story, outfit and sneaker,
> with or without the user's photo, is signed with the **full-colour
> `lockup-horizontal.svg`**, not a grey watermark. Centred horizontally,
> **below** all content, never over the user's photo or the colour band, on the
> plain white ground. Size: **28 logical px tall in the 432 × 768 story frame
> (70 px in the 1080 × 1920 export)** on the photo story; the card-only story
> keeps 32 / 80 px. Its bottom edge stays **inside the story-safe band** (≥ 80
> logical / 200 px from the bottom edge, where Instagram/TikTok overlay their
> reply bar). Clearspace per §3. Casing "PiketeMaker" (rule 6). Logo turquoise
> here is not a UI mint dose (§9).
>
> `watermark-story.svg` (lockup in `textDisabled #8F87A3` + purple piquete) is
> **retired from shared stories**: after platform recompression it is not
> legible. It remains available for low-emphasis in-app uses only. The on-screen
> result cards keep their small text watermark (`BrandWatermark`), which never
> appears in an exported image.

Also update the §1 asset-index row for `watermark-story.svg` to: "Retired from shared stories (§6); low-emphasis in-app use only".

**And `docs/design/DESIGN_SYSTEM.md` §5**: replace the watermark bullet with:

> - The shared 9:16 story (F6/N1, outfit and sneaker) carries **the user's whole
>   uploaded photo with the hero combo band under it** (switch "Incluir mi foto",
>   default ON; OFF shares the result card) and is signed with the **full-colour
>   lockup** below the content, inside the story-safe band (logo/USAGE.md §6).
>   The on-screen cards keep a discreet `textDisabled` text watermark that never
>   reaches the export.

---

## 7. N3: the "+ CREMA" wrap. Recommendation

### 7.1 Diagnosis

On screen, the band is **screen width − 90** wide (20 + 20 screen margin, 24 + 24 card padding, 2 border). With the outfit flex 130 : 150 : 90, the neutral segment is only **24.3%** of that, minus 2 × 8 segment padding. The pill "+ CREMA" (10 px / 700, 0.6 px tracking, 7 px side padding) is ≈ 63 px, so the segment needs ≈ **79 px**. On the photo story the band is as wide as the photo, so the same problem shows up there:

| Where | 320 dp | 360 dp | 375 dp | 390 dp | 411 dp (M33) | story, 9:16 photo | story, 3:4 photo |
|---|--:|--:|--:|--:|--:|--:|--:|
| Band width | 230 | 270 | 285 | 300 | 321 | 259 | 311 |
| Neutral segment today | **55.9** | **65.7** | **69.3** | **73.0** | 78.1 | **63.0** | **75.6** |
| Needs | ≈ 79 | ≈ 79 | ≈ 79 | ≈ 79 | ≈ 79 | ≈ 79 | ≈ 79 |

(Arial Bold proxy; Roboto runs ~3–5% narrower. The M33 fits by ~1 px, which is why the CEO rarely sees it.) **Accessibility text scaling** is the other trigger: at 1.3× system font, it wraps on every phone.

### 7.2 Fix (in the shared `HeroComboBand` / `_ComboSegment`: one fix covers outfit, sneaker, screen and story)

1. **Never wrap:** tag `Text` with `maxLines: 1, softWrap: false`, inside `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)`.
2. **Content-aware widths:** measure each tag pill with `TextPainter` (same style, current text scaler), then `min_i = pill_i + 2 × Space.sm`. Start from the flex shares. Any segment below its min is set to its min, and the deficit is taken from the others in proportion to their flex, never below their own min (converges in ≤ 3 passes). This is exactly how CSS flexbox resolves `min-width: auto`; the mockup's "after" band uses that to demo it live.
3. **Last resort:** if `Σ min_i > band width`, fall back to widths proportional to the mins and let the `FittedBox` shrink the pills. Floor **0.8×** (8 px text). Below the floor, the string is too long for the band, and that is a copy bug to fix in the ARB, not a layout one.
4. **No es copy change**; "+ CREMA" / "+ NEGRO" stay.

Effect at 360 dp (es outfit): segments go 94.9 / 109.5 / **65.7** → about 88 / 102 / **79**. The complement is still the widest segment, and the colour proportions barely move.

### 7.3 Acceptance matrix (widget tests)

Widths: on screen **320, 360, 375, 390, 411, 432**; story bands **236** (sneaker, 5:8 at 377), **259** (outfit, 5:8 at 415), **283**, **311**, **392**. Locales es/en/ca/fr (+ zh/ko/ja smoke). Outfit **and** sneaker specs. Text scale 1.0 and 1.3.

- **Outfit:** no tag on more than one line anywhere. No scaling at ≥ 259 for es/en/fr/ca at 1.0×. ca may scale to ≥ 0.95× at 236–245.
- **Sneaker (a new finding, pre-existing on screen, and now also on the story):** the sneaker tags are much longer. Today, **es "TUS ZAPAS" wraps at 360 dp**, and en/ca/fr wrap even on the M33 (ca "LES TEVES BAMBES" needs ~141 px in a ~103 px segment). Layout alone can't save ca/en/fr on the 236 story band (they would need 0.66–0.76×, below the floor). **With the §4.3 copy** they hold: es 0.93×, en 0.89×, fr 0.94×, ca 1.0× at 236, and no scaling at ≥ 283.

---

## 8. Implementation notes for mobile-dev

### 8.1 Photo bytes plumbing (capture → result)

- **Outfit:** `AnalyzingScreen` already holds the original picker bytes (`widget.args.photo`; ≤ 1600 px long side, JPEG q90, from `ImagePickerPhotoPicker`). Today it pushes `AppRoutes.result` with **only** the `AnalysisResult` (`analyzing_screen.dart`, `_releaseResultIfReady`). Add `ResultArgs({required AnalysisResult result, Uint8List? photo})`, mirroring `SneakerResultArgs`; update `app.dart`'s route switch and the `AppRoutes.result` doc. `photo == null` → the toggle is hidden (tests / legacy).
- **Sneaker:** `SneakerResultArgs.photo` already exists (it feeds "Otras zapas"). For §5.3, add the chosen situation: `SneakerSourceSelectorScreen` pops `(situation, source)` instead of just `PhotoSource`, carried through `CaptureArgs` / `AnalyzingArgs` to `SneakerResultArgs`.
- Keep the bytes **in memory only**, never written to disk by us except as part of the rendered story PNG (§8.6).
- **No engine change:** the whole-photo story needs nothing from segmentation. No `cv_core` change, parity fixtures untouched.

### 8.2 EXIF orientation

- The picker bytes can carry an EXIF Orientation tag with unrotated pixels. Decode the story photo with `dart:ui` (the same decoder `prepareImageForAnalysis` uses, which applies the orientation), and take the aspect ratio **from the decoded image**, never from the JPEG header.
- Required test: a fixture JPEG with **Orientation = 6** (portrait stored landscape). The story must be upright, with a portrait card.
- Privacy bonus: the story is a PNG **re-rendered from pixels**, so **no EXIF/GPS metadata of the original photo can ride along** into the share. Keep it that way (never attach the original file).

### 8.3 Sized decode (reuse r13's provider)

- Photo box at export = the photo box above × 2.5 (max **980 × 1038 px**; 3:4 → 778 × 1038).
- Because the box has the photo's own aspect (except for the clamp), cover == contain, so **`CoverSizedMemoryImage` / `coverDecodeSize` work as they are** with `boxWidth/boxHeight` = the box in export px. The clamp case is also a plain cover. Picker photos are ≤ 1600 px, so there is never an upscale beyond ~1×.
- The preview in the sheet does NOT decode the photo: it shows the PNG with `cacheWidth` = preview width × DPR.

### 8.4 Offscreen render (keep r13's pipeline). ⚠ One real gotcha

- `renderWidgetToPng` builds, lays out and paints **once, synchronously**. An `Image`/`Image.memory` widget resolves **asynchronously**, so inside that tree it would **paint empty** (r13's frame was vectors and text only, so this never came up).
- Therefore: **await the decode to a `ui.Image` first** (via the provider above), pass it into the frame, and paint it with `RawImage` (`fit: BoxFit.cover`, `alignment: Alignment.center`) or a `CustomPainter`. `dispose()` the `ui.Image` in a `finally` after the PNG encode.
- Frame widget: generalise r13's `OutfitStoryFrame` into one `StoryFrame` with two layouts: **photo** (headline + photo card + band + lockup 28) and **card-only** (a mode's share canvas, watermark off, + lockup 32, which is r13's). Parameterise it by a per-mode spec (headline string, band spec, card widget). Both modes use it.
- The sheet: one shared `StorySharePreviewSheet` widget taking two async renderers (`withPhoto`, `cardOnly`), the default state, and the `StorySharer` seam. Both result screens call it.

### 8.5 Sneaker result CTA

`sneaker_result_screen.dart` CTA zone: primary unchanged; add `PkSecondaryButton(resultCtaStory)` (with a `GlobalKey` for the iPad popover origin, as outfit does); restyle "Otras zapas" as a text button (`cta` 16/700, `action` ink, min height 44, centred). Add a `shareStory` seam like `ResultScreen`'s. Update the D27 doc comment ("NO share CTA") to the new decision.

### 8.6 Performance, cache hygiene, analytics

- A photo-heavy 1080 × 1920 PNG is much heavier than r13's flat card (expect **~2–4 MB** and a few hundred ms to encode on the M33). Budget: **preview visible < 600 ms** on the M33. Measure; if it's over, start rendering on tap while the sheet animates in (≈ 300 ms of cover).
- Render ON when the sheet opens (or OFF first, for screenshot-sourced sneakers). Render the other state lazily on the first toggle. Cache both for the sheet's life and drop them on close.
- Keep r13's fixed cache file (`piketemaker_story.png`, overwritten). **New: delete it when the sheet closes and on app start.** It now contains the user's photo, and ONB-1 promises "no la guardamos". share_plus keeps its own copy in its app-private cache folder until its next share: acceptable, but documented.
- Share status: `success` / `unavailable` → close the sheet; `dismissed` → keep it open.
- `story_exported` gets **`photo: true|false`** and **`mode: outfit|sneaker`** (booleans/enums, never image data). Telemetry is off anyway (D33).

### 8.7 Tests to add

Photo-size rule unit tests (3:4, 4:5, 1:1, 4:3, 9:16 → clamp, 9:20, 21:9 → clamp; 1- and 2-line headline) · frame geometry (group centred; logo fully inside 80..688; no text in the unsafe bands; card width == band width) · EXIF-6 fixture · offscreen photo actually painted (non-blank pixel check) · sheet: default ON, remembered OFF, screenshot-sourced sneaker opens OFF, toggle swaps bytes, CTA disabled until ready, **shared bytes identical to previewed bytes**, photo-render failure → card-only with toggle hidden, `photo == null` → toggle hidden · sneaker result CTA order + geometry · N3 matrix (§7.3).

---

## 9. Decisions

### 9.1 Taken by the CEO (2026-09-29): applied throughout

| # | Decision |
|---|---|
| C1 | **Whole photo, face included** (not an outfit crop) |
| C2 | Preview sheet as proposed; **"Incluir mi foto" default ON**; OFF = r13's card-only image; privacy line |
| C3 | **Sneaker mode in this block**, including a share button on the sneaker result (supersedes D25/D27 for sharing) |

### 9.2 Still for the CEO: my recommendation for each

| # | Decision | Recommendation |
|---|---|---|
| 1 | **Logo (N4):** full-colour lockup below vs §6 grey watermark | **Full-colour lockup, 28 px, centred below the card**; USAGE §6 + DESIGN_SYSTEM §5 rewritten as in §6 |
| 2 | **N3 fix:** content-aware widths + one-line tags (+ 0.8× floor) vs shorter es copy | **Layout fix, no es copy change**, plus the en/ca/fr sneaker tag shortening in §4.3 (required now that the sneaker story ships) |
| 3 | **Story voice:** second person (reuse) vs first person | **Second person**: Wrapped-style "the app's verdict on me", zero drift, zero new strings |
| 4 | **Privacy line wording** | **"Tu foto solo sale del móvil si tú la compartes."** (your line + "del móvil" to remove the "appears" ambiguity) |
| 5 | **Remember the switch** | **Yes, locally**, except for screenshot-sourced sneaker photos, which always open OFF |
| 6 | **Sneaker screenshots** ("Captura de pantalla") | **Switch opens OFF for that source** (copyright of shop images); needs the situation threaded (§5.3) |
| 7 | **Sneaker CTA placement** | **"Súbela a tu story" = secondary pill (same slot as outfit), "Otras zapas" = text button under it** |
| 8 | **What leaves the photo story** (date, kicker, caption, palette strip) | **Drop them all**: the photo is the evidence; the OFF card still has everything |

**Cost update for BACKLOG N1 step (2)** (mobile-dev implementation + tests): M 130–180k → with the whole photo (no engine work), sneaker mode, the shared sheet/frame and the N3 fix folded in, **≈ 190–250k (L)**. Consider splitting into two passes: (i) frame + sheet + outfit + N3, (ii) sneaker CTA + situation threading + sneaker copy.

---

## 10. Risks and escalations

1. **The privacy promise wording (escalate to PM/legal):** ONB-1 says *"Tu foto no sale de tu móvil y no la guardamos"* and the legal first-run copy says *"Tu foto no sale del móvil"*. With N1, the photo **does** leave, face included, but only by the user's own explicit share through the OS. The promise stays true in spirit, and the sheet's line makes the exception explicit. I'd add one item to the lawyer's open confirmations: *user-initiated sharing of an image containing their own photo, rendered locally, no upload by us*. The cache-delete rule (§8.6) is what keeps "no la guardamos" literally true.
2. **Faces are now in the default share** (C1). The mitigations are the mandatory preview, the one-tap OFF and the remembered OFF. Bystanders in the photo are the user's responsibility, as with any photo they post; no face handling in v1.
3. **Third-party images:** sneaker "Captura de pantalla" (§5.3). Recommended mitigation: default OFF for that source.
4. **Offscreen image decode** (§8.4): if missed, the photo renders blank in the shared PNG. It's easy to catch with a pixel test, but it's the likeliest implementation bug.
5. **PNG weight/latency** (§8.6): a photo PNG is ~10× r13's. Measure on the M33 before calling it done.
6. **D27 superseded for sharing:** PM must record the new decision (§5.4) so D27's "NO share CTA" isn't enforced by a future reviewer or test.

---

## 11. Living docs to update after approval (PM/ux, not now)

- `docs/design/logo/USAGE.md` §6 + §1 row (text in §6 above).
- `docs/design/DESIGN_SYSTEM.md` §5 (text in §6 above).
- `docs/design/user-flows.md`: add the preview-sheet branch of "Súbela a tu story" (the Mermaid in §3.1) to both result flows.
- `docs/design/2026-07-11_1030_F2S_sneaker-flow-final-spec.md` is an immutable snapshot, so don't edit it. The sneaker CTA change is recorded here and in the new decision (§5.4).
- `docs/BACKLOG.md` N1/N3/N4: the cost update in §9.2; PRD + CLAUDE.md: the new decision (§5.4).
