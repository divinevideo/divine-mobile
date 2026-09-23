// ABOUTME: Riverpod dependency wiring for crossposting settings
// ABOUTME: Owns the API client lifecycle and repository construction

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
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

final crosspostingAvailabilityProvider = Provider<CrosspostingAvailability>((
  ref,
) {
  final authState = ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  final registered =
      authState == AuthState.authenticated &&
      authService.currentPublicKeyHex != null &&
      authService.isRegistered;
  if (!registered) return CrosspostingAvailability.unavailable;
  // Fail to webOnly, not unavailable: an unresolved lookup must not hide the
  // feature, and the web page is a working connect path regardless.
  final oauthSupported = ref.watch(appOAuthSupportProvider).value ?? false;
  return oauthSupported
      ? CrosspostingAvailability.native
      : CrosspostingAvailability.webOnly;
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
  final authState = container.read(currentAuthStateProvider);
  final authService = container.read(authServiceProvider);
  final registered =
      authState == AuthState.authenticated &&
      authService.currentPublicKeyHex != null &&
      authService.isRegistered;
  if (!registered) return CrosspostingAvailability.unavailable;
  final supported = await container.read(appOAuthSupportProvider.future);
  return supported
      ? CrosspostingAvailability.native
      : CrosspostingAvailability.webOnly;
}
