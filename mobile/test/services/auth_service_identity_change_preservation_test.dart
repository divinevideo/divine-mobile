// ABOUTME: Regression tests for #4625 — owner-scoped drafts, clips, and
// ABOUTME: pending uploads must NOT be deleted on non-destructive identity change.

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockCacheDao extends Mock implements CacheDao {}

/// Runs [body] while silencing unhandled async errors from `_performDiscovery`.
///
/// `_setupUserSession` fires `unawaited(_performDiscovery())` which creates a
/// `NostrClient` that tries to open a WebSocket. In the test environment this
/// throws asynchronously ("Unsupported operation: Mocked response") and the
/// test runner flags it as a test failure. Wrapping with `runZonedGuarded`
/// prevents that unhandled error from reaching the test zone.
Future<T> _ignoringDiscoveryErrors<T>(Future<T> Function() body) async {
  final completer = Completer<T>();
  runZonedGuarded(
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
      when(
        () => mockKeyStorage.deleteIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => newKeyContainer);
      when(
        () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => newKeyContainer);
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => newKeyContainer);
      when(
        () => mockKeyStorage.switchToIdentity(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => true);

      // Cleanup service stubs: shouldClearDataForUser returns true (different
      // user), and clearUserSpecificData/claimLegacyRows complete normally.
      when(
        () => mockCleanupService.shouldClearDataForUser(any()),
      ).thenReturn(true);
      when(
        () => mockCleanupService.clearUserSpecificData(
          reason: any(named: 'reason'),
          isIdentityChange: any(named: 'isIdentityChange'),
          userPubkey: any(named: 'userPubkey'),
          deleteUserData: any(named: 'deleteUserData'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => mockCleanupService.claimLegacyRows(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockCleanupService.markOwnerScopedLegacyDataForUser(any()),
      ).thenAnswer((_) async {});

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

    test(
      'remove-device signOut (deleteKeys: true) preserves user data by default',
      () async {
        // First sign in so there is a current identity to sign out from.
        when(
          () => mockCleanupService.shouldClearDataForUser(any()),
        ).thenReturn(false);
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
      },
    );

    test('account deletion opts in to deleting local user data', () async {
      final cacheDao = _MockCacheDao();
      when(() => cacheDao.deletePrefix(any())).thenAnswer((_) async {});
      await CacheSync.init(dao: cacheDao);
      when(
        () => mockCleanupService.shouldClearDataForUser(any()),
      ).thenReturn(false);
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
        when(
          () => mockCleanupService.shouldClearDataForUser(any()),
        ).thenReturn(false);
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
