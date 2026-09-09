// ABOUTME: Riverpod dependency wiring for crossposting settings
// ABOUTME: Owns the API client lifecycle and repository construction

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/crossposting_api_client.dart';

final crosspostingEligibleProvider = Provider<bool>((ref) {
  // Hidden entirely while the platform's OAuth callback path is unknown or
  // unreliable (iOS < 17.4) — offering the flow there fails mid-session.
  final oauthSupported = ref.watch(appOAuthSupportProvider).value ?? false;
  if (!oauthSupported) return false;
  final authState = ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authState == AuthState.authenticated &&
      authService.currentPublicKeyHex != null &&
      authService.isRegistered;
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
