import 'dart:math' as math;
import 'dart:ui' show Color;

import '../../core/color_engine/harmony.dart' show isNeutral, rgbToHsv;
import '../../core/color_engine/palette.dart' show srgbToLab;

/// Localized color naming for user-facing copy (sneaker caption/badge, the
/// #82 "Ver looks así" search queries) — i18n round, D18 extended 2026-07-15.
///
/// NOTE (spec deviation, flagged): the spec says the names come from "the
/// engine's existing ES color-naming map", but no such map exists in the
/// engine (only code comments name the canvas accents). This is that map,
/// built UI-side on the engine's own primitives (chroma-based neutrality #22,
/// colorsys-parity HSV) so naming can never disagree with the engine about
/// what is neutral. It deliberately does NOT touch engine semantics.
///
/// The namer's OUTPUT SET is finite ([ColorTerm]), so localization is a
/// per-locale vocabulary TABLE, not free translation. Accuracy over flavor:
/// these must be the correct native color terms (this is not slang — a teal
/// searched as the wrong word finds the wrong looks). Locale selection keys
/// off the language code from `context.l10n.localeName`; unknown languages
/// fall back to canonical es.
///
/// TELEMETRY STAYS ES: analytics events keep logging [spanishColorName] so
/// the G2/G2S funnels join on one stable vocabulary across markets.

/// The finite set of names the namer can produce: 8 hue buckets + brown
/// (BACKLOG E7) + 4 neutrals.
enum ColorTerm {
  rojo,
  naranja,
  amarillo,
  verde,
  verdeAzulado,
  azul,
  morado,
  rosa,
  marron,
  negro,
  blanco,
  crema,
  gris,
}

/// Hue buckets in degrees: a color whose hue is below the bound (and at/above
/// the previous one) gets the term. Coarse on purpose — copy, not science.
/// The teal bucket is centered so the spec's own example holds:
/// #2E9E86 (h≈167°) → verdeAzulado ("verde-azulado").
const List<(double, ColorTerm)> _hueTerms = <(double, ColorTerm)>[
  (15, ColorTerm.rojo),
  (45, ColorTerm.naranja),
  (70, ColorTerm.amarillo),
  (150, ColorTerm.verde),
  (195, ColorTerm.verdeAzulado),
  (255, ColorTerm.azul),
  (290, ColorTerm.morado),
  (345, ColorTerm.rosa),
  (360, ColorTerm.rojo),
];

/// BROWN (BACKLOG E7, 2026-10-01): a warm hue (the naranja + amarillo
/// buckets, [_brownHueMin]..[_brownHueMax) degrees) that is DARK (HSV value
/// below [_brownMaxValue]) or MUTED AND MID-DARK (LAB chroma below
/// [_brownMaxChroma] with L* below [_brownMaxL]) reads as brown — khaki,
/// tobacco, camel-in-shadow — not as orange/yellow. Before E7 the recolor
/// kicker called the khaki partner #8C7453 "naranja" (r18 emulator pass).
/// Light and saturated warm colours are untouched: a clear orange stays
/// naranja, a light mustard stays as before, and the neutrals (crema…) keep
/// their own rule above (they never reach the hue buckets).
const double _brownHueMin = 15;
const double _brownHueMax = 70;
const double _brownMaxValue = 0.6;
const double _brownMaxChroma = 30;
const double _brownMaxL = 60;

/// LAB L* bounds for the neutral terms.
const double _blackMaxL = 25;
const double _whiteMinL = 88;

/// A warm-leaning light neutral reads as "crema", not "gris": minimum LAB b*
/// (warmth) and L* (lightness).
const double _cremaMinB = 5;
const double _cremaMinL = 65;

/// Per-locale vocabulary. Hyphens mark compound names that the search-query
/// builder flattens to spaces ("verde-azulado" → "verde azulado"). The es
/// column is the pre-i18n map VERBATIM (byte-identical guarantee); fr uses
/// "bleu canard" for teal (the natural French fashion term) and ja keeps
/// katakana where that is what people actually search (オレンジ, ピンク…).
const Map<String, Map<ColorTerm, String>> _vocabulary =
    <String, Map<ColorTerm, String>>{
  'es': <ColorTerm, String>{
    ColorTerm.rojo: 'rojo',
    ColorTerm.naranja: 'naranja',
    ColorTerm.amarillo: 'amarillo',
    ColorTerm.verde: 'verde',
    ColorTerm.verdeAzulado: 'verde-azulado',
    ColorTerm.azul: 'azul',
    ColorTerm.morado: 'morado',
    ColorTerm.rosa: 'rosa',
    ColorTerm.marron: 'marrón',
    ColorTerm.negro: 'negro',
    ColorTerm.blanco: 'blanco',
    ColorTerm.crema: 'crema',
    ColorTerm.gris: 'gris',
  },
  'en': <ColorTerm, String>{
    ColorTerm.rojo: 'red',
    ColorTerm.naranja: 'orange',
    ColorTerm.amarillo: 'yellow',
    ColorTerm.verde: 'green',
    ColorTerm.verdeAzulado: 'teal',
    ColorTerm.azul: 'blue',
    ColorTerm.morado: 'purple',
    ColorTerm.rosa: 'pink',
    ColorTerm.marron: 'brown',
    ColorTerm.negro: 'black',
    ColorTerm.blanco: 'white',
    ColorTerm.crema: 'cream',
    ColorTerm.gris: 'gray',
  },
  'ca': <ColorTerm, String>{
    ColorTerm.rojo: 'vermell',
    ColorTerm.naranja: 'taronja',
    ColorTerm.amarillo: 'groc',
    ColorTerm.verde: 'verd',
    ColorTerm.verdeAzulado: 'verd blavós',
    ColorTerm.azul: 'blau',
    ColorTerm.morado: 'morat',
    ColorTerm.rosa: 'rosa',
    ColorTerm.marron: 'marró',
    ColorTerm.negro: 'negre',
    ColorTerm.blanco: 'blanc',
    ColorTerm.crema: 'crema',
    ColorTerm.gris: 'gris',
  },
  'fr': <ColorTerm, String>{
    ColorTerm.rojo: 'rouge',
    ColorTerm.naranja: 'orange',
    ColorTerm.amarillo: 'jaune',
    ColorTerm.verde: 'vert',
    ColorTerm.verdeAzulado: 'bleu canard',
    ColorTerm.azul: 'bleu',
    ColorTerm.morado: 'violet',
    ColorTerm.rosa: 'rose',
    ColorTerm.marron: 'marron',
    ColorTerm.negro: 'noir',
    ColorTerm.blanco: 'blanc',
    ColorTerm.crema: 'crème',
    ColorTerm.gris: 'gris',
  },
  // DRAFT (native review pending, same gate as the ARB — D18 amendment).
  'zh': <ColorTerm, String>{
    ColorTerm.rojo: '红色',
    ColorTerm.naranja: '橙色',
    ColorTerm.amarillo: '黄色',
    ColorTerm.verde: '绿色',
    ColorTerm.verdeAzulado: '蓝绿色',
    ColorTerm.azul: '蓝色',
    ColorTerm.morado: '紫色',
    ColorTerm.rosa: '粉色',
    ColorTerm.marron: '棕色',
    ColorTerm.negro: '黑色',
    ColorTerm.blanco: '白色',
    ColorTerm.crema: '米色',
    ColorTerm.gris: '灰色',
  },
  // DRAFT (native review pending).
  'ko': <ColorTerm, String>{
    ColorTerm.rojo: '빨강',
    ColorTerm.naranja: '주황',
    ColorTerm.amarillo: '노랑',
    ColorTerm.verde: '초록',
    ColorTerm.verdeAzulado: '청록',
    ColorTerm.azul: '파랑',
    ColorTerm.morado: '보라',
    ColorTerm.rosa: '분홍',
    ColorTerm.marron: '갈색',
    ColorTerm.negro: '검정',
    ColorTerm.blanco: '흰색',
    ColorTerm.crema: '크림색',
    ColorTerm.gris: '회색',
  },
  // DRAFT (native review pending).
  'ja': <ColorTerm, String>{
    ColorTerm.rojo: '赤',
    ColorTerm.naranja: 'オレンジ',
    ColorTerm.amarillo: '黄色',
    ColorTerm.verde: '緑',
    ColorTerm.verdeAzulado: '青緑',
    ColorTerm.azul: '青',
    ColorTerm.morado: '紫',
    ColorTerm.rosa: 'ピンク',
    ColorTerm.marron: 'ブラウン',
    ColorTerm.negro: '黒',
    ColorTerm.blanco: '白',
    ColorTerm.crema: 'クリーム',
    ColorTerm.gris: 'グレー',
  },
};

/// The [ColorTerm] of [color]. Deterministic; total (every color gets one).
/// The pre-i18n classification logic, with ONE addition: the brown rule
/// (BACKLOG E7) carved out of the warm hue buckets.
ColorTerm colorTermOf(Color color) {
  final List<int> rgb = <int>[
    (color.r * 255.0).round().clamp(0, 255),
    (color.g * 255.0).round().clamp(0, 255),
    (color.b * 255.0).round().clamp(0, 255),
  ];
  if (isNeutral(rgb)) {
    final List<double> lab = srgbToLab(
        <double>[rgb[0].toDouble(), rgb[1].toDouble(), rgb[2].toDouble()]);
    final double l = lab[0];
    final double b = lab[2];
    if (l < _blackMaxL) return ColorTerm.negro;
    if (l >= _whiteMinL) return ColorTerm.blanco;
    if (b >= _cremaMinB && l >= _cremaMinL) return ColorTerm.crema;
    return ColorTerm.gris;
  }
  final (double h, _, double v) = rgbToHsv(rgb);
  final double deg = h * 360.0;
  if (deg >= _brownHueMin && deg < _brownHueMax) {
    final List<double> lab = srgbToLab(
        <double>[rgb[0].toDouble(), rgb[1].toDouble(), rgb[2].toDouble()]);
    final double chroma = math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
    if (v < _brownMaxValue ||
        (chroma < _brownMaxChroma && lab[0] < _brownMaxL)) {
      return ColorTerm.marron;
    }
  }
  for (final (double bound, ColorTerm term) in _hueTerms) {
    if (deg < bound) return term;
  }
  return ColorTerm.rojo; // deg == 360 wraps to red
}

/// The native word for [term] in [language] (a `localeName` language code);
/// unknown languages fall back to canonical es.
String colorTermName(ColorTerm term, String language) =>
    (_vocabulary[_languageOf(language)] ?? _vocabulary['es']!)[term]!;

/// The localized name of [color] for user-facing copy and search queries.
String localizedColorName(Color color, String language) =>
    colorTermName(colorTermOf(color), language);

/// The ES name of [color] ("rojo", "verde-azulado", "crema"…). Kept as the
/// canonical shortcut: ANALYTICS keeps logging ES names (stable funnel
/// vocabulary across markets) and the pre-i18n tests pin these outputs.
String spanishColorName(Color color) => localizedColorName(color, 'es');

/// `localeName` can be "zh_Hans_CN" style — keep only the language subtag.
/// Public: the search-query patterns (looks_search.dart) and the localized
/// short date (result_blocks.dart) key off the same subtag.
String languageSubtag(String localeName) => _languageOf(localeName);

String _languageOf(String localeName) {
  final int sep = localeName.indexOf(RegExp('[_-]'));
  return sep == -1 ? localeName : localeName.substring(0, sep);
}
