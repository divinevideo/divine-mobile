import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/database_corruption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/common.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

/// The corrupt statement behind #7507, as the real `sqlite3` type.
///
/// The database runs on a background isolate, so the app actually sees a
/// `DriftRemoteException` — but its `toString()` is exactly
/// `remoteCause.toString()` and its constructor is private, so the cause
/// itself is the faithful stand-in. The bound parameter matters: it is what
/// puts content below the header line.
final _realCorruptionException = SqliteException(
  extendedResultCode: 26,
  message: 'file is not a database',
  explanation: 'file is not a database (code 26)',
  operation: 'selecting from statement',
  causingStatement: 'PRAGMA user_version;',
  parametersToStatement: <Object?>['abc123'],
);

/// An ordinary constraint failure whose bound user data quotes SQLite's
/// corruption message. Must never read as corruption.
final _quotedCorruptionInUserData = SqliteException(
  extendedResultCode: 19,
  message: 'UNIQUE constraint failed: event.id',
  explanation: 'UNIQUE constraint failed: event.id (code 19)',
  operation: 'inserting a row',
  causingStatement: 'INSERT INTO event (content) VALUES (?)',
  parametersToStatement: const <Object?>[
    'SqliteException(11): database disk image is malformed',
  ],
);

void main() {
  group(DatabaseCorruptionService, () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    DatabaseCorruptionService build({
      Future<void> Function(Object error, StackTrace stack)? recordError,
    }) {
      final service = DatabaseCorruptionService(
        preferences: prefs,
        recordError: recordError,
      );
      addTearDown(service.dispose);
      return service;
    }

    group('report', () {
      test('flips isCorrupted so the UI can prompt for a restart', () {
        final service = build();
        expect(service.isCorrupted.value, isFalse);

        service.report(Exception('malformed'), StackTrace.current);

        expect(service.isCorrupted.value, isTrue);
      });

      test('persists the flag so the next launch salvages', () async {
        final service = build();

        service.report(Exception('malformed'), StackTrace.current);
        await service.recoveryPersisted;

        expect(
          prefs.getBool(DatabaseCorruptionService.pendingRecoveryKey),
          isTrue,
        );
        expect(build().hasPendingRecovery, isTrue);
      });

      test('recoveryPersisted resolves only once the flag is written', () async {
        final service = build();
        service.report(Exception('malformed'), StackTrace.current);

        // The restart prompt gates its close button on this future, so it must
        // not resolve while the write that makes recovery possible is still in
        // flight — closing early would strand the user on the same database.
        await service.recoveryPersisted;

        expect(build().hasPendingRecovery, isTrue);
      });

      test(
        'recoveryPersisted resolves immediately before any report',
        () async {
          await build().recoveryPersisted.timeout(const Duration(seconds: 1));
        },
      );

      test('reports the error once, not per failing statement', () async {
        final reported = <Object>[];
        final service = build(
          recordError: (error, _) async => reported.add(error),
        );

        // A corrupt database throws from many statements in a row.
        service.report(Exception('first'), StackTrace.current);
        service.report(Exception('second'), StackTrace.current);
        service.report(Exception('third'), StackTrace.current);
        await pumpEventQueue();

        expect(reported, hasLength(1));
        expect(reported.single.toString(), contains('first'));
      });

      test('files the incident as a DatabaseCorruptionEvent', () async {
        // The wrapper is what keeps every runtime detection in one Crashlytics
        // group and what lets the incident through the echo filter below.
        final reported = <Object>[];
        final service = build(
          recordError: (error, _) async => reported.add(error),
        );

        service.report(_realCorruptionException, StackTrace.current);
        await pumpEventQueue();

        expect(
          reported.single,
          isA<DatabaseCorruptionEvent>().having(
            (event) => event.cause,
            'cause',
            same(_realCorruptionException),
          ),
        );
      });

      test('files the incident with a trace from the service', () async {
        // A Drift failure forwarded from the database isolate carries no
        // frames Crashlytics can render, so the trace has to come from here
        // for the group to key on a stable frame instead of the statement.
        StackTrace? filed;
        final service = build(
          recordError: (_, stackTrace) async => filed = stackTrace,
        );

        service.report(_realCorruptionException, StackTrace.empty);
        await pumpEventQueue();

        expect(filed.toString(), contains('DatabaseCorruptionService.report'));
      });

      test('retries a refused flag write before giving up', () async {
        final failing = _MockSharedPreferences();
        var attempts = 0;
        when(() => failing.setBool(any(), any())).thenAnswer((_) async {
          attempts += 1;
          // setBool reports a refused write by returning false rather than
          // throwing, and report() drops every later corruption report, so an
          // unnoticed false would leave the next launch with no reason to
          // salvage.
          return attempts > 1;
        });
        final service = DatabaseCorruptionService(preferences: failing);
        addTearDown(service.dispose);

        service.report(Exception('malformed'), StackTrace.current);
        await service.recoveryPersisted;

        expect(attempts, equals(2));
      });

      test(
        'releases the restart prompt when the flag write keeps failing',
        () async {
          final failing = _MockSharedPreferences();
          when(
            () => failing.setBool(any(), any()),
          ).thenThrow(Exception('disk full'));
          final service = DatabaseCorruptionService(preferences: failing);
          addTearDown(service.dispose);

          service.report(Exception('malformed'), StackTrace.current);

          // The button waits on this future. If a doomed write left it pending
          // the user would be locked in a session that cannot recover at all.
          await service.recoveryPersisted.timeout(const Duration(seconds: 1));
          expect(service.isCorrupted.value, isTrue);
        },
      );

      test('does not throw when reporting the non-fatal fails', () async {
        final service = build(
          recordError: (_, _) async => throw Exception('crashlytics down'),
        );

        service.report(Exception('malformed'), StackTrace.current);
        await pumpEventQueue();

        // The database is already broken; telemetry must not make it worse by
        // throwing into whichever query tripped the corruption.
        expect(service.isCorrupted.value, isTrue);
        expect(
          prefs.getBool(DatabaseCorruptionService.pendingRecoveryKey),
          isTrue,
        );
      });
    });

    group('hasPendingRecovery', () {
      test('is false on a healthy install', () {
        expect(build().hasPendingRecovery, isFalse);
      });

      test('survives into a new service instance', () async {
        SharedPreferences.setMockInitialValues({
          DatabaseCorruptionService.pendingRecoveryKey: true,
        });
        prefs = await SharedPreferences.getInstance();

        expect(build().hasPendingRecovery, isTrue);
      });
    });

    group('clearPendingRecovery', () {
      test(
        'clears the flag so recovery does not repeat every launch',
        () async {
          SharedPreferences.setMockInitialValues({
            DatabaseCorruptionService.pendingRecoveryKey: true,
          });
          prefs = await SharedPreferences.getInstance();
          final service = build();

          await service.clearPendingRecovery();

          expect(service.hasPendingRecovery, isFalse);
        },
      );
    });

    group('echoesReportedCorruption', () {
      /// The error every downstream bloc sees while the database is broken:
      /// a Drift failure forwarded from the background isolate, wrapped at the
      /// `addError` call site. `_publishLike` is a real reporting site behind
      /// one of the duplicate Crashlytics groups in #7507.
      Reportable<Object> blocCorruptionFailure() =>
          Reportable(_realCorruptionException, context: '_publishLike');

      test('claims nothing while the database looks healthy', () {
        // Without this half, the classification alone would drop the very
        // first corrupt statement — the report worth keeping.
        final service = build();

        expect(
          service.echoesReportedCorruption(_realCorruptionException),
          isFalse,
        );
        expect(
          service.echoesReportedCorruption(blocCorruptionFailure()),
          isFalse,
        );
      });

      test('claims the raw failure once corruption is known', () {
        final service = build()
          ..report(_realCorruptionException, StackTrace.current);

        expect(
          service.echoesReportedCorruption(_realCorruptionException),
          isTrue,
        );
      });

      test('claims the failure wrapped at a bloc call site', () {
        final service = build()
          ..report(_realCorruptionException, StackTrace.current);

        expect(
          service.echoesReportedCorruption(blocCorruptionFailure()),
          isTrue,
        );
      });

      test('claims an extended corruption code', () {
        // 779 is SQLITE_CORRUPT_INDEX: the primary code lives in the low byte.
        final service = build()
          ..report(_realCorruptionException, StackTrace.current);

        expect(
          service.echoesReportedCorruption(
            SqliteException(
              extendedResultCode: 779,
              message: 'database disk image is malformed',
              explanation: 'database disk image is malformed (code 779)',
              operation: 'executing statement',
              causingStatement: 'INSERT OR REPLACE INTO event (id) VALUES (?)',
              parametersToStatement: <Object?>['abc123'],
            ),
          ),
          isTrue,
        );
      });

      test('claims the real ParallelWaitError signature', () async {
        // Signature 5 of #7507, raised from
        // `NotificationFeedBloc._onRefreshed`: the corrupt statement is one
        // leg of a record `.wait`, and `ParallelWaitError` extends `Error`, so
        // it lands in that handler's generic catch and is wrapped there.
        //
        // Built by actually failing a `.wait` rather than by hand-writing what
        // it prints — the gate's whole job is reading a string the SDK
        // produces, so a fabricated one would prove nothing about the fix.
        final service = build()
          ..report(_realCorruptionException, StackTrace.current);

        Object? raised;
        try {
          await (
            Future<int>.error(_realCorruptionException),
            Future<String>.value('ok'),
          ).wait;
        } on Object catch (error) {
          raised = error;
        }

        expect(
          service.echoesReportedCorruption(
            Reportable(raised!, context: '_onRefreshed'),
          ),
          isTrue,
        );
      });

      test('claims a corruption a wrapper pushed off the header line', () {
        // `CouldNotRollBackException` prints the ROLLBACK's own failure first
        // and the error that triggered the rollback below it, so the SQLite
        // header is not on line 1. This is the shape that requires
        // `mentionsDatabaseCorruption` rather than the header-only classifier;
        // every other wrapper in play keeps the header on line 1.
        final service = build()
          ..report(_realCorruptionException, StackTrace.current);

        expect(
          service.echoesReportedCorruption(
            Reportable(
              CouldNotRollBackException(
                _realCorruptionException,
                StackTrace.empty,
                StateError('connection closed'),
              ),
              context: '_onVoteCountsFetchRequested',
            ),
          ),
          isTrue,
        );
      });

      test('lets its own incident report through', () async {
        // The filter reads the same flag report() flips, and the report is
        // filed after the flip — so without this exemption the one report
        // worth keeping would be the first thing the filter drops.
        final reported = <Object>[];
        final service = build(
          recordError: (error, _) async => reported.add(error),
        )..report(_realCorruptionException, StackTrace.current);
        await pumpEventQueue();

        expect(reported.single, isA<DatabaseCorruptionEvent>());
        expect(service.echoesReportedCorruption(reported.single), isFalse);
      });

      test('leaves an unrelated defect alone while corruption is known', () {
        // The gate must narrow to the handled failure. A programming-invariant
        // error that happens to fire after the flag flips is still a defect.
        final service = build()
          ..report(_realCorruptionException, StackTrace.current);

        expect(
          service.echoesReportedCorruption(
            Reportable(StateError('boom'), context: 'unrelated'),
          ),
          isFalse,
        );
      });

      test('leaves quoted corruption text in bound user data alone', () {
        final service = build()
          ..report(_realCorruptionException, StackTrace.current);

        expect(
          service.echoesReportedCorruption(
            Reportable(_quotedCorruptionInUserData, context: '_publishLike'),
          ),
          isFalse,
        );
      });
    });
  });

  group(DatabaseCorruptionEvent, () {
    test('keeps the result code and statement, drops bound parameters', () {
      // Bound parameters are user content — event JSON, pubkeys, signatures —
      // and neither belong in a crash report nor make a useful grouping key.
      final text = DatabaseCorruptionEvent(_realCorruptionException).toString();

      expect(text, startsWith('DatabaseCorruptionEvent: SqliteException(26)'));
      expect(text, contains('Causing statement: PRAGMA user_version;'));
      expect(text, isNot(contains('parameters')));
      expect(text, isNot(contains('abc123')));
    });

    test('passes a cause without bound parameters through whole', () {
      final text = DatabaseCorruptionEvent(
        StateError('database disk image is malformed'),
      ).toString();

      expect(
        text,
        'DatabaseCorruptionEvent: Bad state: database disk image is malformed',
      );
    });
  });
}
