// ABOUTME: Riverpod provider for the local OG Viner positive cache.
// ABOUTME: Keeps badge reads local-only and avoids per-user server lookups.

import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/og_viner_cache_service.dart';

/// The OG Viner set for the environment the app points at, so a badge learned
/// against one environment's funnelcake never shows in another.
final ogVinerCacheServiceProvider = ChangeNotifierProvider<OgVinerCacheService>(
  (ref) {
    final storageKey = ogVinerPubkeysCacheKeyFor(
      ref.watch(currentEnvironmentProvider).environment,
    );
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      return OgVinerCacheService(prefs: prefs, storageKey: storageKey);
    } on ProviderException catch (e) {
      if (e.exception is UnimplementedError) {
        return OgVinerCacheService();
      }
      rethrow;
    }
  },
);
