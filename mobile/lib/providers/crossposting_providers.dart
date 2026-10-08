// ABOUTME: Riverpod dependency wiring for crossposting settings
// ABOUTME: Owns the API client lifecycle and repository construction

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/auth_service.dart'
    show AuthService, AuthState;
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/nip98_http_client.dart';
import 'package:url_launcher/url_launcher.dart';

/// How this build can drive the crossposting connect flow.
enum CrosspostingAvailability {
  /// Authenticated and in-app OAuth works; connect inside the app.
  native,

  /// Authenticated, but in-app OAuth cannot deliver the callback (iOS < 17.4,
  /// or the system version could not be determined). Connect on the web.
  webOnly,

  /// Signed out or unable to sign; show no crossposting CTA.
  unavailable,
}

/// Opens the crossposter web setup page; the fallback when in-app OAuth is
/// unsupported.
typedef CrosspostingWebOpener = Future<bool> Function(Uri url);

final crosspostingWebOpenerProvider = Provider<CrosspostingWebOpener>((ref) {
  return (url) => launchUrl(url, mode: LaunchMode.externalApplication);
});

/// Whether the signed-in account can crosspost at all: authenticated, with a
/// known public key, and a signer that is ready now.
bool isCrosspostingAccountEligible({
  required AuthState authState,
  required String? publicKeyHex,
  required bool canSign,
}) {
  return authState == AuthState.authenticated &&
      publicKeyHex != null &&
      canSign;
}

/// The single availability decision shared by
/// [crosspostingAvailabilityProvider] (visibility) and
/// [resolveCrosspostingAvailability] (routing), so the two cannot drift.
CrosspostingAvailability crosspostingAvailabilityFor({
  required bool accountEligible,
  required bool oauthSupported,
  required bool webAccountEligible,
}) {
  if (!accountEligible) return CrosspostingAvailability.unavailable;
  return oauthSupported
      ? CrosspostingAvailability.native
      : webAccountEligible
      ? CrosspostingAvailability.webOnly
      : CrosspostingAvailability.unavailable;
}

bool _isCurrentAccountEligible(AuthState authState, AuthService authService) {
  if (authState != AuthState.authenticated) return false;
  return isCrosspostingAccountEligible(
    authState: authState,
    publicKeyHex: authService.currentPublicKeyHex,
    canSign: authService.canPublishNostrWritesNow,
  );
}

final crosspostingAvailabilityProvider = Provider<CrosspostingAvailability>((
  ref,
) {
  final authState = ref.watch(currentAuthStateProvider);
  if (authState == AuthState.authenticated) {
    ref.watch(currentAuthRpcCapabilityProvider);
  }
  final eligible = _isCurrentAccountEligible(
    authState,
    ref.watch(authServiceProvider),
  );
  // The web setup page only supports Divine OAuth accounts. Other signers
  // must wait for native OAuth support before offering the connect flow.
  final oauthSupported =
      eligible && (ref.watch(appOAuthSupportProvider).value ?? false);
  return crosspostingAvailabilityFor(
    accountEligible: eligible,
    oauthSupported: oauthSupported,
    webAccountEligible: ref.read(authServiceProvider).isRegistered,
  );
});

/// The account a NIP-98 request must be signed by.
final crosspostingOwnerPubkeyProvider = Provider<String?>((ref) {
  if (ref.watch(currentAuthStateProvider) != AuthState.authenticated) {
    return null;
  }
  return ref.watch(authServiceProvider).currentPublicKeyHex;
});

typedef CrosspostingApiClientFactory = CrosspostingApiClient Function({
  required Nip98AuthService nip98AuthService,
  required String? ownerPubkey,
});

final crosspostingApiClientFactoryProvider =
    Provider<CrosspostingApiClientFactory>((ref) {
      final newHttpClient = ref.watch(instrumentedHttpClientFactoryProvider);
      return ({required nip98AuthService, required ownerPubkey}) =>
          CrosspostingApiClient(
            nip98AuthService: nip98AuthService,
            ownerPubkey: ownerPubkey,
            httpClient: Nip98HttpClient(
              inner: newHttpClient(),
              authService: nip98AuthService,
              trustedOrigin: Uri.parse(CrosspostingApiClient.defaultBaseUrl),
              retryBudget: CrosspostingApiClient.requestTimeout,
            ),
          );
    });

final crosspostingApiClientProvider = Provider<CrosspostingApiClient>((ref) {
  final createClient = ref.watch(crosspostingApiClientFactoryProvider);
  final client = createClient(
    nip98AuthService: ref.watch(nip98AuthServiceProvider),
    ownerPubkey: ref.watch(crosspostingOwnerPubkeyProvider),
  );
  ref.onDispose(client.close);
  return client;
});

final crosspostingRepositoryProvider = Provider<CrosspostingRepository>((ref) {
  return CrosspostingRepository(ref.watch(crosspostingApiClientProvider));
});

/// Resolves availability, waiting for the OAuth-support lookup if it has not
/// settled. Use this for routing decisions so a cold provider read cannot send
/// a native-capable device to the web fallback.
Future<CrosspostingAvailability> resolveCrosspostingAvailability(
  ProviderContainer container,
) async {
  final eligible = _isCurrentAccountEligible(
    container.read(currentAuthStateProvider),
    container.read(authServiceProvider),
  );
  final oauthSupported =
      eligible && await container.read(appOAuthSupportProvider.future);
  return crosspostingAvailabilityFor(
    accountEligible: eligible,
    oauthSupported: oauthSupported,
    webAccountEligible: container.read(authServiceProvider).isRegistered,
  );
}
