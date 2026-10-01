import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/result/looks_search.dart';
import 'package:piketemaker/features/sneaker/sneaker_result_screen.dart';
import 'package:piketemaker/features/sneaker/sneaker_strings.dart';
import 'package:piketemaker/theme/app_colors.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// F5 v0 on the SNEAKER result (#82): the hero combo is the default
/// selection, "Otras combis" rows toggle (select / re-tap back to the hero),
/// and "Enséñame otros piketes" deep-links the selection with ES color names
/// — including the hero's own "crema"/"negro" neutral.

const Color _red = Color(0xFFE02020); // 'rojo' (dark → hero neutral = crema)
const Color _teal = Color(0xFF20B2A2); // 'verde azulado'
const Color _cobalt = Color(0xFF2B5CE4); // 'azul'
const Color _emerald = Color(0xFF12A150); // 'verde'
const Color _mustard = Color(0xFFE0A000); // 'naranja'
const Color _raspberry = Color(0xFFD6248C); // 'rosa'

const AnalysisResult _kicks = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _red, weight: 0.7),
    ColorSample(color: Color(0xFF808080), weight: 0.3),
  ],
  harmonies: <Harmony>[
    Harmony(
      type: HarmonyType.complementary,
      name: 'Complementario',
      description: 'Contraste máximo',
      colors: <Color>[_red, _teal],
    ),
    Harmony(
      type: HarmonyType.analogous,
      name: 'Análogo',
      description: 'Vecinos',
      colors: <Color>[_red, _mustard, _raspberry],
    ),
    Harmony(
      type: HarmonyType.triadic,
      name: 'Triádico',
      description: '3 colores',
      colors: <Color>[_red, _cobalt, _emerald],
    ),
    Harmony(
      type: HarmonyType.splitComplementary,
      name: 'Split',
      description: 'Punch',
      colors: <Color>[_red, _teal, _cobalt],
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  AnalysisResult result, {
  InMemoryAnalyticsService? analytics,
  LooksSearchLauncher? launcher,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: SneakerResultScreen(
      args: SneakerResultArgs(result: result, photo: Uint8List(0)),
      analytics: analytics,
      launchSearch: launcher ?? (Uri url) async => true,
    ),
  ));
  await tester.pumpAndSettle();
}

Color _nameInk(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

Future<void> _tapRow(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _tapCta(WidgetTester tester) async {
  await tester.ensureVisible(find.text(SneakerStrings.resultCtaPrimary));
  await tester.tap(find.text(SneakerStrings.resultCtaPrimary));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'default: no row selected (hero combo is the selection); CTA present',
      (WidgetTester tester) async {
    await _pump(tester, _kicks);

    expect(find.text(SneakerStrings.resultCtaPrimary), findsOneWidget);
    expect(_nameInk(tester, SneakerStrings.harmonyAnalogousName),
        AppColors.light.textPrimary);
    expect(_nameInk(tester, SneakerStrings.harmonyTriadicName),
        AppColors.light.textPrimary);
    expect(_nameInk(tester, SneakerStrings.harmonySplitCompName),
        AppColors.light.textPrimary);
  });

  testWidgets('default CTA deep-links the HERO combo, "crema" included',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final List<Uri> launched = <Uri>[];
    await _pump(tester, _kicks, analytics: analytics,
        launcher: (Uri url) async {
      launched.add(url);
      return true;
    });

    await _tapCta(tester);

    final Uri uri = launched.single;
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['tbm'], 'isch');
    // Hero trio = base + complement + suggested neutral, the caption's names.
    expect(uri.queryParameters['q'], 'outfit rojo, verde azulado y crema');
    expect(
      analytics.named(AnalyticsEvents.looksSearchLaunched).single.params,
      <String, Object?>{
        'mode': 'sneaker',
        'scheme': 'complementary',
        'query': 'outfit rojo, verde azulado y crema',
      },
    );
  });

  testWidgets(
      'selecting an "Otras combis" row re-targets the CTA; re-tap toggles back',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final List<Uri> launched = <Uri>[];
    await _pump(tester, _kicks, analytics: analytics,
        launcher: (Uri url) async {
      launched.add(url);
      return true;
    });

    // Select "Equilibrada" (triadic): action-fill chip, white ink.
    await _tapRow(tester, SneakerStrings.harmonyTriadicName);
    expect(_nameInk(tester, SneakerStrings.harmonyTriadicName),
        AppColors.light.actionOnFill);
    expect(
      analytics.named(AnalyticsEvents.harmonySelected).single.params,
      <String, Object?>{'mode': 'sneaker', 'scheme': 'triadic'},
    );

    await _tapCta(tester);
    expect(launched.single.queryParameters['q'], 'outfit rojo, azul y verde');
    expect(
      analytics.named(AnalyticsEvents.looksSearchLaunched).single.params,
      containsPair('scheme', 'triadic'),
    );

    // Toggle off: back to the hero combo.
    await _tapRow(tester, SneakerStrings.harmonyTriadicName);
    expect(_nameInk(tester, SneakerStrings.harmonyTriadicName),
        AppColors.light.textPrimary);
    expect(
      analytics.named(AnalyticsEvents.harmonySelected).last.params,
      containsPair('scheme', 'complementary'),
      reason: 'deselecting lands back on the hero',
    );

    await _tapCta(tester);
    expect(launched.last.queryParameters['q'],
        'outfit rojo, verde azulado y crema');
  });

  testWidgets('offline/no-browser: SnackBar, no crash, no launch event',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await _pump(tester, _kicks,
        analytics: analytics, launcher: (Uri url) async => false);

    await _tapCta(tester);

    expect(find.text(kLooksSearchFailedCopy), findsOneWidget);
    expect(analytics.fired(AnalyticsEvents.looksSearchLaunched), isFalse);
    expect(tester.takeException(), isNull);
  });
}
