import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// i18n access point (D18 extended to 7 locales, 2026-07-15).
///
/// SPANISH IS CANONICAL: `app_es.arb` carries the pre-i18n copy verbatim and
/// is the gen-l10n template. Widgets read copy through [L10nX.l10n], never
/// through `AppLocalizations.of` directly, because of the fallback below.
///
/// Locale resolution is TWO-LAYERED by design:
///  1. `PiketeMakerApp` (app.dart) wires MaterialApp with the delegates and
///     the es-first supported list; production (`main.dart`) follows the
///     DEVICE locale, while the widget-test harness pins es (the flutter
///     tester shell always reports en_US, which would silently flip the
///     copy-pinning suite — the F&F beta regression net — to English).
///  2. [L10nX.l10n] falls back to canonical es when no delegate is installed
///     (widget tests that pump a screen inside a bare MaterialApp keep
///     rendering today's exact Spanish copy without any harness change).
const Locale kCanonicalLocale = Locale('es');

/// Locales the app ships, canonical es FIRST — the order matters: Flutter's
/// default resolution falls back to the first entry when the device locale
/// is unsupported. (The generated `AppLocalizations.supportedLocales` is
/// alphabetical, which would make Catalan the fallback.)
///
/// zh/ko/ja are complete but DRAFT quality (native review pending, see the
/// `@@x-status` header of each ARB and the D18 note in docs/PRD.md).
const List<Locale> kSupportedLocales = <Locale>[
  Locale('es'),
  Locale('en'),
  Locale('ca'),
  Locale('fr'),
  Locale('zh'),
  Locale('ko'),
  Locale('ja'),
];

/// Canonical-Spanish lookup, resolved once. Used as the [L10nX.l10n]
/// fallback and by the ES facades tests pin against (SneakerStrings,
/// kLooksSearchFailedCopy…): a single source of truth — the ARB.
final AppLocalizations esL10n = lookupAppLocalizations(kCanonicalLocale);

extension L10nX on BuildContext {
  /// The active localizations, or canonical es when no delegate is installed
  /// (bare-MaterialApp widget tests). `l10n.localeName` is the app's single
  /// language signal for the non-ARB vocabulary tables (color names, search
  /// query patterns, short dates).
  AppLocalizations get l10n => AppLocalizations.of(this) ?? esL10n;
}
