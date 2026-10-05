// ABOUTME: Tests for local-first Divine OAuth startup behavior
// ABOUTME: Verifies that matching local keys authenticate before RPC refresh

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show NostrSigner, generatePrivateKey;
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/local_key_signer.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/shared_channel_override.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Local-first Divine OAuth startup', () {
    late _MockUserDataCleanupService mockCleanupService;
    late _MockKeycastOAuth mockOAuthClient;
    late Map<String, String> secureStorage;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      mockOAuthClient = _MockKeycastOAuth();
      when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);

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

      secureStorage = {};

      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      overrideSharedChannel(channel, (MethodCall call) async {
        switch (call.method) {
          case 'read':
            final key = call.arguments['key'] as String?;
            return secureStorage[key];
          case 'write':
            final key = call.arguments['key'] as String?;
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) {
              secureStorage[key] = value;
            }
            return null;
          case 'delete':
            final key = call.arguments['key'] as String?;
            secureStorage.remove(key);
            return null;
          case 'deleteAll':
            secureStorage.clear();
            return null;
          case 'readAll':
            return secureStorage;
          case 'containsKey':
            final key = call.arguments['key'] as String?;
            return secureStorage.containsKey(key);
          case 'getCapabilities':
            return {'basicSecureStorage': true};
          default:
            return null;
        }
      });

      const capabilityChannel = MethodChannel('openvine.secure_storage');
      overrideSharedChannel(capabilityChannel, (MethodCall call) async {
        switch (call.method) {
          case 'getCapabilities':
            return {
              'hasHardwareSecurity': false,
              'hasBiometrics': false,
              'hasKeychain': true,
            };
          default:
            return null;
        }
      });
    });

    /// Helper: stores a Keycast session and a valid local nsec that matches
    /// the session pubkey.
    String arrangeSessionWithMatchingLocalKeys({required DateTime expiresAt}) {
      final privateKeyHex = generatePrivateKey();
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      final pubkey = container.publicKeyHex;

      final session = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'token_abc123',
        expiresAt: expiresAt,
        userPubkey: pubkey,
      );
      secureStorage['keycast_session'] = jsonEncode(session.toJson());

      secureStorage['nostr_primary_key'] =
          'privateKeyHex:$privateKeyHex'
          '|publicKeyHex:${container.publicKeyHex}'
          '|npub:${container.npub}';

      return pubkey;
    }

    /// Helper: stores an expired Keycast session and a valid local nsec
    /// that matches the session pubkey.
    String arrangeExpiredSessionWithMatchingLocalKeys() {
      return arrangeSessionWithMatchingLocalKeys(
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
    }

    AuthService createAuthService({Duration? startupNetworkOperationTimeout}) {
      final keyStorage = SecureKeyStorage(
        securityConfig: const SecurityConfig(requireHardwareBacked: false),
      );
      final authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        keyStorage: keyStorage,
        oauthClient: mockOAuthClient,
        startupNetworkOperationTimeout: startupNetworkOperationTimeout,
      );
      addTearDown(authService.dispose);
      return authService;
    }

    test('divineOAuth local restore starts in upgrading state '
        'before RPC is ready', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      arrangeExpiredSessionWithMatchingLocalKeys();

      // refreshSession returns null (failed)
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) async => null);

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();

          expect(authService.isAuthenticated, isTrue);
          expect(
            authService.authenticationSource,
            equals(AuthenticationSource.divineOAuth),
          );
          // RPC capability should not be rpcReady since refresh failed
          expect(
            authService.authRpcCapability,
            isNot(equals(AuthRpcCapability.rpcReady)),
          );
        },
        (error, stack) {
          // Ignore background relay discovery errors
        },
      );
    });

    test(
      'authRpcCapability defaults to unavailable for non-oauth sources',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'tos_accepted': true,
        });

        // Store a local key for automatic login
        final privateKeyHex = generatePrivateKey();
        final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
        secureStorage['nostr_primary_key'] =
            'privateKeyHex:$privateKeyHex'
            '|publicKeyHex:${container.publicKeyHex}'
            '|npub:${container.npub}';

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            expect(authService.isAuthenticated, isTrue);
            expect(
              authService.authRpcCapability,
              equals(AuthRpcCapability.unavailable),
            );
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );

    test(
      'canPublishNostrWritesNow is true when local private key exists',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        arrangeExpiredSessionWithMatchingLocalKeys();

        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            expect(authService.isAuthenticated, isTrue);
            expect(authService.canPublishNostrWritesNow, isTrue);
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );

    test('canPublishNostrWritesNow is false when not authenticated', () {
      final authService = createAuthService();
      expect(authService.canPublishNostrWritesNow, isFalse);
    });

    test('canPublishNostrWritesNow waits for RPC-backed Keycast readiness', () {
      final authService = createAuthService();
      const pubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      authService.debugSetIdentity(
        KeycastNostrIdentity(pubkey: pubkey, rpcSigner: _MockNostrSigner()),
      );

      expect(authService.authRpcCapability, AuthRpcCapability.unavailable);
      expect(authService.canPublishNostrWritesNow, isFalse);
    });

    test('canPublishNostrWritesNow allows Keycast with a local signer', () {
      final authService = createAuthService();
      final privateKeyHex = generatePrivateKey();
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);

      authService.debugSetIdentity(
        KeycastNostrIdentity(
          pubkey: container.publicKeyHex,
          rpcSigner: _MockNostrSigner(),
          localSigner: LocalKeySigner(container),
        ),
      );

      expect(authService.canPublishNostrWritesNow, isTrue);
    });

    test('matching local key authenticates before refresh completes', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final pubkey = arrangeExpiredSessionWithMatchingLocalKeys();

      final refresh = Completer<KeycastSession?>();
      // Hold refresh until local-first auth has been asserted.
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer(
        (_) => refresh.future,
      );

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();

          // Should be authenticated immediately from local keys
          expect(authService.isAuthenticated, isTrue);
          expect(authService.currentPublicKeyHex, equals(pubkey));
          expect(
            authService.authenticationSource,
            equals(AuthenticationSource.divineOAuth),
          );
          // RPC is upgrading (refresh is still in-flight)
          expect(
            authService.authRpcCapability,
            equals(AuthRpcCapability.upgrading),
          );
        },
        (error, stack) {
          // Ignore background errors
        },
      );
      refresh.complete(null);
      await pumpEventQueue();
      expect(authService.isRpcUpgradeInProgress, isFalse);
    });

    test('stale background RPC refresh does not resurrect the previous '
        'account after sign-out and account switch', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final accountAPubkey = arrangeExpiredSessionWithMatchingLocalKeys();

      // The refresh for account A stays in flight across sign-out and
      // the switch to a fresh account.
      final refreshCompleter = Completer<KeycastSession?>();
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) => refreshCompleter.future);
      when(() => mockOAuthClient.logout()).thenAnswer((_) async {});

      final authService = createAuthService();

      // Assertions live OUTSIDE the zone: a failing expect inside
      // runZonedGuarded is swallowed by the zone handler and the test
      // hangs to timeout instead of reporting the failure.
      late bool authenticatedAfterInit;
      late AuthRpcCapability capabilityAfterInit;
      late bool authenticatedAfterSignOut;
      late AuthResult imported;
      String? accountBPubkey;

      await runZonedGuarded(
        () async {
          await authService.initialize();
          authenticatedAfterInit = authService.isAuthenticated;
          capabilityAfterInit = authService.authRpcCapability;

          await authService.signOut();
          authenticatedAfterSignOut = authService.isAuthenticated;

          imported = await authService.importFromHex(generatePrivateKey());
          accountBPubkey = authService.currentPublicKeyHex;

          // Account A's refresh finally resolves with a fresh session.
          refreshCompleter.complete(
            KeycastSession(
              bunkerUrl: 'https://login.divine.video/api/nostr',
              accessToken: 'fresh_token_for_account_a',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              userPubkey: accountAPubkey,
            ),
          );
          await pumpEventQueue();
        },
        (error, stack) {
          // Ignore background relay discovery errors
        },
      );

      expect(authenticatedAfterInit, isTrue);
      expect(capabilityAfterInit, equals(AuthRpcCapability.upgrading));
      expect(authenticatedAfterSignOut, isFalse);
      expect(imported.success, isTrue);
      expect(accountBPubkey, isNotNull);
      expect(accountBPubkey, isNot(equals(accountAPubkey)));
      expect(
        authService.currentPublicKeyHex,
        equals(accountBPubkey),
        reason: 'stale refresh must not change the active account',
      );
      expect(
        authService.authRpcCapability,
        isNot(equals(AuthRpcCapability.rpcReady)),
        reason:
            "account A's refresh must not grant RPC capability to account B",
      );
      expect(
        authService.currentIdentity,
        isNot(isA<KeycastNostrIdentity>()),
        reason:
            "account A's RPC signer must not be attached to account B's "
            'identity',
      );
    });

    test('stale app-resume OAuth refresh does not attach the previous '
        'account signer after sign-out and account switch', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final accountAPubkey = arrangeSessionWithMatchingLocalKeys(
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final refreshCompleter = Completer<KeycastSession?>();
      when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) => refreshCompleter.future);
      when(() => mockOAuthClient.logout()).thenAnswer((_) async {});

      final authService = createAuthService();

      late bool authenticatedAfterInit;
      late AuthRpcCapability capabilityAfterInit;
      late bool authenticatedAfterSignOut;
      late AuthResult imported;
      String? accountBPubkey;

      await runZonedGuarded(
        () async {
          await authService.initialize();
          authenticatedAfterInit = authService.isAuthenticated;
          capabilityAfterInit = authService.authRpcCapability;

          authService.onAppResumed();
          await pumpEventQueue();

          await authService.signOut();
          authenticatedAfterSignOut = authService.isAuthenticated;

          imported = await authService.importFromHex(generatePrivateKey());
          accountBPubkey = authService.currentPublicKeyHex;

          refreshCompleter.complete(
            KeycastSession(
              bunkerUrl: 'https://login.divine.video/api/nostr',
              accessToken: 'fresh_token_for_account_a',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              userPubkey: accountAPubkey,
            ),
          );
          await pumpEventQueue();
        },
        (error, stack) {
          // Ignore background relay discovery errors.
        },
      );

      expect(authenticatedAfterInit, isTrue);
      expect(capabilityAfterInit, equals(AuthRpcCapability.rpcReady));
      expect(authenticatedAfterSignOut, isFalse);
      expect(imported.success, isTrue);
      expect(accountBPubkey, isNotNull);
      expect(accountBPubkey, isNot(equals(accountAPubkey)));
      expect(
        authService.currentPublicKeyHex,
        equals(accountBPubkey),
        reason: 'stale resume refresh must not change the active account',
      );
      expect(
        authService.authRpcCapability,
        isNot(equals(AuthRpcCapability.rpcReady)),
        reason:
            "account A's resume refresh must not grant RPC capability to "
            'account B',
      );
      expect(
        authService.currentIdentity,
        isNot(isA<KeycastNostrIdentity>()),
        reason:
            "account A's resume RPC signer must not be attached to account "
            "B's identity",
      );
    });

    test(
      'refresh timeout does not block local authenticated startup',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        arrangeExpiredSessionWithMatchingLocalKeys();

        // refreshSession hangs forever — will be timed out
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) => Completer<KeycastSession?>().future);

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            // User is authenticated immediately — not waiting on refresh
            expect(authService.isAuthenticated, isTrue);
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );

    test('no local key + no valid session → unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      // Expired session, no local keys
      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) async => null);

      final authService = createAuthService();

      await authService.initialize();

      expect(authService.authState, equals(AuthState.unauthenticated));
      expect(authService.hasExpiredOAuthSession, isTrue);
    });

    test('no local key + hanging refresh reaches unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

      final refreshCompleter = Completer<KeycastSession?>();
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) => refreshCompleter.future);

      final authService = createAuthService(
        startupNetworkOperationTimeout: const Duration(milliseconds: 1),
      );

      await authService.initialize();

      expect(authService.authState, equals(AuthState.unauthenticated));
      expect(authService.hasExpiredOAuthSession, isTrue);
    });

    test(
      'startup refresh timeout keeps OAuth refresh single-flight occupied',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        final expiredSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

        final refreshCompleter = Completer<KeycastSession?>();
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) => refreshCompleter.future);

        final authService = createAuthService(
          startupNetworkOperationTimeout: const Duration(milliseconds: 1),
        );

        await authService.initialize();
        expect(authService.authState, equals(AuthState.unauthenticated));

        final retry = authService.tryRefreshExpiredSession();
        await pumpEventQueue();

        verify(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).called(1);

        refreshCompleter.complete(null);
        expect(await retry, isFalse);
      },
    );
  });
}
