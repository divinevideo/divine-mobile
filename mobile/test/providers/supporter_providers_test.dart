// ABOUTME: Tests account and signer gates for automatic supporter recovery.
// ABOUTME: Ensures recovery waits for NIP-98 signing capability.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
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
      when(() => repository.recoverPurchases()).thenAnswer((_) async {});
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

  group('supporterApiBaseUrl', () {
    // The supporter feature is no longer flag-gated, so this constant is the
    // only thing standing between a build and a working supporter flow. When
    // it is empty, supporterApiClientProvider returns null, the settings tile
    // is hidden and the route redirects — indistinguishable from the feature
    // never having shipped. Worth pinning.
    test('defaults to the deployed production Worker', () {
      expect(supporterApiBaseUrl, 'https://supporters.divine.video');
    });

    test('is an absolute https URL that can be parsed', () {
      final uri = Uri.parse(supporterApiBaseUrl);
      expect(uri.isAbsolute, isTrue);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    });
  });
}
