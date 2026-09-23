// ABOUTME: Tests reactive OAuth wiring and disposal for crossposting providers
// ABOUTME: Uses the injectable client factory without generated Riverpod code

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockCrosspostingApiClient extends Mock
    implements CrosspostingApiClient {}

final _authSelectorProvider = StateProvider<AuthService>((_) {
  throw StateError('Must be overridden');
});

void main() {
  test('auth changes rebuild and dispose owner-bound API clients', () async {
    final firstAuth = _MockAuthService();
    final secondAuth = _MockAuthService();
    final firstClient = _MockCrosspostingApiClient();
    final secondClient = _MockCrosspostingApiClient();
    when(firstAuth.getBoundDivineAccessToken).thenAnswer((_) async => 'first');
    when(
      secondAuth.getBoundDivineAccessToken,
    ).thenAnswer((_) async => 'second');
    when(firstClient.close).thenReturn(null);
    when(secondClient.close).thenReturn(null);
    final readers = <CrosspostingAccessTokenReader>[];
    final container = ProviderContainer(
      overrides: [
        _authSelectorProvider.overrideWith((_) => firstAuth),
        authServiceProvider.overrideWith(
          (ref) => ref.watch(_authSelectorProvider),
        ),
        crosspostingApiClientFactoryProvider.overrideWithValue((reader) {
          readers.add(reader);
          return readers.length == 1 ? firstClient : secondClient;
        }),
      ],
    );

    expect(container.read(crosspostingApiClientProvider), same(firstClient));
    expect(await readers.single(), 'first');
    container.read(_authSelectorProvider.notifier).state = secondAuth;
    await Future<void>.delayed(Duration.zero);

    expect(container.read(crosspostingApiClientProvider), same(secondClient));
    expect(await readers.last(), 'second');
    expect(readers, hasLength(2));
    verify(firstClient.close).called(1);
    verifyNever(secondClient.close);

    container.dispose();

    verify(secondClient.close).called(1);
  });

  group('crosspostingAvailabilityProvider', () {
    ProviderContainer buildContainer({
      bool oauthSupported = true,
      bool resolveSupport = true,
      bool authenticated = true,
      bool registered = true,
    }) {
      final auth = _MockAuthService();
      when(() => auth.currentPublicKeyHex).thenReturn('a' * 64);
      when(() => auth.isRegistered).thenReturn(registered);
      return ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(
            authenticated ? AuthState.authenticated : AuthState.unauthenticated,
          ),
          authServiceProvider.overrideWithValue(auth),
          appOAuthSupportProvider.overrideWith((ref) async {
            if (!resolveSupport) return Completer<bool>().future;
            return oauthSupported;
          }),
        ],
      );
    }

    test('is native when authenticated and OAuth is supported', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(appOAuthSupportProvider.future);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.native,
      );
    });

    test('is webOnly when OAuth is unsupported', () async {
      final container = buildContainer(oauthSupported: false);
      addTearDown(container.dispose);
      await container.read(appOAuthSupportProvider.future);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.webOnly,
      );
    });

    test('is webOnly while the support lookup is unresolved', () async {
      final container = buildContainer(resolveSupport: false);
      addTearDown(container.dispose);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.webOnly,
      );
    });

    test('is unavailable when signed out', () async {
      final container = buildContainer(authenticated: false);
      addTearDown(container.dispose);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.unavailable,
      );
    });

    test('is unavailable when the account is not registered', () async {
      final container = buildContainer(registered: false);
      addTearDown(container.dispose);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.unavailable,
      );
    });
  });
}
