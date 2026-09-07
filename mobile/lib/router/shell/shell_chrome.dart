// ABOUTME: Renders the shell app bar and bottom nav around the branch content
// ABOUTME: Takes decided values so it can be pumped without the shell's wiring

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';
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
      body: Column(
        children: [
          Expanded(child: child),
          const UpdateBanner(),
        ],
      ),
      // PointerInterceptor ensures the bottom nav receives taps on web even
      // when HTML platform views (video elements) overlap the area.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EnvironmentIndicatorLine(),
          PointerInterceptor(
            intercepting: kIsWeb,
            child: VineBottomNav(currentIndex: currentIndex),
          ),
        ],
      ),
    );
  }
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
