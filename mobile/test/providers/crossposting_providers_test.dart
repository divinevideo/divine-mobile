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

  group('crosspostingEligibleProvider', () {
    ProviderContainer buildContainer({
      required bool oauthSupported,
      bool resolveSupport = true,
    }) {
      final auth = _MockAuthService();
      when(() => auth.currentPublicKeyHex).thenReturn('a' * 64);
      when(() => auth.isRegistered).thenReturn(true);
      return ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          authServiceProvider.overrideWithValue(auth),
          appOAuthSupportProvider.overrideWith((ref) async {
            if (!resolveSupport) {
              // Never settle: models the window before the device lookup
              // completes.
              return Completer<bool>().future;
            }
            return oauthSupported;
          }),
        ],
      );
    }

    test(
      'an eligible account is visible when the platform supports OAuth',
      () async {
        final container = buildContainer(oauthSupported: true);
        addTearDown(container.dispose);

        await container.read(appOAuthSupportProvider.future);

        expect(container.read(crosspostingEligibleProvider), isTrue);
      },
    );

    test('an eligible account is hidden when the platform does not support '
        'the OAuth callback', () async {
      // iOS 16.0-17.3: the flow exists but offering it fails mid-session.
      final container = buildContainer(oauthSupported: false);
      addTearDown(container.dispose);

      // Load-bearing: assert after the lookup settles, so this cannot pass
      // for the unresolved-loading reason below.
      await container.read(appOAuthSupportProvider.future);

      expect(container.read(crosspostingEligibleProvider), isFalse);
    });

    test(
      'stays hidden while the platform support lookup is unresolved',
      () async {
        final container = buildContainer(
          oauthSupported: true,
          resolveSupport: false,
        );
        addTearDown(container.dispose);

        expect(container.read(crosspostingEligibleProvider), isFalse);
      },
    );
  });
}
