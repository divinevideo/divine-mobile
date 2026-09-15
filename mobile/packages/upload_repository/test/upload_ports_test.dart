// ABOUTME: Contract tests for the UploadCrashReporter port — verifies the
// ABOUTME: interface is implementable and forwards its arguments faithfully.

import 'package:flutter_test/flutter_test.dart';
import 'package:upload_repository/upload_repository.dart';

/// Records every call so the test can assert faithful argument forwarding.
class _RecordingReporter implements UploadCrashReporter {
  final List<(String, Object)> customKeys = [];
  final List<String> logs = [];
  final List<(Object, StackTrace?, String?)> recordedErrors = [];

  @override
  Future<void> setCustomKey(String key, Object value) async {
    customKeys.add((key, value));
  }

  @override
  void log(String message) {
    logs.add(message);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    recordedErrors.add((error, stack, reason));
  }
}

void main() {
  group(UploadCrashReporter, () {
    late _RecordingReporter reporter;

    setUp(() => reporter = _RecordingReporter());

    test('a conforming implementation satisfies the interface', () {
      expect(reporter, isA<UploadCrashReporter>());
    });

    test('setCustomKey forwards key and value', () async {
      await reporter.setCustomKey('upload_id', 'abc-123');
      await reporter.setCustomKey('retry_count', 4);

      expect(reporter.customKeys, [
        ('upload_id', 'abc-123'),
        ('retry_count', 4),
      ]);
    });

    test('log forwards the breadcrumb message', () {
      reporter.log('upload started');

      expect(reporter.logs, ['upload started']);
    });

    test('recordError forwards error, stack, and reason', () async {
      final error = StateError('boom');
      final stack = StackTrace.current;

      await reporter.recordError(error, stack, reason: 'upload failure');

      expect(reporter.recordedErrors, hasLength(1));
      final (recordedError, recordedStack, recordedReason) =
          reporter.recordedErrors.single;
      expect(recordedError, same(error));
      expect(recordedStack, same(stack));
      expect(recordedReason, 'upload failure');
    });

    test('recordError accepts a null stack and omitted reason', () async {
      await reporter.recordError('failure', null);

      expect(reporter.recordedErrors, [('failure', null, null)]);
    });
  });
}
