// ABOUTME: Unit test for AuthService destructive sign-out recovery —
// ABOUTME: _completeDestructiveSignOutAfterDeletedKeys when cleanup throws.
//
// #4741 PR1 gap-fill: signOut(deleteKeys: true, abortOnKeyDeletionFailure: true)
// deletes local login material BEFORE session cleanup. If a later cleanup step
// then throws, the app must NOT stay authenticated-in-memory with no keys on
// disk — signOut routes to _completeDestructiveSignOutAfterDeletedKeys, which
// disconnects only the actor and propagates incomplete cleanup. Failure is injected via the
// mocked UserDataCleanupService.markOwnerScopedLegacyDataForUser (called
// unwrapped in the destructive branch), with a real channel-backed
// SecureKeyStorage for the authenticated starting state.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _Discovery extends Mock implements RelayDiscoveryService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService destructive sign-out recovery', () {
    late _MockUserDataCleanupService mockCleanupService;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      stubUserDataCleanupSuccess(mockCleanupService);
      AuthServiceChannelMocks.install();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    });

    tearDown(AuthServiceChannelMocks.remove);

    AuthService createAuthService() {
      final discovery = _Discovery();
      when(() => discovery.discoverRelays(any())).thenAnswer(
        (_) async =>
            RelayDiscoveryResult.failure('No network in cleanup tests'),
      );
      when(() => discovery.clearCache(any())).thenAnswer((_) async {});
      return AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        keyStorage: SecureKeyStorage(securityConfig: SecurityConfig.desktop),
        flutterSecureStorage: const FlutterSecureStorage(),
        relayDiscoveryService: discovery,
        profileCheckIndexerUrl: 'unsupported://profile.invalid',
      );
    }

    test('reports incomplete deletion and disconnects the outgoing actor when a '
        'cleanup step throws after key deletion', () async {
      final authService = createAuthService();
      addTearDown(authService.dispose);

      // Authenticated starting state.
      final result = await authService.importFromHex(generatePrivateKey());
      expect(result.success, isTrue);
      expect(authService.committedAccountActivationReceipt!.isCurrent, isTrue);
      expect(authService.isAuthenticated, isTrue);

      // Fail a cleanup step that runs AFTER the pre-flight key deletion in the
      // destructive branch, forcing the recovery path.
      when(
        () => mockCleanupService.markOwnerScopedLegacyDataForUser(any()),
      ).thenAnswer((_) async => throw Exception('cleanup boom'));

      await expectLater(
        authService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'controlled required cleanup failure',
            'Exception: cleanup boom',
          ),
        ),
      );

      // The recovery path tore down the session rather than leaving an
      // authenticated-in-memory state with no keys on disk.
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentIdentity, isNull);
      expect(authService.committedAccountActivationReceipt, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(
        AccountActivationCoordinator.forPreferences(prefs)
            .hasUnresolvedActivation,
        isTrue,
      );
    });
  });
}
