// ABOUTME: Tests signer-capability eligibility and account-bound client wiring
// ABOUTME: Uses the injectable client factory without generated Riverpod code

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

class _MockCrosspostingApiClient extends Mock
    implements CrosspostingApiClient {}

const _firstPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _secondPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final _ownerSelectorProvider = StateProvider<String?>((_) => _firstPubkey);

void main() {
  group('crosspostingApiClientProvider', () {
    test('an account change rebuilds the client for the new owner and '
        'closes the old one', () async {
      final nip98 = _MockNip98AuthService();
      final firstClient = _MockCrosspostingApiClient();
      final secondClient = _MockCrosspostingApiClient();
      when(firstClient.close).thenReturn(null);
      when(secondClient.close).thenReturn(null);
      final owners = <String?>[];
      final signers = <Nip98AuthService>[];
      final container = ProviderContainer(
        overrides: [
          nip98AuthServiceProvider.overrideWithValue(nip98),
          crosspostingOwnerPubkeyProvider.overrideWith(
            (ref) => ref.watch(_ownerSelectorProvider),
          ),
          crosspostingApiClientFactoryProvider.overrideWithValue(({
            required nip98AuthService,
            required ownerPubkey,
          }) {
            owners.add(ownerPubkey);
            signers.add(nip98AuthService);
            return owners.length == 1 ? firstClient : secondClient;
          }),
        ],
      );

      expect(container.read(crosspostingApiClientProvider), same(firstClient));
      final firstRepository = container.read(crosspostingRepositoryProvider);

      container.read(_ownerSelectorProvider.notifier).state = _secondPubkey;

      expect(container.read(crosspostingApiClientProvider), same(secondClient));
      expect(
        container.read(crosspostingRepositoryProvider),
        isNot(same(firstRepository)),
      );
      expect(owners, equals([_firstPubkey, _secondPubkey]));
      expect(signers, everyElement(same(nip98)));
      verify(firstClient.close).called(1);
      verifyNever(secondClient.close);

      container.dispose();

      verify(secondClient.close).called(1);
    });
  });

  group('crosspostingOwnerPubkeyProvider', () {
    ProviderContainer buildContainer(AuthState authState) {
      final auth = _MockAuthService();
      when(() => auth.currentPublicKeyHex).thenReturn(_firstPubkey);
      final container = ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(authState),
          authServiceProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is the active pubkey while authenticated', () {
      final container = buildContainer(AuthState.authenticated);

      expect(
        container.read(crosspostingOwnerPubkeyProvider),
        equals(_firstPubkey),
      );
    });

    test('is null while signed out', () {
      final container = buildContainer(AuthState.unauthenticated);

      expect(container.read(crosspostingOwnerPubkeyProvider), isNull);
    });
  });

  group('isCrosspostingAccountEligible', () {
    test('is true for an authenticated, signer-capable account with a key', () {
      expect(
        isCrosspostingAccountEligible(
          authState: AuthState.authenticated,
          publicKeyHex: 'a' * 64,
          canSign: true,
        ),
        isTrue,
      );
    });

    test('is false when signed out', () {
      expect(
        isCrosspostingAccountEligible(
          authState: AuthState.unauthenticated,
          publicKeyHex: 'a' * 64,
          canSign: true,
        ),
        isFalse,
      );
    });

    test('is false when the public key is not known yet', () {
      expect(
        isCrosspostingAccountEligible(
          authState: AuthState.authenticated,
          publicKeyHex: null,
          canSign: true,
        ),
        isFalse,
      );
    });

    test('is false when the account cannot sign', () {
      expect(
        isCrosspostingAccountEligible(
          authState: AuthState.authenticated,
          publicKeyHex: 'a' * 64,
          canSign: false,
        ),
        isFalse,
      );
    });
  });

  group('crosspostingAvailabilityFor', () {
    test('is native for an eligible account with OAuth support', () {
      expect(
        crosspostingAvailabilityFor(
          accountEligible: true,
          oauthSupported: true,
          webAccountEligible: false,
        ),
        CrosspostingAvailability.native,
      );
    });

    test('is webOnly for an eligible account without OAuth support', () {
      expect(
        crosspostingAvailabilityFor(
          accountEligible: true,
          oauthSupported: false,
          webAccountEligible: true,
        ),
        CrosspostingAvailability.webOnly,
      );
    });

    test('is unavailable for an ineligible account regardless of OAuth', () {
      expect(
        crosspostingAvailabilityFor(
          accountEligible: false,
          oauthSupported: true,
          webAccountEligible: false,
        ),
        CrosspostingAvailability.unavailable,
      );
    });
  });

  group('crosspostingAvailabilityProvider', () {
    ProviderContainer buildContainer({
      bool oauthSupported = true,
      bool resolveSupport = true,
      bool authenticated = true,
      bool canSign = true,
      bool registered = false,
      bool anonymous = false,
    }) {
      final auth = _MockAuthService();
      when(() => auth.currentPublicKeyHex).thenReturn('a' * 64);
      when(() => auth.isRegistered).thenReturn(registered);
      when(() => auth.isAnonymous).thenReturn(anonymous);
      when(() => auth.canPublishNostrWritesNow).thenReturn(canSign);
      when(() => auth.authRpcCapability)
          .thenReturn(AuthRpcCapability.unavailable);
      when(() => auth.authRpcCapabilityStream)
          .thenAnswer((_) => const Stream.empty());
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

    test(
      'a signer-ready local-key account needs no Divine registration',
      () async {
        final container = buildContainer();
        addTearDown(container.dispose);
        await container.read(appOAuthSupportProvider.future);

        expect(
          container.read(crosspostingAvailabilityProvider),
          CrosspostingAvailability.native,
        );
      },
    );

    test('anonymous local-key accounts can use native crossposting', () async {
      final container = buildContainer(anonymous: true);
      addTearDown(container.dispose);
      await container.read(appOAuthSupportProvider.future);
      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.native,
      );
    });

    test('becomes available when a remote signer becomes ready', () async {
      final auth = _MockAuthService();
      final capability = StreamController<AuthRpcCapability>.broadcast();
      addTearDown(capability.close);
      var canSign = false;
      when(() => auth.currentPublicKeyHex).thenReturn('a' * 64);
      when(() => auth.isRegistered).thenReturn(false);
      when(() => auth.canPublishNostrWritesNow).thenAnswer((_) => canSign);
      when(
        () => auth.authRpcCapability,
      ).thenReturn(AuthRpcCapability.unavailable);
      when(
        () => auth.authRpcCapabilityStream,
      ).thenAnswer((_) => capability.stream);
      final container = ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          authServiceProvider.overrideWithValue(auth),
          appOAuthSupportProvider.overrideWith((ref) async => true),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appOAuthSupportProvider.future);
      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.unavailable,
      );

      canSign = true;
      capability.add(AuthRpcCapability.rpcReady);
      await pumpEventQueue();
      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.native,
      );
    });

    test(
      'local-key accounts cannot use the Divine-only web fallback',
      () async {
        final container = buildContainer(oauthSupported: false);
        addTearDown(container.dispose);
        await container.read(appOAuthSupportProvider.future);
        expect(
          container.read(crosspostingAvailabilityProvider),
          CrosspostingAvailability.unavailable,
        );
        expect(
          await resolveCrosspostingAvailability(container),
          CrosspostingAvailability.unavailable,
        );
      },
    );

    test('is webOnly when OAuth is unsupported', () async {
      final container = buildContainer(oauthSupported: false, registered: true);
      addTearDown(container.dispose);
      await container.read(appOAuthSupportProvider.future);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.webOnly,
      );
    });

    test('is webOnly while the support lookup is unresolved', () async {
      final container = buildContainer(resolveSupport: false, registered: true);
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

    test('is unavailable when the account cannot sign', () async {
      final container = buildContainer(canSign: false);
      addTearDown(container.dispose);

      expect(
        container.read(crosspostingAvailabilityProvider),
        CrosspostingAvailability.unavailable,
      );
    });
  });

  group('resolveCrosspostingAvailability', () {
    ProviderContainer buildContainer({
      Future<bool>? support,
      bool authenticated = true,
      bool canSign = true,
      bool registered = false,
    }) {
      final auth = _MockAuthService();
      when(() => auth.isRegistered).thenReturn(registered);
      when(() => auth.currentPublicKeyHex).thenReturn('a' * 64);
      when(() => auth.canPublishNostrWritesNow).thenReturn(canSign);
      when(() => auth.authRpcCapability)
          .thenReturn(AuthRpcCapability.unavailable);
      when(() => auth.authRpcCapabilityStream)
          .thenAnswer((_) => const Stream.empty());
      return ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(
            authenticated ? AuthState.authenticated : AuthState.unauthenticated,
          ),
          authServiceProvider.overrideWithValue(auth),
          appOAuthSupportProvider.overrideWith((ref) async {
            if (support != null) return support;
            return true;
          }),
        ],
      );
    }

    test('is unavailable when signed out', () async {
      final container = buildContainer(authenticated: false);
      addTearDown(container.dispose);

      expect(
        await resolveCrosspostingAvailability(container),
        CrosspostingAvailability.unavailable,
      );
    });

    test('does not wait on the support lookup when signed out', () async {
      final container = buildContainer(
        support: Completer<bool>().future,
        authenticated: false,
      );
      addTearDown(container.dispose);

      expect(
        await resolveCrosspostingAvailability(container),
        CrosspostingAvailability.unavailable,
      );
    });

    test('is unavailable when the account cannot sign', () async {
      final container = buildContainer(canSign: false);
      addTearDown(container.dispose);

      expect(
        await resolveCrosspostingAvailability(container),
        CrosspostingAvailability.unavailable,
      );
    });

    test('waits for an unresolved support lookup that resolves true', () async {
      final completer = Completer<bool>();
      final container = buildContainer(support: completer.future);
      addTearDown(container.dispose);

      final pending = resolveCrosspostingAvailability(container);
      completer.complete(true);

      expect(await pending, CrosspostingAvailability.native);
    });

    test('is webOnly when support resolves false', () async {
      final container = buildContainer(
        support: Future.value(false),
        registered: true,
      );
      addTearDown(container.dispose);

      expect(
        await resolveCrosspostingAvailability(container),
        CrosspostingAvailability.webOnly,
      );
    });
  });
}
