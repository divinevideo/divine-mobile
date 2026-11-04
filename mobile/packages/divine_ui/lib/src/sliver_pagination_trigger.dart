import 'package:divine_ui/src/loading/divine_progress_indicator.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A composable sliver that triggers pagination when scrolled into view.
///
/// Placed after a list's slivers, it calls [onLoadMore] once the list is
/// scrolled near its end: when this sliver comes within the viewport's cache
/// extent. A list too short to fill the viewport asks right away.
///
/// When [isLoadingMore] is true, a loading indicator shows instead. When
/// [hasMore] is false, the sliver collapses to nothing.
///
/// [onLoadMore] runs after the frame in which the end came into reach, never
/// during build or layout, so it may change state directly.
///
/// **Asking again:** it asks each time the end comes back into reach, and
/// each time a load finishes ([isLoadingMore] going back to false) while the
/// end is still in reach — as it is when a page added too little to push it
/// out. The consumer must guard against duplicate requests (e.g.
/// `if (isLoadingMore) return` + `sequential()` transformer).
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

  /// Called when the user scrolled near the end.
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
    // A viewport builds all its slivers, whatever their position, so the
    // sentinel goes in only once layout shows the end within reach.
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverToBoxAdapter(
        child: constraints.remainingCacheExtent > 0
            ? _LoadMoreSentinel(onLoadMore: onLoadMore)
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Calls `onLoadMore` after the frame it is mounted in.
///
/// [SliverPaginationTrigger] mounts it only while the end of the list is in
/// reach, and mounts it anew after each load.
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
    // Mounted during layout, when the caller may not change state yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
