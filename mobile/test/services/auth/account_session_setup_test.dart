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
    if (resume != null) await resume.future;
    final failure = readFailure;
    if (failure != null) throw failure;
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
          if (refuseDatabase) throw StateError('Database cleanup refused');
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
    when(() => keys.storeIdentityKeyContainer(any(), any()))
        .thenAnswer((_) async {});
  }

  void stubNetworkFreeDiscovery() {
    when(() => discovery.discoverRelays(any())).thenAnswer(
      (_) async => RelayDiscoveryResult.failure('No relay discovery in test'),
    );
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
        final lease = CuratedListSessionCoordinator.forPreferences(preferences)
            .acquire();
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
        final lease = CuratedListSessionCoordinator.forPreferences(preferences)
            .acquire();
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
        when(() => keys.getIdentityKeyContainer(incoming.npub))
            .thenAnswer((_) async => incoming);
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
        final lease = CuratedListSessionCoordinator.forPreferences(preferences)
            .acquire();
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
      test('OAuth with originally live=$originallyLive cannot borrow a newly '
          'authenticated same-owner session', () async {
        if (originallyLive) await establishLive();
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
          throwsA(isA<UserDataCleanupException>()),
        );
        await lookupEntered.future;
        // Finish another real setup while the OAuth entry is awaiting keys. Its
        // authenticated state must not replace the OAuth entry's captured one.
        await reenter();
        expect(auth.authState, AuthState.authenticated);
        expect(auth.currentIdentity, isNot(same(originalIdentity)));
        expect(sweeps, isEmpty);
        await recordPending();
        final marker = preferences.getString(PendingAccountCleanup.storageKey);
        refuseDatabase = true;
        resumeLookup.complete();
        await failed;
        expect(sweeps.single.owner, container.publicKeyHex);
        expect(auth.authState, AuthState.unauthenticated);
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
          if (originallyLive) await establishLive();
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
            throwsA(isA<UserDataCleanupException>()),
          );
          await lookupEntered.future;
          await reenter();
          expect(auth.authState, AuthState.authenticated);
          expect(auth.currentIdentity, isNot(same(originalIdentity)));
          await recordPending();
          final marker = preferences.getString(
            PendingAccountCleanup.storageKey,
          );
          refuseDatabase = true;
          resumeLookup.complete();
          await failed;
          expect(sweeps.single.owner, container.publicKeyHex);
          expect(auth.authState, AuthState.unauthenticated);
          expect(
            preferences.getString(PendingAccountCleanup.storageKey),
            marker,
          );
        },
      );

      test('stored OAuth with originally live=$originallyLive cannot recapture '
          'a newly authenticated same-owner session', () async {
        await auth.dispose();
        secureStorage = const FlutterSecureStorage();
        auth = createAuth();
        if (originallyLive) await establishLive();
        final originalIdentity = auth.currentIdentity;
        final archiveKey = 'keycast_session_${container.publicKeyHex}';
        final data = <String, String>{
          archiveKey: jsonEncode(oauthSession().toJson()),
        };
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
                data[key!] = call.arguments['value'] as String;
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
          throwsA(isA<UserDataCleanupException>()),
        );
        await readEntered.future;
        await reenter();
        expect(auth.authState, AuthState.authenticated);
        expect(auth.currentIdentity, isNot(same(originalIdentity)));
        await recordPending();
        final marker = preferences.getString(PendingAccountCleanup.storageKey);
        refuseDatabase = true;
        resumeRead.complete();
        await failed;
        expect(sweeps.single.owner, container.publicKeyHex);
        expect(auth.authState, AuthState.unauthenticated);
        expect(preferences.getString(PendingAccountCleanup.storageKey), marker);
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
      'explicit key import cannot borrow a concurrently established session',
      () async {
        final importEntered = Completer<void>();
        final resumeImport = Completer<void>();
        when(() => keys.importFromNsec(any())).thenAnswer((_) async {
          importEntered.complete();
          await resumeImport.future;
          return container;
        });
        final attempt = auth.importFromNsec(nsec);
        await importEntered.future;
        await reenter();
        expect(auth.isAuthenticated, isTrue);
        await recordPending();
        final marker = preferences.getString(PendingAccountCleanup.storageKey);
        refuseDatabase = true;
        resumeImport.complete();
        final result = await attempt;
        expect(result.success, isFalse);
        expect(result.failureReason, AuthFailureReason.accountCleanupFailed);
        expect(sweeps.single.owner, container.publicKeyHex);
        expect(preferences.getString(PendingAccountCleanup.storageKey), marker);
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
          final tentative = auth.currentIdentity;
          expect(tentative, isNot(same(established)));
          expect(tentative!.pubkey, container.publicKeyHex);
          if (replacement == 'identity') {
            auth.debugSetIdentity(
              LocalNostrIdentity(
                keyContainer: SecureKeyContainer.fromNsec(nsec),
              ),
            );
            expect(auth.currentIdentity, isNot(same(tentative)));
          } else {
            auth.debugSetCurrentKeyContainer(SecureKeyContainer.fromNsec(nsec));
            expect(auth.currentIdentity, same(tentative));
          }
          expect(auth.currentPublicKeyHex, container.publicKeyHex);
          expect(auth.authState, AuthState.authenticated);
          resumeRead.complete();
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
        await expectLater(
          reenter(),
          throwsA(isA<AccountRestoreFailedException>()),
        );
        expect(auth.isAuthenticated, isFalse);
        expect(sweeps, isEmpty);
        expect(preferences.getString(PendingAccountCleanup.storageKey), marker);
        backend.readFailure = null;
        expect(
          (await backend
              .getAll())['flutter.${PendingAccountCleanup.storageKey}'],
          marker,
        );
      },
    );
  });
}
