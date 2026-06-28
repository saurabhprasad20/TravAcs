import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'failure.dart';

/// Central crash/error logging. All methods are **guarded** — if Crashlytics
/// isn't available (e.g. unit tests, init failed) they silently no-op, so error
/// mapping never throws because of logging.
class ErrorReporter {
  const ErrorReporter._();

  /// Log a handled (non-fatal) failure with its raw detail (never user-shown).
  static void reportNonFatal(Failure failure) {
    try {
      if (kDebugMode) {
        debugPrint('[Failure] ${failure.code ?? ''} '
            '${failure.debugDetail ?? failure.message}');
      }
      FirebaseCrashlytics.instance.recordError(
        failure.debugDetail ?? failure.message,
        null,
        reason: '${failure.runtimeType}(${failure.code ?? '-'})',
        fatal: false,
      );
    } catch (_) {
      // Crashlytics unavailable — ignore.
    }
  }

  /// Log an uncaught error/crash.
  static void reportFatal(Object error, StackTrace? stack, {bool fatal = true}) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
    } catch (_) {
      if (kDebugMode) debugPrint('[Uncaught] $error\n$stack');
    }
  }
}
