// ABOUTME: Always provides anonymous native short-link creation and owns its HTTP lifecycle.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/services/short_link_client.dart';

final shortLinkClientProvider = Provider<ShortLinkClient?>((ref) {
  // The gateway does not allow the Flutter web origin yet.
  if (kIsWeb) {
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
