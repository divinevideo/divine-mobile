// ABOUTME: Tests for the relay log message batcher used by the debugPrint bridge.
// ABOUTME: Verifies batching without depending on private implementation details.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  group('LogMessageBatcher', () {
    late LogMessageBatcher batcher;
    late LogCaptureService logCapture;
    late Set<LogCategory> previousCategories;
    late LogLevel previousLevel;

    setUp(() async {
      previousCategories = Set<LogCategory>.from(
        UnifiedLogger.enabledCategories,
      );
      previousLevel = UnifiedLogger.currentLevel;
      batcher = LogMessageBatcher();
      logCapture = LogCaptureService();

      await logCapture.clearAllLogs();
      UnifiedLogger.enableCategories({LogCategory.relay});
      UnifiedLogger.setLogLevel(LogLevel.debug);
      await logCapture.clearAllLogs();
    });

    tearDown(() async {
      batcher.dispose();
      UnifiedLogger.enableCategories(previousCategories);
      UnifiedLogger.setLogLevel(previousLevel);
      await logCapture.clearAllLogs();
    });

    test('ignores messages that do not match a batchable pattern', () {
      expect(
        batcher.tryBatchMessage(
          '[EXTERNAL-EVENT] relay connected',
          category: LogCategory.relay,
        ),
        isFalse,
      );

      batcher.dispose();

      expect(logCapture.getRecentLogs(), isEmpty);
    });

    test('disposing a second batcher does not flush the first one', () {
      final other = LogMessageBatcher();
      addTearDown(other.dispose);

      expect(
        batcher.tryBatchMessage(
          '[EXTERNAL-EVENT] Event abc matches subscription feed',
          level: LogLevel.debug,
          category: LogCategory.relay,
        ),
        isTrue,
      );

      other.dispose();

      expect(logCapture.getRecentLogs(), isEmpty);
    });

    test('flushes matching subscription messages on the interval', () {
      fakeAsync((async) {
        batcher.initialize();

        expect(
          batcher.tryBatchMessage(
            '[EXTERNAL-EVENT] Event abc matches subscription feed',
            level: LogLevel.debug,
            category: LogCategory.relay,
          ),
          isTrue,
        );
        expect(
          batcher.tryBatchMessage(
            '[EXTERNAL-EVENT] Event def matches subscription feed',
            level: LogLevel.debug,
            category: LogCategory.relay,
          ),
          isTrue,
        );
        expect(logCapture.getRecentLogs(), isEmpty);

        async.elapse(const Duration(seconds: 10));

        final logs = logCapture.getRecentLogs();
        expect(logs, hasLength(1));
        expect(logs.single.level, LogLevel.debug);
        expect(logs.single.category, LogCategory.relay);
        expect(
          logs.single.message,
          contains('BATCHED: 2 events matched subscriptions'),
        );

        batcher.dispose();
      });
    });

    test('flushing pending messages keeps the interval armed', () {
      fakeAsync((async) {
        batcher.initialize();
        batcher.tryBatchMessage(
          '[EXTERNAL-EVENT] Event abc matches subscription feed',
          level: LogLevel.debug,
          category: LogCategory.relay,
        );

        batcher.flush();

        expect(logCapture.getRecentLogs(), hasLength(1));
        batcher.tryBatchMessage(
          '[EXTERNAL-EVENT] Event def matches subscription feed',
          level: LogLevel.debug,
          category: LogCategory.relay,
        );

        async.elapse(const Duration(seconds: 10));

        expect(logCapture.getRecentLogs(), hasLength(2));
      });
    });

    test('flushes immediately when a pattern reaches the max batch size', () {
      for (var i = 0; i < 50; i++) {
        expect(
          batcher.tryBatchMessage(
            '[EXTERNAL-EVENT] Event $i already exists in database or was rejected',
            category: LogCategory.relay,
          ),
          isTrue,
        );
      }

      final logs = logCapture.getRecentLogs();
      expect(logs, hasLength(1));
      expect(logs.single.level, LogLevel.info);
      expect(logs.single.category, LogCategory.relay);
      expect(
        logs.single.message,
        contains(
          'BATCHED: 50 events already existed in database and were not saved',
        ),
      );
    });

    test('dispose flushes pending received-event summaries', () {
      expect(
        batcher.tryBatchMessage(
          '[EXTERNAL-EVENT] Received event abc from relay.example - kind: 32222',
          level: LogLevel.warning,
          category: LogCategory.relay,
        ),
        isTrue,
      );

      batcher.dispose();

      final logs = logCapture.getRecentLogs();
      expect(logs, hasLength(1));
      expect(logs.single.level, LogLevel.warning);
      expect(logs.single.category, LogCategory.relay);
      expect(
        logs.single.message,
        contains('BATCHED: 1 events received from external relays'),
      );
    });
  });
}
