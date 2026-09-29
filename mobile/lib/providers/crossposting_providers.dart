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
import 'package:url_launcher/url_launcher.dart';

/// How this build can drive the crossposting connect flow.
enum CrosspostingAvailability {
  /// Authenticated and in-app OAuth works; connect inside the app.
  native,

  /// Authenticated, but in-app OAuth cannot deliver the callback (iOS < 17.4,
  /// or the system version could not be determined). Connect on the web.
  webOnly,

  /// Signed out or not registered; show no crossposting CTA.
  unavailable,
}

/// Opens the crossposter web setup page; the fallback when in-app OAuth is
/// unsupported.
typedef CrosspostingWebOpener = Future<bool> Function(Uri url);

final crosspostingWebOpenerProvider = Provider<CrosspostingWebOpener>((ref) {
  return (url) => launchUrl(url, mode: LaunchMode.externalApplication);
});

/// Whether the signed-in account can crosspost at all: authenticated, with a
/// known public key, and registered with Divine.
bool isCrosspostingAccountEligible({
  required AuthState authState,
  required String? publicKeyHex,
  required bool isRegistered,
}) {
  return authState == AuthState.authenticated &&
      publicKeyHex != null &&
      isRegistered;
}

/// The single availability decision shared by
/// [crosspostingAvailabilityProvider] (visibility) and
/// [resolveCrosspostingAvailability] (routing), so the two cannot drift.
CrosspostingAvailability crosspostingAvailabilityFor({
  required bool accountEligible,
  required bool oauthSupported,
}) {
  if (!accountEligible) return CrosspostingAvailability.unavailable;
  return oauthSupported
      ? CrosspostingAvailability.native
      : CrosspostingAvailability.webOnly;
}

bool _isCurrentAccountEligible(AuthState authState, AuthService authService) {
  return isCrosspostingAccountEligible(
    authState: authState,
    publicKeyHex: authService.currentPublicKeyHex,
    isRegistered: authService.isRegistered,
  );
}

final crosspostingAvailabilityProvider = Provider<CrosspostingAvailability>((
  ref,
) {
  final eligible = _isCurrentAccountEligible(
    ref.watch(currentAuthStateProvider),
    ref.watch(authServiceProvider),
  );
  // Fail to webOnly, not unavailable: an unresolved lookup must not hide the
  // feature, and the web page is a working connect path regardless.
  final oauthSupported =
      eligible && (ref.watch(appOAuthSupportProvider).value ?? false);
  return crosspostingAvailabilityFor(
    accountEligible: eligible,
    oauthSupported: oauthSupported,
  );
});

typedef CrosspostingApiClientFactory = CrosspostingApiClient Function(
  CrosspostingAccessTokenReader accessTokenReader,
);

final crosspostingApiClientFactoryProvider =
    Provider<CrosspostingApiClientFactory>((ref) {
      final newHttpClient = ref.watch(instrumentedHttpClientFactoryProvider);
      return (accessTokenReader) => CrosspostingApiClient(
        accessTokenReader: accessTokenReader,
        httpClient: newHttpClient(),
      );
    });

final crosspostingApiClientProvider = Provider<CrosspostingApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  final createClient = ref.watch(crosspostingApiClientFactoryProvider);
  final client = createClient(authService.getBoundDivineAccessToken);
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
  );
}
