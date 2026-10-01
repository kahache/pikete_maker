import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Global test harness config (gen-l10n-aware suite, all files).
///
/// The default flutter_test surface is 800×600 logical — SHORTER than any real
/// phone in portrait. The app's full-screen layouts (notably the split Home,
/// whose two zones each hold glyph + label + caption + a 44 px pill) are tuned
/// for phone heights; split_home_test already sets a phone surface by hand and
/// documents that 800×600 "leaves the zones too cramped". When #94 item 2 gave
/// the Home blocks more air (divider gap 24 → 48 px, CEO 2026-07-19), that last
/// bit of slack vanished on the 600 px surface and every Home-rendering test
/// tripped an 8.5 px overflow.
///
/// Fix, once, for the whole suite: raise the DEFAULT surface HEIGHT to a
/// realistic portrait figure. Width stays 800 logical (text wrapping unchanged)
/// and the device pixel ratio stays at the flutter_test default 3.0 (pixel-ratio
/// -sensitive checks unaffected) — only vertical logical space grows 600 → 1200.
/// Tests that set their own `tester.view.physicalSize` (e.g. split_home's
/// geometry test at 390×844) run their body AFTER this setUp and override it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    final TestFlutterView view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .implicitView!;
    // 2400×3600 physical ÷ DPR 3.0 = 800×1200 logical.
    view.physicalSize = const Size(2400, 3600);
    addTearDown(view.reset);
  });
  await testMain();
}
