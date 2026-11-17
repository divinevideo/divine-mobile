// ABOUTME: Shares REST profile answers across signer-free and signing handles.
// ABOUTME: Replaces the session cache when Funnelcake's environment changes.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:profile_repository/profile_repository.dart';

/// Read coordination must not depend on which profile handle fetched the data.
final profileApiCacheProvider = Provider<ProfileApiCache>((ref) {
  return ProfileApiCache(client: ref.watch(funnelcakeApiClientProvider));
});
