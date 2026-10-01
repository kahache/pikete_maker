import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/core/analytics/analytics_service.dart';
import 'package:piketemaker/core/color_engine/models.dart';
import 'package:piketemaker/features/result/looks_search.dart';
import 'package:piketemaker/features/result/result_screen.dart';
import 'package:piketemaker/theme/app_colors.dart';
import 'package:piketemaker/theme/app_theme.dart';

/// F5 v0 on the OUTFIT result (#82): selectable harmony rows (radio, first
/// pre-selected; selected = action-fill chip with white text), "Ver looks así"
/// deep-links the selection, analytics fire, offline degrades to a SnackBar.

const Color _red = Color(0xFFE02020); // 'rojo'
const Color _teal = Color(0xFF20B2A2); // 'verde azulado'
const Color _cobalt = Color(0xFF2B5CE4); // 'azul'
const Color _emerald = Color(0xFF12A150); // 'verde'
const Color _mustard = Color(0xFFE0A000); // 'naranja'
const Color _raspberry = Color(0xFFD6248C); // 'rosa'

const AnalysisResult _outfit = AnalysisResult(
  baseIndex: 0,
  palette: <ColorSample>[
    ColorSample(color: _red, weight: 0.7),
    ColorSample(color: Color(0xFF808080), weight: 0.3),
  ],
  harmonies: <Harmony>[
    Harmony(
      type: HarmonyType.complementary,
      name: 'Complementario',
      description: 'Contraste máximo, 2 colores',
      colors: <Color>[_red, _teal],
    ),
    Harmony(
      type: HarmonyType.analogous,
      name: 'Análogo',
      description: 'Vecinos de rueda, suave',
      colors: <Color>[_red, _mustard, _raspberry],
    ),
    Harmony(
      type: HarmonyType.triadic,
      name: 'Triádico',
      description: '3 colores, atrevida',
      colors: <Color>[_red, _cobalt, _emerald],
    ),
  ],
);

/// Canvas mode: 100% neutral outfit + the curated pops (D10).
const AnalysisResult _canvasOutfit = AnalysisResult(
  baseIndex: -1,
  palette: <ColorSample>[
    ColorSample(color: Color(0xFF3C3937), weight: 0.6), // → 'negro'
    ColorSample(color: Color(0xFFD0CCC9), weight: 0.4), // → 'blanco'
  ],
  harmonies: <Harmony>[],
  canvasAccents: <Color>[
    Color(0xFFE4322B), // 'rojo'
    Color(0xFF2B5CE4),
    Color(0xFFE0A000),
    Color(0xFF12A150),
    Color(0xFFD6248C),
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
    home: ResultScreen(
      result: result,
      analytics: analytics,
      launchSearch: launcher ?? (Uri url) async => true,
    ),
  ));
  await tester.pumpAndSettle();
}

/// Ink color of a harmony row's name chip: white when selected, textPrimary
/// when not (the CEO's selected-state spec).
Color _nameInk(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

Future<void> _tapRow(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _tapCta(WidgetTester tester) async {
  await tester.tap(find.text('Ver looks así'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('CTA present; the FIRST harmony is pre-selected (radio default)',
      (WidgetTester tester) async {
    await _pump(tester, _outfit);

    expect(find.text('Ver looks así'), findsOneWidget);
    expect(_nameInk(tester, 'Complementario'), AppColors.light.actionOnFill,
        reason: 'default selection: white ink on the action fill');
    expect(_nameInk(tester, 'Análogo'), AppColors.light.textPrimary);
    expect(_nameInk(tester, 'Triádico'), AppColors.light.textPrimary);
  });

  testWidgets('tapping a row moves the selection and fires harmony_selected',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await _pump(tester, _outfit, analytics: analytics);

    await _tapRow(tester, 'Análogo');
    expect(_nameInk(tester, 'Análogo'), AppColors.light.actionOnFill);
    expect(_nameInk(tester, 'Complementario'), AppColors.light.textPrimary);

    final AnalyticsEvent event =
        analytics.named(AnalyticsEvents.harmonySelected).single;
    expect(event.params,
        <String, Object?>{'mode': 'outfit', 'scheme': 'analogous'});

    // Radio behavior: re-tapping the selected row is a no-op (no dupe event).
    await _tapRow(tester, 'Análogo');
    expect(_nameInk(tester, 'Análogo'), AppColors.light.actionOnFill);
    expect(analytics.named(AnalyticsEvents.harmonySelected), hasLength(1));
  });

  testWidgets('CTA deep-links the DEFAULT selection with ES color names',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final List<Uri> launched = <Uri>[];
    await _pump(tester, _outfit, analytics: analytics,
        launcher: (Uri url) async {
      launched.add(url);
      return true;
    });

    await _tapCta(tester);

    final Uri uri = launched.single;
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['tbm'], 'isch');
    expect(uri.queryParameters['q'], 'outfit rojo y verde azulado');

    final AnalyticsEvent event =
        analytics.named(AnalyticsEvents.looksSearchLaunched).single;
    expect(event.params, <String, Object?>{
      'mode': 'outfit',
      'scheme': 'complementary',
      'query': 'outfit rojo y verde azulado',
    });
  });

  testWidgets('CTA follows the selection (triadic → its 3 names)',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    final List<Uri> launched = <Uri>[];
    await _pump(tester, _outfit, analytics: analytics,
        launcher: (Uri url) async {
      launched.add(url);
      return true;
    });

    await _tapRow(tester, 'Triádico');
    await _tapCta(tester);

    expect(launched.single.queryParameters['q'], 'outfit rojo, azul y verde');
    expect(
      analytics.named(AnalyticsEvents.looksSearchLaunched).single.params,
      containsPair('scheme', 'triadic'),
    );
  });

  testWidgets('offline/no-browser: SnackBar, no crash, no launch event',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await _pump(tester, _outfit,
        analytics: analytics, launcher: (Uri url) async => false);

    await _tapCta(tester);

    expect(find.text(kLooksSearchFailedCopy), findsOneWidget);
    expect(analytics.fired(AnalyticsEvents.looksSearchLaunched), isFalse);
  });

  testWidgets('a THROWING launcher degrades the same way (no crash)',
      (WidgetTester tester) async {
    final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
    await _pump(tester, _outfit,
        analytics: analytics,
        launcher: (Uri url) async => throw Exception('no browser'));

    await _tapCta(tester);

    expect(find.text(kLooksSearchFailedCopy), findsOneWidget);
    expect(analytics.fired(AnalyticsEvents.looksSearchLaunched), isFalse);
    expect(tester.takeException(), isNull);
  });

  group('canvas mode (D10)', () {
    Finder accentPop(Color color) => find.byWidgetPredicate((Widget w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color == color);

    testWidgets('default CTA searches the neutral look itself',
        (WidgetTester tester) async {
      final List<Uri> launched = <Uri>[];
      await _pump(tester, _canvasOutfit, launcher: (Uri url) async {
        launched.add(url);
        return true;
      });

      await _tapCta(tester);
      expect(launched.single.queryParameters['q'], 'outfit negro y blanco');
    });

    testWidgets('selecting a pop adds it to the query; re-tap clears it',
        (WidgetTester tester) async {
      final InMemoryAnalyticsService analytics = InMemoryAnalyticsService();
      final List<Uri> launched = <Uri>[];
      await _pump(tester, _canvasOutfit, analytics: analytics,
          launcher: (Uri url) async {
        launched.add(url);
        return true;
      });

      const Color rojo = Color(0xFFE4322B);
      await tester.ensureVisible(accentPop(rojo));
      await tester.tap(accentPop(rojo));
      await tester.pumpAndSettle();

      // Selected state: check mark on the pop; analytics knows WHICH accent.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        analytics.named(AnalyticsEvents.harmonySelected).single.params,
        <String, Object?>{
          'mode': 'outfit',
          'scheme': 'canvas',
          'accent': 'rojo',
        },
      );

      await _tapCta(tester);
      expect(
          launched.single.queryParameters['q'], 'outfit negro, blanco y rojo');
      expect(
        analytics.named(AnalyticsEvents.looksSearchLaunched).single.params,
        containsPair('scheme', 'canvas'),
      );

      // Toggle off: back to the plain neutral query.
      await tester.tap(accentPop(rojo));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsNothing);
      await _tapCta(tester);
      expect(launched.last.queryParameters['q'], 'outfit negro y blanco');
    });
  });
}
