// ABOUTME: Riverpod providers wiring the supporter feature.
// ABOUTME: Selects the store-backed EntitlementValidator on iOS/Android and a
// ABOUTME: stub elsewhere, owned by an account-scoped SupporterRepository.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/supporter_api_client.dart';
import 'package:openvine/services/supporter_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'supporter_providers.g.dart';

/// True when this platform has a real in-app purchase store.
///
/// Mirrors the [hasNativeVideoPlayer] gate: iOS/Android only, web-safe.
bool get hasInAppPurchaseStore =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.linux &&
    defaultTargetPlatform != TargetPlatform.windows &&
    defaultTargetPlatform != TargetPlatform.macOS;

/// Optional Worker URL supplied by the build once divine-supporters exists.
///
/// Keeping this empty by default prevents the flag-gated client foundation
/// from sending requests to an invented or undeployed endpoint.
const supporterApiBaseUrl = String.fromEnvironment('SUPPORTERS_API_BASE_URL');

/// The NIP-98 authenticated supporter Worker client, when configured.
@riverpod
SupporterApiClient? supporterApiClient(Ref ref) {
  if (supporterApiBaseUrl.isEmpty) return null;

  final authService = ref.watch(nip98AuthServiceProvider);
  final client = SupporterApiClient(
    baseUri: Uri.parse(supporterApiBaseUrl),
    httpClient: ref.watch(instrumentedHttpClientFactoryProvider)(),
    authHeaderProvider: ({required url, required method, payload}) async {
      final token = await authService.createAuthToken(
        url: url,
        method: method,
        payload: payload,
      );
      if (token == null) return null;
      return (
        authorizationHeader: token.authorizationHeader,
        pubkey: token.signedEvent.pubkey,
      );
    },
  );
  ref.onDispose(client.dispose);
  return client;
}

/// The store-backed [EntitlementValidator] for the current platform.
///
/// Returns an [InAppPurchaseValidator] on iOS/Android and a
/// [StubEntitlementValidator] elsewhere so the rest of the app can treat the
/// supporter feature uniformly.
@Riverpod(keepAlive: true)
EntitlementValidator entitlementValidator(Ref ref) {
  if (!hasInAppPurchaseStore) {
    return StubEntitlementValidator();
  }
  final validator = InAppPurchaseValidator();
  validator.startListening();
  ref.onDispose(validator.dispose);
  return validator;
}

/// The account-scoped [SupporterRepository] that owns the cached entitlement.
@Riverpod(keepAlive: true)
SupporterRepository supporterRepository(Ref ref) {
  ref.watch(currentAuthStateProvider);
  final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  final repository = SupporterRepository(
    pubkey: pubkey ?? 'unauthenticated',
    apiClient: ref.watch(supporterApiClientProvider),
    validator: ref.watch(entitlementValidatorProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

/// Repairs store purchases automatically after a signed-in app enters the
/// foreground.
///
/// This deliberately does not depend on the Supporter screen or the feature
/// flag. Purchases with a known local or canonical account owner can recover
/// without opening Settings. Unbound legacy purchases require explicit Restore
/// to choose their account. The repository coalesces overlapping calls and
/// retries temporary failures on a later foreground edge.
final supporterRecoveryProvider = Provider<Future<void>?>((ref) {
  final authService = ref.watch(authServiceProvider);
  final authState = ref.watch(currentAuthStateProvider);
  ref.watch(currentAuthRpcCapabilityProvider);
  final isForeground = ref.watch(appForegroundProvider);
  if (authState != AuthState.authenticated ||
      !authService.canPublishNostrWritesNow ||
      !isForeground) {
    return null;
  }

  final repository = ref.watch(supporterRepositoryProvider);
  if (!repository.hasServerClient) return null;
  return repository.recoverPurchases();
});
