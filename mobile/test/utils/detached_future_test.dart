// ABOUTME: Tests for the fire-and-forget helper behind detached lifecycle work.
// ABOUTME: Pins that a rejected operation is logged and never leaks a rejection.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Runs [body] in a guarded zone and returns every error that escaped it.
///
/// Errors escaping [runDetached] are reported to the zone current when the
/// future was created, so the call under test has to run inside [body].
Future<List<Object>> unhandledErrorsWhile(Future<void> Function() body) async {
  final errors = <Object>[];
  await runZonedGuarded(() async {
    await body();
    await pumpEventQueue();
  }, (error, _) => errors.add(error));
  return errors;
}

Future<bool> failingBoolOperation() async => throw StateError('boom');

class _RecordedError {
  const _RecordedError(this.error, this.stackTrace, this.reason);

  final Object error;
  final StackTrace? stackTrace;
  final String? reason;
}

class _RecordingCrashReporter implements CrashReporter {
  final recordedErrors = <_RecordedError>[];

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    recordedErrors.add(_RecordedError(error, stackTrace, reason));
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}

void main() {
  group('runDetached', () {
    late LogCaptureService logCapture;

    setUp(() async {
      logCapture = LogCaptureService();
      await logCapture.clearAllLogs();
    });

    tearDown(() async {
      await logCapture.clearAllLogs();
    });

    test(
      'logs a rejected operation instead of leaking the rejection',
      () async {
        final errors = await unhandledErrorsWhile(() async {
          runDetached(
            Future<void>.error(StateError('boom')),
            'load badges',
            logName: 'BadgeLoader',
            category: LogCategory.ui,
          );
        });

        expect(errors, isEmpty);
        final logs = logCapture.getRecentLogs();
        expect(logs, hasLength(1));
        expect(logs.single.level, LogLevel.error);
        expect(logs.single.name, 'BadgeLoader');
        expect(logs.single.category, LogCategory.ui);
        expect(logs.single.message, 'Failed to load badges: Bad state: boom');
        expect(logs.single.error, 'Bad state: boom');
        expect(logs.single.stackTrace, isNotNull);
      },
    );

    test('forwards bare invariant failures to the crash reporter', () async {
      final reporter = _RecordingCrashReporter();
      final error = StateError('closed');

      final unhandledErrors = await unhandledErrorsWhile(() async {
        runDetached(
          Future<void>.error(error),
          'load badges',
          logName: 'BadgeLoader',
          category: LogCategory.ui,
          reporter: reporter,
        );
      });

      expect(unhandledErrors, isEmpty);
      expect(reporter.recordedErrors, hasLength(1));
      final record = reporter.recordedErrors.single;
      expect(record.error, isA<ReportableError>());
      expect((record.error as Reportable<Object>).unwrap(), same(error));
      expect(record.stackTrace, isNotNull);
      expect(record.reason, 'runDetached BadgeLoader');
    });

    test(
      'forwards explicitly reportable failures to the crash reporter',
      () async {
        final reporter = _RecordingCrashReporter();
        final error = Reportable(Exception('invariant'), context: 'test');

        final unhandledErrors = await unhandledErrorsWhile(() async {
          runDetached(
            Future<void>.error(error),
            'load badges',
            logName: 'BadgeLoader',
            category: LogCategory.ui,
            reporter: reporter,
          );
        });

        expect(unhandledErrors, isEmpty);
        expect(reporter.recordedErrors, hasLength(1));
        expect(reporter.recordedErrors.single.error, same(error));
      },
    );

    test(
      'keeps expected operational failures out of the crash reporter',
      () async {
        final reporter = _RecordingCrashReporter();

        final unhandledErrors = await unhandledErrorsWhile(() async {
          runDetached(
            Future<void>.error(TimeoutException('offline')),
            'load badges',
            logName: 'BadgeLoader',
            category: LogCategory.ui,
            reporter: reporter,
          );
        });

        expect(unhandledErrors, isEmpty);
        expect(reporter.recordedErrors, isEmpty);
        expect(logCapture.getRecentLogs(), hasLength(1));
      },
    );

    test(
      'does not reject again when the operation is a Future<bool> passed as '
      'Future<void>',
      () async {
        final reporter = _RecordingCrashReporter();
        // A `Future<T>.catchError` handler must return a `T`; a void logging
        // handler returns null, which used to surface as a second, unhandled
        // ArgumentError once the logged error had already been reported.
        final errors = await unhandledErrorsWhile(() async {
          runDetached(
            failingBoolOperation(),
            'autosave the draft',
            logName: 'Autosave',
            category: LogCategory.video,
            reporter: reporter,
          );
        });

        expect(errors, isEmpty);
        final logs = logCapture.getRecentLogs();
        expect(logs, hasLength(1));
        expect(
          logs.single.message,
          'Failed to autosave the draft: Bad state: boom',
        );
        expect(reporter.recordedErrors, hasLength(1));
      },
    );

    group('detachedFailureReporter', () {
      late CrashReporter originalReporter;
      late _RecordingCrashReporter reporter;

      setUp(() {
        originalReporter = detachedFailureReporter;
        reporter = _RecordingCrashReporter();
        detachedFailureReporter = reporter;
      });

      tearDown(() {
        detachedFailureReporter = originalReporter;
      });

      test('receives reportable failures when no reporter is passed', () async {
        final error = StateError('closed');

        final unhandledErrors = await unhandledErrorsWhile(() async {
          runDetached(
            Future<void>.error(error),
            'load badges',
            logName: 'BadgeLoader',
            category: LogCategory.ui,
          );
        });

        expect(unhandledErrors, isEmpty);
        expect(reporter.recordedErrors, hasLength(1));
        expect(
          (reporter.recordedErrors.single.error as Reportable<Object>).unwrap(),
          same(error),
        );
      });
    });

    test('logs nothing when the operation completes', () async {
      final errors = await unhandledErrorsWhile(() async {
        runDetached(
          Future<void>.value(),
          'load badges',
          logName: 'BadgeLoader',
          category: LogCategory.ui,
        );
      });

      expect(errors, isEmpty);
      expect(logCapture.getRecentLogs(), isEmpty);
    });
  });
}
