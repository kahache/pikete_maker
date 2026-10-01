# `lib/` — a tour for first-time readers

PiketeMaker is a Flutter app that analyses a photo of an outfit (or a pair of
sneakers) entirely **on the device** and proposes colour harmonies. Nothing is
uploaded; there is no backend in the analysis path.

Read the layers in this order:

## `core/` — the engine and its seams (no UI here)

| Folder | What it is |
|---|---|
| `color_engine/` | The colour algorithm: palette extraction (K-means in LAB), neutrality, harmony generation, per-garment assembly. This is a **Dart port of the Python `colorlab` package** (`cv_core/`), which is the canonical source of truth; parity is pinned by golden fixtures in `test/`. Change the algorithm in Python first. |
| `segmentation/` | Per-garment segmentation (Phase 2.5): the MediaPipe Selfie Multiclass TFLite model behind a `GarmentSegmenter` seam, plus mask hygiene and the upper/lower split. A whole-photo implementation is the fallback. |
| `telemetry/` | Anonymous usage signals (D33): retention is computed **on-device**; only unlinkable anonymous cards are sent, and only when an endpoint is configured at build time. Empty endpoint = the whole subsystem is a no-op. |
| `analytics/`, `crash/` | Thin instrumentation seams with local, no-network defaults. |
| `onboarding/` | First-run state. |

## `features/` — one folder per screen flow

`home` (split entry: sneakers vs outfit) · `capture` · `analyzing` ·
`result` (outfit) · `sneaker` (product mode) · `story` (the shared 9:16
story + its preview sheet, used by both results) · `onboarding` ·
`settings` · `feedback`.

Each feature owns a screen file plus a `widgets/` folder with the pieces that
screen composes. Screens stay small and declarative; the logic lives in `core/`.

## The rest

- `theme/` — design tokens mapped to `ThemeData` in one place. Colours and
  spacing are never hardcoded in widgets.
- `l10n/` — 7 locales via `gen-l10n`. Spanish (`app_es.arb`) is the canonical
  source; `l10n/gen/` is generated, never edited by hand.
- `routing/` — route names and the navigation map.
- `widgets/` — widgets shared across more than one feature.

## Conventions

- User-facing strings go into `app_es.arb` first — never hardcoded in a widget.
- Magic numbers become named constants at module level.
- Public API in `core/` is documented (`public_member_api_docs` is enforced
  there via a nested `analysis_options.yaml`).
- Any behaviour validated against a real photo has a test.
