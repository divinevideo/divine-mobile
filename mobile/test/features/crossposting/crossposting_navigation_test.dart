// ABOUTME: Tests crossposting setup routing into native or web fallback
// ABOUTME: Uses a ProviderContainer so the route decision is exercised headless

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/features/crossposting/crossposting_navigation.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('openCrosspostingSetup', () {
    ProviderContainer buildContainer({
      required bool oauthSupported,
      required List<Uri> opened,
    }) {
      final auth = _MockAuthService();
      when(() => auth.currentPublicKeyHex).thenReturn('a' * 64);
      when(() => auth.isRegistered).thenReturn(true);
      return ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          authServiceProvider.overrideWithValue(auth),
          appOAuthSupportProvider.overrideWith((ref) async => oauthSupported),
          crosspostingWebOpenerProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
        ],
      );
    }

    test('opens the web setup page when in-app OAuth is unsupported', () async {
      final opened = <Uri>[];
      final container = buildContainer(oauthSupported: false, opened: opened);
      addTearDown(container.dispose);

      await openCrosspostingSetup(container);

      expect(opened, [Uri.parse(AppConfig.crossposterBaseUrl)]);
    });
  });
}
