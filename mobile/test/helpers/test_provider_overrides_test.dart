// ABOUTME: Tests for shared widget-test provider overrides.
// ABOUTME: Guards against real services leaking into unrelated widget tests.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';

import 'test_provider_overrides.dart';

class _FakeAuthService extends Fake implements AuthService {}

void main() {
  group('createMockAuthService', () {
    for (final authState in AuthState.values) {
      test('keeps isAuthenticated consistent with $authState', () {
        final auth = createMockAuthService(authState: authState);

        expect(auth.authState, authState);
        expect(auth.isAuthenticated, authState == AuthState.authenticated);
      });
    }

    test('defaults to an unauthenticated session without a public key', () {
      final auth = createMockAuthService();

      expect(auth.authState, AuthState.unauthenticated);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentPublicKeyHex, isNull);
    });

    test('accepts an authenticated state and public key together', () {
      final publicKeyHex = 'a' * 64;
      final auth = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: publicKeyHex,
      );

      expect(auth.authState, AuthState.authenticated);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentPublicKeyHex, publicKeyHex);
    });
  });

  group('getStandardTestOverrides', () {
    test('standard overrides give auth mocks a session-cleanup callback', () {
      final auth = MockAuthService();

      getStandardTestOverrides(mockAuthService: auth);

      final unregister = auth.registerBeforeSessionTeardownCallback(
        () async {},
      );
      expect(unregister, isA<void Function()>());
      expect(unregister, returnsNormally);
    });

    test('standard overrides leave hand-written auth fakes alone', () {
      expect(
        () => getStandardTestOverrides(mockAuthService: _FakeAuthService()),
        returnsNormally,
      );
    });

    test('standard overrides keep analytics inert in unrelated tests', () {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides().cast(),
      );
      addTearDown(container.dispose);

      expect(
        container.read(analyticsServiceProvider),
        isA<TestAnalyticsService>(),
      );
    });

    test('standard overrides mock NIP-05 verification by default', () {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides().cast(),
      );
      addTearDown(container.dispose);

      expect(
        container.read(nip05VerificationServiceProvider),
        isA<MockNip05VerificationService>(),
      );
    });
  });
}
