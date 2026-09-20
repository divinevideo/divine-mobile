// ABOUTME: Fire-and-forget async helper for widget lifecycle callbacks
// ABOUTME: Logs every failure, reports the reportable ones, leaks no rejection

import 'dart:async';

import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:unified_logger/unified_logger.dart';

/// Crash reporter used for reportable detached failures after bootstrap.
///
/// The app assigns its configured reporter during startup. The injectable
/// [runDetached] parameter keeps tests independent of this process-global
/// seam.
CrashReporter detachedFailureReporter = const SilentCrashReporter();

/// Runs [operation] without awaiting it, logging any error under [logName]
/// instead of letting it surface as an unhandled Future rejection.
///
/// Intended for `State` lifecycle callbacks (`initState`, `didUpdateWidget`,
/// `dispose`) and event handlers that intentionally don't await their async
/// work — [operation] is still owned, just not correctness-sensitive to the
/// caller's own return.
///
/// [description] names the operation in the log message (e.g. `'load
/// badges'`); [logName] and [category] route the log the same way the
/// caller's other [Log] calls do. [reporter] defaults to the app-wide
/// [detachedFailureReporter] and receives only errors eligible under the
/// project reportability policy.
void runDetached(
  Future<void> operation,
  String description, {
  required String logName,
  required LogCategory category,
  CrashReporter? reporter,
}) {
  // `then<void>` rather than `catchError`: the latter completes a future of
  // [operation]'s reified type, so a `Future<bool>` handed in as
  // `Future<void>` would log the failure and then reject again with
  // "The error handler of Future.catchError must return a value of the
  // future's type" — the unhandled rejection this helper exists to prevent.
  unawaited(
    operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        Log.error(
          'Failed to $description: $error',
          name: logName,
          category: category,
          error: error,
          stackTrace: stackTrace,
        );
        final reportableError = asReportableError(
          error,
          context: 'runDetached $description',
        );
        if (reportableError == null) return;
        unawaited(
          (reporter ?? detachedFailureReporter).recordError(
            reportableError,
            stackTrace,
            reason: sanitizeForCrashReport('runDetached $logName'),
          ),
        );
      },
    ),
  );
}
