// ABOUTME: Gate providers for coordinating app readiness state
// ABOUTME: Ensures subscriptions only start when the app is foregrounded

import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'readiness_gate_providers.g.dart';

/// Provider that combines all readiness gates to determine if app is ready for subscriptions
@riverpod
bool appReady(Ref ref) {
  final isForegrounded = ref.watch(appForegroundProvider);

  final ready = isForegrounded;

  // Debug logging to track gate state changes
  Log.debug(
    '[GATE] 🚦 appReady: $ready (foreground: $isForegrounded)',
    name: 'ReadinessGates',
    category: LogCategory.system,
  );

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
