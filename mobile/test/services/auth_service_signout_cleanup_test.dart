// ABOUTME: Tests for AuthService signOut clearing user-specific data
// ABOUTME: Verifies that explicit logout clears pubkey tracking and user data

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart'
    show SharedPreferencesRelayStorage;
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

/// Tracking [CacheDao] so assertions can check which invalidation surface
/// was hit on signOut. `deletePrefixCalls` records the prefix passed for
/// each `deletePrefix` call so the multi-account assertion can verify
/// only the leaving pubkey was targeted.
///
/// Setting [throwOnDeletePrefix] causes the next `deletePrefix` call to
/// throw — used to pin that signOut tolerates cache-layer failures.
class _TrackingCacheDao implements CacheDao {
  final Map<String, String> store = {};
  final List<String> deletePrefixCalls = [];
  Object? throwOnDeletePrefix;

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    store[key] = payload;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }

  @override
  Future<void> deletePrefix(String prefix) async {
    deletePrefixCalls.add(prefix);
    final err = throwOnDeletePrefix;
    if (err != null) {
      throwOnDeletePrefix = null;
      throw err;
    }
    store.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<int> totalPayloadBytes() async =>
      store.values.fold<int>(0, (sum, v) => sum + v.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

void main() {
  setupTestEnvironment();

  group('AuthService signOut cleanup', () {
    late _MockSecureKeyStorage mockKeyStorage;
    late _MockUserDataCleanupService mockCleanupService;
    late _TrackingCacheDao cacheDao;
    late AuthService authService;
    late SharedPreferences prefs;

    // Test nsec from a known keypair
    const testNsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'current_user_pubkey_hex': 'existing_pubkey_hex_123',
        'age_verified_16_plus': true,
        'terms_accepted_at': '2024-01-01T00:00:00Z',
      });
      prefs = await SharedPreferences.getInstance();
      mockKeyStorage = _MockSecureKeyStorage();
      mockCleanupService = _MockUserDataCleanupService();
      cacheDao = _TrackingCacheDao();
      await CacheSync.init(dao: cacheDao);

      // Create AuthService with mock dependencies
      authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
      );
      addTearDown(authService.dispose);

      // Setup mock behaviors
      when(
        () => mockCleanupService.shouldClearDataForUser(any()),
      ).thenReturn(false);
      when(
        () => mockCleanupService.clearUserSpecificData(
          reason: any(named: 'reason'),
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
      when(
        () => mockKeyStorage.deleteIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => null);
    });

    test('signOut should clear current_user_pubkey_hex', () async {
      // Arrange: Verify pubkey is initially stored
      expect(prefs.getString('current_user_pubkey_hex'), isNotNull);

      // Setup mock to not delete keys (just clearing cache)
      when(() => mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out without deleting keys
      await authService.signOut();

      // Assert: Pubkey should be cleared
      expect(prefs.getString('current_user_pubkey_hex'), isNull);
    });

    test('signOut should clear TOS acceptance flags', () async {
      // Arrange: Verify TOS flags are initially set
      expect(prefs.getBool('age_verified_16_plus'), isTrue);
      expect(prefs.getString('terms_accepted_at'), isNotNull);

      // Setup mock
      when(() => mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out
      await authService.signOut();

      // Assert: TOS flags should be cleared
      expect(prefs.getBool('age_verified_16_plus'), isNull);
      expect(prefs.getString('terms_accepted_at'), isNull);
    });

    test('signOut clears configured and user-removed relays', () async {
      await prefs.setStringList(
        SharedPreferencesRelayStorage.defaultKey,
        ['wss://relay.divine.video'],
      );
      await prefs.setStringList(
        SharedPreferencesRelayStorage.defaultRemovedRelaysKey,
        ['wss://relay.divine.video'],
      );
      when(() => mockKeyStorage.clearCache()).thenReturn(null);

      await authService.signOut();

      expect(
        prefs.getStringList(SharedPreferencesRelayStorage.defaultKey),
        isNull,
      );
      expect(
        prefs.getStringList(
          SharedPreferencesRelayStorage.defaultRemovedRelaysKey,
        ),
        isNull,
      );
    });

    test('non-destructive signOut passes deleteUserData: false', () async {
      // Setup mock
      when(() => mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out without deleting keys (account switch)
      await authService.signOut();

      // Assert: Cleanup called with deleteUserData=false (preserves
      // per-user DAO data since it's scoped by ownerPubkey)
      verify(
        () => mockCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: any(named: 'userPubkey'),
          // Explicit false is the sign-out cleanup behavior under verification.
          // ignore: avoid_redundant_argument_values
          deleteUserData: false,
        ),
      ).called(1);
    });

    test('remove-device signOut preserves owner-scoped user data', () async {
      // Arrange
      when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
      when(
        () => mockKeyStorage.deleteIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
      when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});

      // Auto-create new identity after deletion
      final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
      when(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => newKeyContainer);

      // Act: remove local login material without deleting local work.
      await authService.signOut(deleteKeys: true);

      // Assert: Keys should be deleted
      verify(() => mockKeyStorage.deleteKeys()).called(1);

      // Assert: owner-scoped rows are preserved. Removing local login material
      // should not destroy device-local drafts/clips.
      verify(
        () => mockCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: any(named: 'userPubkey'),
          // Explicit false is the sign-out cleanup behavior under verification.
          // ignore: avoid_redundant_argument_values
          deleteUserData: false,
        ),
      ).called(1);

      // Note: After deleteKeys=true, a new identity is auto-created,
      // which sets a new pubkey. So we verify cleanup was called,
      // not that pubkey is null (since new identity sets it).
    });

    test('remove-device signOut clears user-removed relays', () async {
      await prefs.setStringList(
        SharedPreferencesRelayStorage.defaultRemovedRelaysKey,
        ['wss://relay.divine.video'],
      );
      when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
      when(
        () => mockKeyStorage.deleteIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
      when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});
      when(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => SecureKeyContainer.fromNsec(testNsec));

      await authService.signOut(deleteKeys: true);

      expect(
        prefs.getStringList(
          SharedPreferencesRelayStorage.defaultRemovedRelaysKey,
        ),
        isNull,
      );
    });

    test('account deletion signOut deletes owner-scoped user data', () async {
      // Arrange
      when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
      when(
        () => mockKeyStorage.deleteIdentityKeyContainer(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
      when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});

      final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
      when(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => newKeyContainer);

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
      'destructive signOut without a current pubkey skips cache invalidation',
      () async {
        // AuthService.signOut now invalidates by pubkey prefix only. When
        // no current pubkey is set (this test never authenticates) the
        // invalidation block is skipped entirely; with a current pubkey,
        // only that pubkey's entries are deleted (see the authenticated
        // group below).
        await cacheDao.write(
          key: 'aa11:my_followers',
          payload: '{"pubkeys":["a"],"count":1}',
        );

        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
        when(
          () => mockKeyStorage.deleteIdentityKeyContainer(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
        when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});
        final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
        when(
          () => mockKeyStorage.generateAndStoreKeys(
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => newKeyContainer);

        await authService.signOut(deleteKeys: true);

        expect(cacheDao.deletePrefixCalls, isEmpty);
        // Unauthenticated → no current pubkey to scope by → cache survives.
        expect(cacheDao.store, isNotEmpty);
      },
    );

    test(
      'non-destructive signOut without a current pubkey skips cache '
      'invalidation',
      () async {
        await cacheDao.write(
          key: 'aa11:my_followers',
          payload: '{"pubkeys":["a"],"count":1}',
        );
        when(() => mockKeyStorage.clearCache()).thenReturn(null);

        await authService.signOut();

        expect(cacheDao.deletePrefixCalls, isEmpty);
        expect(cacheDao.store, isNotEmpty);
      },
    );

    group('account-scoped CacheSync invalidation (multi-account)', () {
      const pubkeyA =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const pubkeyB =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      late SecureKeyContainer accountAContainer;

      setUp(() {
        accountAContainer = SecureKeyContainer.fromPublicKey(pubkeyA);
        authService.debugSetCurrentKeyContainer(accountAContainer);

        cacheDao.store
          ..['$pubkeyA:my_followers'] = '{"pubkeys":["a"],"count":1}'
          ..['$pubkeyA:my_following'] = '{"pubkeys":["c"],"count":1}'
          ..['$pubkeyB:my_followers'] = '{"pubkeys":["d"],"count":1}';

        when(() => mockKeyStorage.clearCache()).thenReturn(null);
      });

      test(
        'non-destructive signOut invalidates only the leaving account prefix',
        () async {
          await authService.signOut();

          expect(cacheDao.deletePrefixCalls, equals([pubkeyA]));
          expect(cacheDao.store.containsKey('$pubkeyA:my_followers'), isFalse);
          expect(cacheDao.store.containsKey('$pubkeyA:my_following'), isFalse);
          // The headline multi-account assertion: B's cache survives.
          expect(cacheDao.store['$pubkeyB:my_followers'], isNotNull);
        },
      );

      test(
        'destructive signOut also invalidates only the leaving account prefix',
        () async {
          when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
          when(
            () => mockKeyStorage.deleteIdentityKeyContainer(
              any(),
              biometricPrompt: any(named: 'biometricPrompt'),
            ),
          ).thenAnswer((_) async {});
          when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
          when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});
          final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
          when(
            () => mockKeyStorage.generateAndStoreKeys(
              biometricPrompt: any(named: 'biometricPrompt'),
            ),
          ).thenAnswer((_) async => newKeyContainer);

          await authService.signOut(deleteKeys: true);

          expect(cacheDao.deletePrefixCalls, equals([pubkeyA]));
          expect(cacheDao.store.containsKey('$pubkeyA:my_followers'), isFalse);
          expect(cacheDao.store['$pubkeyB:my_followers'], isNotNull);
        },
      );

      test(
        'signOut completes despite a throwing invalidatePrefix',
        () async {
          // The cache-layer failure must NOT abort the rest of signOut.
          // Without the try/catch around CacheSync.invalidatePrefix, a
          // disk error would short-circuit key cleanup, signer
          // teardown, and the auth-state transition.
          cacheDao.throwOnDeletePrefix = StateError(
            'cache layer simulated failure',
          );

          await authService.signOut();

          // The invalidation was attempted with the right prefix...
          expect(cacheDao.deletePrefixCalls, equals([pubkeyA]));
          // ...the throw was swallowed and signOut still completed...
          expect(authService.authState, equals(AuthState.unauthenticated));
          // ...and because the fake throws before any rows are removed,
          // every seeded entry (A's and B's) is still on disk. This pins
          // the contract that a failed invalidation leaves the cache in
          // its pre-call state — no partial cleanup.
          expect(cacheDao.store['$pubkeyA:my_followers'], isNotNull);
          expect(cacheDao.store['$pubkeyA:my_following'], isNotNull);
          expect(cacheDao.store['$pubkeyB:my_followers'], isNotNull);
        },
      );
    });

    test('signOut should set auth state to unauthenticated', () async {
      // Setup mock
      when(() => mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out
      await authService.signOut();

      // Assert: Auth state should be unauthenticated
      expect(authService.authState, equals(AuthState.unauthenticated));
    });

    group('before session teardown callbacks', () {
      test('run sequentially before identity is cleared', () async {
        when(() => mockKeyStorage.clearCache()).thenReturn(null);
        final identity = LocalNostrIdentity(
          keyContainer: SecureKeyContainer.fromNsec(testNsec),
        );
        authService.debugSetIdentity(identity);
        final events = <String>[];

        authService.registerBeforeSessionTeardownCallback(() async {
          events.add('first:${authService.currentIdentity?.pubkey}');
        });
        authService.registerBeforeSessionTeardownCallback(() async {
          events.add('second:${authService.currentIdentity?.pubkey}');
        });

        await authService.signOut();

        expect(events, [
          'first:${identity.pubkey}',
          'second:${identity.pubkey}',
        ]);
        expect(authService.currentIdentity, isNull);
        expect(authService.authState, AuthState.unauthenticated);
      });

      test('unregistered callback does not run', () async {
        when(() => mockKeyStorage.clearCache()).thenReturn(null);
        var called = false;

        final unregister = authService.registerBeforeSessionTeardownCallback(
          () async {
            called = true;
          },
        );
        unregister();

        await authService.signOut();

        expect(called, isFalse);
      });

      test('callback failure does not block unauthenticated state', () async {
        when(() => mockKeyStorage.clearCache()).thenReturn(null);

        authService.registerBeforeSessionTeardownCallback(() async {
          throw StateError('deregister failed');
        });

        await authService.signOut();

        expect(authService.authState, AuthState.unauthenticated);
      });

      test(
        'callback timeout exception does not skip later callbacks',
        () async {
          when(() => mockKeyStorage.clearCache()).thenReturn(null);
          final events = <String>[];

          authService.registerBeforeSessionTeardownCallback(() async {
            events.add('first');
            throw TimeoutException('deregister timed out');
          });
          authService.registerBeforeSessionTeardownCallback(() async {
            events.add('second');
          });

          await authService.signOut();

          expect(events, ['first', 'second']);
          expect(authService.authState, AuthState.unauthenticated);
        },
      );

      test(
        'callbacks share one timeout budget but later callbacks still run',
        () {
          // signOut's OAuth cleanup falls back to a real FlutterSecureStorage
          // when none is injected; without a channel handler it throws
          // MissingPluginException and retries via real async, which races
          // fakeAsync's virtual time (flaky under parallel CI load). Stub the
          // channel so cleanup returns synchronously and stays virtualizable.
          const secureStorageChannel = MethodChannel(
            'plugins.it_nomads.com/flutter_secure_storage',
          );
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(secureStorageChannel, (call) async {
                if (call.method == 'getCapabilities') {
                  return <String, bool>{'basicSecureStorage': true};
                }
                return null;
              });
          // Restore the shared handler installed by setupTestEnvironment()
          // rather than nulling it: this channel is global, and clearing it
          // strands later suites (e.g. nostr_key_manager_profile_fetch_test)
          // with MissingPluginException under CI's --optimization
          // single-isolate run with shuffled ordering.
          addTearDown(setupTestEnvironment);

          fakeAsync((async) {
            when(() => mockKeyStorage.clearCache()).thenReturn(null);
            final events = <String>[];
            var completed = false;

            authService.registerBeforeSessionTeardownCallback(() async {
              events.add('slow started');
              await Future<void>.delayed(const Duration(seconds: 10));
              events.add('slow completed');
            });
            authService.registerBeforeSessionTeardownCallback(() async {
              events.add('second started');
            });

            authService.signOut().then((_) {
              completed = true;
            });
            async.flushMicrotasks();

            expect(events, ['slow started']);

            async.elapse(const Duration(seconds: 5));
            async.flushMicrotasks();

            expect(events, ['slow started', 'second started']);
            expect(completed, isTrue);
            expect(authService.authState, AuthState.unauthenticated);
          });
        },
      );
    });

    group('key deletion error propagation', () {
      test('signOut with deleteKeys rethrows SecureKeyStorageException '
          'after completing cleanup', () async {
        // Arrange: deleteKeys() throws
        when(() => mockKeyStorage.deleteKeys()).thenThrow(
          const SecureKeyStorageException(
            'Platform key deletion failed',
            code: 'platform_deletion_failed',
          ),
        );
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        // Act & Assert: signOut completes cleanup then rethrows
        await expectLater(
          authService.signOut(deleteKeys: true),
          throwsA(isA<SecureKeyStorageException>()),
        );

        // Auth state should still be unauthenticated — cleanup completed
        expect(authService.authState, equals(AuthState.unauthenticated));
      });

      test('signOut with deleteKeys succeeds normally when keys delete '
          'successfully', () async {
        // Arrange: deleteKeys() succeeds
        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        // Act: should not throw
        await authService.signOut(deleteKeys: true);

        // Assert: completed normally
        expect(authService.authState, equals(AuthState.unauthenticated));
        verify(() => mockKeyStorage.deleteKeys()).called(1);
      });

      test(
        'account deletion cleanup failure surfaces after teardown',
        () async {
          final keyContainer = SecureKeyContainer.fromNsec(testNsec);
          authService.debugSetCurrentKeyContainer(keyContainer);
          when(
            () => mockCleanupService.clearUserSpecificData(
              reason: 'explicit_logout',
              userPubkey: keyContainer.publicKeyHex,
              deleteUserData: true,
            ),
          ).thenThrow(StateError('database cleanup failed'));
          when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {});
          when(
            () => mockKeyStorage.deleteIdentityKeyContainer(
              any(),
              biometricPrompt: any(named: 'biometricPrompt'),
            ),
          ).thenAnswer((_) async {});
          when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
          when(
            () => mockKeyStorage.getKeyContainer(),
          ).thenAnswer((_) async => null);

          await expectLater(
            authService.signOut(deleteKeys: true, deleteLocalUserData: true),
            throwsA(isA<UserDataCleanupException>()),
          );

          verify(() => mockKeyStorage.deleteKeys()).called(1);
          expect(authService.currentIdentity, isNull);
          expect(authService.authState, equals(AuthState.unauthenticated));
        },
      );

      test('signOut with abortOnKeyDeletionFailure throws before cleanup '
          'when key deletion fails', () async {
        // Arrange: deleteKeys() throws
        when(() => mockKeyStorage.deleteKeys()).thenThrow(
          const SecureKeyStorageException(
            'Platform key deletion failed',
            code: 'platform_deletion_failed',
          ),
        );

        // Act & Assert: signOut throws immediately
        await expectLater(
          authService.signOut(
            deleteKeys: true,
            abortOnKeyDeletionFailure: true,
          ),
          throwsA(isA<SecureKeyStorageException>()),
        );

        // Auth state should still be initial — no cleanup happened
        expect(authService.authState, isNot(equals(AuthState.unauthenticated)));

        // Cleanup service should NOT have been called
        verifyNever(
          () => mockCleanupService.clearUserSpecificData(
            reason: any(named: 'reason'),
            userPubkey: any(named: 'userPubkey'),
            deleteUserData: any(named: 'deleteUserData'),
          ),
        );
      });

      test('signOut with abortOnKeyDeletionFailure completes normally '
          'when key deletion succeeds', () async {
        // Arrange: deleteKeys() succeeds
        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        // Act: should not throw
        await authService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        );

        // Assert: completed normally, auth state unauthenticated
        expect(authService.authState, equals(AuthState.unauthenticated));

        // deleteKeys() called only once (pre-flight), not twice
        verify(() => mockKeyStorage.deleteKeys()).called(1);
      });
    });
  });
}
