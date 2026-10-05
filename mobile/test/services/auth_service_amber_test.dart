// ABOUTME: Unit tests for AuthService NIP-55 Amber (Android signer) sign-in and
// ABOUTME: session-restore flows. Runs on CI without an emulator via channel mocks.
//
// Covers the previously-uncovered Amber concern (#4741 PR1 gap-fill): the
// connectWithAmber platform/availability guards and the _reconnectAmber restore
// path reached through initialize(). The Amber signer talks to the native
// `nostrmoPlugin` MethodChannel, which is stubbed here; AndroidNostrSigner is
// constructed with a known pubkey on the restore path, so no intent round-trip
// is needed.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
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
