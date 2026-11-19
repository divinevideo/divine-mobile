// ABOUTME: Always provides anonymous native short-link creation and owns its HTTP lifecycle.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/services/short_link_client.dart';

/// Whether this build runs in a browser. Overridden in tests, where [kIsWeb]
/// is always false.
final shortLinkIsWebProvider = Provider<bool>((ref) => kIsWeb);

/// The external-share shortener, or null on Flutter web, where the gateway
/// does not allow the deployment origin. Callers then share the full URL.
final shortLinkClientProvider = Provider<ShortLinkClient?>((ref) {
  if (ref.watch(shortLinkIsWebProvider)) {
    return null;
  }
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  final client = ShortLinkClient(client: httpClient);
  ref.onDispose(() {
    client.close();
    httpClient.close();
  });
  return client;
});
