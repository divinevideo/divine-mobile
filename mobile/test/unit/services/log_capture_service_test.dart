// ABOUTME: Unit tests for LogCaptureService memory buffer functionality
// ABOUTME: Tests in-memory buffer storage, max size enforcement, chronological ordering, and thread safety

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/log_entry.dart';
import 'package:openvine/services/log_capture_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  group('LogCaptureService Memory Buffer', () {
    late LogCaptureService service;

    setUp(() async {
      service = LogCaptureService.instance;
      // Clear all logs (both memory and persistent files)
      await service.clearAllLogs();
    });

    test('should store log entry in buffer', () {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: 'Test log message',
      );

      service.captureLog(entry);

      final logs = service.getRecentLogs();
      expect(logs, contains(entry));
      expect(logs.length, equals(1));
    });

    test('should not exceed max buffer size of 50000 entries', () {
      // Add 50100 log entries
      for (int i = 0; i < 50100; i++) {
        service.captureLog(
          LogEntry(
            timestamp: DateTime.now().add(Duration(milliseconds: i)),
            level: LogLevel.info,
            message: 'Log entry $i',
          ),
        );
      }

      final logs = service.getRecentLogs();
      expect(logs.length, lessThanOrEqualTo(50000));
      expect(logs.length, equals(50000)); // Should be exactly 50000
    });

    test('should evict oldest entries when buffer is full', () {
      // Add 50000 entries
      for (int i = 0; i < 50000; i++) {
        service.captureLog(
          LogEntry(
            timestamp: DateTime.now().add(Duration(milliseconds: i)),
            level: LogLevel.info,
            message: 'Log $i',
          ),
        );
      }

      // Add one more - should evict the first
      final newestEntry = LogEntry(
        timestamp: DateTime.now().add(Duration(milliseconds: 50000)),
        level: LogLevel.info,
        message: 'Log 50000',
      );
      service.captureLog(newestEntry);

      final logs = service.getRecentLogs();
      expect(logs.length, equals(50000));
      expect(logs.last, equals(newestEntry));
      expect(logs.first.message, equals('Log 1')); // First was evicted
    });

    test('should return logs in chronological order', () {
      final now = DateTime.now();

      // Add entries out of order
      service.captureLog(
        LogEntry(
          timestamp: now.add(Duration(seconds: 2)),
          level: LogLevel.info,
          message: 'Third',
        ),
      );
      service.captureLog(
        LogEntry(timestamp: now, level: LogLevel.info, message: 'First'),
      );
      service.captureLog(
        LogEntry(
          timestamp: now.add(Duration(seconds: 1)),
          level: LogLevel.info,
          message: 'Second',
        ),
      );

      final logs = service.getRecentLogs();

      expect(logs.length, equals(3));
      expect(logs[0].message, equals('First'));
      expect(logs[1].message, equals('Second'));
      expect(logs[2].message, equals('Third'));
    });

    test('should return limited number of logs when limit specified', () {
      // Add 10 entries
      for (int i = 0; i < 10; i++) {
        service.captureLog(
          LogEntry(
            timestamp: DateTime.now().add(Duration(milliseconds: i)),
            level: LogLevel.info,
            message: 'Log $i',
          ),
        );
      }

      final logs = service.getRecentLogs(limit: 5);

      expect(logs.length, equals(5));
      // Should return the 5 most recent
      expect(logs.last.message, equals('Log 9'));
    });

    test('should clear all entries from buffer', () async {
      // Add some entries
      service.captureLog(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          message: 'Test 1',
        ),
      );
      service.captureLog(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.error,
          message: 'Test 2',
        ),
      );

      expect(service.getRecentLogs().length, equals(2));

      await service.clearAllLogs();

      expect(service.getRecentLogs().length, equals(0));
    });

    test('should handle concurrent writes safely', () async {
      // Simulate concurrent log captures
      final futures = <Future>[];
      for (int i = 0; i < 100; i++) {
        futures.add(
          Future(() {
            service.captureLog(
              LogEntry(
                timestamp: DateTime.now(),
                level: LogLevel.info,
                message: 'Concurrent log $i',
              ),
            );
          }),
        );
      }

      await Future.wait(futures);

      final logs = service.getRecentLogs();
      expect(logs.length, equals(100));
    });

    test('should capture logs with all fields', () {
      final stackTrace = StackTrace.current.toString();
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        message: 'Error occurred',
        category: LogCategory.video,
        name: 'VideoPlayer',
        error: 'VideoLoadException: timeout',
        stackTrace: stackTrace,
      );

      service.captureLog(entry);

      final logs = service.getRecentLogs();
      final captured = logs.first;

      expect(captured.level, equals(LogLevel.error));
      expect(captured.message, equals('Error occurred'));
      expect(captured.category, equals(LogCategory.video));
      expect(captured.name, equals('VideoPlayer'));
      expect(captured.error, equals('VideoLoadException: timeout'));
      expect(captured.stackTrace, isNotNull);
    });

    test('should filter by minimum log level when specified', () {
      service.captureLog(
        LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.debug,
          message: 'Debug log',
        ),
      );
      service.captureLog(
        LogEntry(
          timestamp: DateTime.now().add(Duration(milliseconds: 1)),
          level: LogLevel.error,
          message: 'Error log',
        ),
      );
      service.captureLog(
        LogEntry(
          timestamp: DateTime.now().add(Duration(milliseconds: 2)),
          level: LogLevel.warning,
          message: 'Warning log',
        ),
      );

      final errorLogsOnly = service.getRecentLogs(minLevel: LogLevel.error);

      expect(errorLogsOnly.length, equals(1));
      expect(errorLogsOnly.first.message, equals('Error log'));
    });

    test('should handle empty buffer gracefully', () async {
      await service.clearAllLogs();

      final logs = service.getRecentLogs();

      expect(logs, isEmpty);
      expect(logs, isA<List<LogEntry>>());
    });
  });
}
