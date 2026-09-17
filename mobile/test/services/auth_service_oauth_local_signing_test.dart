// ABOUTME: Tests local-signing resolution inside signInWithDivineOAuth.
// ABOUTME: Pins that locally-stored nsec bypasses Keycast RPC for signing.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
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

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      data[key] = value;
    } else {
      data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

// Two distinct nsecs so we can exercise the pubkey-mismatch guard.
const _matchingNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
const _otherNsec =
    'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl';

Future<T> _ignoringDiscoveryErrors<T>(Future<T> Function() body) async {
  final completer = Completer<T>();
  runZonedGuarded(
    () async {
      try {
        completer.complete(await body());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    },
    (_, _) {
      // Absorb unawaited _performDiscovery errors.
    },
  );
  return completer.future;
}

void main() {
  setupTestEnvironment();

  late _MockSecureKeyStorage mockKeyStorage;
  late _MockUserDataCleanupService mockCleanupService;
  late _MockKeycastOAuth mockOAuthClient;
  late _FakeFlutterSecureStorage fakeSecureStorage;
  late AuthService authService;

  late SecureKeyContainer matchingContainer;
  late SecureKeyContainer otherContainer;
  late KeycastSession session;

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(_matchingNsec));
  });

  setUp(() {
    mockKeyStorage = _MockSecureKeyStorage();
    mockCleanupService = _MockUserDataCleanupService();
    mockOAuthClient = _MockKeycastOAuth();
    fakeSecureStorage = _FakeFlutterSecureStorage();

    matchingContainer = SecureKeyContainer.fromNsec(_matchingNsec);
    otherContainer = SecureKeyContainer.fromNsec(_otherNsec);

    // A non-expired session whose userPubkey matches matchingContainer so
    // signInWithDivineOAuth never has to round-trip to Keycast for the pubkey.
    session = KeycastSession(
      bunkerUrl: 'https://keycast.example.com',
      accessToken: 'access_token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      refreshToken: 'refresh_token',
      userPubkey: matchingContainer.publicKeyHex,
    );

    when(() => mockKeyStorage.initialize()).thenAnswer((_) async {});
    when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.clearCache()).thenReturn(null);
    when(() => mockKeyStorage.dispose()).thenReturn(null);
    when(
      () => mockKeyStorage.getIdentityKeyContainer(
        any(),
      ),
    ).thenAnswer((_) async => null);
    when(() => mockKeyStorage.getKeyContainer()).thenAnswer((_) async => null);
    when(
      () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
    ).thenAnswer((_) async {});

    when(
      () => mockCleanupService.shouldClearDataForUser(any()),
    ).thenReturn(false);
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

    when(() => mockOAuthClient.close()).thenReturn(null);

    SharedPreferences.setMockInitialValues({});
  });

  AuthService createAuthService() {
    return AuthService(
      backgroundActivityManager: BackgroundActivityManager(),
      userDataCleanupService: mockCleanupService,
      keyStorage: mockKeyStorage,
      flutterSecureStorage: fakeSecureStorage,
      oauthClient: mockOAuthClient,
      oauthConfig: const OAuthConfig(
        serverUrl: 'https://example.com',
        clientId: 'test',
        redirectUri: 'https://example.com/cb',
      ),
    );
  }

  tearDown(() async {
    await authService.dispose();
  });

  group('signInWithDivineOAuth local signing (issue #3066)', () {
    test(
      'uses locally-stored nsec when per-identity container matches session pubkey',
      () async {
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            matchingContainer.npub,
          ),
        ).thenAnswer((_) async => matchingContainer);

        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(
          identity,
          isA<KeycastNostrIdentity>(),
          reason:
              'signInWithDivineOAuth must build a KeycastNostrIdentity when '
              'a Keycast signer is present.',
        );
        expect(
          identity!.pubkey,
          equals(matchingContainer.publicKeyHex),
          reason: 'Identity must carry the session pubkey.',
        );
        final keycast = identity as KeycastNostrIdentity;
        expect(
          keycast.canDecryptInIsolate,
          isTrue,
          reason:
              'When the local nsec is available, the KeycastNostrIdentity '
              'must attach a LocalKeySigner so signing stays local instead '
              'of routing through 200-500ms Keycast RPC calls.',
        );
      },
    );

    test(
      'falls back to primary key container when per-identity slot is empty',
      () async {
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => matchingContainer);

        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          (identity! as KeycastNostrIdentity).canDecryptInIsolate,
          isTrue,
          reason: 'Primary container fallback must also enable local signing.',
        );
      },
    );

    test(
      'ignores local nsec when stored pubkey does not match session pubkey',
      () async {
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => otherContainer);

        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          identity!.pubkey,
          equals(matchingContainer.publicKeyHex),
          reason: 'Pubkey must come from the session, not the stale local key.',
        );
        expect(
          (identity as KeycastNostrIdentity).canDecryptInIsolate,
          isFalse,
          reason:
              "Using another account's nsec would sign for the wrong "
              'identity; the lookup must reject pubkey mismatches and '
              'keep RPC-only signing.',
        );
      },
    );

    test(
      'prefers per-identity container over primary when both exist',
      () async {
        // Per-identity slot: matching nsec for this account.
        // Primary slot: a different account's nsec (e.g. last-used was another).
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            matchingContainer.npub,
          ),
        ).thenAnswer((_) async => matchingContainer);
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => otherContainer);

        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          (identity! as KeycastNostrIdentity).canDecryptInIsolate,
          isTrue,
          reason:
              'The per-identity slot is authoritative when present, even if '
              'the primary slot holds a different account.',
        );

        verify(
          () => mockKeyStorage.getIdentityKeyContainer(
            matchingContainer.npub,
          ),
        ).called(1);
      },
    );

    test(
      'falls back to RPC-only signing when no local nsec is available',
      () async {
        // Defaults already return null for both getters.
        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          (identity! as KeycastNostrIdentity).canDecryptInIsolate,
          isFalse,
          reason:
              'Without a local nsec there is no private key for isolate-based '
              'decryption; KeycastNostrIdentity must go RPC-only.',
        );
      },
    );

    test(
      'key-storage lookup failures do not break sign-in — falls back to RPC',
      () async {
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            any(),
          ),
        ).thenThrow(StateError('simulated keystore failure'));

        authService = createAuthService();

        // Must not throw.
        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          (identity! as KeycastNostrIdentity).canDecryptInIsolate,
          isFalse,
        );
      },
    );

    test(
      'exports local nsec for Divine OAuth account with matching local key',
      () async {
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            matchingContainer.npub,
          ),
        ).thenAnswer((_) async => matchingContainer);

        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        expect(authService.canExportLocalNsec, isTrue);
        expect(await authService.exportNsec(), equals(_matchingNsec));
      },
    );

    test(
      'does not export nsec for Divine OAuth account without local key',
      () async {
        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        expect(authService.canExportLocalNsec, isFalse);
        expect(await authService.exportNsec(), isNull);
        verifyNever(
          () => mockKeyStorage.exportNsec(),
        );
      },
    );

    test(
      'same-pubkey RPC upgrade does not close signer retained by live client',
      () async {
        var retainedCalls = 0;
        final retainedRpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'retained_token',
          httpClient: MockClient((request) async {
            retainedCalls++;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['method'], equals('nip44_encrypt'));
            return http.Response(jsonEncode({'result': 'ciphertext'}), 200);
          }),
        );
        addTearDown(retainedRpc.close);

        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            matchingContainer.npub,
          ),
        ).thenAnswer((_) async => matchingContainer);

        authService = createAuthService();
        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        // Stand in for the signer the live NostrClient was built with: #5909
        // keeps that client across a same-pubkey re-emission, so it holds this
        // identity — and this RPC — after AuthService moves on.
        authService.debugSetKeycastSigner(retainedRpc);
        final retainedIdentity = KeycastNostrIdentity(
          pubkey: matchingContainer.publicKeyHex,
          rpcSigner: retainedRpc,
        );
        authService.debugSetIdentity(retainedIdentity);

        // Drive the real upgrade rather than calling the seam with
        // `closePrevious: false` ourselves: the behaviour under test is
        // _upgradeDivineRpcInBackground *choosing* not to close, so the test
        // must go red if that call site stops passing the flag.
        // No stored RPC session on resume forces the refresh branch.
        when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer(
          (_) async => KeycastSession(
            bunkerUrl: 'https://keycast.example.com',
            accessToken: 'refreshed_access_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            refreshToken: 'refreshed_refresh_token',
            userPubkey: matchingContainer.publicKeyHex,
          ),
        );

        await _ignoringDiscoveryErrors(() async {
          authService.onAppResumed();
          await pumpEventQueue();
        });

        expect(
          authService.currentIdentity,
          isNot(same(retainedIdentity)),
          reason:
              'The upgrade must have reached the signer swap and rebuilt the '
              'identity — otherwise this test passes vacuously without ever '
              'exercising the close decision.',
        );
        expect(
          await retainedIdentity.nip44Encrypt(
            otherContainer.publicKeyHex,
            'hello',
          ),
          equals('ciphertext'),
          reason:
              'The RPC still held by the live NostrClient must survive the '
              'upgrade; closing it strands every publish on that client.',
        );
        expect(retainedCalls, equals(1));
      },
    );

    test(
      'same-pubkey OAuth re-sign-in keeps signer retained by live client open',
      () async {
        var retainedCalls = 0;
        final retainedRpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'retained_token',
          httpClient: MockClient((request) async {
            retainedCalls++;
            return http.Response(jsonEncode({'result': 'ciphertext'}), 200);
          }),
        );
        addTearDown(retainedRpc.close);

        authService = createAuthService();
        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        authService.debugSetKeycastSigner(retainedRpc);
        final retainedIdentity = KeycastNostrIdentity(
          pubkey: matchingContainer.publicKeyHex,
          rpcSigner: retainedRpc,
        );
        authService.debugSetIdentity(retainedIdentity);

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(
            session.copyWith(accessToken: 'refreshed_access_token'),
          ),
        );

        expect(
          await retainedIdentity.nip44Encrypt(
            otherContainer.publicKeyHex,
            'hello',
          ),
          equals('ciphertext'),
        );
        expect(retainedCalls, equals(1));
      },
    );

    test(
      'unbound-session OAuth re-sign-in keeps retained signer open',
      () async {
        // A fresh code-exchange session (fromTokenResponse) carries no
        // userPubkey, so the close decision at the top of
        // signInWithDivineOAuth cannot know the pubkey yet. It must treat
        // unknown as same: closing here would strand the live NostrClient
        // holding the retained RPC — even when the sign-in itself later
        // fails, the close has already happened.
        var retainedCalls = 0;
        final retainedRpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'retained_token',
          httpClient: MockClient((request) async {
            retainedCalls++;
            return http.Response(jsonEncode({'result': 'ciphertext'}), 200);
          }),
        );
        addTearDown(retainedRpc.close);

        authService = createAuthService();
        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        authService.debugSetKeycastSigner(retainedRpc);
        final retainedIdentity = KeycastNostrIdentity(
          pubkey: matchingContainer.publicKeyHex,
          rpcSigner: retainedRpc,
        );
        authService.debugSetIdentity(retainedIdentity);

        final unboundSession = KeycastSession(
          bunkerUrl: 'https://keycast.example.com',
          accessToken: 'fresh_code_exchange_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'fresh_refresh_token',
        );

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(unboundSession),
        );

        expect(
          await retainedIdentity.nip44Encrypt(
            otherContainer.publicKeyHex,
            'hello',
          ),
          equals('ciphertext'),
          reason:
              'The RPC still held by the live NostrClient must survive a '
              'same-pubkey re-sign-in whose session has not bound its '
              'userPubkey yet.',
        );
        expect(retainedCalls, equals(1));
      },
    );
  });
}
