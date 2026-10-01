import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/crash/crash_reporter.dart';

/// Entry point of PiketeMaker (on-device demo MVP, D15).
///
/// The app is 100% OFFLINE: not a single network call (the analysis runs
/// on-device).
///
/// i18n (D18 extended): only PRODUCTION follows the device locale — the
/// test harnesses pump [PiketeMakerApp] directly and stay pinned to
/// canonical es (see the flag's doc in app.dart).
///
/// Error safety net (r13, A1): errors that no screen caught — a widget build
/// throwing, an un-awaited future failing — are routed to the SAME local
/// [CrashReporter] seam the screens use. The reporter instance is shared with
/// the app so both paths land in one place. Still no network: the default
/// reporter only logs (crash_reporter.dart).
void main() {
  const CrashReporter crashReporter = LogCrashReporter();
  installGlobalErrorHooks(crashReporter);
  runApp(const PiketeMakerApp(
    followDeviceLocale: true,
    crashReporter: crashReporter,
  ));
}

/// Routes every uncaught error to [reporter].
///
///  - [FlutterError.onError]: errors the framework catches itself (build,
///    layout, paint, gesture callbacks). The previous handler is chained so
///    the red/grey error widget and the debug console dump keep working.
///  - [PlatformDispatcher.onError]: errors that escape every zone — typically
///    an un-awaited future that throws. Returning `true` marks them handled
///    (they were recorded); the app keeps running, as it would anyway.
///
/// [dispatcher] exists only so tests can target a dispatcher they restore.
@visibleForTesting
void installGlobalErrorHooks(
  CrashReporter reporter, {
  PlatformDispatcher? dispatcher,
}) {
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    reporter.recordError(details.exception, details.stack,
        reason: 'uncaught framework error');
    previous?.call(details);
  };
  (dispatcher ?? PlatformDispatcher.instance).onError =
      (Object error, StackTrace stack) {
    reporter.recordError(error, stack, reason: 'uncaught async error');
    return true;
  };
}
