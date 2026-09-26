// ABOUTME: Tests account and signer gates for automatic supporter recovery,
// ABOUTME: and which builds are offered store billing at all.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/supporter_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockSupporterRepository extends Mock implements SupporterRepository {}

class _BackgroundAppForeground extends AppForeground {
  @override
  bool build() => false;
}

void main() {
  group('supporterRecoveryProvider', () {
    late _MockAuthService authService;
    late _MockSupporterRepository repository;

    setUp(() {
      authService = _MockAuthService();
      repository = _MockSupporterRepository();

      when(() => authService.canPublishNostrWritesNow).thenReturn(false);
      when(() => repository.hasServerClient).thenReturn(true);
      when(() => repository.hasRecoverableEvidence).thenReturn(true);
      when(() => repository.recoverPurchases()).thenAnswer((_) async {});
    });

    test('does not restore when nothing local suggests a purchase', () {
      // The compiled default means every signed-in user reaches this provider.
      // Recovery must stay off for accounts that have never bought anything,
      // or it spends a signing round trip (a bunker call on NIP-46) and a
      // store restore to find nothing.
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      when(() => repository.hasRecoverableEvidence).thenReturn(false);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          appForegroundProvider.overrideWith(AppForeground.new),
          supporterRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(supporterRecoveryProvider), isNull);
      verifyNever(() => repository.recoverPurchases());
    });

    test('waits for signer capability before restoring purchases', () async {
      final unavailableContainer = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.upgrading,
          ),
          appForegroundProvider.overrideWith(AppForeground.new),
          supporterRepositoryProvider.overrideWithValue(repository),
        ],
      );
      expect(unavailableContainer.read(supporterRecoveryProvider), isNull);
      verifyNever(() => repository.recoverPurchases());
      unavailableContainer.dispose();

      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final readyContainer = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          appForegroundProvider.overrideWith(AppForeground.new),
          supporterRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(readyContainer.dispose);
      final recovery = readyContainer.read(supporterRecoveryProvider);
      expect(recovery, isNotNull);
      await recovery;

      verify(() => repository.recoverPurchases()).called(1);
    });

    test('does not restore while the app is backgrounded', () {
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          appForegroundProvider.overrideWith(_BackgroundAppForeground.new),
          supporterRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(supporterRecoveryProvider), isNull);
      verifyNever(() => repository.recoverPurchases());
    });

    test('restores on a background to foreground transition', () async {
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          appForegroundProvider.overrideWith(_BackgroundAppForeground.new),
          supporterRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(
        supporterRecoveryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      verifyNever(() => repository.recoverPurchases());

      container.read(appForegroundProvider.notifier).setForeground(true);
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.recoverPurchases()).called(1);
    });
  });

  group('supportsStoreBilling', () {
    test(
      'offers Google Play billing only to Play-installed Android builds',
      () {
        // Play Billing answers BILLING_UNAVAILABLE for any build it did not
        // install, so a Zapstore or GitHub APK must never reach its checkout.
        expect(
          supportsStoreBilling(
            platform: TargetPlatform.android,
            installSource: InstallSource.playStore,
            isWeb: false,
          ),
          isTrue,
        );
        for (final source in [InstallSource.zapstore, InstallSource.sideload]) {
          expect(
            supportsStoreBilling(
              platform: TargetPlatform.android,
              installSource: source,
              isWeb: false,
            ),
            isFalse,
            reason: '$source',
          );
        }
      },
    );

    test('offers StoreKit on iOS whatever the install source reports', () {
      // A failed iOS install-source lookup falls back to sideload; that must
      // not hide App Store purchases from a paying user.
      for (final source in InstallSource.values) {
        expect(
          supportsStoreBilling(
            platform: TargetPlatform.iOS,
            installSource: source,
            isWeb: false,
          ),
          isTrue,
          reason: '$source',
        );
      }
    });

    test('offers no store billing on web or desktop', () {
      expect(
        supportsStoreBilling(
          platform: TargetPlatform.android,
          installSource: InstallSource.playStore,
          isWeb: true,
        ),
        isFalse,
      );
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          supportsStoreBilling(
            platform: platform,
            installSource: InstallSource.sideload,
            isWeb: false,
          ),
          isFalse,
          reason: '$platform',
        );
      }
    });
  });

  group('entitlementValidatorProvider', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    ProviderContainer containerFor(InstallSource source) {
      final container = ProviderContainer(
        overrides: [installSourceProvider.overrideWithValue(source)],
      );
      addTearDown(container.dispose);
      return container;
    }

    for (final source in [InstallSource.zapstore, InstallSource.sideload]) {
      test('uses the stub validator for a $source Android build', () {
        final container = containerFor(source);

        expect(container.read(supporterStoreBillingAvailableProvider), isFalse);
        expect(
          container.read(entitlementValidatorProvider),
          isA<StubEntitlementValidator>(),
        );
      });
    }

    test('reports store billing available for a Play-installed build', () {
      final container = containerFor(InstallSource.playStore);

      expect(container.read(supporterStoreBillingAvailableProvider), isTrue);
    });
  });

  group('supporterApiBaseUrl', () {
    // The supporter flow is no longer flag-gated, so this constant is the only
    // thing standing between a build and a working supporter flow. An empty or
    // malformed value makes supporterApiClientProvider null, which hides the
    // settings tile and redirects the route — indistinguishable from the
    // feature never having shipped.
    test('defaults to the deployed production Worker', () {
      expect(supporterApiBaseUrl, 'https://supporters.divine.video');
    });

    test('is an absolute https URL with no query or fragment', () {
      final uri = Uri.parse(supporterApiBaseUrl);
      expect(uri.isAbsolute, isTrue);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
      // SupporterApiClient builds paths by string concatenation, so a query or
      // fragment on the base would corrupt every request it makes.
      expect(uri.hasQuery, isFalse);
      expect(uri.hasFragment, isFalse);
    });

    test('supporterApiConfigured admits the compiled default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // The shipping build carries this constant, so it must be usable; the
      // predicate's rejection cases are covered in the supporterApiUsable
      // group below.
      expect(container.read(supporterApiConfiguredProvider), isTrue);
    });
  });

  group('supporterApiUsable', () {
    // The compiled default is the only configuration a shipping build is
    // guaranteed to have. A build-time override is accepted only when it is a
    // base URL the client can resolve request paths against without silently
    // changing hosts or paths.
    test('accepts the compiled default', () {
      expect(supporterApiUsable(supporterApiBaseUrl), isTrue);
    });

    test('accepts an https override with a path prefix or trailing slash', () {
      expect(supporterApiUsable('https://staging.example/api'), isTrue);
      expect(supporterApiUsable('https://staging.example/api/'), isTrue);
    });

    test('rejects an empty or missing override', () {
      expect(supporterApiUsable(''), isFalse);
    });

    test('rejects a base URL that is not absolute https with a host', () {
      expect(supporterApiUsable('http://supporters.divine.video'), isFalse);
      expect(supporterApiUsable('supporters.divine.video'), isFalse);
      expect(supporterApiUsable('https://'), isFalse);
      expect(supporterApiUsable(' https://supporters.divine.video'), isFalse);
    });

    test('rejects a query or fragment, which would misroute requests', () {
      // SupporterApiClient appends a slash to the base before resolving, so
      // `https://host/api?x=1` would resolve `/v1/me` to `https://host/v1/me`.
      expect(supporterApiUsable('https://host/api?x=1'), isFalse);
      expect(supporterApiUsable('https://host/api#fragment'), isFalse);
    });
  });
}
