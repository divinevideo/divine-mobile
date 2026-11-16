// ABOUTME: Times fixed startup boundaries without recording keys or user data.
// ABOUTME: Preserves operation results and errors for the owning recovery flow.

import 'dart:async';

import 'package:unified_logger/unified_logger.dart';

/// Fixed labels for operations that can hold up startup or account restoration.
enum StartupStage {
  databaseRuntime,
  databaseKey,
  databaseMigration,
  databaseProbe,
  databaseOpen,
  accountRestore,
  accountCleanup,
  legacyRowClaim,
}

/// Records a stage even on failure, without logging its value or exception.
Future<T> traceStartupStage<T>(
  StartupStage stage,
  FutureOr<T> Function() operation,
) async {
  final watch = Stopwatch()..start();
  var succeeded = false;
  Log.info(
    '${stage.name} started',
    name: 'StartupTiming',
    category: LogCategory.system,
  );
  try {
    final result = await operation();
    succeeded = true;
    return result;
  } finally {
    watch.stop();
    Log.info(
      '${stage.name} completed in ${watch.elapsedMilliseconds}ms '
      'outcome=${succeeded ? 'success' : 'failure'}',
      name: 'StartupTiming',
      category: LogCategory.system,
    );
  }
}
