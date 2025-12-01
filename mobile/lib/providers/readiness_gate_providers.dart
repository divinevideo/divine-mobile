// ABOUTME: Gate providers for coordinating app readiness state
// ABOUTME: Ensures subscriptions only start when Nostr is initialized and app is foregrounded

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'readiness_gate_providers.g.dart';

/// State notifier that tracks Nostr service initialization status
/// Provides reactive updates when initialization state changes
@Riverpod(keepAlive: true)
class NostrInitialization extends _$NostrInitialization {
  @override
  bool build() {
    // Start as uninitialized
    return false;
  }

  /// Call this when NostrService completes initialization
  void markInitialized() {
    state = true; // Triggers reactive update
  }
}

/// Provider that checks if Nostr service is fully initialized and ready for subscriptions
@Riverpod(keepAlive: true)
bool nostrReady(Ref ref) {
  return ref.watch(nostrInitializationProvider);
}

/// Provider that combines all readiness gates to determine if app is ready for subscriptions
@riverpod
bool appReady(Ref ref) {
  final isForegrounded = ref.watch(appForegroundProvider);
  final isNostrReady = ref.watch(nostrReadyProvider);

  final ready = isForegrounded && isNostrReady;

  // Debug logging to track gate state changes
  Log.debug(
    '[GATE] 🚦 appReady: $ready (foreground: $isForegrounded, nostr: $isNostrReady)',
    name: 'ReadinessGates',
    category: LogCategory.system,
  );

  // App is ready when both foreground and Nostr are ready
  return ready;
}

/// Provider that checks if the discovery/explore tab is currently active
@riverpod
bool isDiscoveryTabActive(Ref ref) {
  final context = ref.watch(pageContextProvider);
  final isActive =
      context.whenOrNull(
        data: (ctx) {
          final active = ctx.type == RouteType.explore;
          Log.debug(
            '[GATE] 🎯 isDiscoveryTabActive: $active (route: ${ctx.type}, hasVideoIndex: ${ctx.videoIndex != null})',
            name: 'ReadinessGates',
            category: LogCategory.system,
          );
          return active;
        },
      ) ??
      false;

  if (!isActive) {
    Log.debug(
      '[GATE] 🎯 isDiscoveryTabActive: false (context state: ${context.runtimeType})',
      name: 'ReadinessGates',
      category: LogCategory.system,
    );
  }

  return isActive;
}
