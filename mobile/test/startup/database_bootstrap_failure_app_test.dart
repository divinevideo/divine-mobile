import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/database_encryption_bootstrap.dart';
import 'package:openvine/startup/database_bootstrap_failure_app.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  // Resolved from the ARB rather than hardcoded, so the assertions
  // survive copy changes and break loudly if the screen stops reading
  // from l10n (it shipped fully hardcoded until this change).
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('resolveDatabaseBootstrapForAppStart', () {
    test('returns the cipher key without rendering failure UI', () async {
      var removedSplash = false;
      Widget? renderedApp;

      final result = await resolveDatabaseBootstrapForAppStart(
        resolveCipherKey: () async => 'a' * 64,
        removeNativeSplash: () => removedSplash = true,
        runApp: (app) => renderedApp = app,
      );

      expect(result.didRenderFailureApp, isFalse);
      expect(result.cipherKey, equals('a' * 64));
      expect(removedSplash, isFalse);
      expect(renderedApp, isNull);
    });

    test(
      'renders a visible failure app and removes native splash on error',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        final error = StateError('secure storage unavailable');

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async => throw error,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(result.cipherKey, isNull);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'repairs local database cache and retries before rendering failure UI',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;
        final error = StateError('database bootstrap failed');

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            if (attempts == 1) throw error;
            return 'b' * 64;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache: (_) => true,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isFalse);
        expect(result.cipherKey, equals('b' * 64));
        expect(attempts, equals(2));
        expect(repaired, isTrue);
        expect(removedSplash, isFalse);
        expect(renderedApp, isNull);
      },
    );

    test(
      'renders failure UI only after automatic repair retry fails',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            throw StateError('database bootstrap failed $attempts');
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache: (_) => true,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(result.cipherKey, isNull);
        expect(attempts, equals(2));
        expect(repaired, isTrue);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'does not repair when the bootstrap error is not repairable',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;
        final error = StateError('SQLCipher is not linked');

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            throw error;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache: (_) => false,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(result.cipherKey, isNull);
        expect(attempts, equals(1));
        expect(repaired, isFalse);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'does not implicitly repair when no repair predicate is provided',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;
        final error = SqliteException(
          extendedResultCode: 26,
          message: 'file is not a database',
        );

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            throw error;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(attempts, equals(1));
        expect(repaired, isFalse);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'does not repair secure-storage failures',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;
        final error = DatabaseCipherStorageUnavailableException(
          _lockedKeychainFailure(),
        );

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            throw error;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache:
              shouldRepairLocalDatabaseCacheAfterBootstrapError,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(attempts, equals(1));
        expect(repaired, isFalse);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );

    test(
      'repairs allowlisted sqlite corruption failures',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        var attempts = 0;
        var repaired = false;

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async {
            attempts += 1;
            if (attempts == 1) {
              throw SqliteException(
                extendedResultCode: 26,
                message: 'file is not a database',
              );
            }
            return 'c' * 64;
          },
          repairLocalDatabaseCache: (error, stack) async {
            repaired = true;
          },
          shouldRepairLocalDatabaseCache:
              shouldRepairLocalDatabaseCacheAfterBootstrapError,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isFalse);
        expect(result.cipherKey, equals('c' * 64));
        expect(attempts, equals(2));
        expect(repaired, isTrue);
        expect(removedSplash, isFalse);
        expect(renderedApp, isNull);
      },
    );
  });

  group('resolveDatabaseBootstrapForAppStart reset wiring', () {
    test('hands the reset hook to the failure app', () async {
      Widget? renderedApp;
      Future<void> reset(DatabaseBootstrapDiagnosis diagnosis) async {}

      await resolveDatabaseBootstrapForAppStart(
        resolveCipherKey: () async => throw StateError('bootstrap failed'),
        resetLocalDatabase: reset,
        removeNativeSplash: () {},
        runApp: (app) => renderedApp = app,
      );

      expect(
        (renderedApp! as DatabaseBootstrapFailureApp).onResetLocalDatabase,
        same(reset),
      );
    });
  });

  group(DatabaseBootstrapFailureApp, () {
    testWidgets('shows a visible database startup failure screen', (
      tester,
    ) async {
      var closed = false;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: DatabaseCipherStorageUnavailableException(
            _lockedKeychainFailure(),
          ),
          stack: StackTrace.current,
          onCloseApp: () => closed = true,
        ),
      );

      expect(
        find.text(l10n.dbFailureTitle),
        findsOneWidget,
      );
      expect(find.text(l10n.dbFailureAdviceRestart), findsOneWidget);
      // The rendered code is what a support report is triaged from, so pin the
      // value rather than just the label.
      expect(
        find.text(l10n.dbFailureDiagnostic('db-secure-storage')),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.dbFailureCloseApp));
      expect(closed, isTrue);
    });

    testWidgets('hides the close action on iOS by platform default', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          DatabaseBootstrapFailureApp(
            error: DatabaseCipherStorageUnavailableException(
              _lockedKeychainFailure(),
            ),
            stack: StackTrace.current,
          ),
        );

        expect(find.text(l10n.dbFailureCloseApp), findsNothing);
        expect(find.text(l10n.dbFailureAdviceRestart), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('classifies cipher availability failures for release diagnostics', () {
      expect(
        databaseBootstrapDiagnosticCode(
          DatabaseCipherUnavailableError(),
        ),
        equals('db-cipher-unavailable'),
      );
    });

    test('classifies an unreachable keystore as a secure-storage failure', () {
      expect(
        databaseBootstrapDiagnosticCode(
          DatabaseCipherStorageUnavailableException(_lockedKeychainFailure()),
        ),
        equals('db-secure-storage'),
      );
    });

    test('classifies a key that no longer opens the database', () {
      expect(
        databaseBootstrapDiagnosticCode(
          SqliteException(
            extendedResultCode: 26,
            message: 'file is not a database',
          ),
        ),
        equals('db-cipher-mismatch'),
      );
    });

    test('classifies a database damaged past classification', () {
      expect(
        databaseBootstrapDiagnosticCode(const DatabaseUnreadableError()),
        equals('db-unreadable'),
      );
    });

    test('classifies an indeterminate database without offering reset', () {
      const error = DatabaseClassificationException(
        stage: DatabaseClassificationStage.readSchema,
        resultCode: 5,
        extendedResultCode: 5,
      );

      expect(
        databaseBootstrapDiagnosticCode(error),
        equals('db-classification-unavailable'),
      );
      expect(databaseBootstrapDiagnosis(error).allowsLocalDatabaseReset, false);
    });

    test('classifies an unrecovered hot journal without offering reset', () {
      const error = DatabaseHotJournalRecoveryError(
        stage: DatabaseHotJournalRecoveryStage.validateIntegrity,
      );

      expect(
        databaseBootstrapDiagnosticCode(error),
        equals('db-journal-unrecovered'),
      );
      expect(databaseBootstrapDiagnosis(error).allowsLocalDatabaseReset, false);
    });

    test('falls back to the catch-all for unrecognized failures', () {
      expect(
        databaseBootstrapDiagnosticCode(StateError('something else entirely')),
        equals('db-bootstrap-failed'),
      );
    });

    testWidgets('offers no reset when the caller supplies no hook', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
        ),
      );

      expect(find.text(l10n.dbFailureResetAction), findsNothing);
    });

    testWidgets('offers no reset for a locked keystore', (tester) async {
      // The database is intact here and the reset would delete the key that
      // opens it. Offering the button would be worse than offering nothing.
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: DatabaseCipherStorageUnavailableException(
            _lockedKeychainFailure(),
          ),
          stack: StackTrace.current,
          onResetLocalDatabase: (_) async {},
        ),
      );

      expect(
        find.text(l10n.dbFailureDiagnostic('db-secure-storage')),
        findsOneWidget,
      );
      expect(find.text(l10n.dbFailureResetAction), findsNothing);
    });

    testWidgets('shows journal-specific advice without offering reset', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: const DatabaseHotJournalRecoveryError(
            stage: DatabaseHotJournalRecoveryStage.replayJournal,
          ),
          stack: StackTrace.current,
          onResetLocalDatabase: (_) async {},
        ),
      );

      expect(find.text(l10n.dbFailureAdviceHotJournal), findsOneWidget);
      expect(find.text(l10n.dbFailureAdviceRestart), findsNothing);
      expect(find.text(l10n.dbFailureResetAction), findsNothing);
    });

    testWidgets('drops the unlock-and-restart advice when a reset is offered', (
      tester,
    ) async {
      // Telling the user to restart after unlocking is the fix for the
      // keystore case only, and misleading next to a reset button.
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onResetLocalDatabase: (_) async {},
        ),
      );

      expect(
        find.text(l10n.dbFailureAdviceRestart),
        findsNothing,
      );
      expect(
        find.text(l10n.dbFailureAdviceResettable),
        findsOneWidget,
      );
    });

    testWidgets('resets and closes once the user confirms', (tester) async {
      DatabaseBootstrapDiagnosis? resetDiagnosis;
      var closed = false;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onCloseApp: () => closed = true,
          onResetLocalDatabase: (diagnosis) async => resetDiagnosis = diagnosis,
        ),
      );

      await tester.tap(find.text(l10n.dbFailureResetAction));
      await tester.pump();

      expect(find.text(l10n.dbFailureConfirmTitle), findsOneWidget);
      expect(find.text(l10n.dbFailureConfirmBody), findsOneWidget);
      expect(resetDiagnosis, isNull, reason: 'confirmation must gate the wipe');

      await tester.tap(find.text(l10n.dbFailureResetConfirm));
      await tester.pump();

      expect(resetDiagnosis, DatabaseBootstrapDiagnosis.bootstrapFailed);
      expect(closed, isTrue);
    });

    testWidgets('passes the database-unreadable diagnosis to reset', (
      tester,
    ) async {
      DatabaseBootstrapDiagnosis? resetDiagnosis;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: const DatabaseUnreadableError(),
          stack: StackTrace.current,
          onResetLocalDatabase: (diagnosis) async => resetDiagnosis = diagnosis,
        ),
      );

      await tester.tap(find.text(l10n.dbFailureResetAction));
      await tester.pump();
      await tester.tap(find.text(l10n.dbFailureResetConfirm));
      await tester.pump();

      expect(resetDiagnosis, DatabaseBootstrapDiagnosis.databaseUnreadable);
    });

    testWidgets('returns to the failure screen on cancel', (tester) async {
      var resets = 0;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onResetLocalDatabase: (_) async => resets++,
        ),
      );

      await tester.tap(find.text(l10n.dbFailureResetAction));
      await tester.pump();
      await tester.tap(find.text(l10n.dbFailureCancel));
      await tester.pump();

      expect(find.text(l10n.dbFailureTitle), findsOneWidget);
      expect(resets, isZero);
    });

    testWidgets('stays put and reports when the reset itself fails', (
      tester,
    ) async {
      var closed = false;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onCloseApp: () => closed = true,
          onResetLocalDatabase: (_) async =>
              throw StateError('keystore delete failed'),
        ),
      );

      await tester.tap(find.text(l10n.dbFailureResetAction));
      await tester.pump();
      await tester.tap(find.text(l10n.dbFailureResetConfirm));
      await tester.pump();

      expect(find.text(l10n.dbFailureResetFailed), findsOneWidget);
      expect(
        closed,
        isFalse,
        reason: 'closing would claim a reset that never happened',
      );
    });

    testWidgets('lands on a terminal step when the app cannot close itself', (
      tester,
    ) async {
      // SystemNavigator.pop cannot end the process on iOS, so without this
      // step a successful reset leaves a spinner behind two disabled buttons.
      var closes = 0;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          canCloseApp: false,
          onCloseApp: () => closes++,
          onResetLocalDatabase: (_) async {},
        ),
      );

      await tester.tap(find.text(l10n.dbFailureResetAction));
      await tester.pump();
      await tester.tap(find.text(l10n.dbFailureResetConfirm));
      await tester.pump();

      expect(find.text(l10n.dbFailureResetDoneTitle), findsOneWidget);
      expect(find.text(l10n.dbFailureResetConfirm), findsNothing);
      expect(closes, isZero);

      expect(find.text(l10n.dbFailureCloseApp), findsNothing);
      expect(find.text(l10n.dbFailureResetDoneBody), findsOneWidget);
      expect(
        closes,
        isZero,
        reason: 'the terminal step must not offer another dead close action',
      );
    });

    testWidgets('keeps the terminal close action on Android', (tester) async {
      var closes = 0;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          canCloseApp: true,
          onCloseApp: () => closes++,
          onResetLocalDatabase: (_) async {},
        ),
      );

      await tester.tap(find.text(l10n.dbFailureResetAction));
      await tester.pump();
      await tester.tap(find.text(l10n.dbFailureResetConfirm));
      await tester.pump();

      expect(closes, equals(1));
      expect(find.text(l10n.dbFailureCloseApp), findsOneWidget);

      await tester.tap(find.text(l10n.dbFailureCloseApp));
      expect(closes, equals(2));
    });

    testWidgets('reports a reset that hangs instead of spinning forever', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onResetLocalDatabase: (_) => Completer<void>().future,
        ),
      );

      await tester.tap(find.text(l10n.dbFailureResetAction));
      await tester.pump();
      await tester.tap(find.text(l10n.dbFailureResetConfirm));
      await tester.pump(const Duration(seconds: 16));

      expect(find.text(l10n.dbFailureResetFailed), findsOneWidget);

      await tester.tap(find.text(l10n.dbFailureCancel));
      await tester.pump();
      expect(
        find.text(l10n.dbFailureTitle),
        findsOneWidget,
        reason: 'a wedged platform call must not disable the way back',
      );
    });

    testWidgets('drops a stale failure banner when the step is re-entered', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('something else entirely'),
          stack: StackTrace.current,
          onResetLocalDatabase: (_) async => throw StateError('nope'),
        ),
      );

      await tester.tap(find.text(l10n.dbFailureResetAction));
      await tester.pump();
      await tester.tap(find.text(l10n.dbFailureResetConfirm));
      await tester.pump();
      expect(find.text(l10n.dbFailureResetFailed), findsOneWidget);

      await tester.tap(find.text(l10n.dbFailureCancel));
      await tester.pump();
      await tester.tap(find.text(l10n.dbFailureResetAction));
      await tester.pump();

      expect(
        find.text(l10n.dbFailureResetFailed),
        findsNothing,
        reason: 'the banner belongs to an attempt, not to the step',
      );
    });
  });

  group(DatabaseBootstrapDiagnosis, () {
    test('allows a reset only where the database is already unusable', () {
      expect(
        DatabaseBootstrapDiagnosis.values
            .where((d) => d.allowsLocalDatabaseReset)
            .toSet(),
        equals({
          DatabaseBootstrapDiagnosis.cipherMismatch,
          DatabaseBootstrapDiagnosis.databaseUnreadable,
          DatabaseBootstrapDiagnosis.bootstrapFailed,
        }),
      );
    });
  });

  group('shouldRepairLocalDatabaseCacheAfterBootstrapError', () {
    test('allowlists sqlite not-a-database and corruption errors', () {
      expect(
        shouldRepairLocalDatabaseCacheAfterBootstrapError(
          SqliteException(
            extendedResultCode: 26,
            message: 'file is not a database',
          ),
        ),
        isTrue,
      );
      expect(
        shouldRepairLocalDatabaseCacheAfterBootstrapError(
          SqliteException(
            extendedResultCode: 11,
            message: 'database disk image is malformed',
          ),
        ),
        isTrue,
      );
    });

    test('excludes cipher linkage and secure-storage failures', () {
      expect(
        shouldRepairLocalDatabaseCacheAfterBootstrapError(
          DatabaseCipherUnavailableError(),
        ),
        isFalse,
      );
      // Repairing deletes the cipher key. The database behind a locked keychain
      // is intact, so clearing it would turn a restart-and-retry into
      // permanent loss of every local-only draft and clip.
      expect(
        shouldRepairLocalDatabaseCacheAfterBootstrapError(
          DatabaseCipherStorageUnavailableException(_lockedKeychainFailure()),
        ),
        isFalse,
      );
    });

    test('excludes an unreadable database despite its message matching the '
        'corruption allowlist', () {
      // Unusable, but the automatic repair also rotates the cipher key, and
      // nothing proves the stored one is stale — rotating it would strand any
      // encrypted backup beside the damaged file. The failure screen offers the
      // same reset with the key kept, so the user chooses the data loss.
      const error = DatabaseUnreadableError();
      expect(
        error.toString(),
        contains('SQLITE_CORRUPT'),
        reason:
            'the type check is only load-bearing while the message would '
            'otherwise match the allowlist below it — without this the '
            'expectation that follows passes no matter what the function does',
      );
      expect(shouldRepairLocalDatabaseCacheAfterBootstrapError(error), isFalse);
    });
  });

  group('DatabaseBootstrapFailureApp localization', () {
    // This screen shipped 100% hardcoded English to all 21 non-English
    // locales — it builds its own MaterialApp before startup finishes, so it
    // inherited no delegates from anywhere. These are the tests a regression
    // back to constants cannot pass.
    final es = lookupAppLocalizations(const Locale('es'));

    test('keeps the reset confirmation platform neutral', () {
      expect(
        l10n.dbFailureResetConfirm.toLowerCase(),
        isNot(contains('close')),
      );
    });

    testWidgets('renders the failure step in the requested locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: DatabaseCipherStorageUnavailableException(
            _lockedKeychainFailure(),
          ),
          stack: StackTrace.current,
          locale: const Locale('es'),
        ),
      );

      expect(find.text(es.dbFailureTitle), findsOneWidget);
      expect(find.text(es.dbFailureAdviceRestart), findsOneWidget);
      expect(find.text(es.dbFailureCloseApp), findsOneWidget);
      expect(find.text(l10n.dbFailureTitle), findsNothing);
    });

    testWidgets('carries the locale through the reset confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('SQLITE_NOTADB: demo'),
          stack: StackTrace.current,
          locale: const Locale('es'),
          onResetLocalDatabase: (_) async {},
        ),
      );

      await tester.tap(find.text(es.dbFailureResetAction));
      await tester.pumpAndSettle();

      expect(find.text(es.dbFailureConfirmTitle), findsOneWidget);
      expect(find.text(es.dbFailureConfirmBody), findsOneWidget);
      expect(find.text(es.dbFailureResetConfirm), findsOneWidget);
      expect(find.text(es.dbFailureCancel), findsOneWidget);
    });

    testWidgets('falls back to the device locale when none is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: DatabaseCipherStorageUnavailableException(
            _lockedKeychainFailure(),
          ),
          stack: StackTrace.current,
        ),
      );

      // resolveAppUiLocale picks English rather than supportedLocales.first,
      // which is Arabic.
      expect(find.text(l10n.dbFailureTitle), findsOneWidget);
    });
  });
}

/// What `flutter_secure_storage` raises when the Keychain refuses a read on a
/// still-locked device: a platform status code and no prose, which is why
/// classifying this case by message never matched.
PlatformException _lockedKeychainFailure() => PlatformException(
  code: 'Unexpected security result code',
  message: 'Code: -25308, Message: User interaction is not allowed.',
);
