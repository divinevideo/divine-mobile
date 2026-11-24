// ABOUTME: Shares REST profile answers across signer-free and signing handles.
// ABOUTME: Replaces the session cache when Funnelcake's environment changes.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:profile_repository/profile_repository.dart';

/// Read coordination must not depend on which profile handle fetched the data.
///
/// Leaves [ProfileApiCache]'s `batchWindow` at its default (`Duration.zero`)
/// until Funnelcake's `POST /api/users/bulk` populates
/// `engagement.archived_loops` (currently only `GET /api/users/<pubkey>` sets
/// it). Routing single lookups through `/api/users/bulk` would otherwise cache
/// Divine-only view totals for classic Vine creators whose seed rows are not
/// preloaded (notably on web, where `SeedDataPreload` is skipped).
final profileApiCacheProvider = Provider<ProfileApiCache>((ref) {
  final cache = ProfileApiCache(
    client: ref.watch(funnelcakeApiClientProvider),
  );
  ref.onDispose(cache.dispose);
  return cache;
});
