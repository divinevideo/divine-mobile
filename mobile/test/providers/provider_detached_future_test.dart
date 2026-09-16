// ABOUTME: Tests for the provider-layer wrapper around detached lifecycle work.
// ABOUTME: Pins that provider failures reach the log under the system category.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  group('runProviderDetached', () {
    late LogCaptureService logCapture;

    setUp(() async {
      logCapture = LogCaptureService();
      await logCapture.clearAllLogs();
    });

    tearDown(() async {
      await logCapture.clearAllLogs();
    });

    test(
      'logs a rejected provider operation under the system category',
      () async {
        final errors = <Object>[];
        await runZonedGuarded(() async {
          runProviderDetached(
            Future<void>.error(StateError('boom')),
            'initialize the follow repository',
            logName: 'FollowRepository',
          );
          await pumpEventQueue();
        }, (error, _) => errors.add(error));

        expect(errors, isEmpty);
        final logs = logCapture.getRecentLogs();
        expect(logs, hasLength(1));
        expect(logs.single.level, LogLevel.error);
        expect(logs.single.name, 'FollowRepository');
        expect(logs.single.category, LogCategory.system);
        expect(
          logs.single.message,
          'Failed to initialize the follow repository: Bad state: boom',
        );
      },
    );
  });
}
