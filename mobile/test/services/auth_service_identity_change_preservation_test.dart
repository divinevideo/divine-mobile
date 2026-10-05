// ABOUTME: Regression tests for #4625 — owner-scoped drafts, clips, and
// ABOUTME: pending uploads must NOT be deleted on non-destructive identity change.

import 'dart:async';
import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/constants/terms_acceptance_keys.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _RefusingPreferences extends Fake implements SharedPreferences {
  _RefusingPreferences(this.backing);
  final SharedPreferences backing;
  final refusedKeys = <String>[];

  @override
  Object? get(String key) => backing.get(key);
  @override
  String? getString(String key) => backing.getString(key);
  @override
  bool containsKey(String key) => backing.containsKey(key);
  @override
  Set<String> getKeys() => backing.getKeys();
  @override
  Future<bool> remove(String key) async {
    refusedKeys.add(key);
    return false;
  }

  @override
  Future<bool> setString(String key, String value) =>
      backing.setString(key, value);
}

class _MockCacheDao extends Mock implements CacheDao {}

class _RefusingQuarantinePreferences extends Fake implements SharedPreferences {
  _RefusingQuarantinePreferences(this.backing, {required this.throwing});
  final SharedPreferences backing;
  final bool throwing;
  int quarantineAttempts = 0;

  @override
  Object? get(String key) => backing.get(key);
  @override
  String? getString(String key) => backing.getString(key);
  @override
  bool containsKey(String key) => backing.containsKey(key);
  @override
  Set<String> getKeys() => backing.getKeys();
  @override
  Future<void> reload() => backing.reload();
  @override
  Future<bool> setString(String key, String value) async {
    if (key.startsWith(CuratedListRecoveryStorage.quarantinePrefix)) {
      quarantineAttempts++;
      if (throwing) throw StateError('PRIVATE_CLEANUP_PAYLOAD');
      return false;
    }
    return backing.setString(key, value);
  }
}

/// Runs [body] while silencing unhandled async errors from `_performDiscovery`.
///
/// `_setupUserSession` fires `unawaited(_performDiscovery())` which creates a
/// `NostrClient` that tries to open a WebSocket. In the test environment this
/// throws asynchronously ("Unsupported operation: Mocked response") and the
/// test runner flags it as a test failure. Wrapping with `runZonedGuarded`
/// prevents that unhandled error from reaching the test zone.
Future<T> _ignoringDiscoveryErrors<T>(Future<T> Function() body) async {
  final completer = Completer<T>();
  await runZonedGuarded(
    () async {
      try {
        final result = await body();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    },
    (error, stack) {
      // Silently absorb async errors from unawaited _performDiscovery
    },
  );
  return completer.future;
}

void main() {
  setupTestEnvironment();

  // Regression: #4625 — account-switch identity change must not delete
  // owner-scoped local content (drafts, clips, pending uploads).

  group('AuthService identity-change data preservation (issue #4625)', () {
    late _MockSecureKeyStorage mockKeyStorage;
    late _MockUserDataCleanupService mockCleanupService;
    late AuthService authService;

    const testNsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    // The old user's pubkey is seeded in SharedPreferences so that
    // shouldClearDataForUser() detects an identity change when the new user
    // (derived from testNsec) signs in.
    const oldPubkeyHex =
        'c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e';

    late SecureKeyContainer newKeyContainer;

    setUpAll(() {
      // mocktail requires a registered fallback for any type used with any()
      // in positional argument position. SecureKeyContainer appears as the
      // second arg of storeIdentityKeyContainer(npub, container).
      registerFallbackValue(SecureKeyContainer.fromNsec(testNsec));
    });

    setUp(() {
      // Pre-seed SharedPreferences with the OLD user's pubkey so that
      // shouldClearDataForUser() returns true when the new user signs in.
      SharedPreferences.setMockInitialValues({
        'current_user_pubkey_hex': oldPubkeyHex,
        'authentication_source': 'imported_keys',
        'kKnownAccounts': '[]',
      });

      mockKeyStorage = _MockSecureKeyStorage();
      mockCleanupService = _MockUserDataCleanupService();

      // The new account will use testNsec keys.
      newKeyContainer = SecureKeyContainer.fromNsec(testNsec);

      // Default key-storage stubs.
      when(() => mockKeyStorage.initialize()).thenAnswer((_) async {});
      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
      when(() => mockKeyStorage.clearCache()).thenReturn(null);
      when(() => mockKeyStorage.dispose()).thenReturn(null);
      when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {});
      when(() => mockKeyStorage.deleteIdentityKeyContainer(any()))
          .thenAnswer((_) async {});
      when(() => mockKeyStorage.generateAndStoreKeys())
          .thenAnswer((_) async => newKeyContainer);
      when(() => mockKeyStorage.importFromNsec(any()))
          .thenAnswer((_) async => newKeyContainer);
      when(() => mockKeyStorage.importFromHex(any()))
          .thenAnswer((_) async => newKeyContainer);
      when(() => mockKeyStorage.storeIdentityKeyContainer(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockKeyStorage.getIdentityKeyContainer(any()))
          .thenAnswer((_) async => newKeyContainer);
      when(() => mockKeyStorage.getKeyContainer())
          .thenAnswer((_) async => newKeyContainer);
      when(() => mockKeyStorage.switchToIdentity(any()))
          .thenAnswer((_) async => true);

      // Cleanup service stubs: shouldClearDataForUser returns true (different
      // user), and clearUserSpecificData/claimLegacyRows complete normally.
      when(() => mockCleanupService.shouldClearDataForUser(any()))
          .thenReturn(true);
      when(
        () => mockCleanupService.clearUserSpecificData(
          reason: any(named: 'reason'),
          isIdentityChange: any(named: 'isIdentityChange'),
          userPubkey: any(named: 'userPubkey'),
          deleteUserData: any(named: 'deleteUserData'),
        ),
      ).thenAnswer((_) async => 0);
      when(() => mockCleanupService.claimLegacyRows(any()))
          .thenAnswer((_) async {});
      when(() => mockCleanupService.markOwnerScopedLegacyDataForUser(any()))
          .thenAnswer((_) async {});

      authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
      );
    });

    tearDown(() async {
      await authService.dispose();
    });

    test(
      'identity-change in _setupUserSession passes deleteUserData: false',
      () async {
        // Signing in as the "new" user triggers an identity change because
        // SharedPreferences holds the old pubkey.
        await _ignoringDiscoveryErrors(authService.createNewIdentity);

        // The cleanup call that fires during _setupUserSession (identity
        // change) must NOT request per-user DAO deletion.  deleteUserData
        // must be false so owner-scoped drafts/clips/uploads are preserved.
        verify(
          () => mockCleanupService.clearUserSpecificData(
            reason: 'identity_change',
            isIdentityChange: true,
            userPubkey: any(named: 'userPubkey'),
            // Explicit false is the identity-preservation regression guard.
            // ignore: avoid_redundant_argument_values
            deleteUserData: false, // ← the regression guard: must NOT be true
          ),
        ).called(1);

        // No call with deleteUserData: true must have occurred from
        // _setupUserSession.
        verifyNever(
          () => mockCleanupService.clearUserSpecificData(
            reason: 'identity_change',
            isIdentityChange: any(named: 'isIdentityChange'),
            userPubkey: any(named: 'userPubkey'),
            deleteUserData: true,
          ),
        );
      },
    );

    test('identity-change cleanup passes old pubkey as userPubkey', () async {
      // Ensure the old pubkey is correctly threaded through even when
      // we are signing in as the new user.
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      final captured = verify(
        () => mockCleanupService.clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true,
          userPubkey: captureAny(named: 'userPubkey'),
          // Explicit false is the identity-preservation regression guard.
          // ignore: avoid_redundant_argument_values
          deleteUserData: false, // regression guard: must NOT be true
        ),
      ).captured;

      // The old pubkey from SharedPreferences must be forwarded so
      // per-user cache keys can be scoped correctly even though we do
      // not delete the underlying data.
      expect(captured.single, equals(oldPubkeyHex));
    });

    test('remove-device signOut (deleteKeys: true) preserves user data by default', () async {
      // First sign in so there is a current identity to sign out from.
      when(() => mockCleanupService.shouldClearDataForUser(any()))
          .thenReturn(false);
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      // Now remove local login material. This must not delete device-local
      // drafts/clips because they are scoped by ownerPubkey.
      when(
        () => mockCleanupService.clearUserSpecificData(
          reason: any(named: 'reason'),
          userPubkey: any(named: 'userPubkey'),
          deleteUserData: any(named: 'deleteUserData'),
        ),
      ).thenAnswer((_) async => 0);

      await authService.signOut(deleteKeys: true);

      // The explicit-logout path preserves owner-scoped local data by default.
      verify(
        () => mockCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: any(named: 'userPubkey'),
          // Explicit false distinguishes explicit logout from deletion.
          // ignore: avoid_redundant_argument_values
          deleteUserData: false,
        ),
      ).called(1);
    });

    test('account deletion opts in to deleting local user data', () async {
      final cacheDao = _MockCacheDao();
      when(() => cacheDao.deletePrefix(any())).thenAnswer((_) async {});
      await CacheSync.init(dao: cacheDao);
      when(() => mockCleanupService.shouldClearDataForUser(any()))
          .thenReturn(false);
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      when(
        () => mockCleanupService.clearUserSpecificData(
          reason: any(named: 'reason'),
          userPubkey: any(named: 'userPubkey'),
          deleteUserData: any(named: 'deleteUserData'),
        ),
      ).thenAnswer((_) async => 0);

      await authService.signOut(deleteKeys: true, deleteLocalUserData: true);

      verify(
        () => mockCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: any(named: 'userPubkey'),
          deleteUserData: true,
        ),
      ).called(1);
    });

    test(
      'non-destructive signOut (account switch) passes deleteUserData: false',
      () async {
        // Sign in first.
        when(() => mockCleanupService.shouldClearDataForUser(any()))
            .thenReturn(false);
        await _ignoringDiscoveryErrors(authService.createNewIdentity);

        when(
          () => mockCleanupService.clearUserSpecificData(
            reason: any(named: 'reason'),
            userPubkey: any(named: 'userPubkey'),
            deleteUserData: any(named: 'deleteUserData'),
          ),
        ).thenAnswer((_) async => 0);
        when(() => mockKeyStorage.clearCache()).thenReturn(null);

        await authService.signOut();

        // Account switch must preserve owner-scoped data.
        verify(
          () => mockCleanupService.clearUserSpecificData(
            reason: 'explicit_logout',
            userPubkey: any(named: 'userPubkey'),
            // Explicit false distinguishes explicit logout from deletion.
            // ignore: avoid_redundant_argument_values
            deleteUserData: false, // regression guard: must NOT be true
          ),
        ).called(1);
      },
    );

    test('a failed identity-change sweep reports a failed sign-in '
        'and leaves the old identity recorded', () async {
      when(
        () => mockCleanupService.clearUserSpecificData(
          reason: any(named: 'reason'),
          isIdentityChange: any(named: 'isIdentityChange'),
          userPubkey: any(named: 'userPubkey'),
          deleteUserData: any(named: 'deleteUserData'),
        ),
      ).thenThrow(
        const UserDataCleanupException('Could not clear account cache'),
      );

      final result = await authService.createNewIdentity();
      expect(result.success, isFalse);
      expect(result.failureReason, AuthFailureReason.accountCleanupFailed);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('current_user_pubkey_hex'),
        equals(oldPubkeyHex),
        reason:
            'the incoming identity must not be recorded over the old '
            "account's data when the sweep failed",
      );
      expect(authService.authState, equals(AuthState.unauthenticated));
    });

    test(
      'signing in to a stored account clears a stale cleanup reason',
      () async {
        when(
          () => mockCleanupService.clearUserSpecificData(
            reason: any(named: 'reason'),
            isIdentityChange: any(named: 'isIdentityChange'),
            userPubkey: any(named: 'userPubkey'),
            deleteUserData: any(named: 'deleteUserData'),
          ),
        ).thenThrow(
          const UserDataCleanupException('Could not clear account cache'),
        );
        final failed = await authService.createNewIdentity();
        expect(failed.failureReason, AuthFailureReason.accountCleanupFailed);
        expect(
          authService.lastFailureReason,
          AuthFailureReason.accountCleanupFailed,
        );

        // No archived Amber info exists, so this attempt fails for a different
        // reason before it reaches any cleanup.
        await expectLater(
          authService.signInForAccount(
            newKeyContainer.publicKeyHex,
            AuthenticationSource.amber,
          ),
          throwsA(isA<Exception>()),
        );

        expect(authService.lastFailureReason, isNull);
      },
    );

    test(
      'startup primary-key fallback preserves cleanup reason and retry',
      () async {
        // No usable per-account container: startup must reach the PRIMARY
        // fallback even if the registry migrates the primary key into a row.
        when(() => mockKeyStorage.getIdentityKeyContainer(any()))
            .thenAnswer((_) async => null);

        when(
          () => mockCleanupService.clearUserSpecificData(
            reason: any(named: 'reason'),
            isIdentityChange: any(named: 'isIdentityChange'),
            userPubkey: any(named: 'userPubkey'),
            deleteUserData: any(named: 'deleteUserData'),
          ),
        ).thenThrow(
          const UserDataCleanupException('Could not clear account cache'),
        );

        await authService.initialize();
        expect(authService.authState, AuthState.unauthenticated);
        expect(
          authService.lastFailureReason,
          AuthFailureReason.accountCleanupFailed,
        );
        expect(authService.lastError, 'Could not clear account data safely');
        verifyNever(() => mockKeyStorage.generateAndStoreKeys());
        verify(() => mockKeyStorage.hasKeys()).called(1);

        // A cleanup failure must not permanently set the key-storage failure
        // latch: retry reaches the same primary-key restore and cleanup again.
        await authService.initialize();
        verify(() => mockKeyStorage.hasKeys()).called(1);
        expect(
          authService.lastFailureReason,
          AuthFailureReason.accountCleanupFailed,
        );
        expect(authService.currentPublicKeyHex, isNull);
        authService.clearError();
        expect(authService.lastFailureReason, isNull);
      },
    );

    test(
      'orphaned preferences cannot hide a failed database sweep on retry',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('current_user_pubkey_hex');
        await prefs.setString('curated_lists', 'orphaned cache');
        final cleanup = UserDataCleanupService(prefs);
        var attempts = 0;
        cleanup.onDatabaseCleanup =
            ({
              userPubkey,
              deleteUserData = false,
              preserveActiveSession = false,
            }) async {
              attempts++;
              throw StateError('database unavailable');
            };
        await authService.dispose();
        authService = AuthService(
          backgroundActivityManager: BackgroundActivityManager(),
          userDataCleanupService: cleanup,
          keyStorage: mockKeyStorage,
        );

        final first = await authService.createNewIdentity();
        expect(first.failureReason, AuthFailureReason.accountCleanupFailed);
        expect(prefs.containsKey('curated_lists'), isFalse);
        final second = await authService.createNewIdentity();
        expect(second.success, isFalse);
        expect(second.failureReason, AuthFailureReason.accountCleanupFailed);
        expect(attempts, 2);
        expect(authService.currentPublicKeyHex, isNull);
        expect(prefs.containsKey('current_user_pubkey_hex'), isFalse);
      },
    );

    for (final operation in [
      'create',
      'nsec',
      'hex',
      'oauth',
      'restore',
      'initialize',
    ]) {
      test('required database cleanup prevents $operation sign-in', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('curated_lists', '[]');
        await prefs.setString('subscribed_list_ids', '[]');
        final cleanup = UserDataCleanupService(prefs);
        var databaseCleanups = 0;
        const privateFailure = 'private database failure sentinel';
        cleanup.onDatabaseCleanup =
            ({
              String? userPubkey,
              bool deleteUserData = false,
              bool preserveActiveSession = false,
            }) async {
              databaseCleanups++;
              expect(userPubkey, oldPubkeyHex);
              expect(deleteUserData, isFalse);
              expect(preserveActiveSession, isFalse);
              throw StateError(privateFailure);
            };
        final logs = LogCaptureService();
        await logs.clearAllLogs();
        addTearDown(logs.clearAllLogs);
        await authService.dispose();
        authService = AuthService(
          backgroundActivityManager: BackgroundActivityManager(),
          userDataCleanupService: cleanup,
          keyStorage: mockKeyStorage,
        );
        switch (operation) {
          case 'create':
            final result = await authService.createNewIdentity();
            expect(result.success, isFalse);
            expect(
              result.failureReason,
              AuthFailureReason.accountCleanupFailed,
            );
          case 'nsec':
            final result = await authService.importFromNsec(testNsec);
            expect(result.success, isFalse);
            expect(
              result.failureReason,
              AuthFailureReason.accountCleanupFailed,
            );
          case 'hex':
            final result = await authService.importFromHex('1' * 64);
            expect(result.success, isFalse);
            expect(
              result.failureReason,
              AuthFailureReason.accountCleanupFailed,
            );
          case 'oauth':
            await expectLater(
              authService.signInWithDivineOAuth(
                KeycastSession(
                  bunkerUrl: 'https://keycast.example.com',
                  accessToken: 'test-access',
                  expiresAt: DateTime.now().add(const Duration(hours: 1)),
                  userPubkey: newKeyContainer.publicKeyHex,
                ),
              ),
              throwsA(isA<UserDataCleanupException>()),
            );
          case 'restore':
            await expectLater(
              authService.signInForAccount(
                newKeyContainer.publicKeyHex,
                AuthenticationSource.automatic,
              ),
              throwsA(isA<UserDataCleanupException>()),
            );
          case 'initialize':
            await prefs.setString('last_used_npub', newKeyContainer.npub);
            await authService.initialize();
            verifyNever(() => mockKeyStorage.generateAndStoreKeys());
        }
        expect(databaseCleanups, 1);
        expect(authService.authState, AuthState.unauthenticated);
        expect(authService.currentPublicKeyHex, isNull);
        expect(authService.currentProfile, isNull);
        expect(prefs.getString('current_user_pubkey_hex'), oldPubkeyHex);
        expect(prefs.containsKey('curated_lists'), isFalse);
        expect(prefs.containsKey('subscribed_list_ids'), isFalse);
        for (final entry in logs.getRecentLogs()) {
          expect(entry.message, isNot(contains(privateFailure)));
        }
      });
    }

    for (final operation in [
      'create',
      'nsec',
      'hex',
      'oauth',
      'restore',
      'initialize',
    ]) {
      test(
        'real refused removal prevents $operation sign-in and database cleanup',
        () async {
          final prefs = await SharedPreferences.getInstance();
          final outgoingCache = jsonEncode([
            CuratedList(
              id: 'outgoing-list',
              name: 'Outgoing account list',
              pubkey: oldPubkeyHex,
              videoEventIds: const [],
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ).toJson(),
          ]);
          await prefs.setString('curated_lists', outgoingCache);
          await prefs.setString('subscribed_list_ids', 'old follows');
          final refusingPrefs = _RefusingPreferences(prefs);
          final cleanup = UserDataCleanupService(refusingPrefs);
          var databaseCleanups = 0;
          cleanup.onDatabaseCleanup =
              ({
                String? userPubkey,
                bool deleteUserData = false,
                bool preserveActiveSession = false,
              }) async {
                databaseCleanups++;
              };
          await authService.dispose();
          authService = AuthService(
            backgroundActivityManager: BackgroundActivityManager(),
            userDataCleanupService: cleanup,
            keyStorage: mockKeyStorage,
          );
          switch (operation) {
            case 'create':
              final result = await authService.createNewIdentity();
              expect(result.success, isFalse);
              expect(
                result.failureReason,
                AuthFailureReason.accountCleanupFailed,
              );
            case 'nsec':
              final result = await authService.importFromNsec(testNsec);
              expect(result.success, isFalse);
              expect(
                result.failureReason,
                AuthFailureReason.accountCleanupFailed,
              );
            case 'hex':
              final result = await authService.importFromHex('1' * 64);
              expect(result.success, isFalse);
              expect(
                result.failureReason,
                AuthFailureReason.accountCleanupFailed,
              );
            case 'oauth':
              final session = KeycastSession(
                bunkerUrl: 'https://keycast.example.com',
                accessToken: 'test-access',
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
                userPubkey: newKeyContainer.publicKeyHex,
              );
              await expectLater(
                authService.signInWithDivineOAuth(session),
                throwsA(isA<UserDataCleanupException>()),
              );
            case 'initialize':
              await prefs.setString('last_used_npub', newKeyContainer.npub);
              await authService.initialize();
              verifyNever(() => mockKeyStorage.generateAndStoreKeys());
            case 'restore':
              await expectLater(
                authService.signInForAccount(
                  newKeyContainer.publicKeyHex,
                  AuthenticationSource.automatic,
                ),
                throwsA(isA<UserDataCleanupException>()),
              );
          }
          expect(authService.authState, AuthState.unauthenticated);
          expect(refusingPrefs.refusedKeys, contains('curated_lists'));
          expect(prefs.getString('current_user_pubkey_hex'), oldPubkeyHex);
          expect(prefs.getString('curated_lists'), outgoingCache);
          expect(prefs.getString('subscribed_list_ids'), 'old follows');
          expect(databaseCleanups, 0);
        },
      );
    }

    for (final failure in [
      'malformed shared cache',
      'quarantine refusal',
      'quarantine throw',
    ]) {
      for (final operation in [
        'create',
        'nsec',
        'hex',
        'oauth',
        'restore',
        'initialize',
      ]) {
        test(
          'required cleanup $failure blocks $operation without tentative session',
          () async {
            final prefs = await SharedPreferences.getInstance();
            final validCache = jsonEncode([
              CuratedList(
                id: 'outgoing-list',
                name: 'Outgoing account list',
                pubkey: oldPubkeyHex,
                videoEventIds: const [],
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
              ).toJson(),
            ]);
            const privatePayload = 'PRIVATE_CLEANUP_PAYLOAD';
            final outgoingCache = failure == 'malformed shared cache'
                ? '{$privatePayload malformed cache'
                : validCache;
            final journalKey = CuratedListRecoveryJournal.storageKey(
              oldPubkeyHex,
            );
            final journalRaw = failure.startsWith('quarantine')
                ? '{$privatePayload malformed journal'
                : jsonEncode({
                    'healthy': {
                      'plaintextEventIds': ['d' * 64],
                    },
                  });
            await prefs.setString('curated_lists', outgoingCache);
            await prefs.setString('subscribed_list_ids', 'old follows');
            await prefs.setString(journalKey, journalRaw);
            final refusingQuarantine = failure.startsWith('quarantine')
                ? _RefusingQuarantinePreferences(
                    prefs,
                    throwing: failure == 'quarantine throw',
                  )
                : null;
            final cleanup = UserDataCleanupService(refusingQuarantine ?? prefs);
            var databaseCleanups = 0;
            cleanup.onDatabaseCleanup =
                ({
                  String? userPubkey,
                  bool deleteUserData = false,
                  bool preserveActiveSession = false,
                }) async {
                  databaseCleanups++;
                };
            await authService.dispose();
            authService = AuthService(
              backgroundActivityManager: BackgroundActivityManager(),
              userDataCleanupService: cleanup,
              keyStorage: mockKeyStorage,
            );
            final logs = LogCaptureService();
            await logs.clearAllLogs();
            Log.info('required-cleanup probe', name: 'AuthCleanupRegression');
            Object? caught;
            bool? returnedSuccess;
            AuthFailureReason? failureReason;
            try {
              switch (operation) {
                case 'create':
                  final result = await authService.createNewIdentity();
                  returnedSuccess = result.success;
                  failureReason = result.failureReason;
                case 'nsec':
                  final result = await authService.importFromNsec(testNsec);
                  returnedSuccess = result.success;
                  failureReason = result.failureReason;
                case 'hex':
                  final result = await authService.importFromHex('1' * 64);
                  returnedSuccess = result.success;
                  failureReason = result.failureReason;
                case 'oauth':
                  await authService.signInWithDivineOAuth(
                    KeycastSession(
                      bunkerUrl: 'https://keycast.example.com',
                      accessToken: 'test-access',
                      expiresAt: DateTime.now().add(const Duration(hours: 1)),
                      userPubkey: newKeyContainer.publicKeyHex,
                    ),
                  );
                case 'restore':
                  await authService.signInForAccount(
                    newKeyContainer.publicKeyHex,
                    AuthenticationSource.automatic,
                  );
                case 'initialize':
                  await prefs.setString('last_used_npub', newKeyContainer.npub);
                  await authService.initialize();
              }
            } on Object catch (error) {
              caught = error;
            }
            await prefs.reload();
            expect(authService.authState, AuthState.unauthenticated);
            expect(authService.currentProfile, isNull);
            expect(authService.currentPublicKeyHex, isNull);
            expect(prefs.getString('current_user_pubkey_hex'), oldPubkeyHex);
            expect(prefs.getString(journalKey), journalRaw);
            expect(
              prefs.containsKey(TermsAcceptanceKeys.termsAcceptedAt),
              isFalse,
            );
            expect(
              prefs.getBool(TermsAcceptanceKeys.ageVerified16Plus),
              isNot(isTrue),
            );
            expect(databaseCleanups, 0);
            expect(prefs.getString('curated_lists'), outgoingCache);
            expect(prefs.getString('subscribed_list_ids'), 'old follows');
            if (refusingQuarantine != null) {
              expect(refusingQuarantine.quarantineAttempts, 1);
            }
            verifyNever(() => mockKeyStorage.deleteKeys());
            verifyNever(
              () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
            );
            if (operation == 'initialize') {
              verifyNever(() => mockKeyStorage.generateAndStoreKeys());
            } else if (['create', 'nsec', 'hex'].contains(operation)) {
              expect(returnedSuccess, isFalse);
              expect(failureReason, AuthFailureReason.accountCleanupFailed);
            } else {
              expect(caught, isA<UserDataCleanupException>());
              expect(caught.toString(), isNot(contains(privatePayload)));
            }
            final captured = (await logs.getAllLogsAsText()).join('\n');
            expect(captured, contains('required-cleanup probe'));
            expect(captured, isNot(contains(privatePayload)));
          },
        );
      }
    }

    test('identity-change: isIdentityChange=true is still passed '
        'so legacy and database cleanup stays fail-closed', () async {
      // The identity-change flag still guards legacy unscoped state and
      // makes database cleanup errors abort the account transition. Scoped
      // following and relay caches are preserved independently.
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      verify(
        () => mockCleanupService.clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true, // must still be true
          userPubkey: any(named: 'userPubkey'),
          // Explicit false is the identity-preservation regression guard.
          // ignore: avoid_redundant_argument_values
          deleteUserData: false, // regression guard: must NOT be true
        ),
      ).called(1);
    });
  });
}
