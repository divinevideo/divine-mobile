// ABOUTME: Tests that a review-status fetch records the account's last-known
// ABOUTME: restriction, which the router gates on while the next fetch runs.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/minor_account_review_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockRepository extends Mock implements MinorAccountReviewRepository {}

void main() {
  group('currentMinorAccountReviewStatusProvider', () {
    final pubkey = 'a' * 64;

    late SharedPreferences prefs;
    late _MockRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = _MockRepository();
    });

    ProviderContainer createContainer() {
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          sharedPreferencesProvider.overrideWithValue(prefs),
          minorAccountReviewRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('records the fetched status for the signed-in account', () async {
      when(repository.fetchCurrentStatus).thenAnswer(
        (_) async => const MinorAccountReviewStatus(
          restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
        ),
      );
      final container = createContainer();

      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpEventQueue();

      expect(
        container
            .read(minorAccountReviewStatusStoreProvider)
            .lastKnownRestrictedFor(pubkey),
        isTrue,
      );
    });
  });
}
