// ABOUTME: Composes anonymous short-link creation with the feature flag and HTTP lifecycle.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/services/short_link_client.dart';

final shortLinkClientProvider = Provider<ShortLinkClient?>((ref) {
  if (!ref.watch(isFeatureEnabledProvider(FeatureFlag.shortLinksSharing))) {
    return null;
  }
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  final client = ShortLinkClient(client: httpClient, enabled: true);
  ref.onDispose(() {
    client.close();
    httpClient.close();
  });
  return client;
});
