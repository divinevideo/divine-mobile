// ABOUTME: Composes the gated short-link creator with existing account and HTTP lifecycles.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/short_link_client.dart';

final shortLinkClientProvider = Provider<ShortLinkClient?>((ref) {
  if (!ref.watch(isFeatureEnabledProvider(FeatureFlag.shortLinksSharing))) {
    return null;
  }
  ref.watch(currentAuthStateProvider);
  ref.watch(currentAccountActivationReceiptProvider);
  final auth = ref.watch(authServiceProvider);
  if (!auth.isAuthenticated) return null;
  final nip98 = ref.watch(nip98AuthServiceProvider);
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  final client = ShortLinkClient(
    client: httpClient,
    enabled: true,
    authorize: (endpoint, body) async {
      if (!auth.canPublishNostrWritesNow) return null;
      return (await nip98.createAuthToken(
        url: endpoint,
        method: HttpMethod.post,
        payload: body,
      ))?.authorizationHeader;
    },
  );
  ref.onDispose(() {
    client.close();
    httpClient.close();
  });
  return client;
});
