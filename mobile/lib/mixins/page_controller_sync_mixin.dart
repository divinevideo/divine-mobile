// ABOUTME: Reusable PageController sync mixin for URL-driven router screens
// ABOUTME: Eliminates code duplication across home, explore, and profile router screens

import 'package:flutter/material.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Mixin that provides PageController synchronization logic for router screens.
///
/// This eliminates duplication of the PageController sync pattern across
/// home_screen_router.dart, explore_screen_router.dart, and profile_screen_router.dart.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen> with PageControllerSyncMixin {
///   PageController? _controller;
///   int? _lastUrlIndex;
///
///   @override
///   Widget build(BuildContext context) {
///     // ... get urlIndex from route context ...
///
///     if (shouldSync(urlIndex: urlIndex, lastUrlIndex: _lastUrlIndex, controller: _controller, targetIndex: urlIndex)) {
///       _lastUrlIndex = urlIndex;
///       syncPageController(controller: _controller!, targetIndex: urlIndex, itemCount: videos.length);
///     }
///   }
/// }
/// ```
mixin PageControllerSyncMixin {
  /// Override this in your State class (automatically provided by State)
  bool get mounted;
  int? _lastSyncedIndex;

  /// The last index that was synced to the PageController
  int? get lastSyncedIndex => _lastSyncedIndex;

  /// Determines if the PageController should sync based on URL state and current position.
  ///
  /// Returns true if:
  /// - URL index changed from last known value, OR
  /// - Controller position doesn't match target index
  ///
  /// This handles two cases:
  /// 1. User navigates via URL (back/forward button, deeplink)
  /// 2. Provider rebuilds with new data causing position mismatch
  bool shouldSync({
    required int urlIndex,
    required int? lastUrlIndex,
    PageController? controller,
    int? targetIndex,
  }) {
    // Case 1: URL changed
    if (urlIndex != lastUrlIndex) {
      return true;
    }

    // Case 2: Controller position doesn't match target
    if (controller != null && targetIndex != null && controller.hasClients) {
      final currentPage = controller.page?.round() ?? 0;
      if (currentPage != targetIndex) {
        return true;
      }
    }

    return false;
  }

  /// Syncs PageController to target index using post-frame callback.
  ///
  /// - Clamps targetIndex to valid range [0, itemCount-1]
  /// - Checks if controller has clients
  /// - Uses post-frame callback to avoid build-time mutations
  /// - Only jumps if current page doesn't match target
  /// - Tracks lastSyncedIndex for debugging
  void syncPageController({
    required PageController controller,
    required int targetIndex,
    required int itemCount,
  }) {
    if (!controller.hasClients) {
      Log.debug(
        '⚠️  PageController sync skipped - no clients',
        name: 'PageControllerSyncMixin',
        category: LogCategory.video,
      );
      return;
    }

    final safeIndex = targetIndex.clamp(0, itemCount - 1);
    _lastSyncedIndex = safeIndex; // Track optimistically

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;

      final currentPage = controller.page?.round() ?? 0;
      if (currentPage != safeIndex) {
        Log.debug(
          '🔄 Syncing PageController: current=$currentPage -> target=$safeIndex',
          name: 'PageControllerSyncMixin',
          category: LogCategory.video,
        );
        controller.jumpToPage(safeIndex);
      }
    });
  }
}
