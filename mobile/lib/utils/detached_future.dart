// ABOUTME: Fire-and-forget async helper for widget lifecycle callbacks
// ABOUTME: Logs a failure instead of leaving it an unhandled Future rejection

import 'dart:async';

import 'package:unified_logger/unified_logger.dart';

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
/// caller's other [Log] calls do.
void runDetached(
  Future<void> operation,
  String description, {
  required String logName,
  required LogCategory category,
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
          stackTrace: stackTrace,
        );
      },
    ),
  );
}
