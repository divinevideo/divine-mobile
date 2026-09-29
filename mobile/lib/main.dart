// ABOUTME: Application entry point
// ABOUTME: Hands off to the blocking startup sequence in app_bootstrap

import 'dart:async';

import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/startup/app_bootstrap.dart';
import 'package:openvine/widgets/global_error_widget.dart';

void main() {
  // Built here, before the zone, so the uncaught-error handler and the startup
  // sequence report through the same instance. `DeviceScope` then pins it for
  // every container (#4743).
  final crashReporting = CrashReportingService();

  // Every uncaught async error funnels through here, including anything
  // thrown during the blocking startup sequence.
  runZonedGuarded(
    () async {
      await startOpenVineApp(
        errorWidgetBuilder: buildGlobalErrorWidget,
        crashReporting: crashReporting,
      );
    },
    (error, stack) => handleUncaughtZoneError(
      error,
      stack,
      crashReporting: crashReporting,
    ),
  );
}
