// ABOUTME: Tracks last video index for each tab to preserve scroll position
// ABOUTME: Automatically updated when URL changes, used when switching tabs

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';

/// Tracks the last video index for each route type
/// This preserves scroll position when switching between tabs
class LastTabPosition extends Notifier<Map<RouteType, int>> {
  @override
  Map<RouteType, int> build() {
    // Watch page context changes to auto-update last position
    ref.listen(pageContextProvider, (prev, next) {
      final ctx = next.asData?.value;
      if (ctx == null) return;

      // Only track video-based routes
      if (ctx.type == RouteType.camera || ctx.type == RouteType.settings)
        return;

      final index = ctx.videoIndex ?? 0;
      if (state[ctx.type] != index) {
        state = {...state, ctx.type: index};
      }
    });

    // Default to index 0 for tabs that always have an index (home, profile)
    // For tabs with grid/feed modes (explore, search, hashtag), start with no index (grid mode)
    return {
      RouteType.home: 0,
      RouteType.profile: 0,
      // explore, search, hashtag not included - will default to null (grid mode)
    };
  }

  /// Get last position for a route type
  /// For routes with grid/feed modes (explore, search, hashtag): defaults to null (grid mode)
  /// For routes that always have an index (home, notifications, profile): defaults to 0
  int? getPosition(RouteType type) {
    // For routes that have grid/feed modes, return null for grid mode by default
    if (type == RouteType.explore ||
        type == RouteType.search ||
        type == RouteType.hashtag) {
      return state[type]; // Returns null if not set, indicating grid mode
    }
    // For routes that always have an index (home, notifications, profile), default to 0
    return state[type] ?? 0;
  }
}

final lastTabPositionProvider =
    NotifierProvider<LastTabPosition, Map<RouteType, int>>(() {
      return LastTabPosition();
    });
