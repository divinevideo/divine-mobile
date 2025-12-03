// ABOUTME: Reusable pagination mixin with throttling for PageView widgets
// ABOUTME: Prevents duplicate loadMore() calls with configurable threshold and throttle

import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Mixin that provides pagination logic with throttling for scrollable lists
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with PaginationMixin {
///   PageView.builder(
///     onPageChanged: (index) {
///       checkForPagination(
///         currentIndex: index,
///         totalItems: videos.length,
///         onLoadMore: () => loadMoreVideos(),
///       );
///     },
///   );
/// }
/// ```
mixin PaginationMixin<T extends StatefulWidget> on State<T> {
  DateTime? _lastPaginationCall;

  /// Check if pagination should be triggered and call onLoadMore if appropriate
  ///
  /// - [currentIndex]: Current scroll position
  /// - [totalItems]: Total number of items in the list
  /// - [onLoadMore]: Callback to load more items
  /// - [threshold]: Number of items from the end to trigger (default: 3)
  /// - [throttleSeconds]: Minimum seconds between loadMore calls (default: 5)
  void checkForPagination({
    required int currentIndex,
    required int totalItems,
    required VoidCallback onLoadMore,
    int threshold = 3,
    int throttleSeconds = 5,
  }) {
    // Only trigger when within threshold of the end
    if (currentIndex < totalItems - threshold) {
      return;
    }

    // Rate limit pagination calls to prevent spam
    final now = DateTime.now();
    if (_lastPaginationCall != null &&
        now.difference(_lastPaginationCall!).inSeconds < throttleSeconds) {
      Log.debug(
        'Pagination: Skipping loadMore - too soon since last call '
        '(index=$currentIndex, total=$totalItems, threshold=$threshold)',
        name: 'PaginationMixin',
        category: LogCategory.video,
      );
      return;
    }

    _lastPaginationCall = now;

    Log.info(
      'Pagination: Triggering loadMore (index=$currentIndex, total=$totalItems, threshold=$threshold)',
      name: 'PaginationMixin',
      category: LogCategory.video,
    );

    onLoadMore();
  }

  /// Reset pagination throttle (useful after refresh or reset operations)
  void resetPagination() {
    _lastPaginationCall = null;
    Log.debug(
      'Pagination: Reset throttle',
      name: 'PaginationMixin',
      category: LogCategory.video,
    );
  }
}
