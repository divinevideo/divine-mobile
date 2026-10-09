// ABOUTME: Preserves a continuing account when its deferred sweep is safe.
// ABOUTME: Exercises real cleanup, durable markers and list-session barriers.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/shared_channel_override.dart';
import '../../test_setup.dart';

class _Keys extends Mock implements SecureKeyStorage {}

class _Discovery extends Mock implements RelayDiscoveryService {}

class _CleanupBackend extends InMemorySharedPreferencesStore {
  _CleanupBackend(super.data) : super.withData();

  Completer<void>? readEntered;
  Completer<void>? resumeRead;
  Object? readFailure;
  final refusedKeys = <String>{};
  final lyingKeys = <String>{};

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (refusedKeys.any(key.endsWith)) {
      return false;
    }
    if (lyingKeys.any(key.endsWith)) {
      return true;
    }
    return super.setValue(type, key, value);
  }

  void pauseRead() {
    readEntered = Completer<void>();
    resumeRead = Completer<void>();
  }

  @override
  Future<Map<String, Object>> getAll() async {
    final entered = readEntered;
    final resume = resumeRead;
    readEntered = null;
    resumeRead = null;
    entered?.complete();
    if (resume != null) {
      await resume.future;
    }
    final failure = readFailure;
    if (failure != null) {
      throw failure;
    }
    return super.getAll();
  }
}

void main() {
  setupTestEnvironment();

  const nsec =
      'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
  const otherOwner =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  late SharedPreferencesStorePlatform originalStore;
  late _CleanupBackend backend;
  late SharedPreferences preferences;
  late UserDataCleanupService cleanup;
  late AuthService auth;
  late _Keys keys;
  late _Discovery discovery;
  late SecureKeyContainer container;
  FlutterSecureStorage? secureStorage;
  late List<({String? owner, bool destructive, bool preserveSession})> sweeps;
  var refuseDatabase = false;

  setUpAll(() => registerFallbackValue(SecureKeyContainer.fromNsec(nsec)));

  AuthService createAuth() {
    return AuthService(
      userDataCleanupService: cleanup,
      backgroundActivityManager: BackgroundActivityManager(),
      keyStorage: keys,
      flutterSecureStorage: secureStorage,
      relayDiscoveryService: discovery,
      // Fails synchronously inside the profile discovery's own catch instead
      // of starting a real WebSocket or suppressing unhandled test errors.
      profileCheckIndexerUrl: 'unsupported://profile.invalid',
    );
  }

  setUp(() async {
    container = SecureKeyContainer.fromNsec(nsec);
    secureStorage = null;
    originalStore = SharedPreferencesStorePlatform.instance;
    backend = _CleanupBackend({
      'flutter.current_user_pubkey_hex': container.publicKeyHex,
      'flutter.authentication_source': 'imported_keys',
      'flutter.kKnownAccounts': '[]',
    });
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = backend;
    preferences = await SharedPreferences.getInstance();
    sweeps = [];
    refuseDatabase = false;
    cleanup = UserDataCleanupService(preferences);
    cleanup.onDatabaseCleanup =
        ({
          String? userPubkey,
          bool deleteUserData = false,
          bool preserveActiveSession = false,
        }) async {
          sweeps.add((
            owner: userPubkey,
            destructive: deleteUserData,
            preserveSession: preserveActiveSession,
          ));
          if (refuseDatabase) {
            throw StateError('Database cleanup refused');
          }
        };

    keys = _Keys();
    discovery = _Discovery();
  });

  void stubKeyLifecycle() {
    when(keys.initialize).thenAnswer((_) async {});
    when(keys.hasKeys).thenAnswer((_) async => true);
    when(keys.clearCache).thenReturn(null);
    when(keys.dispose).thenReturn(null);
  }

  void stubLocalAndStoredKeys() {
    when(() => keys.importFromNsec(any())).thenAnswer((_) async => container);
    when(() => keys.getIdentityKeyContainer(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.single == container.npub
          ? container
          : null,
    );
    when(keys.getKeyContainer).thenAnswer((_) async => container);
    when(() => keys.switchToIdentity(any())).thenAnswer((_) async => true);
    when(
      () => keys.storeIdentityKeyContainer(any(), any()),
    ).thenAnswer((_) async {});
  }

  void stubNetworkFreeDiscovery() {
    when(() => discovery.clearCache(any())).thenAnswer((_) async {});
    when(() => discovery.discoverRelays(any())).thenAnswer(
      (_) async => RelayDiscoveryResult.failure('No relay discovery in test'),
    );
  }

  void stubGeneratedPrimary(SecureKeyContainer generated) {
    var primary = container;
    when(keys.getKeyContainer).thenAnswer((_) async => primary);
    when(() => keys.importFromNsec(any())).thenAnswer((_) async {
      primary = container;
      return container;
    });
    when(
      () => keys.generateAndStoreKeys(
        primaryWriteGuard: any(named: 'primaryWriteGuard'),
      ),
    ).thenAnswer((invocation) async {
      final guard =
          invocation.namedArguments[#primaryWriteGuard]
              as PrimaryKeyPersistenceGuard;
      await guard(generated.publicKeyHex, () async {
        primary = generated;
      });
      return generated;
    });
  }

  tearDown(() async {
    await auth.dispose();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = originalStore;
  });

  Future<void> establishLive() async {
    final result = await auth.importFromNsec(nsec);
    expect(result.success, isTrue);
    expect(auth.authState, AuthState.authenticated);
    expect(auth.currentPublicKeyHex, container.publicKeyHex);
    expect(sweeps, isEmpty);
    // Let the injected, network-free discovery finish before concurrency tests
    // reset the singleton. Only preferences loading is paused in those tests.
    await pumpEventQueue();
  }

  Future<void> recordPending({
    String? owner,
    bool destructive = false,
  }) => PendingAccountCleanup(
    userPubkey: owner ?? container.publicKeyHex,
    isIdentityChange: true,
    deleteUserData: destructive,
  ).record(preferences);

  Future<void> reenter() => auth.signInForAccount(
    container.publicKeyHex,
    AuthenticationSource.importedKeys,
  );

  KeycastSession oauthSession({String? owner}) => KeycastSession(
    bunkerUrl: 'https://keycast.example.com',
    accessToken: 'synthetic-access-token',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    userPubkey: owner ?? container.publicKeyHex,
  );

  Future<void> expectFailedSweep({required String? owner}) async {
    refuseDatabase = true;
    final marker = preferences.get(PendingAccountCleanup.storageKey);
    await expectLater(reenter(), throwsA(isA<UserDataCleanupException>()));
    expect(sweeps.single.owner, owner);
    expect(sweeps.single.preserveSession, isFalse);
    expect(auth.authState, AuthState.unauthenticated);
    expect(auth.currentPublicKeyHex, isNull);
    expect(auth.lastFailureReason, AuthFailureReason.accountCleanupFailed);
    expect(preferences.get(PendingAccountCleanup.storageKey), marker);
  }

  group('prepared native signer entry', () {
    setUp(stubKeyLifecycle);
    setUp(stubLocalAndStoredKeys);
    setUp(stubNetworkFreeDiscovery);

    test(
      'a queued import cannot borrow or disable suspended signer authority',
      () async {
        secureStorage = const FlutterSecureStorage();
        auth = createAuth();
        final archiveKey = 'keycast_session_${container.publicKeyHex}';
        final globalWrites = <String>[];
        final data = <String, String>{};
        final readEntered = Completer<void>();
        final resumeRead = Completer<void>();
        var pauseArchive = false;
        overrideSharedChannel(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final key = call.arguments['key'] as String?;
            switch (call.method) {
              case 'read':
                if (key == archiveKey && pauseArchive) {
                  pauseArchive = false;
                  readEntered.complete();
                  await resumeRead.future;
                }
                return data[key];
              case 'write':
                globalWrites.add(key!);
                data[key] = call.arguments['value'] as String;
              case 'delete':
                globalWrites.add(key!);
                data.remove(key);
            }
            return null;
          },
        );
        await establishLive();
        final originalIdentity = auth.currentIdentity;
        final archiveRaw = jsonEncode(oauthSession().toJson());
        data[archiveKey] = archiveRaw;
        pauseArchive = true;
        globalWrites.clear();
        final oldAttempt = expectLater(
          auth.signInForAccount(
            container.publicKeyHex,
            AuthenticationSource.divineOAuth,
          ),
          throwsA(isA<AccountActivationRetiredException>()),
        );
        Future<void>? nextChecked;
        try {
          await readEntered.future;
          final nextBegun = AccountActivationCoordinator.forPreferences(
            preferences,
          ).changes.first;
          // Import intent retires the signer, but its PRIMARY write waits for
          // the old native lease before changing a tentative identity.
          final nextImport = auth.importFromNsec(nsec);
          nextChecked = expectLater(
            nextImport,
            completion(
              isA<AuthResult>().having(
                (result) => result.success,
                'success',
                isFalse,
              ),
            ),
          );
          await nextBegun;
          expect(auth.currentIdentity, same(originalIdentity));
          expect(auth.committedAccountActivationReceipt, isNull);
          auth.retireAccountSwitchActivation();
        } finally {
          if (!resumeRead.isCompleted) {
            resumeRead.complete();
          }
          await oldAttempt;
          if (nextChecked != null) {
            await nextChecked;
          }
        }
        expect(
          globalWrites,
          isEmpty,
          reason: 'Retired native proof cannot write session or signer slots',
        );
        expect(preferences.getString('authentication_source'), 'imported_keys');
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        expect(data[archiveKey], archiveRaw);
      },
    );
  });

  group('activation publication boundary', () {
    setUp(() {
      secureStorage = null;
      stubKeyLifecycle();
      stubLocalAndStoredKeys();
      stubNetworkFreeDiscovery();
      auth = createAuth();
    });

    for (final key in [
      'current_user_pubkey_hex',
      'authentication_source',
      'last_used_npub',
      'known_accounts',
    ]) {
      for (final failure in ['refused', 'lying']) {
        test('$failure $key cannot emit an authenticated activation', () async {
          // Different pre-existing values make a lying acknowledgement visible
          // to native readback instead of accidentally satisfying the assertion.
          await preferences.remove(key);
          if (failure == 'refused') backend.refusedKeys.add(key);
          if (failure == 'lying') backend.lyingKeys.add(key);
          final emitted = <AuthState>[];
          final subscription = auth.authStateStream.listen(emitted.add);
          final result = await auth.importFromNsec(nsec);
          await pumpEventQueue();
          expect(result.success, isFalse);
          expect(auth.authState, AuthState.unauthenticated);
          expect(result.failureReason, AuthFailureReason.accountCleanupFailed);
          expect(auth.currentIdentity, isNull);
          expect(auth.currentPublicKeyHex, isNull);
          expect(emitted, isNot(contains(AuthState.authenticated)));
          expect(auth.committedAccountOwnerPubkey, isNull);
          expect(auth.committedAccountActivationReceipt, isNull);
          expect(auth.takeFreshAccountListCreationPermit(), isNull);
          expect(
            AccountActivationCoordinator.forPreferences(
              preferences,
            ).hasUnresolvedActivation,
            isTrue,
          );
          await subscription.cancel();
        });
      }
    }

    test('unreadable known accounts retain their exact evidence', () async {
      await preferences.setString('known_accounts', '{damaged');
      final result = await auth.importFromNsec(nsec);
      expect(result.success, isFalse);
      expect(preferences.getString('known_accounts'), '{damaged');
      expect(auth.committedAccountOwnerPubkey, isNull);
    });

    test(
      'imported and restored identities cannot obtain creation permission',
      () async {
        await establishLive();
        final importedReceipt = auth.committedAccountActivationReceipt!;
        expect(importedReceipt.isCurrent, isTrue);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        await reenter();
        expect(importedReceipt.isCurrent, isFalse);
        expect(auth.committedAccountActivationReceipt!.isCurrent, isTrue);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        verifyNever(
          () => keys.generateAndStoreKeys(
            primaryWriteGuard: any(named: 'primaryWriteGuard'),
          ),
        );
      },
    );

    test(
      'only real generation creates a revocable one-use permission',
      () async {
        final generated = await SecureKeyContainer.generate();
        stubGeneratedPrimary(generated);
        final result = await auth.createNewIdentity();
        expect(result.success, isTrue);
        final permit = auth.takeFreshAccountListCreationPermit()!;
        expect(permit.ownerPubkey, generated.publicKeyHex);
        expect(permit.consumeFor(otherOwner), isFalse);
        expect(permit.consumeFor(generated.publicKeyHex), isTrue);
        expect(permit.consumeFor(generated.publicKeyHex), isFalse);
        expect(permit.isCurrentFor(generated.publicKeyHex), isTrue);
        await auth.importFromNsec(nsec);
        expect(permit.isCurrentFor(generated.publicKeyHex), isFalse);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        verify(
          () => keys.generateAndStoreKeys(
            primaryWriteGuard: any(named: 'primaryWriteGuard'),
          ),
        ).called(1);
      },
    );

    test(
      'normal verified logout can restore its account without a creation grant',
      () async {
        await establishLive();
        final before = auth.committedAccountActivationReceipt!;
        final owner = container.publicKeyHex;
        final originalKeys = container;
        await auth.signOut();
        expect(auth.authState, AuthState.unauthenticated);
        expect(before.isCurrent, isFalse);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(
          AccountActivationCoordinator.forPreferences(
            preferences,
          ).hasUnresolvedActivation,
          isFalse,
        );
        expect(
          () => originalKeys.publicKeyHex,
          throwsA(isA<SecureKeyException>()),
        );
        // Native restore creates a fresh key object; the old auth object is
        // intentionally disposed by logout and cannot be reused by this mock.
        container = SecureKeyContainer.fromNsec(nsec);
        expect(container.publicKeyHex, owner);
        await reenter();
        expect(auth.authState, AuthState.authenticated);
        expect(auth.committedAccountOwnerPubkey, owner);
        expect(auth.committedAccountActivationReceipt!.isCurrent, isTrue);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
      },
    );

    test(
      'terminal event carries proof after assignment and fresh permission',
      () async {
        final generated = await SecureKeyContainer.generate();
        stubGeneratedPrimary(generated);
        final delivered = <bool>[];
        final subscription = auth.accountActivationChanges.listen((receipt) {
          if (receipt != null) {
            delivered.add(
              identical(receipt, auth.committedAccountActivationReceipt) &&
                  auth.isAuthenticated &&
                  receipt.isCurrent &&
                  auth.takeFreshAccountListCreationPermit() != null,
            );
          }
        });
        expect((await auth.createNewIdentity()).success, isTrue);
        await pumpEventQueue();
        expect(delivered, [true]);
        await subscription.cancel();
      },
    );
  });

  group('signInForAccount pending cleanup', () {
    setUp(stubKeyLifecycle);
    setUp(stubLocalAndStoredKeys);
    setUp(stubNetworkFreeDiscovery);
    setUp(() {
      auth = createAuth();
    });

    test(
      'same live owner preserves its marker, list lease and authentication',
      () async {
        await establishLive();
        final lease = CuratedListSessionCoordinator.forPreferences(
          preferences,
        ).acquire();
        await recordPending();
        final marker = preferences.getString(PendingAccountCleanup.storageKey);
        // An unavailable cleanup backend cannot disconnect this continuing owner.
        refuseDatabase = true;
        await reenter();
        await reenter();
        expect(sweeps, isEmpty);
        expect(lease.isCurrent, isTrue);
        expect(auth.authState, AuthState.authenticated);
        expect(auth.currentPublicKeyHex, container.publicKeyHex);
        expect(preferences.getString(PendingAccountCleanup.storageKey), marker);
      },
    );

    test(
      'a deferred marker executes before the next cold authentication',
      () async {
        await establishLive();
        await recordPending();
        await reenter();
        expect(sweeps, isEmpty);
        final owner = container.publicKeyHex;
        await auth.dispose();
        // Disposal securely destroys a key container; emulate reading it again.
        container = SecureKeyContainer.fromNsec(nsec);
        SharedPreferences.resetStatic();
        preferences = await SharedPreferences.getInstance();
        cleanup = UserDataCleanupService(preferences)
          ..onDatabaseCleanup =
              ({
                userPubkey,
                deleteUserData = false,
                preserveActiveSession = false,
              }) async {
                expect(auth.isAuthenticated, isFalse);
                sweeps.add((
                  owner: userPubkey,
                  destructive: deleteUserData,
                  preserveSession: preserveActiveSession,
                ));
              };
        auth = createAuth();
        final lease = CuratedListSessionCoordinator.forPreferences(
          preferences,
        ).acquire();
        await reenter();
        expect(sweeps.single.owner, owner);
        expect(lease.isCurrent, isFalse);
        expect(
          preferences.containsKey(PendingAccountCleanup.storageKey),
          isFalse,
        );
        expect(auth.authState, AuthState.authenticated);
      },
    );

    test(
      'cold same-owner cleanup cannot use a live-session exception',
      () async {
        await recordPending();
        await expectFailedSweep(owner: container.publicKeyHex);
      },
    );

    test('a destructive pending intent cannot be deferred', () async {
      await establishLive();
      await recordPending(destructive: true);
      await expectFailedSweep(owner: container.publicKeyHex);
      expect(sweeps.single.destructive, isTrue);
    });

    test('an intent for a different owner cannot be deferred', () async {
      await establishLive();
      await recordPending(owner: otherOwner);
      await expectFailedSweep(owner: otherOwner);
    });

    test(
      'matching stored and intent owners cannot replace the established owner',
      () async {
        await establishLive();
        final incoming = SecureKeyContainer.fromNsec(
          'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl',
        );
        await recordPending(owner: incoming.publicKeyHex);
        await preferences.setString(
          'current_user_pubkey_hex',
          incoming.publicKeyHex,
        );
        when(
          () => keys.getIdentityKeyContainer(incoming.npub),
        ).thenAnswer((_) async => incoming);
        when(() => keys.switchToIdentity(incoming.npub)).thenAnswer((_) async {
          when(keys.getKeyContainer).thenAnswer((_) async => incoming);
          return true;
        });
        refuseDatabase = true;
        await expectLater(
          auth.signInForAccount(
            incoming.publicKeyHex,
            AuthenticationSource.importedKeys,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(sweeps.single.owner, incoming.publicKeyHex);
        expect(auth.authState, AuthState.unauthenticated);
      },
    );

    test(
      'an unowned intent cannot be assumed to belong to the live account',
      () async {
        await establishLive();
        await const PendingAccountCleanup(
          userPubkey: null,
          isIdentityChange: true,
          deleteUserData: false,
        ).record(preferences);
        await expectFailedSweep(owner: null);
      },
    );

    for (final storedOwner in [otherOwner, null]) {
      test(
        'persisted owner $storedOwner cannot borrow the live exception',
        () async {
          await establishLive();
          await recordPending();
          if (storedOwner == null) {
            await preferences.remove('current_user_pubkey_hex');
          } else {
            await preferences.setString('current_user_pubkey_hex', storedOwner);
          }
          await expectFailedSweep(owner: container.publicKeyHex);
          expect(preferences.getString('current_user_pubkey_hex'), storedOwner);
        },
      );
    }

    for (final marker in ['{broken', '{"version":1}', true]) {
      test(
        'unreadable marker $marker stays intact and blocks sign-in',
        () async {
          await establishLive();
          if (marker is String) {
            await preferences.setString(
              PendingAccountCleanup.storageKey,
              marker,
            );
          } else if (marker is bool) {
            await preferences.setBool(PendingAccountCleanup.storageKey, marker);
          }
          final lease = CuratedListSessionCoordinator.forPreferences(
            preferences,
          ).acquire();
          await expectLater(
            reenter(),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(sweeps, isEmpty);
          expect(lease.isCurrent, isFalse);
          expect(auth.authState, AuthState.unauthenticated);
          expect(auth.currentPublicKeyHex, isNull);
          expect(preferences.get(PendingAccountCleanup.storageKey), marker);
          expect(
            (await backend
                .getAll())['flutter.${PendingAccountCleanup.storageKey}'],
            marker,
          );
        },
      );
    }
  });

  group('signInWithDivineOAuth pending cleanup', () {
    setUp(stubKeyLifecycle);
    setUp(stubLocalAndStoredKeys);
    setUp(stubNetworkFreeDiscovery);
    setUp(() {
      auth = createAuth();
    });

    test(
      'OAuth captures the continuing account before its authenticating state',
      () async {
        await establishLive();
        await recordPending();
        final marker = preferences.getString(PendingAccountCleanup.storageKey);
        final lease = CuratedListSessionCoordinator.forPreferences(
          preferences,
        ).acquire();
        refuseDatabase = true;
        await auth.signInWithDivineOAuth(oauthSession());
        expect(sweeps, isEmpty);
        expect(lease.isCurrent, isTrue);
        expect(auth.authState, AuthState.authenticated);
        expect(preferences.getString(PendingAccountCleanup.storageKey), marker);
      },
    );

    test('cold OAuth cannot borrow a continuing account context', () async {
      await recordPending();
      refuseDatabase = true;
      await expectLater(
        auth.signInWithDivineOAuth(oauthSession()),
        throwsA(isA<UserDataCleanupException>()),
      );
      expect(sweeps.single.owner, container.publicKeyHex);
      expect(auth.authState, AuthState.unauthenticated);
    });

    test('OAuth changing owners still performs required cleanup', () async {
      await establishLive();
      await recordPending();
      refuseDatabase = true;
      await expectLater(
        auth.signInWithDivineOAuth(oauthSession(owner: otherOwner)),
        throwsA(isA<UserDataCleanupException>()),
      );
      expect(sweeps.single.owner, container.publicKeyHex);
      expect(auth.authState, AuthState.unauthenticated);
    });

    test(
      'OAuth cannot reuse an identity replaced before setup starts',
      () async {
        await establishLive();
        await recordPending();
        final lookupEntered = Completer<void>();
        final resumeLookup = Completer<void>();
        when(() => keys.getIdentityKeyContainer(any())).thenAnswer((_) async {
          lookupEntered.complete();
          await resumeLookup.future;
          return container;
        });
        refuseDatabase = true;
        final attempt = auth.signInWithDivineOAuth(oauthSession());
        final failed = expectLater(
          attempt,
          throwsA(isA<UserDataCleanupException>()),
        );
        await lookupEntered.future;
        auth.debugSetIdentity(
          LocalNostrIdentity(keyContainer: SecureKeyContainer.fromNsec(nsec)),
        );
        resumeLookup.complete();
        await failed;
        expect(sweeps.single.owner, container.publicKeyHex);
        expect(auth.authState, AuthState.unauthenticated);
      },
    );

    for (final originallyLive in [true, false]) {
      test('retired OAuth with originally live=$originallyLive cannot alter a '
          'newly authenticated same-owner session', () async {
        if (originallyLive) {
          await establishLive();
        }
        final originalIdentity = auth.currentIdentity;
        final lookupEntered = Completer<void>();
        final resumeLookup = Completer<void>();
        var pauseNextLookup = true;
        when(() => keys.getIdentityKeyContainer(any())).thenAnswer((_) async {
          if (pauseNextLookup) {
            pauseNextLookup = false;
            lookupEntered.complete();
            await resumeLookup.future;
          }
          return container;
        });

        final attempt = auth.signInWithDivineOAuth(oauthSession());
        final failed = expectLater(
          attempt,
          throwsA(isA<AccountActivationRetiredException>()),
        );
        await lookupEntered.future;
        // Finish another real setup while the OAuth entry is awaiting keys. Its
        // authenticated state must not replace the OAuth entry's captured one.
        await reenter();
        expect(auth.authState, AuthState.authenticated);
        expect(auth.currentIdentity, isNot(same(originalIdentity)));
        final replacementIdentity = auth.currentIdentity;
        final replacementReceipt = auth.committedAccountActivationReceipt;
        expect(sweeps, isEmpty);
        await recordPending();
        final marker = preferences.getString(PendingAccountCleanup.storageKey);
        refuseDatabase = true;
        resumeLookup.complete();
        await failed;
        expect(sweeps, isEmpty);
        expect(auth.authState, AuthState.authenticated);
        expect(auth.currentIdentity, same(replacementIdentity));
        expect(
          auth.committedAccountActivationReceipt,
          same(replacementReceipt),
        );
        expect(replacementReceipt!.isCurrent, isTrue);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        expect(preferences.getString(PendingAccountCleanup.storageKey), marker);
      });
    }
  });

  group('signInForAccount entry context', () {
    setUp(stubKeyLifecycle);
    setUp(stubLocalAndStoredKeys);
    setUp(stubNetworkFreeDiscovery);
    setUp(() {
      auth = createAuth();
    });

    for (final originallyLive in [true, false]) {
      test(
        'stored-key entry with originally live=$originallyLive cannot borrow '
        'a newly authenticated same-owner session',
        () async {
          if (originallyLive) {
            await establishLive();
          }
          final originalIdentity = auth.currentIdentity;
          final lookupEntered = Completer<void>();
          final resumeLookup = Completer<void>();
          var pauseNextLookup = true;
          when(() => keys.getIdentityKeyContainer(any())).thenAnswer((_) async {
            if (pauseNextLookup) {
              pauseNextLookup = false;
              lookupEntered.complete();
              await resumeLookup.future;
            }
            return container;
          });
          final failed = expectLater(
            reenter(),
            throwsA(isA<AccountActivationRetiredException>()),
          );
          await lookupEntered.future;
          await reenter();
          expect(auth.authState, AuthState.authenticated);
          expect(auth.currentIdentity, isNot(same(originalIdentity)));
          final replacementIdentity = auth.currentIdentity;
          final replacementReceipt = auth.committedAccountActivationReceipt;
          await recordPending();
          final marker = preferences.getString(
            PendingAccountCleanup.storageKey,
          );
          refuseDatabase = true;
          resumeLookup.complete();
          await failed;
          expect(sweeps, isEmpty);
          expect(auth.authState, AuthState.authenticated);
          expect(auth.currentIdentity, same(replacementIdentity));
          expect(
            auth.committedAccountActivationReceipt,
            same(replacementReceipt),
          );
          expect(replacementReceipt!.isCurrent, isTrue);
          expect(auth.takeFreshAccountListCreationPermit(), isNull);
          expect(
            preferences.getString(PendingAccountCleanup.storageKey),
            marker,
          );
        },
      );

      test('retired stored OAuth with originally live=$originallyLive cannot '
          'write through the next same-owner session', () async {
        await auth.dispose();
        secureStorage = const FlutterSecureStorage();
        auth = createAuth();
        if (originallyLive) {
          await establishLive();
        }
        final originalIdentity = auth.currentIdentity;
        final archiveKey = 'keycast_session_${container.publicKeyHex}';
        final archiveRaw = jsonEncode(oauthSession().toJson());
        final data = <String, String>{archiveKey: archiveRaw};
        final signerWrites = <String>[];
        final readEntered = Completer<void>();
        final resumeRead = Completer<void>();
        var pauseArchive = true;
        overrideSharedChannel(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final key = call.arguments['key'] as String?;
            switch (call.method) {
              case 'read':
                if (key == archiveKey && pauseArchive) {
                  pauseArchive = false;
                  readEntered.complete();
                  await resumeRead.future;
                }
                return data[key];
              case 'write':
                signerWrites.add(key!);
                data[key] = call.arguments['value'] as String;
              case 'delete':
                data.remove(key);
            }
            return null;
          },
        );
        final failed = expectLater(
          auth.signInForAccount(
            container.publicKeyHex,
            AuthenticationSource.divineOAuth,
          ),
          throwsA(isA<AccountActivationRetiredException>()),
        );
        Future<void>? nextChecked;
        var nextCompleted = false;
        try {
          await readEntered.future;
          final oldRecord = preferences.getString(
            AccountActivationCoordinator.storageKey,
          );
          final nextBegun = AccountActivationCoordinator.forPreferences(
            preferences,
          ).changes.first;
          final nextOperation = reenter().whenComplete(() {
            nextCompleted = true;
          });
          nextChecked = expectLater(nextOperation, completes);
          await nextBegun;
          expect(nextCompleted, isFalse);
          expect(auth.currentIdentity, same(originalIdentity));
          expect(auth.committedAccountActivationReceipt, isNull);
          expect(sweeps, isEmpty);
          expect(signerWrites, isEmpty);
          expect(
            preferences.getString(AccountActivationCoordinator.storageKey),
            oldRecord,
          );
        } finally {
          if (!resumeRead.isCompleted) {
            resumeRead.complete();
          }
          await failed;
          if (nextChecked != null) {
            await nextChecked;
          }
        }
        expect(nextCompleted, isTrue);
        expect(auth.authState, AuthState.authenticated);
        expect(auth.currentIdentity, isNot(same(originalIdentity)));
        expect(auth.committedAccountActivationReceipt!.isCurrent, isTrue);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        expect(sweeps, isEmpty);
        expect(data[archiveKey], archiveRaw);
        expect(
          signerWrites,
          isNot(
            anyOf(
              contains('keycast_session'),
              contains('keycast_refresh_token'),
              contains('keycast_auth_handle'),
            ),
          ),
        );
      });
    }
  });

  group('importFromNsec entry context', () {
    setUp(stubKeyLifecycle);
    setUp(stubLocalAndStoredKeys);
    setUp(stubNetworkFreeDiscovery);
    setUp(() {
      auth = createAuth();
    });

    test(
      'a retired native import cannot alter the replacement session',
      () async {
        final importEntered = Completer<void>();
        final resumeImport = Completer<void>();
        when(() => keys.importFromNsec(any())).thenAnswer((_) async {
          importEntered.complete();
          await resumeImport.future;
          return container;
        });
        final attempt = auth.importFromNsec(nsec);
        await importEntered.future.timeout(const Duration(seconds: 5));
        final coordinator = AccountActivationCoordinator.forPreferences(
          preferences,
        );
        final nextBegun = coordinator.changes.first;
        var nextSettled = false;
        final next = reenter().whenComplete(() => nextSettled = true);
        final nextChecked = expectLater(next, completes);
        late AuthResult result;
        try {
          await nextBegun.timeout(const Duration(seconds: 5));
          expect(nextSettled, isFalse);
          expect(auth.currentIdentity, isNull);
          expect(auth.committedAccountActivationReceipt, isNull);
          expect(sweeps, isEmpty);
        } finally {
          resumeImport.complete();
          result = await attempt;
          await nextChecked;
        }
        expect(result.success, isFalse);
        expect(
          result.errorMessage,
          contains('AccountActivationRetiredException'),
        );
        expect(auth.authState, AuthState.authenticated);
        expect(auth.currentPublicKeyHex, container.publicKeyHex);
        expect(auth.committedAccountActivationReceipt!.isCurrent, isTrue);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
        expect(sweeps, isEmpty);
        await recordPending();
        final marker = preferences.getString(PendingAccountCleanup.storageKey);
        await pumpEventQueue();
        expect(preferences.getString(PendingAccountCleanup.storageKey), marker);
      },
    );

    test(
      'a current explicit import cannot borrow the live cleanup exception',
      () async {
        await establishLive();
        await recordPending();
        final marker = preferences.getString(PendingAccountCleanup.storageKey);
        refuseDatabase = true;
        final result = await auth.importFromNsec(nsec);
        expect(result.success, isFalse);
        expect(result.failureReason, AuthFailureReason.accountCleanupFailed);
        expect(sweeps.single.owner, container.publicKeyHex);
        expect(preferences.getString(PendingAccountCleanup.storageKey), marker);
        expect(auth.authState, AuthState.unauthenticated);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(auth.takeFreshAccountListCreationPermit(), isNull);
      },
    );
  });

  group('signInForAccount setup continuity', () {
    setUp(stubKeyLifecycle);
    setUp(stubLocalAndStoredKeys);
    setUp(stubNetworkFreeDiscovery);
    setUp(() {
      auth = createAuth();
    });

    for (final replacement in ['identity', 'key container']) {
      test(
        'same-owner $replacement replacement cannot defer stale setup',
        () async {
          await establishLive();
          await recordPending();
          final marker = preferences.getString(
            PendingAccountCleanup.storageKey,
          );
          final established = auth.currentIdentity;
          backend.pauseRead();
          final readEntered = backend.readEntered!;
          final resumeRead = backend.resumeRead!;
          SharedPreferences.resetStatic();
          refuseDatabase = true;
          final failed = expectLater(
            reenter(),
            throwsA(isA<UserDataCleanupException>()),
          );
          await readEntered.future;
          try {
            // Activation preparation now reads preferences before setup; entry
            // eligibility must preserve BOTH original references across it.
            expect(auth.currentIdentity, same(established));
            if (replacement == 'identity') {
              auth.debugSetIdentity(
                LocalNostrIdentity(
                  keyContainer: SecureKeyContainer.fromNsec(nsec),
                ),
              );
              expect(auth.currentIdentity, isNot(same(established)));
            } else {
              auth.debugSetCurrentKeyContainer(
                SecureKeyContainer.fromNsec(nsec),
              );
              expect(auth.currentIdentity, same(established));
            }
            expect(auth.currentPublicKeyHex, container.publicKeyHex);
            expect(auth.authState, AuthState.authenticated);
          } finally {
            resumeRead.complete();
          }
          await failed;
          expect(sweeps.single.owner, container.publicKeyHex);
          expect(
            preferences.getString(PendingAccountCleanup.storageKey),
            marker,
          );
        },
      );
    }

    test(
      'unexpected preferences read failure cannot become a successful deferral',
      () async {
        await establishLive();
        await recordPending();
        final marker = preferences.getString(PendingAccountCleanup.storageKey);
        backend.readFailure = StateError('Unexpected preferences read failure');
        SharedPreferences.resetStatic();
        final priorReceipt = auth.committedAccountActivationReceipt!;
        final failedAttempt = reenter();
        expect(priorReceipt.isCurrent, isFalse);
        expect(auth.committedAccountActivationReceipt, isNull);
        try {
          await expectLater(
            failedAttempt,
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(auth.isAuthenticated, isFalse);
          expect(auth.authState, AuthState.unauthenticated);
          expect(
            auth.lastFailureReason,
            AuthFailureReason.accountCleanupFailed,
          );
          expect(auth.currentIdentity, isNull);
          expect(auth.currentPublicKeyHex, isNull);
          expect(auth.committedAccountActivationReceipt, isNull);
          expect(auth.takeFreshAccountListCreationPermit(), isNull);
          expect(sweeps, isEmpty);
          expect(
            preferences.getString(PendingAccountCleanup.storageKey),
            marker,
          );
        } finally {
          backend.readFailure = null;
        }
        expect(
          (await backend
              .getAll())['flutter.${PendingAccountCleanup.storageKey}'],
          marker,
        );
      },
    );
  });
}
