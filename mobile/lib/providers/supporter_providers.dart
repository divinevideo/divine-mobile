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

/// Base URL of the divine-supporters Worker.
///
/// Defaults to the deployed production Worker so an ordinary build ships a
/// working supporter flow. A build overrides it with
/// `--dart-define=SUPPORTERS_API_BASE_URL=...` to point at staging or a QA
/// deployment; passing an empty or malformed value disables the client
/// entirely.
const supporterApiBaseUrl = String.fromEnvironment(
  'SUPPORTERS_API_BASE_URL',
  defaultValue: 'https://supporters.divine.video',
);

/// Whether [baseUrl] is a usable base for the supporter Worker.
///
/// A usable base URL is a non-empty absolute `https` URL with a host and no
/// query or fragment. The query and fragment matter because
/// [SupporterApiClient] appends a slash to the base before resolving request
/// paths: `https://host/api?x=1` becomes `https://host/api?x=1/`, so resolving
/// `/v1/me` against it silently drops the `/api` prefix and every request goes
/// somewhere else. Treating a malformed override as unusable disables the
/// client deliberately instead of misrouting it.
bool supporterApiUsable(String baseUrl) {
  if (baseUrl.isEmpty || baseUrl != baseUrl.trim()) return false;
  final uri = Uri.tryParse(baseUrl);
  return uri != null &&
      uri.isAbsolute &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

/// Whether this build can talk to the supporter Worker at all.
///
/// Equivalent to `supporterApiClientProvider != null`, because an unusable
/// base URL is the only thing that makes that provider null — but it answers
/// the question without *building* the client, which pulls in the NIP-98 and
/// secure-auth services and the work they start. A settings tile deciding
/// whether to render, and a route guard evaluating a redirect, should not pay
/// that cost or leave those services running behind them.
@riverpod
bool supporterApiConfigured(Ref ref) => supporterApiUsable(supporterApiBaseUrl);

/// The NIP-98 authenticated supporter Worker client, when configured.
@riverpod
SupporterApiClient? supporterApiClient(Ref ref) {
  if (!supporterApiUsable(supporterApiBaseUrl)) return null;

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
/// flag. It runs only when the device already carries local evidence of a
/// purchase — a cached entitlement or an interrupted claim — so an account that
/// never bought anything does not spend an authenticated request and a store
/// restore to find nothing. A purchase known only canonically (a reinstall, a
/// new device) is picked up when the user opens the Supporter screen, or by an
/// explicit Restore; unbound legacy purchases require that explicit Restore to
/// choose their account. The repository coalesces overlapping calls and retries
/// temporary failures on a later foreground edge.
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
  // Nothing to recover until this device has seen a purchase. See
  // [SupporterRepository.hasRecoverableEvidence].
  if (!repository.hasRecoverableEvidence) return null;
  return repository.recoverPurchases();
});
