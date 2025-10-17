// ABOUTME: AppShell widget providing bottom navigation and dynamic header
// ABOUTME: Header title changes based on route with Pacifico font, includes camera button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'page_context_provider.dart';
import 'route_utils.dart';
import 'nav_extensions.dart';
import 'last_tab_position_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  final Widget child;
  final int currentIndex;

  String _titleFor(WidgetRef ref) {
    final ctx = ref.watch(pageContextProvider).asData?.value;
    switch (ctx?.type) {
      case RouteType.home:
        return 'diVine';
      case RouteType.explore:
        return 'Explore';
      case RouteType.notifications:
        return 'Notifications';
      case RouteType.hashtag:
        final raw = ctx?.hashtag ?? '';
        return raw.isEmpty ? '#—' : '#$raw';
      case RouteType.profile:
        final npub = ctx?.npub ?? '';
        return (npub == 'me') ? 'My Profile' : 'Profile';
      case RouteType.search:
        return 'Search';
      default:
        return '';
    }
  }

  /// Maps tab index to RouteType
  RouteType _routeTypeForTab(int index) {
    switch (index) {
      case 0:
        return RouteType.home;
      case 1:
        return RouteType.explore;
      case 2:
        return RouteType.notifications;
      case 3:
        return RouteType.profile;
      default:
        return RouteType.home;
    }
  }

  /// Handles tab tap - navigates to last known position in that tab
  void _handleTabTap(BuildContext context, WidgetRef ref, int tabIndex) {
    final routeType = _routeTypeForTab(tabIndex);
    final lastIndex = ref.read(lastTabPositionProvider.notifier).getPosition(routeType);

    // Navigate to last position in that tab
    switch (tabIndex) {
      case 0:
        context.goHome(lastIndex ?? 0);  // Home always has an index
        break;
      case 1:
        context.goExplore(lastIndex);  // Explore can be null (grid mode)
        break;
      case 2:
        context.goNotifications(lastIndex ?? 0);  // Notifications always has an index
        break;
      case 3:
        // For profile, use 'me' special identifier for current user
        // Navigation system will resolve 'me' to actual npub
        final ctx = ref.read(pageContextProvider).asData?.value;
        final identifier = ctx?.npub ?? 'me';
        context.goProfile(identifier, lastIndex ?? 0);  // Profile always has an index
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _titleFor(ref);

    // Watch page context to determine if back button should show
    final pageCtxAsync = ref.watch(pageContextProvider);
    final showBackButton = pageCtxAsync.maybeWhen(
      data: (ctx) => ctx.type == RouteType.hashtag || ctx.type == RouteType.search,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          title,
          // Pacifico font, with sane fallbacks if font isn't available yet.
          style: GoogleFonts.pacifico(
            textStyle: const TextStyle(
              fontSize: 24,
              letterSpacing: 0.2,
              // AppBar handles color via theme; no explicit color needed.
            ),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.goSearch(),
          ),
          IconButton(
            tooltip: 'Open camera',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => context.pushCamera(),
          ),
        ],
      ),
      body: child,
      // Bottom nav visible for all shell routes (search, tabs, etc.)
      // For search (currentIndex=-1), no tab is highlighted
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex.clamp(0, 3),
        onTap: (index) => _handleTabTap(context, ref, index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),          label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.explore),       label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.person),        label: 'Profile'),
        ],
      ),
    );
  }
}
