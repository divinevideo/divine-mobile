// ABOUTME: Tests the 18+ verification gate for dashboard-configured featured tabs.
// ABOUTME: Unverified and still-loading viewers fail closed until verification resolves.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

void main() {
  late _MockAgeVerificationService ageVerificationService;

  setUp(() {
    ageVerificationService = _MockAgeVerificationService();
    when(() => ageVerificationService.initialized).thenAnswer((_) async {});
    when(() => ageVerificationService.isAdultContentVerified).thenReturn(false);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        ageVerificationServiceProvider.overrideWithValue(
          ageVerificationService,
        ),
        currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Every account swap transits a non-authenticated auth state before the
  /// new account reports authenticated (see isProtectedMinorProvider).
  void switchAccount(ProviderContainer container) {
    for (final authState in [
      AuthState.authenticating,
      AuthState.authenticated,
    ]) {
      container.updateOverrides([
        ageVerificationServiceProvider.overrideWithValue(
          ageVerificationService,
        ),
        currentAuthStateProvider.overrideWithValue(authState),
      ]);
    }
  }

  group('featuredTabAgeGateProvider', () {
    test('gates while persisted adult verification is loading', () {
      final container = createContainer();

      expect(
        container.read(featuredTabAgeGateProvider),
        FeaturedTabAudience.loading,
      );
    });

    test('gates a viewer without 18+ verification', () async {
      final container = createContainer();

      await container.read(featuredTabViewerIsAdultProvider.future);

      expect(
        container.read(featuredTabAgeGateProvider),
        FeaturedTabAudience.unverified,
      );
    });

    test('does not gate an 18+ verified viewer', () async {
      when(
        () => ageVerificationService.isAdultContentVerified,
      ).thenReturn(true);
      final container = createContainer();

      await container.read(featuredTabViewerIsAdultProvider.future);

      expect(
        container.read(featuredTabAgeGateProvider),
        FeaturedTabAudience.adult,
      );
    });

    test('recomputes when adult verification changes', () async {
      var verified = false;
      when(
        () => ageVerificationService.isAdultContentVerified,
      ).thenAnswer((_) => verified);
      final container = createContainer();
      await container.read(featuredTabViewerIsAdultProvider.future);
      expect(
        container.read(featuredTabAgeGateProvider),
        FeaturedTabAudience.unverified,
      );

      verified = true;
      container
          .read(adultContentVerificationVersionProvider.notifier)
          .increment();
      await container.read(featuredTabViewerIsAdultProvider.future);

      expect(
        container.read(featuredTabAgeGateProvider),
        FeaturedTabAudience.adult,
      );
    });

    test(
      're-gates when the auth state changes to an unverified account',
      () async {
        var verified = true;
        when(
          () => ageVerificationService.isAdultContentVerified,
        ).thenAnswer((_) => verified);
        final container = createContainer();
        await container.read(featuredTabViewerIsAdultProvider.future);
        expect(
          container.read(featuredTabAgeGateProvider),
          FeaturedTabAudience.adult,
        );

        // Account switch: the service now answers for the new account, but
        // nothing bumps the verification version. Only the auth state moves.
        verified = false;
        switchAccount(container);
        expect(
          container.read(featuredTabAgeGateProvider),
          FeaturedTabAudience.loading,
        );
        await container.read(featuredTabViewerIsAdultProvider.future);

        expect(
          container.read(featuredTabAgeGateProvider),
          FeaturedTabAudience.unverified,
        );
      },
    );
  });
}
