import 'dart:ui' show Color;

import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../core/color_engine/display.dart';
import '../../core/color_engine/models.dart';
import '../sneaker/color_names.dart';

/// F5-lite "Ver looks así" (issue #82, F5 v0 per D3/D12): the harmony/combi
/// SELECTED on a result screen becomes a pre-written Google Images search
/// opened in the system browser.
///
/// Legal guardrail (committed decision #3): deep-link ONLY — the app never
/// embeds third-party result images (EU copyright risk). Product guardrail
/// (CEO, #82): the query uses COLOR NAMES, never hexes — nobody tags photos
/// "#2E9E86"; "outfit verde azulado y rojo" actually finds looks. Names are
/// read AFTER the display snap (D31-A) so a diluted black is searched as
/// "negro", exactly what the result screen calls it.
///
/// i18n (D18 extended): the query is built in the ACTIVE locale — its color
/// vocabulary (color_names.dart) AND a locale-appropriate pattern (below).
/// The default language stays canonical es so every pre-i18n call site and
/// test keeps producing byte-identical queries.
///
/// Everything here except [launchLooksSearch] is PURE (unit-testable without
/// the plugin); the result screens take a [LooksSearchLauncher] so widget
/// tests inject a fake and capture the URL.

/// Signature of the deep-link launcher the result screens depend on.
/// Production default: [launchLooksSearch]. Must return false (or throw) when
/// no browser can take the URL — the screens degrade to a SnackBar.
typedef LooksSearchLauncher = Future<bool> Function(Uri url);

/// Graceful-failure copy (offline / no browser installed): a SnackBar, never
/// a crash. The app itself stays 100% offline (D15); only this CTA needs net.
/// Kept as the canonical-es constant the pre-i18n tests pin; the screens
/// render `l10n.looksSearchFailed` (es value identical, single ARB source).
const String kLooksSearchFailedCopy =
    'No se ha podido abrir el navegador. Revisa tu conexión y prueba otra vez.';

/// Cap of color names per query: beyond 3 the search dilutes into noise (the
/// canvas-mode accent set alone would be 5 names).
const int kLooksQueryMaxNames = 3;

/// How a locale phrases the looks query. Two shapes exist:
///  - Latin markets: `<lead> a, b <joiner> c` — a noun up front plus a listed
///    tail ("outfit rojo, negro y crema" / "outfit black, white and red").
///    "outfit" IS the streetwear word in es/en/ca/fr alike (growth can A/B a
///    local noun later).
///  - CJK markets: space-separated color words with the coordination noun
///    LAST — the natural search ordering ("黒 白 コーデ", "검정 흰색 코디",
///    "黑色 白色 穿搭"), never a literal calque of the Latin pattern.
class LooksQueryPattern {
  const LooksQueryPattern({
    required this.lead,
    required this.leadLast,
    this.finalJoiner,
  });

  /// The coordination noun ("outfit", "コーデ"…).
  final String lead;

  /// False → lead first (Latin). True → lead last (CJK ordering).
  final bool leadLast;

  /// Word between the last two names ("y", "and", "i", "et"); null → all
  /// names joined by single spaces (CJK).
  final String? finalJoiner;
}

/// Pattern table, keyed by language subtag; unknown languages fall back to
/// canonical es (same rule as the color vocabulary).
const Map<String, LooksQueryPattern> _queryPatterns =
    <String, LooksQueryPattern>{
  'es': LooksQueryPattern(lead: 'outfit', leadLast: false, finalJoiner: 'y'),
  'en': LooksQueryPattern(lead: 'outfit', leadLast: false, finalJoiner: 'and'),
  'ca': LooksQueryPattern(lead: 'outfit', leadLast: false, finalJoiner: 'i'),
  'fr': LooksQueryPattern(lead: 'outfit', leadLast: false, finalJoiner: 'et'),
  'zh': LooksQueryPattern(lead: '穿搭', leadLast: true),
  'ko': LooksQueryPattern(lead: '코디', leadLast: true),
  'ja': LooksQueryPattern(lead: 'コーデ', leadLast: true),
};

/// Analytics id of a scheme, shared by `harmony_selected` and
/// `looks_search_launched` so the funnel joins on the same value.
String harmonySchemeId(HarmonyType type) => switch (type) {
      HarmonyType.complementary => 'complementary',
      HarmonyType.analogous => 'analogous',
      HarmonyType.triadic => 'triadic',
      HarmonyType.splitComplementary => 'split_complementary',
    };

/// The pre-written query for [colors]: display snap (D31-A) → localized name
/// → [looksSearchQueryFromNames]. Pure. [language] is a `l10n.localeName`
/// value; the default keeps every pre-i18n call byte-identical (es).
String looksSearchQuery(List<Color> colors, {String language = 'es'}) =>
    looksSearchQueryFromNames(
      <String>[
        for (final Color color in colors)
          localizedColorName(snapColorForDisplay(color), language),
      ],
      language: language,
    );

/// Same, from already-resolved localized names — the sneaker hero combo names
/// its suggested neutral itself ("crema": display copy the namer cannot
/// reproduce). Hyphenated names become searchable words ("verde-azulado" →
/// "verde azulado"), duplicates collapse preserving order (a snapped black
/// shoe on a black floor must read "outfit negro", not "negro y negro"), and
/// the list caps at [kLooksQueryMaxNames]. Pure.
String looksSearchQueryFromNames(List<String> rawNames,
    {String language = 'es'}) {
  final LooksQueryPattern pattern =
      _queryPatterns[languageSubtag(language)] ?? _queryPatterns['es']!;
  final List<String> names = <String>[];
  for (final String raw in rawNames) {
    final String name = raw.replaceAll('-', ' ');
    if (!names.contains(name)) names.add(name);
    if (names.length == kLooksQueryMaxNames) break;
  }
  if (names.isEmpty) return pattern.lead;
  final String list;
  if (pattern.finalJoiner == null || names.length == 1) {
    list = names.join(' ');
  } else {
    final String head = names.sublist(0, names.length - 1).join(', ');
    list = '$head ${pattern.finalJoiner} ${names.last}';
  }
  return pattern.leadLast ? '$list ${pattern.lead}' : '${pattern.lead} $list';
}

/// Google Images URL for [query] (the deep-link target). Pure.
Uri looksSearchUri(String query) => Uri.https(
    'www.google.com', '/search', <String, String>{'q': query, 'tbm': 'isch'});

/// Production launcher: the SYSTEM browser (external application), never an
/// in-app webview (decision #3). Returns false when nothing can take the URL.
Future<bool> launchLooksSearch(Uri url) => url_launcher.launchUrl(url,
    mode: url_launcher.LaunchMode.externalApplication);
