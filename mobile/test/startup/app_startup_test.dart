// ABOUTME: Tests for app startup without crashes
// ABOUTME: Validates that the app can initialize without errors

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/logging_config_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App Startup', () {
    setUp(() {
      // Reset services for clean test
      Log.setLogLevel(LogLevel.debug);
    });

    test('CrashReportingService can be initialized early', () async {
      // This mimics what happens in _startOpenVineApp
      final startTime = DateTime.now();

      // Initialize crash reporting first
      await CrashReportingService.instance.initialize();

      // Should not throw
      CrashReportingService.instance.logInitializationStep('Test step');
      CrashReportingService.instance.log('Test message');

      // Initialize logging config
      await LoggingConfigService.instance.initialize();

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      expect(duration, greaterThanOrEqualTo(0));
    });

    test('Startup breadcrumbs can be logged safely', () async {
      // Initialize the service
      await CrashReportingService.instance.initialize();

      // Test various breadcrumb formats used in the app
      final testBreadcrumbs = [
        'Bindings initialized',
        'Starting BackgroundActivityManager',
        '✓ BackgroundActivityManager initialized in 50ms',
        '✗ Service failed: Test error',
        'All services initialized successfully in 100ms',
      ];

      // None of these should throw
      for (final breadcrumb in testBreadcrumbs) {
        CrashReportingService.instance.logInitializationStep(breadcrumb);
      }

      // Also test regular logging
      CrashReportingService.instance.log('Startup timeout detected');
    });

    test('Logging can handle early startup phase', () {
      // These should not crash even before full initialization
      Log.info(
        '[STARTUP] App initialization started',
        name: 'Main',
        category: LogCategory.system,
      );

      Log.warning(
        '[STARTUP] WARNING: Slow initialization',
        name: 'Main',
        category: LogCategory.system,
      );

      Log.error(
        '[STARTUP] Initialization failed',
        name: 'Main',
        category: LogCategory.system,
      );
    });
  });
}
