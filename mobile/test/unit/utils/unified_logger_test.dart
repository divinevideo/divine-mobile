// ABOUTME: Unit tests for UnifiedLogger log capture behavior
// ABOUTME: Ensures ALL logs are captured to file regardless of category/level filtering

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/log_capture_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  group('UnifiedLogger File Capture', () {
    late LogCaptureService logService;

    setUp(() async {
      logService = LogCaptureService.instance;

      // Clear logs and wait for async file operations to complete
      await logService.clearAllLogs();
      await Future.delayed(Duration(milliseconds: 50));

      // Set restrictive category filtering (only system and auth)
      // This mimics the default production configuration
      UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth});
      UnifiedLogger.setLogLevel(LogLevel.info);
    });

    test(
      'should capture ALL categories to file even when category filtering is enabled',
      () async {
        // Given: Category filtering is enabled (only system and auth)
        // This is the default production configuration
        expect(
          UnifiedLogger.enabledCategories,
          equals({LogCategory.system, LogCategory.auth}),
        );

        final beforeCount = logService.getRecentLogs().length;

        // When: We log messages from different categories
        Log.info('System log', category: LogCategory.system);
        Log.info('Auth log', category: LogCategory.auth);
        Log.info(
          'Relay log',
          category: LogCategory.relay,
        ); // NOT enabled for console
        Log.info(
          'Video log',
          category: LogCategory.video,
        ); // NOT enabled for console
        Log.info('UI log', category: LogCategory.ui); // NOT enabled for console
        Log.info(
          'API log',
          category: LogCategory.api,
        ); // NOT enabled for console
        Log.info(
          'Storage log',
          category: LogCategory.storage,
        ); // NOT enabled for console

        // Wait for async file captures to complete
        await Future.delayed(Duration(milliseconds: 100));

        // Then: ALL 7 logs should be captured to file, regardless of category filtering
        final capturedLogs = logService.getRecentLogs();
        final newLogsCount = capturedLogs.length - beforeCount;

        expect(
          newLogsCount,
          equals(7),
          reason:
              'ALL 7 logs should be captured to file, even those from disabled categories',
        );

        // Verify each category was captured (check last 7 logs)
        final newLogs = capturedLogs.skip(beforeCount).toList();
        final categories = newLogs.map((log) => log.category).toSet();
        expect(
          categories,
          containsAll([
            LogCategory.system,
            LogCategory.auth,
            LogCategory.relay,
            LogCategory.video,
            LogCategory.ui,
            LogCategory.api,
            LogCategory.storage,
          ]),
        );
      },
    );

    test(
      'should capture ALL log levels to file even when level filtering is enabled',
      () async {
        // Given: Level filtering is enabled (only info and above)
        UnifiedLogger.setLogLevel(LogLevel.info);
        expect(UnifiedLogger.currentLevel, equals(LogLevel.info));

        final beforeCount = logService.getRecentLogs().length;

        // When: We log messages at different levels
        Log.verbose(
          'Verbose log',
          category: LogCategory.system,
        ); // Below threshold
        Log.debug('Debug log', category: LogCategory.system); // Below threshold
        Log.info('Info log', category: LogCategory.system);
        Log.warning('Warning log', category: LogCategory.system);
        Log.error('Error log', category: LogCategory.system);

        // Wait for async file captures to complete
        await Future.delayed(Duration(milliseconds: 100));

        // Then: ALL 5 logs should be captured to file, regardless of level filtering
        final capturedLogs = logService.getRecentLogs();
        final newLogsCount = capturedLogs.length - beforeCount;

        expect(
          newLogsCount,
          equals(5),
          reason:
              'ALL 5 logs should be captured to file, even verbose and debug',
        );

        // Verify each level was captured
        final newLogs = capturedLogs.skip(beforeCount).toList();
        final levels = newLogs.map((log) => log.level).toSet();
        expect(
          levels,
          containsAll([
            LogLevel.verbose,
            LogLevel.debug,
            LogLevel.info,
            LogLevel.warning,
            LogLevel.error,
          ]),
        );
      },
    );

    test('should capture logs without category to file', () async {
      final beforeCount = logService.getRecentLogs().length;

      // When: We log without specifying a category
      Log.info('Log without category');

      // Wait for async file capture to complete
      await Future.delayed(Duration(milliseconds: 100));

      // Then: Log should still be captured
      final capturedLogs = logService.getRecentLogs();
      final newLogsCount = capturedLogs.length - beforeCount;

      expect(newLogsCount, equals(1));
      final newLog = capturedLogs.last;
      expect(newLog.category, isNull);
      expect(newLog.message, equals('Log without category'));
    });

    test('should capture error details to file', () async {
      final beforeCount = logService.getRecentLogs().length;

      // When: We log an error with exception and stack trace
      final exception = Exception('Test exception');
      final stackTrace = StackTrace.current;

      Log.error(
        'Error occurred',
        category: LogCategory.relay,
        error: exception,
        stackTrace: stackTrace,
      );

      // Wait for async file capture to complete
      await Future.delayed(Duration(milliseconds: 100));

      // Then: Error details should be captured
      final capturedLogs = logService.getRecentLogs();
      final newLogsCount = capturedLogs.length - beforeCount;

      expect(newLogsCount, equals(1));
      final log = capturedLogs.last;
      expect(log.message, equals('Error occurred'));
      expect(log.error, contains('Test exception'));
      expect(log.stackTrace, isNotNull);
      expect(log.category, equals(LogCategory.relay));
    });

    test(
      'should capture logs from disabled categories for bug report export',
      () async {
        // This is the critical test case that was failing in production
        // Users were exporting logs and getting only 25 lines because
        // relay, video, and other categories were filtered out before file capture

        // Given: Only system and auth categories are enabled (production default)
        UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth});

        final beforeCount = logService.getRecentLogs().length;

        // When: We simulate a typical app session with relay connection issues
        Log.info('App started', category: LogCategory.system);
        Log.info('User logged in', category: LogCategory.auth);
        Log.error('Relay connection failed', category: LogCategory.relay);
        Log.error('WebSocket timeout', category: LogCategory.relay);
        Log.warning('Video load slow', category: LogCategory.video);
        Log.debug('Button tapped', category: LogCategory.ui);
        Log.error('API call failed', category: LogCategory.api);

        // Wait for async file captures
        await Future.delayed(Duration(milliseconds: 100));

        // Then: When user exports logs, they should get ALL 7 new entries
        final exportedLogs = logService.getRecentLogs();
        final newLogsCount = exportedLogs.length - beforeCount;

        expect(
          newLogsCount,
          equals(7),
          reason:
              'User log export must include ALL categories for debugging remote issues',
        );

        // Verify critical relay logs are included
        final newLogs = exportedLogs.skip(beforeCount).toList();
        final relayLogs = newLogs.where(
          (log) => log.category == LogCategory.relay,
        );
        expect(
          relayLogs.length,
          equals(2),
          reason:
              'Relay connection errors are critical for debugging and must be captured',
        );
      },
    );
  });
}
