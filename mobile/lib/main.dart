// ABOUTME: Application entry point
// ABOUTME: Hands off to the blocking startup sequence in app_bootstrap

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/startup/app_bootstrap.dart';
import 'package:unified_logger/unified_logger.dart';

/// The error surface shown for a failure that escapes before — or instead of —
/// [MaterialApp].
///
/// Installed by the startup sequence as [ErrorWidget.builder]. It renders
/// outside any theme, font loader or [Directionality], which is why it sets
/// raw text styles with an explicit `TextDecoration.none` rather than reaching
/// for a [VineTheme] helper: those resolve a Google font asynchronously, and
/// a crash screen is the worst place to start a font fetch.
Widget startupErrorWidgetBuilder(FlutterErrorDetails details) {
  // On web, log error details for debugging
  if (kIsWeb) {
    Log.error(
      'ErrorWidget: ${details.exception}\n${details.stack}',
      name: 'ErrorWidget',
      category: LogCategory.system,
    );
  }
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: VineTheme.backgroundColor,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DivineIcon(
                icon: DivineIconName.warningCircle,
                color: VineTheme.accentOrange,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops, something went wrong',
                style: TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '${details.exception}',
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

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
        errorWidgetBuilder: startupErrorWidgetBuilder,
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
