import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show immutable;

/// Crash / non-fatal error reporting seam (#4, Phase 2).
///
/// The real backend (Firebase Crashlytics or Sentry) needs a native plugin and
/// a device, so it is NOT wired here — the default is a log-only no-op. Wiring
/// it later is a one-line swap in `app.dart`, exactly like [AnalyticsService].
/// Injected so the error paths (e.g. the analyzing screen's E3 failure) can
/// report without knowing the concrete backend.

/// A recorded non-fatal error, for the in-memory test double.
@immutable
class RecordedError {
  /// Creates a record of [error] with an optional human [reason] tag.
  const RecordedError(this.error, {this.reason});

  /// The error object that was reported.
  final Object error;

  /// Optional human-readable tag describing where it came from.
  final String? reason;
}

/// The crash-reporting seam. Implementations MUST be cheap and never throw.
abstract interface class CrashReporter {
  /// Records a non-fatal error with an optional human [reason] tag.
  void recordError(Object error, StackTrace? stack, {String? reason});

  /// A breadcrumb log line (context that precedes a later error).
  void log(String message);
}

/// Default implementation: logs to the dev console, reports nowhere. Safe as
/// the app-wide default (no plugin, no network).
class LogCrashReporter implements CrashReporter {
  /// Creates the console-logging crash reporter.
  const LogCrashReporter();

  @override
  void recordError(Object error, StackTrace? stack, {String? reason}) {
    developer.log(reason ?? 'non-fatal error',
        name: 'crash', error: error, stackTrace: stack);
  }

  @override
  void log(String message) => developer.log(message, name: 'crash');
}

/// In-memory implementation for tests: records what was reported.
class InMemoryCrashReporter implements CrashReporter {
  /// Every non-fatal recorded so far, in order.
  final List<RecordedError> errors = <RecordedError>[];

  /// Every breadcrumb line logged so far, in order.
  final List<String> breadcrumbs = <String>[];

  @override
  void recordError(Object error, StackTrace? stack, {String? reason}) =>
      errors.add(RecordedError(error, reason: reason));

  @override
  void log(String message) => breadcrumbs.add(message);
}
