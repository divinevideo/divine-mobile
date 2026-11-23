// ABOUTME: Shares REST profile answers across signer-free and signing handles.
// ABOUTME: Replaces the session cache when Funnelcake's environment changes.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:profile_repository/profile_repository.dart';

/// How long a profile lookup waits for others to share its request: one frame
/// at 60 Hz, so the lookups a frame's widgets start go out together.
const profileLookupBatchWindow = Duration(milliseconds: 16);

/// Read coordination must not depend on which profile handle fetched the data.
final profileApiCacheProvider = Provider<ProfileApiCache>((ref) {
  final cache = ProfileApiCache(
    client: ref.watch(funnelcakeApiClientProvider),
    batchWindow: profileLookupBatchWindow,
  );
  ref.onDispose(cache.dispose);
  return cache;
});
