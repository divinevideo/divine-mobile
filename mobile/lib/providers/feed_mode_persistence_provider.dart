// ABOUTME: Injects device-owned Home preference coordination into account scopes.
// ABOUTME: The fallback supports a single container; DeviceScope shares production ownership.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/feed_mode_persistence.dart';

final feedModePersistenceRegistryProvider =
    Provider<FeedModePersistenceRegistry>((ref) {
      final registry = FeedModePersistenceRegistry(
        sharedPreferences: ref.watch(sharedPreferencesProvider),
      );
      ref.onDispose(registry.dispose);
      return registry;
    });
