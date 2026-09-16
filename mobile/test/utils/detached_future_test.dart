// ABOUTME: Tests for the fire-and-forget helper behind detached lifecycle work.
// ABOUTME: Pins that a rejected operation is logged and never leaks a rejection.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
        expect(logs.single.stackTrace, isNotNull);
      },
    );

    test(
      'does not reject again when the operation is a Future<bool> passed as '
      'Future<void>',
      () async {
        // A `Future<T>.catchError` handler must return a `T`; a void logging
        // handler returns null, which used to surface as a second, unhandled
        // ArgumentError once the logged error had already been reported.
        final errors = await unhandledErrorsWhile(() async {
          runDetached(
            failingBoolOperation(),
            'autosave the draft',
            logName: 'Autosave',
            category: LogCategory.video,
          );
        });

        expect(errors, isEmpty);
        final logs = logCapture.getRecentLogs();
        expect(logs, hasLength(1));
        expect(
          logs.single.message,
          'Failed to autosave the draft: Bad state: boom',
        );
      },
    );

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
