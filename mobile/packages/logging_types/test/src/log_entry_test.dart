import 'package:logging_types/logging_types.dart';
import 'package:test/test.dart';

void main() {
  group('LogEntry', () {
    final timestamp = DateTime.utc(2026, 9, 8, 12, 34, 56);

    test('round-trips every field through JSON', () {
      final entry = LogEntry(
        timestamp: timestamp,
        level: LogLevel.error,
        message: 'Relay failed',
        category: LogCategory.relay,
        name: 'connection',
        error: 'timeout',
        stackTrace: 'frame one\nframe two',
      );

      expect(LogEntry.fromJson(entry.toJson()), entry);
      expect(entry.toJson(), {
        'timestamp': '2026-09-08T12:34:56.000Z',
        'level': 'error',
        'message': 'Relay failed',
        'category': 'RELAY',
        'name': 'connection',
        'error': 'timeout',
        'stackTrace': 'frame one\nframe two',
      });
    });

    test('omits absent optional fields from JSON', () {
      final entry = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'Ready',
      );

      expect(LogEntry.fromJson(entry.toJson()), entry);
      expect(entry.toJson(), {
        'timestamp': '2026-09-08T12:34:56.000Z',
        'level': 'info',
        'message': 'Ready',
      });
    });

    test('formats category, name, and error when present', () {
      final entry = LogEntry(
        timestamp: timestamp,
        level: LogLevel.warning,
        message: 'Retrying',
        category: LogCategory.api,
        name: 'upload',
        error: 'unavailable',
      );

      expect(
        entry.toFormattedString(),
        '[2026-09-08T12:34:56.000Z] [WARNING] [API] '
        '(upload) Retrying | Error: unavailable',
      );
    });

    test('formats required fields when optional fields are absent', () {
      final entry = LogEntry(
        timestamp: timestamp,
        level: LogLevel.debug,
        message: 'Connected',
      );

      expect(
        entry.toFormattedString(),
        '[2026-09-08T12:34:56.000Z] [DEBUG] Connected',
      );
    });

    test('compares all fields and produces matching hash codes', () {
      final first = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'Ready',
      );
      final equal = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'Ready',
      );
      final different = LogEntry(
        timestamp: timestamp,
        level: LogLevel.error,
        message: 'Ready',
      );

      expect(first, equal);
      expect(first.hashCode, equal.hashCode);
      expect(first, isNot(different));
      expect(first, isNot('Ready'));
    });

    test('does not collide when two field values are swapped', () {
      final first = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'Ready',
        name: 'a',
        error: 'b',
      );
      final swapped = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'Ready',
        name: 'b',
        error: 'a',
      );

      expect(first, isNot(swapped));
      expect(first.hashCode, isNot(swapped.hashCode));
    });

    test('does not collide when two self-cancelling pairs differ', () {
      final first = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'a',
        error: 'a',
      );
      final second = LogEntry(
        timestamp: timestamp,
        level: LogLevel.info,
        message: 'b',
        error: 'b',
      );

      expect(first, isNot(second));
      expect(first.hashCode, isNot(second.hashCode));
    });
  });
}
