// ABOUTME: Exercises cleanup failure state and an explicit public sign-in retry.
// ABOUTME: A refused sweep cannot expose a tentative account or accept terms.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/auth_service_test_harness.dart';

class _Cleanup extends Mock implements UserDataCleanupService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService account cleanup failure recovery', () {
    setUp(AuthServiceChannelMocks.install);
    tearDown(AuthServiceChannelMocks.remove);

    test(
      'failed cleanup retires tentative state before explicit retry',
      () async {
        SharedPreferences.setMockInitialValues({});
        final cleanup = _Cleanup();
        stubUserDataCleanupSuccess(cleanup);
        when(() => cleanup.shouldClearDataForUser(any())).thenReturn(true);
        when(
          () => cleanup.clearUserSpecificData(
            reason: any(named: 'reason'),
            isIdentityChange: any(named: 'isIdentityChange'),
            userPubkey: any(named: 'userPubkey'),
            deleteUserData: any(named: 'deleteUserData'),
          ),
        ).thenThrow(const UserDataCleanupException('Account cache refused'));
        final service = buildTestAuthService(cleanupService: cleanup);
        addTearDown(service.dispose);

        final failed = await service.createNewIdentity();
        expect(failed.success, isFalse);
        expect(failed.failureReason, AuthFailureReason.accountCleanupFailed);
        expect(service.authState, AuthState.unauthenticated);
        expect(service.authenticationSource, AuthenticationSource.none);
        expect(service.currentIdentity, isNull);
        expect(service.currentProfile, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('current_user_pubkey_hex'), isNull);
        expect(prefs.getString('terms_accepted_at'), isNull);

        stubUserDataCleanupSuccess(cleanup);
        final retried = await ignoringDiscoveryErrors(
          service.createNewIdentity,
        );
        expect(retried.success, isTrue);
        expect(retried.failureReason, isNull);
        expect(service.currentIdentity, isNotNull);
        await ignoringDiscoveryErrors(service.acceptTerms);
        expect(service.isAuthenticated, isTrue);
      },
    );
  });
}
