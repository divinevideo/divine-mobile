import 'package:divine_ui/src/loading/divine_progress_indicator.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/material.dart';

/// A composable sliver that triggers pagination when scrolled into view.
///
/// Uses a sentinel pattern: a zero-height [StatefulWidget] whose `initState`
/// fires [onLoadMore]. Since slivers are only mounted when within the
/// viewport's cache extent, this naturally triggers at the right time.
///
/// When [isLoadingMore] is true, a loading indicator replaces the sentinel.
/// When [hasMore] is false, the sliver collapses to nothing.
///
/// **Re-mount safety:** If the user scrolls past the sentinel and back,
/// `initState` fires again on remount. This is intentional — the consuming
/// BLoC must guard against duplicate dispatches (e.g. `if (isLoadingMore)
/// return` + `sequential()` transformer).
///
/// **When to use:** Prefer this widget for pagination inside
/// [CustomScrollView] slivers. For widgets that own their own
/// [ScrollController], use `ScrollPaginationMixin` (from the app layer)
/// instead.
class SliverPaginationTrigger extends StatelessWidget {
  /// Creates a sliver pagination trigger.
  const SliverPaginationTrigger({
    required this.onLoadMore,
    required this.hasMore,
    required this.isLoadingMore,
    super.key,
  });

  /// Called when the sentinel is mounted — i.e. the user scrolled near the end.
  final VoidCallback onLoadMore;

  /// Whether more pages are available to load.
  final bool hasMore;

  /// Whether a page is currently being fetched.
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (isLoadingMore) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: DivineCircularProgressIndicator(
              color: VineTheme.primary,
              semanticsLabel: 'Loading more results',
            ),
          ),
        ),
      );
    }
    return SliverToBoxAdapter(child: _LoadMoreSentinel(onLoadMore: onLoadMore));
  }
}

/// Triggers `onLoadMore` in `initState`.
///
/// Because this widget lives inside a [SliverToBoxAdapter], it is only
/// mounted when the sliver enters the viewport's cache extent — so
/// [onLoadMore] fires at the right scroll position automatically.
class _LoadMoreSentinel extends StatefulWidget {
  const _LoadMoreSentinel({required this.onLoadMore});

  final VoidCallback onLoadMore;

  @override
  State<_LoadMoreSentinel> createState() => _LoadMoreSentinelState();
}

class _LoadMoreSentinelState extends State<_LoadMoreSentinel> {
  @override
  void initState() {
    super.initState();
    widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
