// ABOUTME: Unit tests for AuthService NIP-55 Amber (Android signer) sign-in and
// ABOUTME: session-restore flows. Runs on CI without an emulator via channel mocks.
//
// Covers the previously-uncovered Amber concern (#4741 PR1 gap-fill): the
// connectWithAmber platform/availability guards and the _reconnectAmber restore
// path reached through initialize(). The Amber signer talks to the native
// `nostrmoPlugin` MethodChannel, which is stubbed here; AndroidNostrSigner is
// constructed with a known pubkey on the restore path, so no intent round-trip
// is needed.

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart' show Nip89ClientTag;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/notification_activity_sender.dart';
import 'package:openvine/services/notification_activity_session_coordinator.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService NIP-55 Amber', () {
    late _MockUserDataCleanupService mockCleanupService;
    late AuthServiceChannelMocks channels;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      stubUserDataCleanupSuccess(mockCleanupService);
      channels = AuthServiceChannelMocks.install();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      AuthServiceChannelMocks.remove();
    });

    AuthService createAuthService() =>
        buildTestAuthService(cleanupService: mockCleanupService);

    group('connectWithAmber', () {
      test('returns failure on non-Android platforms', () async {
        SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.connectWithAmber();

        expect(result.success, isFalse);
        expect(
          result.errorMessage,
          contains('Android signer only supported on Android'),
        );
        expect(authService.isAuthenticated, isFalse);
        expect(authService.currentIdentity, isNull);
      });

      test('returns failure when no signer app is installed', () async {
        SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        channels.androidSignerInstalled = false;
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.connectWithAmber();

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('No Android signer app'));
        expect(authService.isAuthenticated, isFalse);
      });
    });

    group('restore via initialize()', () {
      test(
        'passive visits and heartbeats cannot launch an Amber lifecycle loop',
        () async {
          channels.secureStorage['amber_pubkey'] = freshPubkeyHex();
          SharedPreferences.setMockInitialValues({
            'authentication_source': 'amber',
            kKnownAccountsKey: '[]',
          });
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          final auth = createAuthService();
          addTearDown(auth.dispose);
          await ignoringDiscoveryErrors(auth.initialize);
          expect(auth.currentIdentity, isA<AmberNostrIdentity>());
          await Nip89ClientTag.setEnabled(enabled: false);
          addTearDown(Nip89ClientTag.resetForTest);
          final nip98 = Nip98AuthService(authService: auth);
          addTearDown(nip98.dispose);
          var httpRequests = 0;
          final transport = MockClient((_) async {
            httpRequests++;
            return http.Response('', 204);
          });
          addTearDown(transport.close);
          final client = FunnelcakeApiClient(
            baseUrl: 'https://api.example.com',
            httpClient: transport,
          );
          addTearDown(client.dispose);
          final sender = NotificationActivitySender(
            client: client,
            authService: nip98,
          );
          var launches = 0;
          final updates = <NotificationActivityUpdate>[];
          fakeAsync((async) {
            late NotificationActivitySessionCoordinator coordinator;
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  const MethodChannel('nostrmoPlugin'),
                  (call) async {
                    if (call.method == 'startActivityForResult') {
                      launches++;
                      if (launches < 3) {
                        coordinator.setForeground(false);
                        coordinator.setForeground(true);
                      }
                    }
                    return null;
                  },
                );
            coordinator = NotificationActivitySessionCoordinator(
              send: (owner, update, current) {
                updates.add(update);
                return sender.send(owner, update, current);
              },
            );
            coordinator.setAccount(
              owner: auth.currentPublicKeyHex,
              ready: true,
            );
            coordinator.setForeground(true);
            async.flushMicrotasks();
            async.elapse(const Duration(minutes: 3));
            coordinator.dispose();
          });
          expect(updates.length, greaterThan(1));
          expect(updates.map((update) => update.visit).toSet(), {1});
          expect(launches, 0);
          expect(httpRequests, 0);
        },
      );

      test(
        'reconnects an Amber account into an AmberNostrIdentity',
        () async {
          final pubkey = freshPubkeyHex();
          channels.secureStorage['amber_pubkey'] = pubkey;
          channels.secureStorage['amber_package'] =
              'com.greenart7c3.nostrsigner';
          SharedPreferences.setMockInitialValues({
            'authentication_source': 'amber',
            kKnownAccountsKey: '[]',
          });
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          channels.androidSignerInstalled = true;
          final authService = createAuthService();
          addTearDown(authService.dispose);

          await ignoringDiscoveryErrors(authService.initialize);

          expect(authService.isAuthenticated, isTrue);
          expect(
            authService.authenticationSource,
            equals(AuthenticationSource.amber),
          );
          expect(authService.currentIdentity, isA<AmberNostrIdentity>());
          expect(authService.currentPublicKeyHex, equals(pubkey));
        },
      );

      test('refused cleanup prevents restored Amber authentication', () async {
        channels.secureStorage['amber_pubkey'] = freshPubkeyHex();
        channels.secureStorage['amber_package'] = 'com.greenart7c3.nostrsigner';
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'amber',
          'current_user_pubkey_hex': 'a' * 64,
          kKnownAccountsKey: '[]',
        });
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        when(() => mockCleanupService.shouldClearDataForUser(any()))
            .thenReturn(true);
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
        final authService = createAuthService();
        addTearDown(authService.dispose);
        await authService.initialize();
        expect(authService.authState, AuthState.unauthenticated);
        expect(authService.currentIdentity, isNull);
        expect(authService.currentPublicKeyHex, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('current_user_pubkey_hex'), 'a' * 64);
      });

      test(
        'stays unauthenticated when the signer app is gone on restore',
        () async {
          channels.secureStorage['amber_pubkey'] = freshPubkeyHex();
          SharedPreferences.setMockInitialValues({
            'authentication_source': 'amber',
            kKnownAccountsKey: '[]',
          });
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          channels.androidSignerInstalled = false;
          final authService = createAuthService();
          addTearDown(authService.dispose);

          await ignoringDiscoveryErrors(authService.initialize);

          expect(authService.isAuthenticated, isFalse);
          expect(authService.currentIdentity, isNull);
        },
      );
    });
  });
}
