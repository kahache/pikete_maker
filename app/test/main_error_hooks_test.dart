import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piketemaker/core/crash/crash_reporter.dart';
import 'package:piketemaker/main.dart';

/// r13 A1: the global safety net in `main.dart` routes errors no screen
/// caught to the local [CrashReporter] seam (no network), and keeps the
/// framework's own error presentation chained.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterExceptionHandler? savedFlutterHandler;
  late ErrorCallback? savedDispatcherHandler;

  setUp(() {
    savedFlutterHandler = FlutterError.onError;
    savedDispatcherHandler = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = savedFlutterHandler;
    PlatformDispatcher.instance.onError = savedDispatcherHandler;
  });

  test('framework errors are recorded AND still reach the previous handler',
      () {
    final List<FlutterErrorDetails> presented = <FlutterErrorDetails>[];
    FlutterError.onError = presented.add;
    final InMemoryCrashReporter reporter = InMemoryCrashReporter();

    installGlobalErrorHooks(reporter);
    final StateError boom = StateError('build blew up');
    FlutterError.onError!(FlutterErrorDetails(
      exception: boom,
      stack: StackTrace.current,
    ));

    expect(reporter.errors.single.error, same(boom));
    expect(reporter.errors.single.reason, 'uncaught framework error');
    expect(presented.single.exception, same(boom),
        reason: 'the error widget / console dump keep working');
  });

  test('uncaught async errors are recorded and marked handled', () {
    final InMemoryCrashReporter reporter = InMemoryCrashReporter();

    installGlobalErrorHooks(reporter);
    final ArgumentError boom = ArgumentError('un-awaited future failed');
    final bool handled =
        PlatformDispatcher.instance.onError!(boom, StackTrace.current);

    expect(handled, isTrue);
    expect(reporter.errors.single.error, same(boom));
    expect(reporter.errors.single.reason, 'uncaught async error');
  });
}
