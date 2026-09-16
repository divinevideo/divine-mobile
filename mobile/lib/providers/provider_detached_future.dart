// ABOUTME: Observes intentionally detached provider lifecycle futures.
// ABOUTME: Routes asynchronous failures through the shared application logger.

import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Runs provider-owned asynchronous work without blocking synchronous builds.
void runProviderDetached(
  Future<void> operation,
  String description, {
  required String logName,
}) {
  runDetached(
    operation,
    description,
    logName: logName,
    category: LogCategory.system,
  );
}
