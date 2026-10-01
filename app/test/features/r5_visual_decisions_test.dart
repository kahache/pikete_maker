import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piketemaker/app.dart';
import 'package:piketemaker/core/onboarding/onboarding_service.dart';
import 'package:piketemaker/features/capture/photo_picker.dart';
import 'package:piketemaker/features/onboarding/onboarding_screen.dart';
import 'package:piketemaker/theme/app_theme.dart';
import 'package:piketemaker/widgets/logo_mark.dart';

/// Picker that always cancels: these tests never leave Home/tutorial.
class _CancellingPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async => null;
}

/// App under test (no native plugins). The engine default is never reached.
PiketeMakerApp _app({OnboardingService? onboarding}) {
  return PiketeMakerApp(
    onboarding: onboarding ?? OnboardingServiceInMemory(),
    picker: _CancellingPicker(),
  );
}

Future<OnboardingService> _alreadySeen() async {
  final OnboardingServiceInMemory s = OnboardingServiceInMemory();
  await s.markSeen();
  return s;
}

/// Effective bold-ness of tutorial phrase [i] in animated mode: the target
/// style of its [AnimatedDefaultTextStyle] (set synchronously when the
/// highlight moves; the 200 ms transition eases the rendering towards it).
FontWeight _tipTargetWeight(WidgetTester tester, int i) {
  final AnimatedDefaultTextStyle w = tester.widget<AnimatedDefaultTextStyle>(
    find.byKey(OnboardingScreen.tipTextKey(i)),
  );
  return w.style.fontWeight!;
}

void _expectOnlyActive(WidgetTester tester, int active) {
  for (int i = 0; i < 3; i++) {
    expect(
      _tipTargetWeight(tester, i),
      i == active ? FontWeight.w600 : FontWeight.w400,
      reason: 'frase $i con la frase $active activa',
    );
  }
}

/// Drives the app to ONB-2 (the pro-tip page with the 3 phrases).
Future<void> _pumpToProTip(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle(); // first launch → tutorial opens on ONB-1
  await tester.tap(find.text('Empezar'));
  await tester.pumpAndSettle();
  expect(find.text('TIP PRO'), findsOneWidget);
}

void main() {
  group('#51 · brand presence (r5 sheet, CEO picks H2 + E3)', () {
    testWidgets(
        'Home (D26 split): the 120 px hero is gone, top lockup unchanged',
        (WidgetTester tester) async {
      await tester.pumpWidget(_app(onboarding: await _alreadySeen()));
      await tester.pumpAndSettle();

      // D26 Variant A sheds the #58a hero by design ("the two zones ARE the
      // screen"): the only mark left is the one inside the small top lockup.
      expect(find.byType(LogoLockup), findsOneWidget);
      expect(tester.widget<LogoLockup>(find.byType(LogoLockup)).height, 24);
      expect(find.byType(LogoMark), findsOneWidget); // the lockup's own mark
    });

    testWidgets(
        'Empezar (ONB-1): symbol 128 px + wordmark stacked below (#58b)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle(); // first launch → ONB-1

      final Finder symbol = find.byKey(OnboardingScreen.brandSymbolKey);
      final Finder wordmark = find.byKey(OnboardingScreen.brandWordmarkKey);
      expect(symbol, findsOneWidget);
      expect(wordmark, findsOneWidget);
      expect(tester.widget<LogoMark>(symbol).size, 128);

      // Stacked: the wordmark sits BELOW the symbol, both centered.
      expect(
        tester.getTopLeft(wordmark).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(symbol).dy),
      );
      expect(
        tester.getCenter(wordmark).dx,
        moreOrLessEquals(tester.getCenter(symbol).dx, epsilon: 1),
      );

      // E3 replaces the small horizontal lockup on ONB-1.
      expect(find.byType(LogoLockup), findsNothing);
      // The headline stays the text hero.
      expect(find.textContaining('Los colores de tu fit'), findsOneWidget);
    });
  });

  group('#53 · tutorial highlight (option b, IN LOOP)', () {
    testWidgets('the highlight walks phrase by phrase and LOOPS back to 1',
        (WidgetTester tester) async {
      await _pumpToProTip(tester);

      // t=0: phrase 1 lit, the others regular.
      _expectOnlyActive(tester, 0);

      // ~2 s per phrase. 2.1 s pumps absorb the page-transition offset
      // without ever drifting across an extra 2 s boundary.
      await tester.pump(const Duration(milliseconds: 2100));
      _expectOnlyActive(tester, 1);

      await tester.pump(const Duration(milliseconds: 2100));
      _expectOnlyActive(tester, 2);

      // The CEO addition: it does not stop — back to phrase 1 and onwards.
      await tester.pump(const Duration(milliseconds: 2100));
      _expectOnlyActive(tester, 0);
      await tester.pump(const Duration(milliseconds: 2100));
      _expectOnlyActive(tester, 1);

      // Leaving the screen disposes the ticker (no pending timers).
      await tester.tap(find.text('Saltar'));
      await tester.pumpAndSettle();
      expect(find.text('TIP PRO'), findsNothing);
    });

    testWidgets('reduced motion: option (a) — all phrases bold, static',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: OnboardingScreen(onboarding: OnboardingServiceInMemory()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      expect(find.text('TIP PRO'), findsOneWidget);

      void expectAllBoldStatic() {
        for (int i = 0; i < 3; i++) {
          // Plain Text (no AnimatedDefaultTextStyle) with explicit bold.
          final Text t =
              tester.widget<Text>(find.byKey(OnboardingScreen.tipTextKey(i)));
          expect(t.style!.fontWeight, FontWeight.w600,
              reason: 'frase $i en negrita');
        }
      }

      expectAllBoldStatic();

      // No ticker: nothing changes over a full would-be cycle.
      await tester.pump(const Duration(seconds: 7));
      expectAllBoldStatic();
    });
  });
}
