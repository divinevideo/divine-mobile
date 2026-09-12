// ABOUTME: Sticky, pinned profile tab bar with scroll-driven top inset.
// ABOUTME: Extracted from profile_grid.dart to keep that file focused (#4339).

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/profile/profile_cache_load_indicator.dart';

/// How one profile tab is presented.
///
/// [semanticId] is the stable, snake_case test anchor; [label] is the
/// localized name. Keeping them as separate fields is what stops the anchor
/// from being announced as the accessible name (#6951).
typedef ProfileTab = ({String semanticId, String label, DivineIconName icon});

/// Sticky tab bar rendering the profile's [tabs] (5 on other profiles, 6 on
/// the own profile, which also shows Lists). See `profileTabKinds`.
class ProfileTabBar extends StatefulWidget {
  const ProfileTabBar({
    required this.controller,
    required this.scrollController,
    required this.tabs,
    required this.headerKey,
    required this.isRefreshing,
    super.key,
  });

  final TabController controller;
  final ScrollController? scrollController;

  /// One entry per tab.
  ///
  /// [ProfileTab.semanticId] is the stable test anchor and [ProfileTab.label]
  /// is the localized name a screen reader reads. They are separate fields on
  /// purpose: the bar is icon-only, so collapsing them means the anchor
  /// becomes the accessible name (#6951).
  final List<ProfileTab> tabs;
  final GlobalKey headerKey;

  /// Whether to show the sticky cache-revalidation bar under the tabs.
  final bool isRefreshing;

  @override
  State<ProfileTabBar> createState() => _ProfileTabBarState();
}

class _ProfileTabBarState extends State<ProfileTabBar> {
  double _tabBarTopInset = 0;

  /// Cached safe area top. Refreshed in [didChangeDependencies] when the
  /// surrounding [MediaQuery] changes (rotation, multi-window resize).
  double _safeAreaTop = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeAreaTop = MediaQuery.paddingOf(context).top;
  }

  @override
  void didUpdateWidget(ProfileTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    // Re-measure every tick so that async header updates (profile data
    // arriving, _profileVisible flip) are always reflected in the trigger
    // threshold. findRenderObject().size is O(1) on a mounted widget.
    final headerHeight =
        (widget.headerKey.currentContext?.findRenderObject() as RenderBox?)
            ?.size
            .height;
    if (headerHeight == null || headerHeight == 0) return;

    final triggerScroll = headerHeight - _safeAreaTop;
    final offset = widget.scrollController?.offset ?? 0;

    // Outside the trigger zone the inset is either 0 (above) or the full
    // safe-area top (below). Skip the clamp/setState work when nothing
    // would change.
    if (offset <= triggerScroll) {
      if (_tabBarTopInset != 0) setState(() => _tabBarTopInset = 0);
      return;
    }
    if (offset >= triggerScroll + _safeAreaTop) {
      if (_tabBarTopInset != _safeAreaTop) {
        setState(() => _tabBarTopInset = _safeAreaTop);
      }
      return;
    }

    final newInset = offset - triggerScroll;
    if (newInset != _tabBarTopInset) {
      setState(() => _tabBarTopInset = newInset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        topInset: _tabBarTopInset,
        isRefreshing: widget.isRefreshing,
        TabBar(
          controller: widget.controller,
          indicatorColor: VineTheme.tabIndicatorGreen,
          indicatorWeight: 4,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: VineTheme.transparent,
          // Material's default 16 leaves each icon only `width / tabs - 32`
          // to grow into. On the own profile (6 tabs) that is 28dp at 360dp
          // wide — exactly the unscaled size, so the icons never actually
          // scale. 8 fits the 1.3x cap down to a 320dp screen.
          //
          // Tabs are equal-width and the icon is centred, so neither icon
          // position nor indicator extent moves. Icon *size* at 1.0x is
          // unchanged from 360dp up, but below that the default padding was
          // already squashing the glyph — 21.3dp at 320dp — and it now
          // renders at its nominal 28dp.
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            for (var i = 0; i < widget.tabs.length; i++)
              _ProfileTab(
                semanticId: widget.tabs[i].semanticId,
                label: widget.tabs[i].label,
                icon: widget.tabs[i].icon,
                isSelected: widget.controller.index == i,
              ),
          ],
        ),
      ),
    );
  }
}

/// Single icon tab for [ProfileTabBar].
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.semanticId,
    required this.label,
    required this.icon,
    required this.isSelected,
  });

  final String semanticId;
  final String label;
  final DivineIconName icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Tab(
      icon: Semantics(
        // The tab renders no visible text, so this label is the only
        // accessible name. Material merges it with its own "Tab N of M",
        // giving "Tab 3 of 6, Liked".
        identifier: semanticId,
        label: label,
        child: DivineIcon(
          icon: icon,
          size: 28,
          color: isSelected
              ? context.vineColors.primaryText
              : context.vineColors.onSurfaceMuted,
        ),
      ),
    );
  }
}

/// Sticky tab bar delegate.
///
/// Adds a [topInset] (typically the safe area top) so that when pinned
/// behind the status bar, the tab bar icons sit below the status bar
/// rather than behind it.
///
/// Also renders the 2px semantic `outlineMuted` divider at the bottom of
/// the header. The rounded top corners of the tab content viewport are
/// applied separately, on the body's [ColoredBox] wrapper.
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(
    this._tabBar, {
    required this.topInset,
    required this.isRefreshing,
  });

  final PreferredSizeWidget _tabBar;
  final double topInset;

  /// Whether to overlay the sticky cache-revalidation bar at the bottom edge.
  final bool isRefreshing;

  /// Height of the divider line painted between the tab bar and the tile
  /// grid.
  static const double _dividerHeight = 2;

  double get _totalExtent =>
      _tabBar.preferredSize.height + topInset + _dividerHeight;

  @override
  double get minExtent => _totalExtent;

  @override
  double get maxExtent => _totalExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => DecoratedBox(
    decoration: BoxDecoration(color: context.vineColors.surface),
    child: Stack(
      clipBehavior: .none,
      children: [
        Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: _tabBar,
            ),
            ColoredBox(
              color: context.vineColors.outlineMuted,
              child: const SizedBox(
                height: _dividerHeight,
                width: double.infinity,
              ),
            ),
          ],
        ),
        // Overlaid on the bottom edge so showing/hiding it never changes the
        // header extent — the grid below does not jump.
        if (isRefreshing)
          const Positioned(
            left: 0,
            right: 0,
            bottom: -4,
            child: ProfileCacheLoadIndicator(),
          ),
      ],
    ),
  );

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) =>
      topInset != oldDelegate.topInset ||
      _tabBar != oldDelegate._tabBar ||
      isRefreshing != oldDelegate.isRefreshing;
}
