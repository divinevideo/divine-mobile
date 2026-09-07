// ABOUTME: Tests for expired Keycast session refresh and auth source
// ABOUTME: preservation — verifies divineOAuth is never lost on expiry

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Nip19, generatePrivateKey;
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/divine_login_banner_dismissal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../helpers/shared_channel_override.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _DelayingSharedPreferencesStore extends InMemorySharedPreferencesStore {
  _DelayingSharedPreferencesStore.withData(
    super.data, {
    required this.delayedRemoveKey,
  }) : super.withData();

  final String delayedRemoveKey;
  final removeStarted = Completer<void>();
  final allowRemove = Completer<void>();

  @override
  Future<bool> remove(String key) async {
    if (key == delayedRemoveKey && !removeStarted.isCompleted) {
      removeStarted.complete();
      await allowRemove.future;
    }
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expired Keycast session handling', () {
    late _MockUserDataCleanupService mockCleanupService;
    late _MockKeycastOAuth mockOAuthClient;
    late Map<String, String> secureStorage;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      mockOAuthClient = _MockKeycastOAuth();

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
      when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);

      // In-memory secure storage backing
      secureStorage = {};

      // Mock flutter_secure_storage platform channel
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

      // Mock secure storage capability check channel
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

    /// Helper: stores an expired Keycast session and a valid local nsec
    void arrangeExpiredSessionWithLocalKeys() {
      final privateKeyHex = generatePrivateKey();
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token_abc123',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        refreshToken: 'refresh_token_still_valid',
        userPubkey: container.publicKeyHex,
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());
      secureStorage['keycast_refresh_token'] = 'refresh_token_still_valid';

      secureStorage['nostr_primary_key'] =
          'privateKeyHex:$privateKeyHex'
          '|publicKeyHex:${container.publicKeyHex}'
          '|npub:${container.npub}';
    }

    /// Helper: creates an AuthService wired to the mocks
    AuthService createAuthService({Duration? oauthRefreshTimeout}) {
      final keyStorage = SecureKeyStorage(
        securityConfig: const SecurityConfig(requireHardwareBacked: false),
      );
      final authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        keyStorage: keyStorage,
        oauthClient: mockOAuthClient,
        oauthRefreshTimeout:
            oauthRefreshTimeout ?? AuthService.rpcRefreshTimeout,
      );
      addTearDown(authService.dispose);
      return authService;
    }

    Future<void> waitForRpcUpgradeToSettle(AuthService authService) async {
      await pumpEventQueue();
      expect(authService.isRpcUpgradeInProgress, isFalse);
    }

    Future<void> runIgnoringMockedHttpErrors(
      Future<void> Function() body,
    ) async {
      Object? unexpectedError;
      StackTrace? unexpectedStack;

      await runZonedGuarded(body, (error, stack) {
        if (error is UnsupportedError && error.message == 'Mocked response') {
          return;
        }
        unexpectedError ??= error;
        unexpectedStack ??= stack;
      });

      if (unexpectedError != null) {
        Error.throwWithStackTrace(unexpectedError!, unexpectedStack!);
      }
    }

    Map<String, Object> prefixedSharedPreferencesData(SharedPreferences prefs) {
      return {
        for (final key in prefs.getKeys())
          if (prefs.get(key) case final Object value) 'flutter.$key': value,
      };
    }

    Future<AuthService> arrangeInitializedDivineOAuthService(
      KeycastSession session,
    ) async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });
      final privateKeyHex = generatePrivateKey();
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      final boundSession = session.copyWith(userPubkey: container.publicKeyHex);
      secureStorage['keycast_session'] = jsonEncode(boundSession.toJson());
      if (boundSession.refreshToken != null) {
        secureStorage['keycast_refresh_token'] = boundSession.refreshToken!;
      }
      secureStorage['nostr_primary_key'] =
          'privateKeyHex:$privateKeyHex'
          '|publicKeyHex:${container.publicKeyHex}'
          '|npub:${container.npub}';

      when(
        () => mockOAuthClient.getSession(),
      ).thenAnswer((_) async => boundSession);
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) async => null);

      final authService = createAuthService();
      await runIgnoringMockedHttpErrors(authService.initialize);
      return authService;
    }

    group('account deletion readiness', () {
      test('allows a fresh authorization-code session', () async {
        final authService = await arrangeInitializedDivineOAuthService(
          KeycastSession(
            bunkerUrl: 'https://login.divine.video/api/nostr',
            accessToken: 'fresh_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            refreshToken: 'refresh_token_still_valid',
            grantType: KeycastSession.authorizationCodeGrant,
          ),
        );

        expect(
          await authService.checkAccountDeletionReadiness(),
          AccountDeletionReadiness.ready,
        );
      });

      test('blocks a refresh-minted session', () async {
        final authService = await arrangeInitializedDivineOAuthService(
          KeycastSession(
            bunkerUrl: 'https://login.divine.video/api/nostr',
            accessToken: 'refreshed_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            refreshToken: 'next_refresh_token',
            grantType: KeycastSession.refreshTokenGrant,
          ),
        );

        expect(
          await authService.checkAccountDeletionReadiness(),
          AccountDeletionReadiness.requiresReauthentication,
        );
      });

      test('blocks a legacy session with no grant marker', () async {
        final authService = await arrangeInitializedDivineOAuthService(
          KeycastSession(
            bunkerUrl: 'https://login.divine.video/api/nostr',
            accessToken: 'legacy_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            refreshToken: 'refresh_token_still_valid',
          ),
        );

        expect(
          await authService.checkAccountDeletionReadiness(),
          AccountDeletionReadiness.requiresReauthentication,
        );
      });

      test('blocks a session expiring inside the deletion window', () async {
        final authService = await arrangeInitializedDivineOAuthService(
          KeycastSession(
            bunkerUrl: 'https://login.divine.video/api/nostr',
            accessToken: 'nearly_expired_token',
            expiresAt: DateTime.now().add(const Duration(minutes: 2)),
            refreshToken: 'refresh_token_still_valid',
            grantType: KeycastSession.authorizationCodeGrant,
          ),
        );

        expect(
          await authService.checkAccountDeletionReadiness(),
          AccountDeletionReadiness.requiresReauthentication,
        );
      });
    });

    test(
      'refresh fails + local keys exist → auth source stays divineOAuth',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        arrangeExpiredSessionWithLocalKeys();

        // refreshSession returns null (failed)
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final authService = createAuthService();

        await runIgnoringMockedHttpErrors(() async {
          await authService.initialize();

          // Auth source preserved as divineOAuth, not downgraded
          expect(
            authService.authenticationSource,
            equals(AuthenticationSource.divineOAuth),
            reason:
                'Auth source should stay divineOAuth when refresh fails '
                'but local keys exist',
          );
          expect(
            authService.isAnonymous,
            isFalse,
            reason:
                'isAnonymous should be false — user registered via OAuth, '
                'session just expired',
          );
          expect(authService.isAuthenticated, isTrue);
          expect(
            authService.hasExpiredOAuthSession,
            isTrue,
            reason:
                'hasExpiredOAuthSession should be true so UI can show '
                '"session expired" instead of "Secure Your Account"',
          );

          // Verify refresh was attempted
          await waitForRpcUpgradeToSettle(authService);
          verify(
            () => mockOAuthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).called(1);
        });
      },
    );

    test('refresh fails + no local keys → falls to unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      // Expired session but NO local nsec
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

      await runZonedGuarded(
        () async {
          await authService.initialize();

          expect(
            authService.authState,
            equals(AuthState.unauthenticated),
            reason: 'No local keys + refresh failed → unauthenticated',
          );
          verify(
            () => mockOAuthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).called(1);
        },
        (error, stack) {
          // Ignore background errors
        },
      );
    });

    test('network refresh failure + no local keys keeps owner-bound session '
        'authenticated in upgrading state', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final pubkey = 'ab' * 32;
      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        refreshToken: 'refresh_token_still_valid',
        userPubkey: pubkey,
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());
      secureStorage['keycast_refresh_token'] = 'refresh_token_still_valid';

      final refreshedSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'fresh_token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        refreshToken: 'next_refresh_token',
        userPubkey: pubkey,
      );
      final backgroundRefresh = Completer<KeycastSession?>();
      var refreshCalls = 0;
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) {
        refreshCalls++;
        if (refreshCalls == 1) {
          throw OAuthNetworkException('offline');
        }
        return backgroundRefresh.future;
      });

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();

          expect(authService.authState, equals(AuthState.authenticated));
          expect(authService.isAuthenticated, isTrue);
          expect(
            authService.authRpcCapability,
            equals(AuthRpcCapability.upgrading),
          );
          expect(authService.currentPublicKeyHex, pubkey);
          expect(authService.currentIdentity, isA<PubkeyOnlyNostrIdentity>());
          expect(authService.canPublishNostrWritesNow, isFalse);
          expect(
            authService.hasExpiredOAuthSession,
            isTrue,
            reason:
                'The degraded session stays retryable while RPC upgrade is '
                'pending so manual re-login affordances remain available.',
          );
          expect(
            secureStorage['keycast_refresh_token'],
            'refresh_token_still_valid',
            reason: 'Offline launch must not discard the retry token.',
          );
          final retryDeadline = DateTime.now().add(const Duration(seconds: 3));
          while (refreshCalls < 2 && DateTime.now().isBefore(retryDeadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          expect(refreshCalls, equals(2));

          backgroundRefresh.complete(refreshedSession);
          await waitForRpcUpgradeToSettle(authService);

          expect(
            authService.authRpcCapability,
            equals(AuthRpcCapability.rpcReady),
          );
          expect(authService.currentIdentity, isA<KeycastNostrIdentity>());
          expect(authService.canPublishNostrWritesNow, isTrue);
          expect(
            authService.hasExpiredOAuthSession,
            isFalse,
            reason: 'A successful background upgrade clears the retry flag.',
          );
        },
        (error, stack) {
          // Ignore background errors
        },
      );
    });

    test('degraded OAuth restore retries on resume but stays authenticated '
        'when the device is still offline', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final pubkey = 'ab' * 32;
      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        refreshToken: 'refresh_token_still_valid',
        userPubkey: pubkey,
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());
      secureStorage['keycast_refresh_token'] = 'refresh_token_still_valid';

      var refreshCalls = 0;
      when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) {
        refreshCalls++;
        throw OAuthNetworkException('offline');
      });

      final authService = createAuthService();

      await runIgnoringMockedHttpErrors(() async {
        await authService.initialize();
        await waitForRpcUpgradeToSettle(authService);

        final authEvents = <AuthState>[];
        final authSubscription = authService.authStateStream.listen(
          authEvents.add,
        );
        addTearDown(authSubscription.cancel);

        refreshCalls = 0;
        authService.onAppResumed();
        await waitForRpcUpgradeToSettle(authService);

        expect(refreshCalls, equals(1));
        expect(authService.authState, equals(AuthState.authenticated));
        expect(authService.isAuthenticated, isTrue);
        expect(authService.currentPublicKeyHex, pubkey);
        expect(authService.currentIdentity, isA<PubkeyOnlyNostrIdentity>());
        expect(authService.canPublishNostrWritesNow, isFalse);
        expect(authService.hasExpiredOAuthSession, isTrue);
        expect(
          authEvents,
          isEmpty,
          reason:
              'Failed offline resume retries leave degraded state unchanged '
              'and should not nudge profile UI to re-show the expired sheet.',
        );
        expect(
          secureStorage['keycast_refresh_token'],
          'refresh_token_still_valid',
          reason: 'Offline resume must not discard the retry token.',
        );
      });
    });

    test('degraded OAuth resume does not refresh another account token when '
        'getSession returns null', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final activePubkey = 'ab' * 32;
      final otherPubkey = 'cd' * 32;
      final expiredActiveSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_active_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        refreshToken: 'refresh_token_account_a',
        userPubkey: activePubkey,
      );
      secureStorage['keycast_session'] = jsonEncode(
        expiredActiveSession.toJson(),
      );
      secureStorage['keycast_refresh_token'] = 'refresh_token_account_a';

      var refreshCalls = 0;
      when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) {
        refreshCalls++;
        throw OAuthNetworkException('offline');
      });

      final authService = createAuthService();

      await runIgnoringMockedHttpErrors(() async {
        await authService.initialize();
        await waitForRpcUpgradeToSettle(authService);

        final expiredOtherSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_other_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          refreshToken: 'refresh_token_account_b',
          userPubkey: otherPubkey,
        );
        secureStorage['keycast_session'] = jsonEncode(
          expiredOtherSession.toJson(),
        );
        secureStorage['keycast_refresh_token'] = 'refresh_token_account_b';

        refreshCalls = 0;
        authService.onAppResumed();
        await waitForRpcUpgradeToSettle(authService);

        expect(refreshCalls, isZero);
        expect(authService.authState, equals(AuthState.authenticated));
        expect(authService.currentPublicKeyHex, activePubkey);
        expect(authService.currentIdentity, isA<PubkeyOnlyNostrIdentity>());
        expect(authService.canPublishNostrWritesNow, isFalse);
        expect(authService.hasExpiredOAuthSession, isTrue);
        expect(
          secureStorage['keycast_refresh_token'],
          'refresh_token_account_b',
          reason: 'Resume must not consume another account refresh token.',
        );
      });
    });

    test('degraded OAuth resume does not rebuild or refresh a mismatched '
        'stored RPC session', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final activePubkey = 'ab' * 32;
      final otherPubkey = 'cd' * 32;
      final expiredActiveSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_active_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        refreshToken: 'refresh_token_account_a',
        userPubkey: activePubkey,
      );
      secureStorage['keycast_session'] = jsonEncode(
        expiredActiveSession.toJson(),
      );
      secureStorage['keycast_refresh_token'] = 'refresh_token_account_a';

      var returnMismatchedSession = false;
      var refreshCalls = 0;
      late final KeycastSession validOtherSession;
      when(() => mockOAuthClient.getSession()).thenAnswer(
        (_) async => returnMismatchedSession ? validOtherSession : null,
      );
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) {
        refreshCalls++;
        throw OAuthNetworkException('offline');
      });

      final authService = createAuthService();

      await runIgnoringMockedHttpErrors(() async {
        await authService.initialize();
        await waitForRpcUpgradeToSettle(authService);

        validOtherSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'fresh_other_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'refresh_token_account_b',
          userPubkey: otherPubkey,
        );
        secureStorage['keycast_session'] = jsonEncode(
          validOtherSession.toJson(),
        );
        secureStorage['keycast_refresh_token'] = 'refresh_token_account_b';

        refreshCalls = 0;
        returnMismatchedSession = true;
        authService.onAppResumed();
        await waitForRpcUpgradeToSettle(authService);

        expect(refreshCalls, isZero);
        expect(authService.authState, equals(AuthState.authenticated));
        expect(authService.currentPublicKeyHex, activePubkey);
        expect(authService.currentIdentity, isA<PubkeyOnlyNostrIdentity>());
        expect(authService.authRpcCapability, AuthRpcCapability.unavailable);
        expect(authService.canPublishNostrWritesNow, isFalse);
        expect(authService.hasExpiredOAuthSession, isTrue);
      });
    });

    test(
      'degraded OAuth restore retries on resume when connectivity returns',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        final pubkey = 'ab' * 32;
        final expiredSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          refreshToken: 'refresh_token_still_valid',
          userPubkey: pubkey,
        );
        secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());
        secureStorage['keycast_refresh_token'] = 'refresh_token_still_valid';

        final refreshedSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'fresh_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'next_refresh_token',
          userPubkey: pubkey,
        );
        var resumeRefreshEnabled = false;
        var refreshCalls = 0;
        when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) {
          refreshCalls++;
          if (!resumeRefreshEnabled) {
            throw OAuthNetworkException('offline');
          }
          return Future<KeycastSession?>.value(refreshedSession);
        });

        final authService = createAuthService();

        await runIgnoringMockedHttpErrors(() async {
          await authService.initialize();
          await waitForRpcUpgradeToSettle(authService);
          refreshCalls = 0;
          resumeRefreshEnabled = true;
          authService.onAppResumed();
          await waitForRpcUpgradeToSettle(authService);

          expect(refreshCalls, equals(1));
          expect(authService.authState, equals(AuthState.authenticated));
          expect(
            authService.authRpcCapability,
            equals(AuthRpcCapability.rpcReady),
          );
          expect(authService.currentIdentity, isA<KeycastNostrIdentity>());
          expect(authService.canPublishNostrWritesNow, isTrue);
          expect(authService.hasExpiredOAuthSession, isFalse);
        });
      },
    );

    test(
      'resume rebuilds a missing signer from a matching stored RPC session',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        final pubkey = 'ab' * 32;
        final expiredSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          refreshToken: 'refresh_token_still_valid',
          userPubkey: pubkey,
        );
        secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());
        secureStorage['keycast_refresh_token'] = 'refresh_token_still_valid';

        var refreshCalls = 0;
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) {
          refreshCalls++;
          throw OAuthNetworkException('offline');
        });

        final authService = createAuthService();

        await runIgnoringMockedHttpErrors(() async {
          await authService.initialize();
          await waitForRpcUpgradeToSettle(authService);

          expect(authService.authState, equals(AuthState.authenticated));
          expect(authService.currentPublicKeyHex, pubkey);
          expect(authService.currentIdentity, isA<PubkeyOnlyNostrIdentity>());
          expect(authService.hasExpiredOAuthSession, isTrue);
          expect(authService.canPublishNostrWritesNow, isFalse);

          final storedRpcSession = expiredSession.copyWith(
            accessToken: 'fresh_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          );
          when(
            () => mockOAuthClient.getSession(),
          ).thenAnswer((_) async => storedRpcSession);

          final refreshCallsBeforeResume = refreshCalls;
          authService.onAppResumed();
          await pumpEventQueue();

          expect(refreshCalls, equals(refreshCallsBeforeResume));
          expect(authService.authRpcCapability, AuthRpcCapability.rpcReady);
          expect(authService.currentIdentity, isA<KeycastNostrIdentity>());
          expect(authService.canPublishNostrWritesNow, isTrue);
          expect(authService.hasExpiredOAuthSession, isFalse);
        });
      },
    );

    test(
      'healthy OAuth resume keeps the stored RPC session without refreshing',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        final privateKeyHex = generatePrivateKey();
        final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
        final session = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'fresh_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'refresh_token_still_valid',
          userPubkey: container.publicKeyHex,
        );
        secureStorage['keycast_session'] = jsonEncode(session.toJson());
        secureStorage['keycast_refresh_token'] = 'refresh_token_still_valid';
        secureStorage['nostr_primary_key'] =
            'privateKeyHex:$privateKeyHex'
            '|publicKeyHex:${container.publicKeyHex}'
            '|npub:${container.npub}';

        var refreshCalls = 0;
        when(
          () => mockOAuthClient.getSession(),
        ).thenAnswer((_) async => session);
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async {
          refreshCalls++;
          return null;
        });

        final authService = createAuthService();

        await runIgnoringMockedHttpErrors(() async {
          await authService.initialize();

          expect(authService.authState, equals(AuthState.authenticated));
          expect(authService.authRpcCapability, AuthRpcCapability.rpcReady);
          expect(authService.currentIdentity, isA<KeycastNostrIdentity>());
          expect(authService.hasExpiredOAuthSession, isFalse);

          authService.onAppResumed();
          await pumpEventQueue();

          expect(refreshCalls, isZero);
          expect(authService.authRpcCapability, AuthRpcCapability.rpcReady);
          expect(authService.currentIdentity, isA<KeycastNostrIdentity>());
          expect(authService.hasExpiredOAuthSession, isFalse);
          expect(
            secureStorage['keycast_refresh_token'],
            'refresh_token_still_valid',
            reason: 'Healthy resume must not risk rotating the refresh token.',
          );
        });
      },
    );

    test('stale resume rebuild does not attach a signer after sign-out during '
        'banner clear', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final pubkey = 'ab' * 32;
      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        refreshToken: 'refresh_token_still_valid',
        userPubkey: pubkey,
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());
      secureStorage['keycast_refresh_token'] = 'refresh_token_still_valid';

      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) {
        throw OAuthNetworkException('offline');
      });
      when(() => mockOAuthClient.logout()).thenAnswer((_) async {});

      final authService = createAuthService();

      await runIgnoringMockedHttpErrors(() async {
        await authService.initialize();
        await waitForRpcUpgradeToSettle(authService);

        expect(authService.currentPublicKeyHex, pubkey);
        expect(authService.currentIdentity, isA<PubkeyOnlyNostrIdentity>());

        final storedRpcSession = expiredSession.copyWith(
          accessToken: 'fresh_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        when(
          () => mockOAuthClient.getSession(),
        ).thenAnswer((_) async => storedRpcSession);

        final prefs = await SharedPreferences.getInstance();
        final delayedPrefs = _DelayingSharedPreferencesStore.withData(
          prefixedSharedPreferencesData(prefs),
          delayedRemoveKey:
              'flutter.${DivineLoginBannerDismissalStore.keyFor(pubkey)}',
        );
        final initialPreferencesStore = SharedPreferencesStorePlatform.instance;
        addTearDown(() {
          SharedPreferencesStorePlatform.instance = initialPreferencesStore;
          SharedPreferences.resetStatic();
        });
        SharedPreferencesStorePlatform.instance = delayedPrefs;
        SharedPreferences.resetStatic();

        authService.onAppResumed();
        await delayedPrefs.removeStarted.future;

        await authService.signOut();
        delayedPrefs.allowRemove.complete();
        await pumpEventQueue();

        expect(authService.authState, equals(AuthState.unauthenticated));
        expect(authService.currentIdentity, isNull);
        expect(
          authService.authRpcCapability,
          isNot(equals(AuthRpcCapability.rpcReady)),
        );
      });
    });

    test('stale degraded resume refresh does not attach a signer after '
        'sign-out', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final pubkey = 'ab' * 32;
      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        refreshToken: 'refresh_token_still_valid',
        userPubkey: pubkey,
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());
      secureStorage['keycast_refresh_token'] = 'refresh_token_still_valid';

      final resumeRefresh = Completer<KeycastSession?>();
      var resumeRefreshStarted = false;
      when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);
      when(() => mockOAuthClient.logout()).thenAnswer((_) async {});
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) {
        if (!resumeRefreshStarted) {
          throw OAuthNetworkException('offline');
        }
        return resumeRefresh.future;
      });

      final authService = createAuthService();

      await runIgnoringMockedHttpErrors(() async {
        await authService.initialize();
        await waitForRpcUpgradeToSettle(authService);
        expect(authService.currentIdentity, isA<PubkeyOnlyNostrIdentity>());

        resumeRefreshStarted = true;
        authService.onAppResumed();
        await pumpEventQueue();
        expect(authService.isRpcUpgradeInProgress, isTrue);

        await authService.signOut();
        resumeRefresh.complete(
          KeycastSession(
            bunkerUrl: 'https://login.divine.video/api/nostr',
            accessToken: 'fresh_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            refreshToken: 'next_refresh_token',
            userPubkey: pubkey,
          ),
        );
        await waitForRpcUpgradeToSettle(authService);

        expect(authService.authState, equals(AuthState.unauthenticated));
        expect(authService.currentIdentity, isNull);
        expect(
          authService.authRpcCapability,
          isNot(equals(AuthRpcCapability.rpcReady)),
        );
      });
    });

    test('non-OAuth local identities do not refresh OAuth on resume', () async {
      SharedPreferences.setMockInitialValues({'tos_accepted': true});

      final authService = createAuthService();

      await runIgnoringMockedHttpErrors(() async {
        final imported = await authService.importFromHex(generatePrivateKey());
        expect(imported.success, isTrue);
        expect(
          authService.authenticationSource,
          AuthenticationSource.importedKeys,
        );

        authService.onAppResumed();
        await pumpEventQueue();

        verifyNever(() => mockOAuthClient.getSession());
        verifyNever(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        );
      });
    });

    test(
      'expired OAuth flag does not leak after signing in with imported keys',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });
        arrangeExpiredSessionWithLocalKeys();
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final authService = createAuthService();

        await runIgnoringMockedHttpErrors(() async {
          await authService.initialize();
          await waitForRpcUpgradeToSettle(authService);
          expect(
            authService.authenticationSource,
            AuthenticationSource.divineOAuth,
          );
          expect(authService.hasExpiredOAuthSession, isTrue);

          await authService.signOut();
          final imported = await authService.importFromHex(
            generatePrivateKey(),
          );
          expect(imported.success, isTrue);
          expect(
            authService.authenticationSource,
            AuthenticationSource.importedKeys,
          );
          expect(authService.hasExpiredOAuthSession, isFalse);

          clearInteractions(mockOAuthClient);
          expect(await authService.tryRefreshExpiredSession(), isFalse);
          verifyNever(
            () => mockOAuthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          );
        });
      },
    );

    test(
      'tryRefreshExpiredSession refuses a stored session for another account',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });
        arrangeExpiredSessionWithLocalKeys();
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final authService = createAuthService();

        await runIgnoringMockedHttpErrors(() async {
          await authService.initialize();
          await waitForRpcUpgradeToSettle(authService);
          final currentPubkey = authService.currentPublicKeyHex;
          expect(currentPubkey, isNotNull);
          expect(authService.hasExpiredOAuthSession, isTrue);

          final otherSession = KeycastSession(
            bunkerUrl: 'https://login.divine.video/api/nostr',
            accessToken: 'expired_other_token',
            expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
            refreshToken: 'refresh_token_account_b',
            userPubkey: 'cd' * 32,
          );
          secureStorage['keycast_session'] = jsonEncode(
            otherSession.toJson(),
          );
          secureStorage['keycast_refresh_token'] = 'refresh_token_account_b';

          clearInteractions(mockOAuthClient);
          expect(await authService.tryRefreshExpiredSession(), isFalse);
          verifyNever(
            () => mockOAuthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          );
        });
      },
    );

    test(
      'rejected refresh + no local keys still falls to unauthenticated',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        final pubkey = 'ab' * 32;
        final expiredSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          refreshToken: 'rejected_refresh_token',
          userPubkey: pubkey,
        );
        secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            expect(authService.authState, equals(AuthState.unauthenticated));
            expect(authService.isAuthenticated, isFalse);
            verify(
              () => mockOAuthClient.refreshSession(
                userPubkey: any(named: 'userPubkey'),
              ),
            ).called(1);
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );

    test(
      'refresh succeeds → saves new session and attempts signInWithDivineOAuth',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        // Store expired session
        final expiredSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

        // refreshSession returns a valid new session
        final testPubkey = 'ab' * 32;
        final refreshedSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'fresh_access_token',
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          refreshToken: 'new_refresh_token',
          userPubkey: testPubkey,
        );
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async {
          secureStorage['keycast_session'] = jsonEncode(
            refreshedSession.toJson(),
          );
          return refreshedSession;
        });

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            // Refresh was attempted
            verify(
              () => mockOAuthClient.refreshSession(
                userPubkey: any(named: 'userPubkey'),
              ),
            ).called(1);

            // The refreshed session was saved to storage before
            // signInWithDivineOAuth was called
            final savedJson = secureStorage['keycast_session'];
            expect(savedJson, isNotNull);
            final savedSession = KeycastSession.fromJson(
              jsonDecode(savedJson!) as Map<String, dynamic>,
            );
            expect(savedSession.accessToken, 'fresh_access_token');

            // Note: signInWithDivineOAuth is called but fails in test
            // (no real Keycast RPC server) — that's expected.
            // The important thing is refresh was attempted and succeeded.
          },
          (error, stack) {
            // Ignore background errors (RPC connection, relay discovery)
          },
        );
      },
    );

    test('sign-out closes the active Keycast RPC signer', () async {
      // Pins the production close-on-clear decision: signOut() clears the
      // signer through _setKeycastSigner(null), which must close the owned
      // KeycastRpc transport rather than abandon it.
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      arrangeExpiredSessionWithLocalKeys();
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(() => mockOAuthClient.logout()).thenAnswer((_) async {});

      final activeRpc = KeycastRpc(
        nostrApi: 'https://login.divine.video/api/nostr',
        accessToken: 'active_token',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'result': 'ok'}),
            200,
          ),
        ),
      );

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();
          authService.debugSetKeycastSigner(activeRpc);
          await authService.signOut();
        },
        (error, stack) {
          // Ignore background relay/RPC errors
        },
      );

      expect(authService.authState, equals(AuthState.unauthenticated));
      await expectLater(
        activeRpc.getPublicKey(),
        throwsA(isA<KeycastRpcClosedException>()),
        reason:
            'sign-out must close the KeycastRpc it cleared so later use is '
            'terminal (KeycastRpcClosedException), not silently dead',
      );
    });

    test("same-pubkey nsec import retains the live client's signer", () async {
      // Pins the retain decision in _setupUserSession's non-OAuth branch:
      // a Divine OAuth user importing their own nsec keeps the pubkey, so
      // the app-wide NostrClient is NOT rebuilt (#5909) and still holds the
      // previous KeycastNostrIdentity — its RPC must stay usable.
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      arrangeExpiredSessionWithLocalKeys();
      final expiredSession = KeycastSession.fromJson(
        jsonDecode(secureStorage['keycast_session']!) as Map<String, dynamic>,
      );

      // The nsec for the SAME pubkey the expired session is bound to: the
      // arrange helper stored its private key in nostr_primary_key.
      final storedKey = secureStorage['nostr_primary_key']!;
      final privateKeyHex = storedKey
          .substring(
            storedKey.indexOf('privateKeyHex:') + 'privateKeyHex:'.length,
          )
          .split('|')
          .first;
      final expiredPubkey = expiredSession.userPubkey!;

      final retainedRpc = KeycastRpc(
        nostrApi: 'https://login.divine.video/api/nostr',
        accessToken: 'retained_token',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'result': expiredPubkey}),
            200,
          ),
        ),
      );

      final authService = createAuthService();
      final retainedIdentity = KeycastNostrIdentity(
        pubkey: expiredPubkey,
        rpcSigner: retainedRpc,
      );
      late AuthResult result;

      await runZonedGuarded(
        () async {
          // Stand in for the authenticated OAuth session whose live
          // NostrClient holds the retained identity.
          authService.debugSetKeycastSigner(retainedRpc);
          authService.debugSetIdentity(retainedIdentity);

          result = await authService.importFromNsec(
            Nip19.encodePrivateKey(privateKeyHex),
          );
        },
        (error, stack) {
          // Ignore background errors (RPC connection, relay discovery).
          // Assertions live outside the zone: this handler must not
          // swallow them into a framework timeout.
        },
      );

      expect(result.success, isTrue);

      // Anti-vacuous: the import must have actually swapped the
      // identity off the retained one while keeping the pubkey.
      expect(authService.currentIdentity, isNot(same(retainedIdentity)));
      expect(authService.currentPublicKeyHex, equals(expiredPubkey));

      // The production regression this pins: if the non-OAuth branch
      // closed the previous signer, this throws
      // KeycastRpcClosedException.
      expect(
        await retainedRpc.getPublicKey(),
        equals(expiredPubkey),
        reason:
            'the RPC still held by the live NostrClient must survive a '
            'same-pubkey nsec import',
      );
    });

    test('isRpcUpgradeInProgress is false after upgrade completes', () async {
      // Regression for #4626: isRpcUpgradeInProgress must be false after
      // _upgradeDivineRpcInBackground finishes so the session-expired sheet
      // is no longer suppressed once the silent refresh has definitively
      // resolved.
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      arrangeExpiredSessionWithLocalKeys();

      // Refresh fails immediately.
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) async => null);

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();

          // The background upgrade is unawaited but resolves quickly since
          // refreshSession returns immediately. Pump the event queue until
          // the upgrade finishes — it should complete well within 1 second.
          final deadline = DateTime.now().add(const Duration(seconds: 3));
          while (authService.isRpcUpgradeInProgress &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }

          expect(
            authService.isRpcUpgradeInProgress,
            isFalse,
            reason:
                'isRpcUpgradeInProgress must be false after the upgrade '
                'completes (failure path)',
          );

          // Session is still flagged as expired (refresh failed).
          expect(authService.hasExpiredOAuthSession, isTrue);
        },
        (error, stack) {
          // Ignore background relay/RPC errors
        },
      );
    });

    test('concurrent tryRefreshExpiredSession calls share one in-flight future '
        '(single-flight guard)', () async {
      // Regression for #4626: if multiple UI surfaces call
      // tryRefreshExpiredSession concurrently (e.g. profile header + settings
      // tile both visible), only one token refresh should be attempted.
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      arrangeExpiredSessionWithLocalKeys();

      // Refresh always returns null (failure).
      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) async => null);

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();

          // Wait for the background upgrade to finish before testing
          // tryRefreshExpiredSession in isolation. This avoids the
          // _pendingOAuthRefresh single-flight slot being held by the
          // background upgrade, which would conflate call counts.
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (authService.isRpcUpgradeInProgress &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }

          // Session should be expired after init with failed refresh.
          expect(authService.hasExpiredOAuthSession, isTrue);

          // Reset interaction tracking after init's refresh calls.
          clearInteractions(mockOAuthClient);

          // Two concurrent callers.
          final results = await Future.wait([
            authService.tryRefreshExpiredSession(),
            authService.tryRefreshExpiredSession(),
          ]);

          // Both callers receive the same result (false — refresh failed).
          expect(results, equals([false, false]));

          // refreshSession was only called ONCE despite two concurrent
          // tryRefreshExpiredSession calls (single-flight _pendingRefresh).
          verify(
            () => mockOAuthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).called(1);
        },
        (error, stack) {
          // Ignore background errors
        },
      );
    });

    test(
      'hung refresh fails within the bounded time and clears the pending '
      'slot so a later tryRefreshExpiredSession starts a fresh attempt',
      () async {
        // Regression for #4942: a Keycast refresh request hanging on a dead
        // socket must not poison the process-lifetime single-flight slot.
        // Before the fix, the never-completing future stayed in
        // _pendingOAuthRefresh forever and EVERY re-login surface joined it,
        // so the user could not log back in until the app was killed.
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        arrangeExpiredSessionWithLocalKeys();

        // Init-phase refresh fails fast so initialize() settles quickly.
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        // Short injected bound so the test does not wait the production 10s.
        final authService = createAuthService(
          oauthRefreshTimeout: const Duration(milliseconds: 300),
        );

        await runZonedGuarded(
          () async {
            await authService.initialize();

            // Wait for the background upgrade to release the single-flight
            // slot before exercising tryRefreshExpiredSession in isolation.
            final deadline = DateTime.now().add(const Duration(seconds: 5));
            while (authService.isRpcUpgradeInProgress &&
                DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            expect(authService.hasExpiredOAuthSession, isTrue);
            clearInteractions(mockOAuthClient);

            // First call hangs forever (dead socket); later calls fail fast.
            var refreshCalls = 0;
            final hung = Completer<KeycastSession?>();
            when(
              () => mockOAuthClient.refreshSession(
                userPubkey: any(named: 'userPubkey'),
              ),
            ).thenAnswer((_) {
              refreshCalls++;
              return refreshCalls == 1
                  ? hung.future
                  : Future<KeycastSession?>.value();
            });

            // (a) The hung attempt must fail within the bounded time
            // instead of wedging forever.
            final first = await authService.tryRefreshExpiredSession().timeout(
              const Duration(seconds: 5),
            );
            expect(first, isFalse);

            // (b) The pending slot must be released so this triggers a
            // FRESH refresh attempt rather than joining the hung one.
            final second = await authService.tryRefreshExpiredSession().timeout(
              const Duration(seconds: 5),
            );
            expect(second, isFalse);

            expect(
              refreshCalls,
              2,
              reason:
                  'Second tryRefreshExpiredSession must start a fresh '
                  'refresh attempt — the hung first attempt must not '
                  'occupy the single-flight slot after its timeout',
            );
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );
    test(
      'Expired session with still-offline terminal state',
      () async {
        // Regression: Terminal offline state must not loop upgrade attempts
        // indefinitely and must preserve session data for future recovery.
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        final pubkey = 'ab' * 32;
        final expiredSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          refreshToken: 'refresh_token_for_offline',
          userPubkey: pubkey,
        );
        secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());
        secureStorage['keycast_refresh_token'] = 'refresh_token_for_offline';

        // getSession returns null (no active session after expiry)
        // refreshSession throws OAuthNetworkException (network offline)
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenThrow(
          OAuthNetworkException('Network offline'),
        );

        final authService = createAuthService();

        // initialize() kicks off relay discovery against real sockets, which
        // the test binding rejects with the UnsupportedError 'Mocked
        // response'. Tolerate exactly that noise — but keep every assertion
        // OUTSIDE the guarded zone: an expect() thrown inside a guarded zone
        // is swallowed by the error handler and orphans the zone future, so
        // the test can only ever time out instead of reporting the failure.
        await runIgnoringMockedHttpErrors(authService.initialize);

        // initialize() returns while the unawaited background RPC upgrade
        // (authRpcCapability: unavailable -> upgrading) is still in flight.
        // Every mock resolves without real timers, so the event queue drains
        // deterministically before the terminal-state assertions below.
        await waitForRpcUpgradeToSettle(authService);

        // After timeout, identity downgrades to PubkeyOnly
        expect(
          authService.currentIdentity,
          isA<PubkeyOnlyNostrIdentity>(),
          reason:
              'Terminal offline state downgrades to PubkeyOnlyNostrIdentity '
              'when no recovery path exists',
        );

        // RPC capability is unavailable (no recovery possible)
        expect(
          authService.authRpcCapability,
          equals(AuthRpcCapability.unavailable),
          reason:
              'Terminal offline state sets authRpcCapability to unavailable '
              'since network is down and no fallback refresh can occur',
        );

        // Session is still flagged as expired
        expect(
          authService.hasExpiredOAuthSession,
          isTrue,
          reason:
              'Expired session flag persists even in terminal offline state '
              'for UI to show recovery affordances',
        );

        // Refresh token is preserved for potential future recovery
        expect(
          secureStorage['keycast_refresh_token'],
          equals('refresh_token_for_offline'),
          reason:
              'Refresh token must be preserved in terminal offline state '
              'so user can manually retry login when network returns',
        );

        // The in-flight flag must be cleared on the network-failure path so
        // later upgrade attempts are not wedged behind a finished one.
        expect(
          authService.isRpcUpgradeInProgress,
          isFalse,
          reason:
              'Terminal offline state must release the RPC upgrade in-flight '
              'flag when the offline refresh fails',
        );
      },
    );
  });
}
