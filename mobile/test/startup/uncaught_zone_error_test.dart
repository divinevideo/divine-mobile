import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/database_corruption_service.dart';
import 'package:openvine/startup/app_bootstrap.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/common.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  group('handleUncaughtZoneError', () {
    late List<({Object error, String? reason})> filed;

    setUp(() => filed = []);

    Future<void> Function(Object, StackTrace, {String? reason}) recorder() {
      return (error, stack, {reason}) async {
        filed.add((error: error, reason: reason));
      };
    }

    test('does not report a relay handshake that failed on DNS', () async {
      // The zone guard is where this lands: nothing catches the failed
      // handshake, so it escapes as an uncaught async error (#7290).
      await app.handleUncaughtZoneError(
        crashReporting: CrashReportingService(),
        WebSocketChannelException.from(
          const SocketException("Failed host lookup: 'relay.divine.video'"),
        ),
        StackTrace.current,
        recordError: recorder(),
      );

      expect(filed, isEmpty);
    });

    test('does not report a bare socket failure', () async {
      await app.handleUncaughtZoneError(
        crashReporting: CrashReportingService(),
        const SocketException("Failed host lookup: 'media.divine.video'"),
        StackTrace.current,
        recordError: recorder(),
      );

      expect(filed, isEmpty);
    });

    test('reports a socket failure the app inflicted on itself', () async {
      // Narrowed in review: only a DNS failure is dropped here, so a leaked
      // or double-closed descriptor still reaches Crashlytics (#7310).
      const error = SocketException(
        'OS Error: Bad file descriptor',
        osError: OSError('Bad file descriptor', 9),
      );

      await app.handleUncaughtZoneError(
        crashReporting: CrashReportingService(),
        error,
        StackTrace.current,
        recordError: recorder(),
      );

      expect(filed, hasLength(1));
      expect(filed.single.error, same(error));
      expect(filed.single.reason, 'runZonedGuarded');
    });

    test('still reports an unexpected error', () async {
      final error = StateError('No public key available');

      await app.handleUncaughtZoneError(
        crashReporting: CrashReportingService(),
        error,
        StackTrace.current,
        recordError: recorder(),
      );

      expect(filed, hasLength(1));
      expect(filed.single.error, same(error));
      expect(filed.single.reason, 'runZonedGuarded');
    });

    test(
      'writes an unexpected error to the unified log before filing it',
      () async {
        // The zone guard is installed before Crashlytics initializes, so for
        // the whole pre-init window recordError is its only sink and that sink
        // is inert. The unified log is what a bug report carries, so the
        // handler has to write there itself, as DivineBlocObserver does (#8616).
        final marker = 'zone-error-${DateTime.now().microsecondsSinceEpoch}';
        final error = StateError(marker);

        await app.handleUncaughtZoneError(
          error,
          StackTrace.current,
          crashReporting: CrashReportingService(),
        );

        final logged = LogCaptureService()
            .getRecentLogs(minLevel: LogLevel.error)
            .where(
              (entry) =>
                  entry.name == 'Main' &&
                  (entry.error?.contains(marker) ?? false),
            );
        expect(logged, hasLength(1));
      },
    );

    group('once the local database has reported corruption (#7507)', () {
      // The largest of the duplicate groups in #7507: every Drift statement
      // that fails after the first one escapes as an uncaught async error, so
      // one corrupt file produced tens of `runZonedGuarded` reports per
      // session. The handler files through the shared reporter, and the
      // reporter carries the corruption service's suppression, so the
      // wiring in app_bootstrap is what this exercises end to end.
      late _MockFirebaseCrashlytics crashlytics;
      late CrashReportingService crashReporting;
      late DatabaseCorruptionService corruption;

      /// The failure as the zone sees it: a Drift statement forwarded from the
      /// database isolate, whose `toString()` is the `SqliteException` text.
      final corruptStatement = SqliteException(
        extendedResultCode: 26,
        message: 'file is not a database',
        explanation: 'file is not a database (code 26)',
        operation: 'selecting from statement',
        causingStatement: 'PRAGMA user_version;',
      );

      setUp(() async {
        registerFallbackValue(StackTrace.empty);
        crashlytics = _MockFirebaseCrashlytics();
        when(
          () => crashlytics.setCustomKey(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => crashlytics.setCrashlyticsCollectionEnabled(any()),
        ).thenAnswer((_) async {});
        when(
          () => crashlytics.isCrashlyticsCollectionEnabled,
        ).thenReturn(false);
        when(() => crashlytics.log(any())).thenAnswer((_) async {});
        when(
          () => crashlytics.recordError(
            any<dynamic>(),
            any<StackTrace?>(),
            reason: any(named: 'reason'),
          ),
        ).thenAnswer((_) async {});
        final originalOnError = FlutterError.onError;
        final originalPlatformOnError = PlatformDispatcher.instance.onError;
        addTearDown(() {
          FlutterError.onError = originalOnError;
          PlatformDispatcher.instance.onError = originalPlatformOnError;
        });
        crashReporting = CrashReportingService(
          initializeFirebase: () async {},
          crashlytics: () => crashlytics,
        );
        await crashReporting.initialize();

        SharedPreferences.setMockInitialValues({});
        corruption = DatabaseCorruptionService(
          preferences: await SharedPreferences.getInstance(),
          recordError: (error, stack) => crashReporting.recordError(
            error,
            stack,
            reason: 'Runtime database corruption',
          ),
        );
        addTearDown(corruption.dispose);
        // The same registration app_bootstrap makes.
        crashReporting.suppressWhen(
          name: 'reported database corruption echo',
          isSuppressed: corruption.echoesReportedCorruption,
        );
      });

      test('files the first corrupt statement, drops the echoes', () async {
        // What the interceptor does on the first failing statement …
        corruption.report(corruptStatement, StackTrace.current);
        await pumpEventQueue();
        // … and what the zone then sees from every later one.
        await app.handleUncaughtZoneError(
          corruptStatement,
          StackTrace.current,
          crashReporting: crashReporting,
        );
        await app.handleUncaughtZoneError(
          corruptStatement,
          StackTrace.current,
          crashReporting: crashReporting,
        );

        final incident = verify(
          () => crashlytics.recordError(
            captureAny<dynamic>(),
            any<StackTrace?>(),
            reason: 'Runtime database corruption',
          ),
        ).captured;
        expect(incident.single, isA<DatabaseCorruptionEvent>());
        verifyNever(
          () => crashlytics.recordError(
            any<dynamic>(),
            any<StackTrace?>(),
            reason: 'runZonedGuarded',
          ),
        );
      });

      test('keeps filing a corrupt statement nobody has reported', () async {
        // Classification alone must not drop anything: before the interceptor
        // has spoken, an uncaught corrupt statement is still the incident.
        await app.handleUncaughtZoneError(
          corruptStatement,
          StackTrace.current,
          crashReporting: crashReporting,
        );

        verify(
          () => crashlytics.recordError(
            any<dynamic>(),
            any<StackTrace?>(),
            reason: 'runZonedGuarded',
          ),
        ).called(1);
      });

      test('keeps filing an unrelated uncaught error', () async {
        corruption.report(corruptStatement, StackTrace.current);
        await pumpEventQueue();

        await app.handleUncaughtZoneError(
          StateError('No public key available'),
          StackTrace.current,
          crashReporting: crashReporting,
        );

        verify(
          () => crashlytics.recordError(
            any<dynamic>(),
            any<StackTrace?>(),
            reason: 'runZonedGuarded',
          ),
        ).called(1);
      });
    });
  });
}
