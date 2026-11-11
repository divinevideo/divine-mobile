// ABOUTME: Unit tests for UnifiedLogger log capture behavior
// ABOUTME: Ensures ALL logs are captured to file regardless of category/level filtering

import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  group('UnifiedLogger File Capture', () {
    late LogCaptureService logService;

    setUp(() async {
      logService = LogCaptureService();

      // Clear logs and wait for async file operations to complete
      await logService.clearAllLogs();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Set restrictive category filtering (only system and auth)
      // This mimics the default production configuration
      UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth});
      UnifiedLogger.setLogLevel(LogLevel.info);
    });

    test(
      'captures ALL categories to file even when '
      'category filtering is enabled',
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
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Then: ALL 7 logs should be captured to file,
        // regardless of category filtering
        final capturedLogs = logService.getRecentLogs();
        final newLogsCount = capturedLogs.length - beforeCount;

        expect(
          newLogsCount,
          equals(7),
          reason:
              'ALL 7 logs should be captured to file, '
              'even those from disabled categories',
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
      'captures ALL log levels to file even when '
      'level filtering is enabled',
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
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Then: ALL 5 logs should be captured,
        // regardless of level filtering
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
      await Future<void>.delayed(const Duration(milliseconds: 100));

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
      await Future<void>.delayed(const Duration(milliseconds: 100));

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

    test('should capture warning details to file', () async {
      final beforeCount = logService.getRecentLogs().length;

      final exception = Exception('Warning exception');
      final stackTrace = StackTrace.current;

      Log.warning(
        'Warning occurred',
        category: LogCategory.video,
        error: exception,
        stackTrace: stackTrace,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final capturedLogs = logService.getRecentLogs();
      final newLogsCount = capturedLogs.length - beforeCount;

      expect(newLogsCount, equals(1));
      final log = capturedLogs.last;
      expect(log.level, equals(LogLevel.warning));
      expect(log.message, equals('Warning occurred'));
      expect(log.error, contains('Warning exception'));
      expect(log.stackTrace, isNotNull);
      expect(log.category, equals(LogCategory.video));
    });

    test(
      'captures logs from disabled categories '
      'for bug report export',
      () async {
        // This is the critical test case that was failing in production
        // Users were exporting logs and getting only 25 lines because
        // relay, video, and other categories were
        // filtered out before file capture

        // Given: Only system and auth categories
        // are enabled (production default)
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
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Then: When user exports logs, they should get ALL 7 new entries
        final exportedLogs = logService.getRecentLogs();
        final newLogsCount = exportedLogs.length - beforeCount;

        expect(
          newLogsCount,
          equals(7),
          reason:
              'User log export must include ALL categories '
              'for debugging remote issues',
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
              'Relay connection errors are critical '
              'for debugging and must be captured',
        );
      },
    );
  });

  group('UnifiedLogger timestamp encoding', () {
    late LogCaptureService logService;
    late Set<LogCategory> enabledCategories;
    late LogLevel logLevel;

    setUp(() async {
      logService = LogCaptureService();
      await logService.clearAllLogs();
      enabledCategories = UnifiedLogger.enabledCategories;
      logLevel = UnifiedLogger.currentLevel;
      UnifiedLogger.enableCategories({LogCategory.system});
      UnifiedLogger.setLogLevel(LogLevel.info);
    });

    tearDown(() {
      UnifiedLogger.enableCategories(enabledCategories);
      UnifiedLogger.setLogLevel(logLevel);
    });

    test('captures the entry timestamp in UTC', () {
      Log.info('utc probe', category: LogCategory.system);

      final entry = logService.getRecentLogs().lastWhere(
        (log) => log.message == 'utc probe',
      );

      expect(
        entry.timestamp.isUtc,
        isTrue,
        reason:
            'A local timestamp exports without an offset, so support '
            'cannot align it with relay or funnelcake rows.',
      );
    });

    test('exports a Z-suffixed timestamp', () async {
      Log.info('export probe', category: LogCategory.system);

      final line = (await logService.getAllLogsAsText()).firstWhere(
        (text) => text.contains('export probe'),
      );

      expect(
        line,
        matches(
          RegExp(r'^\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z\] '),
        ),
      );
    });
  });

  group('secret redaction at the sink (#10385)', () {
    // NIP-19's published test vectors; they control no real account.
    const nsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
    const npub =
        'npub10elfcs4fr0l0r8af98jlmgdh9c8tcxjvz9qkw038js35mp4dma8qzvjptg';
    const hex =
        '7e7e9c42a91bfef19fa929e5fda1b72e0ebc1a4c1141673e2794234d86addf4e';

    setUp(() async {
      await LogCaptureService().clearAllLogs();
    });

    test('redacts an nsec from a captured message', () {
      Log.info('opened /profile/$nsec', name: 'Test');

      final entry = LogCaptureService().getRecentLogs().last;
      expect(entry.message, equals('opened /profile/[REDACTED]'));
    });

    test('redacts an uppercase ncryptsec from a captured message', () {
      Log.info('key NCRYPTSEC1QGQEYAFQWZ here', name: 'Test');

      final entry = LogCaptureService().getRecentLogs().last;
      expect(entry.message.toLowerCase(), isNot(contains('ncryptsec1')));
    });

    test('redacts an nsec from a captured error and stack trace', () {
      Log.error(
        'failed',
        name: 'Test',
        error: const FormatException('bad link $nsec'),
        stackTrace: StackTrace.fromString('#0 open ($nsec)'),
      );

      final entry = LogCaptureService().getRecentLogs().last;
      expect(entry.error, isNot(contains('nsec1')));
      expect(entry.stackTrace, isNot(contains('nsec1')));
      expect(entry.error, contains('bad link [REDACTED]'));
    });

    // The 52 data characters already hold the whole key; the last six are
    // checksum, so a paste cut short is still the secret.
    test('redacts an nsec missing its checksum', () {
      Log.info('opened /profile/${nsec.substring(0, 57)}', name: 'Test');

      final entry = LogCaptureService().getRecentLogs().last;
      expect(entry.message, equals('opened /profile/[REDACTED]'));
    });

    test('logs public ids whole', () {
      Log.info('author $npub ($hex)', name: 'Test');

      final entry = LogCaptureService().getRecentLogs().last;
      expect(entry.message, equals('author $npub ($hex)'));
    });
  });
}
