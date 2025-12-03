// ABOUTME: Controller providers for router-driven HomeScreen
// ABOUTME: Pagination and refresh logic separated from UI lifecycle

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Pagination controller for home feed
/// Triggers loadMore() when user scrolls near end of feed
final homePaginationControllerProvider = Provider((ref) {
  return HomePaginationController(ref);
});

class HomePaginationController {
  HomePaginationController(this.ref);

  final Ref ref;
  DateTime? _lastLoadMoreCall;
  static const _loadMoreThrottle = Duration(seconds: 5);

  /// Maybe load more content if:
  /// - Not already loading
  /// - Rate limit passed
  /// - Has more content available
  Future<void> maybeLoadMore() async {
    final now = DateTime.now();
    if (_lastLoadMoreCall != null &&
        now.difference(_lastLoadMoreCall!) < _loadMoreThrottle) {
      Log.debug(
        'HomePagination: Skipping loadMore - rate limited',
        name: 'HomePaginationController',
        category: LogCategory.video,
      );
      return;
    }

    final asyncState = ref.read(homeFeedProvider);
    final state = asyncState.hasValue ? asyncState.value : null;

    if (state == null) return;
    if (state.isLoadingMore) return;
    if (!state.hasMoreContent) return;

    _lastLoadMoreCall = now;

    Log.info(
      'HomePagination: Loading more home feed videos...',
      name: 'HomePaginationController',
      category: LogCategory.video,
    );

    await ref.read(homeFeedProvider.notifier).loadMore();
  }
}

/// Refresh controller for home feed
/// Handles pull-to-refresh logic
final homeRefreshControllerProvider = Provider((ref) {
  return HomeRefreshController(ref);
});

class HomeRefreshController {
  HomeRefreshController(this.ref);

  final Ref ref;

  /// Refresh the home feed
  Future<void> refresh() async {
    Log.info(
      'HomeRefresh: Refreshing home feed...',
      name: 'HomeRefreshController',
      category: LogCategory.video,
    );

    await ref.read(homeFeedProvider.notifier).refresh();
  }
}
