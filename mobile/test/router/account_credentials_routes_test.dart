// ABOUTME: Tests that the change-email/change-password locations are routable
// ABOUTME: and that the credential gate closes them for key-only identities

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/routes/settings_routes.dart';
import 'package:openvine/screens/settings/account/change_email_screen.dart';
import 'package:openvine/screens/settings/account/change_password_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('account credential routes', () {
    late _MockAuthService authService;

    setUp(() {
      authService = _MockAuthService();
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    ProviderContainer buildContainer(AuthenticationSource source) {
      when(() => authService.authenticationSource).thenReturn(source);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(authService)],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// Whether the router has a route for [location] at all. A path nobody
    /// registered resolves to the error route — which on screen reads as
    /// "this page does not exist", the symptom a path/parent mismatch causes.
    bool isRoutable(ProviderContainer container, String location) {
      final router = container.read(goRouterProvider);
      return !router.configuration.findMatch(Uri.parse(location)).isError;
    }

    test('both credential screens are registered under General Settings', () {
      final container = buildContainer(AuthenticationSource.divineOAuth);

      expect(ChangePasswordScreen.path, startsWith(GeneralSettingsScreen.path));
      expect(ChangeEmailScreen.path, startsWith(GeneralSettingsScreen.path));
      expect(isRoutable(container, ChangePasswordScreen.path), isTrue);
      expect(isRoutable(container, ChangeEmailScreen.path), isTrue);
    });

    test('the gate lets a Divine-login account through', () {
      final container = buildContainer(AuthenticationSource.divineOAuth);

      expect(accountCredentialsRedirectIfUnavailable(container), isNull);
    });

    test('the gate sends a key-only identity back to General Settings', () {
      final container = buildContainer(AuthenticationSource.importedKeys);

      expect(
        accountCredentialsRedirectIfUnavailable(container),
        GeneralSettingsScreen.path,
      );
    });
  });
}
