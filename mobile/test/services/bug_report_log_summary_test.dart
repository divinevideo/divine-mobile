// ABOUTME: Tests for buildLogsSummary() log prioritization logic
// ABOUTME: Verifies error/warning prioritization, dedup, chronological ordering

import 'package:flutter_test/flutter_test.dart';
import 'package:logging_types/logging_types.dart'
    show LogCategory, LogEntry, LogLevel;
import 'package:openvine/services/bug_report_log_summary.dart';

LogEntry _log(int minute, LogLevel level, String msg) => LogEntry(
  timestamp: DateTime(2026, 3, 30, 10, minute),
  level: level,
  message: msg,
);

void main() {
  group('buildLogsSummary', () {
    test('returns null for empty logs', () {
      expect(buildLogsSummary([]), isNull);
    });

    test('includes all entries when under limits', () {
      final logs = [
        _log(0, LogLevel.info, 'startup'),
        _log(1, LogLevel.error, 'crash'),
        _log(2, LogLevel.info, 'recovered'),
      ];
      final result = buildLogsSummary(logs)!;
      expect(result, contains('startup'));
      expect(result, contains('crash'));
      expect(result, contains('recovered'));
    });

    test('prioritizes errors/warnings over old info logs', () {
      // 100 info logs, then 5 errors at the end
      final logs = <LogEntry>[
        for (var i = 0; i < 100; i++) _log(i, LogLevel.info, 'info-$i'),
        for (var i = 100; i < 105; i++) _log(i, LogLevel.error, 'error-$i'),
      ];

      final result = buildLogsSummary(logs)!;

      // All 5 errors should be present
      for (var i = 100; i < 105; i++) {
        expect(result, contains('error-$i'));
      }
      // Old info logs (before last 50) should NOT be present
      expect(result, isNot(contains('info-0')));
      expect(result, isNot(contains('info-10')));
      // Recent info logs (last 50: indices 55-99 from info + 100-104 from error)
      expect(result, contains('info-55'));
      expect(result, contains('info-99'));
    });

    test('deduplicates entries that appear in both sets', () {
      // 60 info logs, then an error at minute 60.
      // The error falls into both the "all errors" set AND the "last 50" set.
      final logs = <LogEntry>[
        for (var i = 0; i < 60; i++) _log(i, LogLevel.info, 'info-$i'),
        _log(60, LogLevel.error, 'shared-error'),
      ];

      final result = buildLogsSummary(logs)!;
      // The error appears in both windows but should only be in output once
      final count = 'shared-error'.allMatches(result).length;
      expect(count, 1);
    });

    test('sorts output chronologically', () {
      // Error early, info late -- output should be time-ordered
      final logs = <LogEntry>[
        _log(5, LogLevel.error, 'early-error'),
        for (var i = 10; i < 20; i++) _log(i, LogLevel.info, 'late-info-$i'),
      ];

      final result = buildLogsSummary(logs)!;
      final earlyIdx = result.indexOf('early-error');
      final lateIdx = result.indexOf('late-info-15');
      expect(earlyIdx, lessThan(lateIdx));
    });

    test('caps error/warning entries at 200', () {
      // 300 warnings + 10 info at the end
      final logs = <LogEntry>[
        for (var i = 0; i < 300; i++) _log(i, LogLevel.warning, 'warn-$i'),
        for (var i = 300; i < 310; i++) _log(i, LogLevel.info, 'info-$i'),
      ];

      final result = buildLogsSummary(logs)!;
      // First 100 warnings should be dropped (only last 200 kept)
      expect(result, isNot(contains('warn-0')));
      expect(result, isNot(contains('warn-99')));
      // warn-100 onward should be present
      expect(result, contains('warn-100'));
      expect(result, contains('warn-299'));
      // Recent info should be present
      expect(result, contains('info-309'));
    });

    test('handles all-error logs', () {
      final logs = <LogEntry>[
        for (var i = 0; i < 10; i++) _log(i, LogLevel.error, 'error-$i'),
      ];

      final result = buildLogsSummary(logs)!;
      for (var i = 0; i < 10; i++) {
        expect(result, contains('error-$i'));
      }
    });

    test('handles all-info logs with no errors', () {
      final logs = <LogEntry>[
        for (var i = 0; i < 100; i++) _log(i, LogLevel.info, 'info-$i'),
      ];

      final result = buildLogsSummary(logs)!;
      // Only last 50 should be present
      expect(result, isNot(contains('info-0')));
      expect(result, contains('info-50'));
      expect(result, contains('info-99'));
    });

    test('truncates individual entries longer than 500 characters', () {
      final longMessage = 'x' * 1000;
      final logs = [_log(0, LogLevel.error, longMessage)];

      final result = buildLogsSummary(logs)!;
      // Full 1000-char message should not appear
      expect(result, isNot(contains(longMessage)));
      // Should be truncated with marker
      expect(result, contains('... [truncated]'));
      // Total line length should be capped (500 + truncation marker)
      expect(result.length, lessThan(600));
    });

    test('redacts a credential inside a log entry', () {
      final result = buildLogsSummary([
        _log(0, LogLevel.error, 'auth failed password: hunter2'),
      ])!;

      expect(result, contains('[REDACTED]'));
      expect(result, isNot(contains('hunter2')));
    });

    test('builds a production-shaped summary via real compute', () async {
      final result = await buildLogsSummaryOffMain([
        LogEntry(
          timestamp: DateTime.fromMillisecondsSinceEpoch(7080),
          level: LogLevel.error,
          category: LogCategory.api,
          name: 'request',
          message: 'token: summary-secret',
          error: 'network error',
          stackTrace: 'stack trace',
        ),
      ]);

      expect(result, contains('[REDACTED]'));
      expect(result, isNot(contains('summary-secret')));
      expect(result, contains('[API]'));
    });

    test('a credential in one entry cannot consume the next entry', () {
      // Sanitizing per entry is what bounds this. Against the assembled
      // summary, the unclosed brace in the first entry reaches the closing
      // brace in the second and takes that entry with it - support loses a log
      // line it was never told about.
      final result = buildLogsSummary([
        _log(0, LogLevel.error, 'auth failed password: {oops'),
        _log(
          1,
          LogLevel.error,
          'upload failed {code: 500} then relay '
          'reconnected',
        ),
      ])!;

      expect(result, contains('[REDACTED]'));
      expect(result, contains('relay reconnected'));
    });

    test('caps total summary length at 32KB', () {
      // 300 errors with 400-char messages -- would exceed 32KB without cap
      final logs = <LogEntry>[
        for (var i = 0; i < 300; i++)
          _log(i, LogLevel.error, '${'e' * 390}-$i'),
      ];

      final result = buildLogsSummary(logs)!;
      expect(result.length, lessThanOrEqualTo(32 * 1024 + 100));
      // Should contain truncation notice
      expect(result, contains('entries truncated'));
    });
  });
}
