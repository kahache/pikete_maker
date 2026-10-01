# UX audit — implemented app vs. design spec (Phase 1, D12 critical path)

| | |
|---|---|
| **Owner** | ux-designer |
| **Date** | 2026-07-09 |
| **Scope** | The Flutter app as implemented in `app/lib/features/**` + `app/lib/widgets/**` (D12 critical path, working on the CEO's Android) audited against `docs/design/user-flows.md`, `DESIGN_SYSTEM.md`, `onboarding-tutorial.md`, `tokens.json` v1.2 and `mockups/result.html` |
| **Companion deliverables** | Synced mockups: `mockups/home.html`, `mockups/onboarding.html`, `mockups/capture-flow.html`, `mockups/analyzing.html`, `mockups/ugly-states.html` (each mirrors the CODE, not the pre-build spec) |
| **Issue** | #9 (refocused: mockups now document the implemented app) · includes evidence for #26 |

Severity scale: **High** = hurts the demo or a design principle in a visible way ·
**Medium** = spec deviation worth fixing, not demo-blocking · **Low** = polish/debt ·
**Info** = accepted/positive deviation, no action.

---

## 1. Overall verdict

The implemented app is **remarkably faithful** to the design system: token
discipline is intact (semantic aliases consumed via `ThemeExtension`, no
hardcoded colors in widgets), brand-color dosage respects D8 (mint only on
tappables; purple ≤ 2 doses per screen — Home 0, ONB-1 0, ONB-2 1, sheet 0,
confirm 0, analyzing 1, result 2), all UI copy matches the Spanish copy specs
verbatim, and every ugly state offers an actionable exit. No High-severity
findings. The findings below are deviations, most of them defensible, ranked.

## 2. Findings

### F-1 · App-bar wordmark casing is inconsistent — **Medium**

- Confirm screen: `AppBar(title: Text('PiketeMaker'))` (`capture_screen.dart`).
- Result screen: `AppBar(title: Text('PIKETEMAKER'))` (`result_screen.dart`).
- The canonical mockup's kicker renders uppercase (`text-transform: uppercase`
  in `result.html`); Flutter's `AppType.label` style cannot auto-uppercase, so
  the string itself decides — and the two screens disagree.
- **Recommendation:** one shared constant (or a tiny `PkKickerTitle` widget)
  with a single casing. My call as owner of the brand voice: the kicker is a
  system *label* (11px, 0.08em tracking) → uppercase **PIKETEMAKER**
  everywhere it appears in label style. (The mixed-case "PiketeMaker" is
  reserved to the two-color lockup, per LOGO.md.)

### F-2 · ONB-2 BIEN/MAL cards don't show the *why* — **Medium** (evidence for #26)

- Spec (`onboarding-tutorial.md` §2.3): two illustrated miniatures — neutral
  silhouette on a **plain light wall** (BIEN) vs. the same silhouette in a
  **cluttered room** (MAL).
- Implemented (`onboarding_screen.dart` → `_ExampleCard`): both cards render
  the identical `Icons.person` glyph on `surfaceSubtle`; only the frame
  (success 1.5px vs. border 1px) and the ✓/✕ label differ. The visual argument
  — *plain background vs. clutter* — is not actually depicted, so the key
  didactic screen teaches with words only.
- What IS right: no real photos (no body/skin bias ✓), ✕/MAL in textTertiary
  and never in error red ✓ (we don't blame the user), BIEN border in success ✓.
- **Recommendation:** keep the layout; enrich only the card backgrounds — BIEN
  with a flat single-tone backdrop, MAL with 3–4 simple clutter shapes
  (frames/shelf rectangles in neutrals). Pure `CustomPainter` or two tiny
  inline vectors; no assets, no bias. Good candidate for the assets round
  (#31) if not sooner.

### F-3 · E3/E4 primary CTA lands on Confirm, not the source sheet — **Medium** (flagged point c — see §3)

### F-4 · No in-app capture screen with framing guides — **Low** (accepted for demo)

- Spec (`user-flows.md` §4.3): "Capture with guides" — overlay with full-body
  framing + light hint + plain-background hint, so the F13 tip reappears *at
  framing time* even for tutorial-skippers.
- Implemented: the camera is the **system camera app** via `image_picker`
  (no overlay possible). The F13 hint safety net was relocated: source sheet
  (tint band, before opening the camera) + Confirm screen (hint row, after).
- Verdict: acceptable trade-off under D15 (huge scope saved; on Android the
  system camera also avoids needing our own CAMERA permission, making E1
  near-unreachable). The tip still brackets the shot (before + after), which
  preserves most of the de-risking. Debt: when the embedded camera arrives
  (the `PhotoPicker` abstraction already anticipates it), restore the overlay
  hint per spec.

### F-5 · Result CTA stubs speak developer, not Dani — **Low**

- "Ver looks así" / "Súbela a tu story" / harmony rows show snackbars with
  internal voice: *"F5-lite · deep-link (fast-follow)"*, *"F6 · exportar story
  (fast-follow)"*, *"Complementario · F5-lite (fast-follow)"*.
- The skeleton doc §7 left this to the CEO (disabled vs. honest placeholder);
  the implementation chose "enabled + placeholder" but with spec-voice copy.
  In an investor demo this may even help (shows the roadmap), but it breaks
  the copy tone (§4 of the design system) if any outsider taps it.
- **Recommendation:** keep the snackbar, swap copy to user voice:
  **"Muy pronto: looks reales con estos colores."** / **"Muy pronto: tu
  paleta lista para story."** One-line changes.

### F-6 · Ad-slot placeholder copy is spec-voice — **Info** (intentional)

- The slot shows "HUECO REWARDED · F8 · ADMOB" + an explanation of the F8
  design rule. Per D12/skeleton §4 this is deliberate in the demo ("el hueco
  muestra su etiqueta, sin ad real") — it *sells* the monetization slot to
  investors. No action for the demo; obviously replaced when AdMob lands.

### F-7 · Home top-right: tutorial re-entry instead of Settings — **Info** (positive deviation)

- Skeleton §3 sketched a settings gear; `onboarding-tutorial.md` §1.3 parked
  tutorial re-entry inside a future Settings screen. The app has no Settings,
  so `home_screen.dart` puts a `help_outline` icon ("Cómo hacer la foto") that
  re-opens the tutorial. This honors the re-entry requirement with less
  surface. Endorsed; documented in `mockups/home.html`.

### F-8 · Progress honesty cap — **Info** (positive addition)

- Not in any spec: the progress animates easeOutCubic over a nominal 6 s and
  **caps at 96% until the engine actually returns** (`_capWithoutResult`).
  Never shows 100% without a palette. This is perceived-honesty done right;
  I'm adopting it into the canonical spec via `mockups/analyzing.html`.

### F-9 · E2 implemented but unreachable — **Info**

- Correct: the D15 demo is offline; E2 stays dormant in the template for the
  future "Ver looks así" network dependency. No action.

### F-10 · `result.html` drift vs. the app — **Info** (NOT edited, per scope)

Canonical `result.html` now trails the implementation in three places:
1. Analyzing subtext "Separando la ropa del fondo" — obsolete post-D15
   (see §3, point a). `mockups/analyzing.html` supersedes that phone.
2. Result top bar: mockup shows back + kicker; the app uses a standard
   `AppBar` with "PIKETEMAKER" (visually equivalent).
3. Meta date is hardcoded in the mockup; the app renders a live short date
   ("9 jul 2026") without `intl` — fine.
   Recommendation: on the next touch of `result.html`, update the analyzing
   phone's subtext or delete that phone in favor of `analyzing.html`.

## 3. Explicit verdicts on the three points mobile-dev flagged

### (a) Honest pipeline steps replacing "Separando la ropa del fondo" — **VALIDATED**

`Leyendo tu foto` → `Agrupando los colores` → `Montando tus armonías`.

The old subtext promised background removal the D15 MVP doesn't do — showing
it would be lying on the most-watched screen of the app. The new steps are
honest, jargon-free, in second-person tone, and each is genuinely what the
engine is doing. **I approve the copy as-is.** One optional refinement, not a
request: step 3 introduces the word "armonías", which the result screen never
uses (it says "Combina con"). If we ever want perfect vocabulary continuity,
**"Montando tus combinaciones"** matches the result's language. I mildly
prefer keeping **"armonías"** — it's the one credibility word ("there's color
theory behind this") and it's not jargon-without-translation since the result
immediately shows what it means. Ship as-is.

### (b) E1 "Abrir ajustes" guiding via snackbar — **ACCEPTABLE FOR THE DEMO, with one caveat**

Accepted because: (1) on Android E1 is near-unreachable — the system camera
needs no app-side permission, so this path is defensive (iOS/odd OEMs); (2)
the snackbar gives a complete, actionable manual path; (3) the gallery escape
hatch is right below, so nobody is stuck. It does not endanger the demo.

The caveat: a CTA that *says* "Abrir ajustes" and doesn't open settings is a
broken promise the moment a real user hits it. This is fine as **demo debt,
not launch debt**: before any distribution beyond the CEO's phone, either
(i) add `app_settings`/`permission_handler` and make the CTA do what it says
(preferred; keeps spec copy), or (ii) if the plugin stays unapproved, relabel
the primary to **"Cómo activarla"** so copy and behavior match. Do not ship to
strangers with the current mismatch.

### (c) E3/E4 primary landing on Confirm instead of the source sheet — **CHANGE IT (post-demo)**

The spec (user-flows §2) routes "Probar con otra foto" / "Hacer otra foto" to
the **photo source**. The implementation lands on **Confirm, still showing the
photo that just failed**, and the user must tap "Repetir" to actually get a
new one. Two problems: an extra tap on a frustrated user's path, and a
momentary contradiction — the screen asks "¿Se ve bien tu fit?" about a photo
the app just declared unusable. That second point is the real UX smell.

It is **not demo-blocking** (no dead end, and the hero-photo demo rarely hits
E3/E4), so I'm not asking for a pre-demo change. The fix I recommend keeps the
current navigation shape: land on Confirm **and auto-open the source sheet on
arrival** (equivalent to pressing "Repetir" for the user). If they dismiss the
sheet, Confirm-with-old-photo is then a sensible fallback rather than the
first thing they see. E4's secondary ("Elegir de la galería" → picker
directly) is already correct.

## 4. Verification of the implemented tutorial vs. `onboarding-tutorial.md` (evidence for #26)

| Spec item | Status in code |
|---|---|
| 2 screens, not more (ONB-1 Bienvenida + ONB-2 Tip pro) | ✅ `PageView` with exactly 2 pages |
| Skippable from BOTH screens, "Saltar" low hierarchy (caption/textTertiary, top-right, 44px target) | ✅ persistent overlay `_SkipLink` |
| `onboardingSeen` set on complete **and** on skip; never repeats; local only (SharedPreferences), no backend | ✅ `OnboardingServicePrefs`, key `onboardingSeen` |
| "Hacer mi primera foto" → straight to source sheet (warm user shoots); "Saltar" → Home | ✅ pop-with-result pattern; Home chains the sheet |
| Camera permission contextual (no tutorial permission screen); denied → E1 with gallery alternative | ✅ requested at picker use; `photo_flow.dart` routes to E1 |
| ONB-1 copy: "Los colores de tu fit, con criterio." / "Hazte una foto y te digo tu paleta y con qué combina." / "Empezar" / "Saltar" | ✅ verbatim |
| ONB-2 copy: badge "TIP PRO" · "El truco para clavar los colores" · 3 tips · "Cuanto más liso el fondo, mejor te leo los colores." · "Hacer mi primera foto" | ✅ verbatim (incl. tip order, hero = plain wall) |
| ONB-1: zero purple, mint only on CTA, single display, brand lockup discreet | ✅ |
| ONB-2: exactly 1 purple dose (TIP PRO badge, accentTint + accent ink) | ✅ |
| Hero tip visually heavier (first + more weight) | ✅ textPrimary + w600 vs. textSecondary |
| BIEN/MAL: no real photos, ✓ in success / ✕ in textTertiary (never error) | ✅ |
| **BIEN/MAL: illustrated wall-vs-clutter miniatures** | ❌ **NOT implemented** — identical neutral person glyph in both cards; only frame + label differ (finding F-2) |
| Plain-background hint repeated outside the tutorial (safety net for skippers) | ✅* relocated: source-sheet tint band + Confirm hint row (the spec's capture-overlay location doesn't exist — system camera, finding F-4) |
| Re-accessible ("Cómo hacer la foto") | ✅* from Home help icon instead of Settings (Settings doesn't exist; finding F-7, endorsed) |
| 2-dot progress indicator (skeleton §2 hi-fi addition) | ✅ active pill in action mint |
| Background *hue* wording ("de un solo color", absorbing the ux↔backend open box) | ✅ copy unchanged, decision still open (not the app's fault) |

**Verdict for #26: the implementation respects the spec in flow, exits, flag
semantics, copy (verbatim), brand discipline and accessibility targets. The
single material gap is F-2 (the BIEN/MAL cards don't depict the plain-vs-
cluttered comparison).** My recommendation to the PM: close #26 as done, and
carry F-2 as a small follow-up item (fold it into the assets round #31 or a
standalone polish issue) rather than keeping #26 open for one illustration.

## 5. What I need from the CEO / PM

1. **Ratify the three verdicts of §3** — (a) keep the honest steps as-is;
   (b) accept E1 snackbar as demo debt with the pre-distribution condition;
   (c) schedule the E3/E4 auto-open-sheet fix post-demo.
2. **Close #26** per §4, spawning the F-2 illustration as follow-up.
3. **F-1 (wordmark casing):** approve "PIKETEMAKER uppercase wherever it's a
   kicker/label; mixed case only in the two-color lockup" as the rule, so
   mobile-dev can unify in a one-liner.
4. **F-5:** approve the two user-voice "Muy pronto" strings for the result
   stubs (copy provided above) — cheap win before showing the demo around.
