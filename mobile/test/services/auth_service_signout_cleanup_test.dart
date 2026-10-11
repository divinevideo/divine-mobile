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
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/shared_channel_override.dart';
import '../test_setup.dart';

class _MockRelayDiscoveryService extends Mock
    implements RelayDiscoveryService {}

RelayDiscoveryService _networkFreeDiscovery() {
  final discovery = _MockRelayDiscoveryService();
  when(() => discovery.discoverRelays(any())).thenAnswer(
    (_) async => RelayDiscoveryResult.failure('No network in logout tests'),
  );
  when(() => discovery.clearCache(any())).thenAnswer((_) async {});
  return discovery;
}

/// Consumer fixture with actual key-derived ownership and readback. Backend
/// current/legacy native slot behavior is exercised by the package's real tests.
class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {
  final identitySnapshots = <String, SecureKeyContainer>{};

  @override
  Future<bool> hasKeysStrict() async => (await getKeyContainer()) != null;

  @override
  Future<void> deleteOwnedLoginStrict(
    String owner, {
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(owner)) {
      throw const SecureKeyStorageException('Invalid deletion owner');
    }
    final coordinate = SecureKeyContainer.fromPublicKey(owner);
    final npub = coordinate.npub;
    coordinate.dispose();
    final beforePrimary = await getKeyContainer();
    ensureCurrent?.call();
    final beforeArchive = identitySnapshots[npub];
    if (beforeArchive != null && beforeArchive.publicKeyHex != owner) {
      throw const SecureKeyStorageException('Contradictory saved identity');
    }
    // These are the same storage-only native fakes the existing assertions
    // observe. Acknowledgement without a matching readback is not success.
    await deleteIdentityKeyContainer(npub);
    ensureCurrent?.call();
    if (beforePrimary?.publicKeyHex == owner) {
      await deleteKeys();
      ensureCurrent?.call();
    }
    final afterPrimary = await getKeyContainer();
    ensureCurrent?.call();
    if (identitySnapshots.containsKey(npub) ||
        afterPrimary?.publicKeyHex == owner ||
        (beforePrimary != null &&
            beforePrimary.publicKeyHex != owner &&
            !identical(afterPrimary, beforePrimary))) {
      throw const SecureKeyStorageException('Owner removal readback failed');
    }
  }
}

/// Invokes AuthService's real persistence boundary around a storage-only fake.
Future<SecureKeyContainer> _completeGeneratedKeys(
  Invocation invocation,
  SecureKeyContainer keys,
  _MockSecureKeyStorage keyStorage,
) async {
  final guard =
      invocation.namedArguments[#primaryWriteGuard]
          as PrimaryKeyPersistenceGuard;
  var persisted = false;
  await guard(keys.publicKeyHex, () async {
    if (persisted) {
      throw StateError('PRIMARY was persisted more than once');
    }
    persisted = true;
    // The PRIMARY fake must reflect the same successful native write that
    // AuthService reads back under its actual activation lease.
    when(keyStorage.getKeyContainer).thenAnswer((_) async => keys);
    when(keyStorage.hasKeys).thenAnswer((_) async => true);
  });
  if (!persisted) {
    throw StateError('PRIMARY persistence was not completed');
  }
  return keys;
}

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
    SecureKeyContainer? primaryKeys;

    // Test nsec from a known keypair
    const testNsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    setUpAll(() {
      registerFallbackValue(SecureKeyContainer.fromNsec(testNsec));
    });

    AuthService createAuth() => AuthService(
      backgroundActivityManager: BackgroundActivityManager(),
      userDataCleanupService: mockCleanupService,
      keyStorage: mockKeyStorage,
      relayDiscoveryService: _networkFreeDiscovery(),
      profileCheckIndexerUrl: 'unsupported://profile.invalid',
    );

    Future<void> useOwnerlessFixture() async {
      await authService.dispose();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      primaryKeys = null;
      when(mockKeyStorage.getKeyContainer).thenAnswer((_) async => primaryKeys);
      when(mockKeyStorage.hasKeys).thenAnswer((_) async => primaryKeys != null);
      authService = createAuth();
      addTearDown(authService.dispose);
    }

    setUp(() async {
      // Establish the real AuthService session instead of an unauthenticated
      // actor with an unrelated persisted placeholder owner.
      SharedPreferences.setMockInitialValues({
        'age_verified_16_plus': true,
        'terms_accepted_at': '2024-01-01T00:00:00Z',
      });
      prefs = await SharedPreferences.getInstance();
      mockKeyStorage = _MockSecureKeyStorage();
      mockCleanupService = _MockUserDataCleanupService();
      cacheDao = _TrackingCacheDao();
      await CacheSync.init(dao: cacheDao);
      primaryKeys = null;
    });

    Future<void> prepareAuthenticatedFixture() async {
      when(mockKeyStorage.getKeyContainer).thenAnswer((_) async => primaryKeys);
      when(mockKeyStorage.hasKeys).thenAnswer((_) async => primaryKeys != null);
      when(mockKeyStorage.initialize).thenAnswer((_) async {});
      when(mockKeyStorage.clearCache).thenReturn(null);
      when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {
        primaryKeys = null;
      });
      when(() => mockKeyStorage.importFromNsec(testNsec)).thenAnswer((_) async {
        primaryKeys = SecureKeyContainer.fromNsec(testNsec);
        return primaryKeys!;
      });
      when(
        () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
      ).thenAnswer((invocation) async {
        mockKeyStorage.identitySnapshots[invocation.positionalArguments.first
                as String] =
            invocation.positionalArguments.last as SecureKeyContainer;
      });
      when(() => mockKeyStorage.deleteIdentityKeyContainer(any()))
          .thenAnswer((invocation) async {
            mockKeyStorage.identitySnapshots.remove(
              invocation.positionalArguments.single as String,
            );
          });
      when(() => mockCleanupService.shouldClearDataForUser(any()))
          .thenReturn(false);
      when(
        () => mockCleanupService.clearUserSpecificData(
          reason: any(named: 'reason'),
          isIdentityChange: any(named: 'isIdentityChange'),
          userPubkey: any(named: 'userPubkey'),
          deleteUserData: any(named: 'deleteUserData'),
        ),
      ).thenAnswer(
        (invocation) => UserDataCleanupService(prefs).clearUserSpecificData(
          reason: invocation.namedArguments[#reason] as String?,
          isIdentityChange:
              (invocation.namedArguments[#isIdentityChange] as bool?) ?? false,
          userPubkey: invocation.namedArguments[#userPubkey] as String?,
          deleteUserData:
              (invocation.namedArguments[#deleteUserData] as bool?) ?? false,
        ),
      );
      when(() => mockCleanupService.claimLegacyRows(any()))
          .thenAnswer((_) async {});
      when(() => mockCleanupService.markOwnerScopedLegacyDataForUser(any()))
          .thenAnswer((_) async {});
      authService = createAuth();
      addTearDown(authService.dispose);
      final result = await authService.importFromNsec(testNsec);
      expect(result.success, isTrue);
      expect(authService.committedAccountActivationReceipt!.isCurrent, isTrue);
      clearInteractions(mockCleanupService);
      clearInteractions(mockKeyStorage);
    }

    group('session metadata and local data', () {
      setUp(prepareAuthenticatedFixture);

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
        await prefs.setStringList(SharedPreferencesRelayStorage.defaultKey, [
          'wss://relay.divine.video',
        ]);
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
        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {
          primaryKeys = null;
        });
        when(() => mockKeyStorage.deleteIdentityKeyContainer(any()))
            .thenAnswer((invocation) async {
              mockKeyStorage.identitySnapshots.remove(
                invocation.positionalArguments.single as String,
              );
            });
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
        when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});

        // Auto-create new identity after deletion
        final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
        when(
          () => mockKeyStorage.generateAndStoreKeys(
            primaryWriteGuard: any(named: 'primaryWriteGuard'),
          ),
        ).thenAnswer(
          (invocation) => _completeGeneratedKeys(
            invocation,
            newKeyContainer,
            mockKeyStorage,
          ),
        );

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

        // Removing login material does not create a replacement identity.
        expect(authService.currentPublicKeyHex, isNull);
      });

      test('remove-device signOut clears user-removed relays', () async {
        await prefs.setStringList(
          SharedPreferencesRelayStorage.defaultRemovedRelaysKey,
          ['wss://relay.divine.video'],
        );
        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {
          primaryKeys = null;
        });
        when(() => mockKeyStorage.deleteIdentityKeyContainer(any()))
            .thenAnswer((invocation) async {
              mockKeyStorage.identitySnapshots.remove(
                invocation.positionalArguments.single as String,
              );
            });
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
        when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});
        when(
          () => mockKeyStorage.generateAndStoreKeys(
            primaryWriteGuard: any(named: 'primaryWriteGuard'),
          ),
        ).thenAnswer(
          (invocation) => _completeGeneratedKeys(
            invocation,
            SecureKeyContainer.fromNsec(testNsec),
            mockKeyStorage,
          ),
        );

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
        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {
          primaryKeys = null;
        });
        when(() => mockKeyStorage.deleteIdentityKeyContainer(any()))
            .thenAnswer((invocation) async {
              mockKeyStorage.identitySnapshots.remove(
                invocation.positionalArguments.single as String,
              );
            });
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
        when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});

        final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
        when(
          () => mockKeyStorage.generateAndStoreKeys(
            primaryWriteGuard: any(named: 'primaryWriteGuard'),
          ),
        ).thenAnswer(
          (invocation) => _completeGeneratedKeys(
            invocation,
            newKeyContainer,
            mockKeyStorage,
          ),
        );

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
          await useOwnerlessFixture();
          // AuthService.signOut now invalidates by pubkey prefix only. When
          // no current pubkey is set (the fresh fixture has no identity) the
          // invalidation block is skipped entirely; with a current pubkey,
          // only that pubkey's entries are deleted (see the authenticated
          // group below).
          await cacheDao.write(
            key: 'aa11:my_followers',
            payload: '{"pubkeys":["a"],"count":1}',
          );

          when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {
            primaryKeys = null;
          });
          when(() => mockKeyStorage.deleteIdentityKeyContainer(any()))
              .thenAnswer((invocation) async {
                mockKeyStorage.identitySnapshots.remove(
                  invocation.positionalArguments.single as String,
                );
              });
          when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
          when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});
          final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
          when(
            () => mockKeyStorage.generateAndStoreKeys(
              primaryWriteGuard: any(named: 'primaryWriteGuard'),
            ),
          ).thenAnswer(
            (invocation) => _completeGeneratedKeys(
              invocation,
              newKeyContainer,
              mockKeyStorage,
            ),
          );

          await authService.signOut(deleteKeys: true);

          expect(cacheDao.deletePrefixCalls, isEmpty);
          // Unauthenticated → no current pubkey to scope by → cache survives.
          expect(cacheDao.store, isNotEmpty);
        },
      );

      test('non-destructive signOut without a current pubkey skips cache '
          'invalidation', () async {
        await useOwnerlessFixture();
        await cacheDao.write(
          key: 'aa11:my_followers',
          payload: '{"pubkeys":["a"],"count":1}',
        );
        when(() => mockKeyStorage.clearCache()).thenReturn(null);

        await authService.signOut();

        expect(cacheDao.deletePrefixCalls, isEmpty);
        expect(cacheDao.store, isNotEmpty);
      });

      test('signOut should set auth state to unauthenticated', () async {
        // Setup mock
        when(() => mockKeyStorage.clearCache()).thenReturn(null);

        // Act: Sign out
        await authService.signOut();

        // Assert: Auth state should be unauthenticated
        expect(authService.authState, equals(AuthState.unauthenticated));
      });
    });

    group('account-scoped CacheSync invalidation (multi-account)', () {
      setUp(prepareAuthenticatedFixture);

      final pubkeyA = SecureKeyContainer.fromNsec(testNsec).publicKeyHex;
      const pubkeyB =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      setUp(() {
        expect(authService.currentPublicKeyHex, pubkeyA);
        expect(
          authService.committedAccountActivationReceipt!.isCurrent,
          isTrue,
        );

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
          when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {
            primaryKeys = null;
          });
          when(() => mockKeyStorage.deleteIdentityKeyContainer(any()))
              .thenAnswer((invocation) async {
                mockKeyStorage.identitySnapshots.remove(
                  invocation.positionalArguments.single as String,
                );
              });
          when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
          when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});
          final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
          when(
            () => mockKeyStorage.generateAndStoreKeys(
              primaryWriteGuard: any(named: 'primaryWriteGuard'),
            ),
          ).thenAnswer(
            (invocation) => _completeGeneratedKeys(
              invocation,
              newKeyContainer,
              mockKeyStorage,
            ),
          );

          await authService.signOut(deleteKeys: true);

          expect(cacheDao.deletePrefixCalls, equals([pubkeyA]));
          expect(cacheDao.store.containsKey('$pubkeyA:my_followers'), isFalse);
          expect(cacheDao.store['$pubkeyB:my_followers'], isNotNull);
        },
      );

      test('signOut completes despite a throwing invalidatePrefix', () async {
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
      });
    });

    group('before session teardown callbacks', () {
      setUp(prepareAuthenticatedFixture);

      test('run sequentially before identity is cleared', () async {
        when(() => mockKeyStorage.clearCache()).thenReturn(null);
        final identity = authService.currentIdentity!;
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
          overrideSharedChannel(secureStorageChannel, (call) async {
            if (call.method == 'getCapabilities') {
              return <String, bool>{'basicSecureStorage': true};
            }
            return null;
          });

          fakeAsync((async) {
            SharedPreferences.setMockInitialValues({});
            late AuthService timeoutAuth;
            var fixtureReady = false;
            final zoneKeys = _MockSecureKeyStorage();
            SecureKeyContainer? zonePrimary;
            when(zoneKeys.getKeyContainer).thenAnswer((_) async => zonePrimary);
            when(zoneKeys.hasKeys).thenAnswer((_) async => zonePrimary != null);
            when(zoneKeys.clearCache).thenReturn(null);
            when(() => zoneKeys.importFromNsec(testNsec)).thenAnswer((_) async {
              zonePrimary = SecureKeyContainer.fromNsec(testNsec);
              return zonePrimary!;
            });
            when(() => zoneKeys.storeIdentityKeyContainer(any(), any()))
                .thenAnswer((_) async {});
            unawaited(() async {
              final zonePrefs = await SharedPreferences.getInstance();
              timeoutAuth = AuthService(
                backgroundActivityManager: BackgroundActivityManager(),
                userDataCleanupService: UserDataCleanupService(zonePrefs),
                keyStorage: zoneKeys,
                relayDiscoveryService: _networkFreeDiscovery(),
                profileCheckIndexerUrl: 'unsupported://profile.invalid',
              );
              final result = await timeoutAuth.importFromNsec(testNsec);
              expect(result.success, isTrue);
              expect(
                timeoutAuth.committedAccountActivationReceipt!.isCurrent,
                isTrue,
              );
              fixtureReady = true;
            }());
            async.flushMicrotasks();
            expect(fixtureReady, isTrue);
            final events = <String>[];
            var completed = false;
            Object? signOutError;
            final slow = Completer<void>();

            timeoutAuth.registerBeforeSessionTeardownCallback(() async {
              events.add('slow started');
              await slow.future;
              events.add('slow completed');
            });
            timeoutAuth.registerBeforeSessionTeardownCallback(() async {
              events.add('second started');
            });

            // Not awaited: signOut only completes once fakeAsync elapses the
            // teardown timeout below.
            unawaited(
              timeoutAuth.signOut().then<void>(
                (_) => completed = true,
                onError: (Object error) => signOutError = error,
              ),
            );
            async.flushMicrotasks();

            expect(events, ['slow started']);

            async.elapse(const Duration(seconds: 5));
            async.flushMicrotasks();

            expect(signOutError, isNull);
            expect(events, ['slow started', 'second started']);
            expect(completed, isTrue);
            expect(timeoutAuth.authState, AuthState.unauthenticated);
            slow.complete();
            async.flushMicrotasks();
            expect(events, [
              'slow started',
              'second started',
              'slow completed',
            ]);
            unawaited(timeoutAuth.dispose());
            async.flushMicrotasks();
          });
        },
      );
    });

    group('key deletion error propagation', () {
      setUp(prepareAuthenticatedFixture);

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
        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {
          primaryKeys = null;
        });
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
          expect(authService.currentPublicKeyHex, keyContainer.publicKeyHex);
          when(
            () => mockCleanupService.clearUserSpecificData(
              reason: 'explicit_logout',
              userPubkey: keyContainer.publicKeyHex,
              deleteUserData: true,
            ),
          ).thenThrow(StateError('database cleanup failed'));
          when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {
            primaryKeys = null;
          });
          when(() => mockKeyStorage.deleteIdentityKeyContainer(any()))
              .thenAnswer((invocation) async {
                mockKeyStorage.identitySnapshots.remove(
                  invocation.positionalArguments.single as String,
                );
              });
          when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
          when(() => mockKeyStorage.getKeyContainer())
              .thenAnswer((_) async => primaryKeys);

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

        // The authenticated leaving session remains intact — no cleanup happened
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
        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {
          primaryKeys = null;
        });
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
