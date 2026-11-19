// ABOUTME: Renders the shell app bar and tab navigation (bottom bar, or side
// ABOUTME: navigation in wide landscape) around the branch content;
// ABOUTME: takes decided values so it can be pumped without the shell's wiring

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/environment_indicator.dart';
import 'package:openvine/widgets/environment_indicator_line.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:unified_logger/unified_logger.dart';

/// App bar + bottom nav wrapped around the active [StatefulShellRoute] branch.
class ShellChrome extends StatelessWidget {
  const ShellChrome({
    required this.currentIndex,
    required this.title,
    required this.routeContext,
    required this.suppressAppBar,
    required this.showBackButton,
    required this.resizeToAvoidBottomInset,
    required this.onBackPressed,
    required this.child,
    super.key,
  });

  /// Active bottom-nav tab.
  final int currentIndex;

  /// Resolved app bar title; empty when the route renders its own header.
  final String title;

  /// Route the chrome is rendering for — decides whether the title is tappable.
  final RouteContext? routeContext;

  /// Whether the route renders a header of its own.
  final bool suppressAppBar;

  final bool showBackButton;

  /// False while a modal sits above the shell, so the feed is not re-laid-out
  /// on every keyboard frame — very laggy on older devices (#5758).
  final bool resizeToAvoidBottomInset;

  final VoidCallback onBackPressed;

  /// The branch navigator container.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = context.adaptiveLayout;
    // Where the system runs its status bar down a side of the window (the
    // iPhone Duo's outer display, and its inner one in landscape), that
    // column is chrome on every tab screen and the content ends at it. In
    // landscape (the Duo open sideways) the tabs move into it below the
    // status bar, as iOS moves its own tab bars there, and the content gets
    // the full height. In portrait (the outer display) the bottom bar stays,
    // its tabs under the content, and the column is filled in the bar's
    // color, so the two read as one frame the status bar sits in.
    final statusBarColumn = layout.statusBarColumn(
      MediaQuery.viewPaddingOf(context),
    );
    final navInColumn =
        statusBarColumn != null && layout.size.width > layout.size.height;
    // The width of the column where the tabs do not fill it.
    final columnFillWidth = navInColumn ? null : statusBarColumn?.width;
    final columnOnLeft = statusBarColumn != null && !statusBarColumn.onRight;
    final columnOnRight = statusBarColumn != null && statusBarColumn.onRight;
    // Other wide landscape windows (tablets) move the tabs into a rail along
    // the leading edge, so the feed keeps the height.
    final usesRail = !navInColumn && layout.isWideLandscape;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final navOnLeft = navInColumn
        ? !statusBarColumn.onRight
        : usesRail && !isRtl;
    final navOnRight = navInColumn
        ? statusBarColumn.onRight
        : usesRail && isRtl;
    final navAtBottom = !navOnLeft && !navOnRight;
    final navigation = PointerInterceptor(
      intercepting: kIsWeb,
      child: VineBottomNav(
        currentIndex: currentIndex,
        // `/following/new` renders inside the home branch, so Home reads
        // as active even though it is not the home feed. The nav needs
        // that distinction to give the tap an escape back to Home.
        isCampaignLanding: routeContext?.isCampaignFollowing ?? false,
        direction: navOnLeft || navOnRight ? Axis.vertical : Axis.horizontal,
        statusBarColumnWidth: navInColumn ? statusBarColumn.width : null,
      ),
    );
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: suppressAppBar
          ? null
          : DiVineAppBar(
              titleWidget: _ShellTitle(
                title: title,
                routeContext: routeContext,
              ),
              titleSuffix: const EnvironmentBadge(),
              showBackButton: showBackButton,
              onBackPressed: showBackButton ? onBackPressed : null,
            ),
      // Keep the branch container in the same slot regardless of tab so
      // switching tabs never reparents it (which would relayout all four
      // kept-alive branches). Keep update availability visible on every tab.
      // A side nav is inserted beside it, and the key keeps the branches when
      // a rotation or a fold adds, moves or removes it. Laid out left to right
      // so the nav lands on the physical side it belongs to.
      body: Row(
        textDirection: TextDirection.ltr,
        children: [
          if (navOnLeft)
            navigation
          else if (columnOnLeft && columnFillWidth != null)
            _StatusBarColumnFill(width: columnFillWidth),
          Expanded(
            key: const ValueKey('shell-branches'),
            // The status bar column is laid out beside the content, so the
            // content no longer keeps clear of that edge.
            child: _WithoutSideInsets(
              left: columnOnLeft,
              right: columnOnRight,
              child: Column(
                children: [
                  Expanded(child: child),
                  const UpdateBanner(),
                  if (!navAtBottom) const EnvironmentIndicatorLine(),
                ],
              ),
            ),
          ),
          if (navOnRight)
            navigation
          else if (columnOnRight && columnFillWidth != null)
            _StatusBarColumnFill(width: columnFillWidth),
        ],
      ),
      // PointerInterceptor ensures the bottom nav receives taps on web even
      // when HTML platform views (video elements) overlap the area.
      // Only a bottom bar takes the slot: the Scaffold drops the content's
      // bottom inset whenever the slot is filled, so with the nav at a side
      // the content would run under the home indicator.
      bottomNavigationBar: navAtBottom
          ? Column(
              mainAxisSize: MainAxisSize.min,
              // Beneath a status bar column the bar keeps its tabs clear of
              // it, under the content, and paints its color on beneath it.
              children: [const EnvironmentIndicatorLine(), navigation],
            )
          : null,
    );
  }
}

/// The status bar column on a tab screen whose tabs sit in the bottom bar:
/// filled in the bar's color, so it meets the bar beneath it, with nothing in
/// it but the status bar the system draws over it.
class _StatusBarColumnFill extends StatelessWidget {
  const _StatusBarColumnFill({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.vineColors.nav,
    child: SizedBox(width: width, height: double.infinity),
  );
}

/// Drops the [left] and [right] safe-area insets for [child].
///
/// Reads the insets in its own context, inside the [Scaffold] slot, which
/// already lacks the insets the app bar and the bottom bar keep clear of.
/// Read above the [Scaffold], they would come back: the content would pad
/// itself clear of a bottom bar it already sits above.
class _WithoutSideInsets extends StatelessWidget {
  const _WithoutSideInsets({
    required this.left,
    required this.right,
    required this.child,
  });

  final bool left;
  final bool right;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.removePadding(
    context: context,
    removeLeft: left,
    removeRight: right,
    child: child,
  );
}

/// The app bar title, tappable on Explore routes to return to the grid.
class _ShellTitle extends StatelessWidget {
  const _ShellTitle({required this.title, required this.routeContext});

  final String title;
  final RouteContext? routeContext;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: VineTheme.titleLargeFont(color: context.vineColors.primaryText),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (routeContext?.type != RouteType.explore) return titleWidget;

    return GestureDetector(
      onTap: () {
        Log.info(
          '👆 User tapped header title: $title',
          name: 'Navigation',
          category: LogCategory.ui,
        );
        // Drop any pushed routes (e.g. a curated list feed) before going back
        // to the explore grid.
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
        context.go(RoutePaths.explore);
      },
      child: titleWidget,
    );
  }
}
