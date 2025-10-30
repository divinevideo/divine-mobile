// ABOUTME: GoRouter configuration with ShellRoute for per-tab state preservation
// ABOUTME: URL is source of truth, bottom nav bound to routes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/router/app_shell.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor_screen.dart';
import 'package:openvine/services/video_stop_navigator_observer.dart';

// Navigator keys for per-tab state preservation
// One key per logical screen (not per route variant)
final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _exploreKey = GlobalKey<NavigatorState>(debugLabel: 'explore');
final _notificationsKey = GlobalKey<NavigatorState>(debugLabel: 'notifications');
final _searchKey = GlobalKey<NavigatorState>(debugLabel: 'search');
final _hashtagKey = GlobalKey<NavigatorState>(debugLabel: 'hashtag');

/// Maps URL location to bottom nav tab index
/// Returns -1 for non-tab routes (like search) to hide bottom nav
int tabIndexFromLocation(String loc) {
  final uri = Uri.parse(loc);
  final first = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  switch (first) {
    case 'home':
      return 0;
    case 'explore':
      return 1;
    case 'hashtag':
      return 1; // Hashtag keeps explore tab active
    case 'notifications':
      return 2;
    case 'profile':
      return 3;
    case 'search':
      return -1; // Search has AppBar but no bottom nav
    default:
      return 0; // fallback to home
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home/0',
    observers: [VideoStopNavigatorObserver()],
    redirect: (context, state) {
      // Redirect to explore if user follows nobody
      final location = state.matchedLocation;

      // Only redirect if navigating to home
      if (location.startsWith('/home')) {
        // Read social provider to check following count
        // Note: We use a try-catch in case the provider isn't ready yet
        try {
          final socialState = ref.read(socialProvider);

          // Only redirect if social state is initialized and user follows 0 people
          if (socialState.isInitialized && socialState.followingPubkeys.isEmpty) {
            return '/explore';
          }
        } catch (e) {
          // If social provider isn't ready, let the route proceed
          // (home screen will show loading or empty state)
        }
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Shell keeps tab navigators alive
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.toString();
          final current = tabIndexFromLocation(location);
          return AppShell(
            currentIndex: current,
            child: child,
          );
        },
        routes: [
          // HOME tab subtree
          GoRoute(
            path: '/home/:index',
            name: 'home',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _homeKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HomeScreenRouter(),
                  settings: const RouteSettings(name: 'home-root'),
                ),
              ),
            ),
          ),

          // EXPLORE tab - grid mode (no index)
          GoRoute(
            path: '/explore',
            name: 'explore',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: const ValueKey('explore-page'),
              child: Navigator(
                key: _exploreKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ExploreScreen(),
                  settings: const RouteSettings(name: 'explore-root'),
                ),
              ),
            ),
          ),

          // EXPLORE tab - feed mode (with video index)
          GoRoute(
            path: '/explore/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: const ValueKey('explore-page'),
              child: Navigator(
                key: _exploreKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ExploreScreen(),
                  settings: const RouteSettings(name: 'explore-root'),
                ),
              ),
            ),
          ),

          // NOTIFICATIONS tab subtree
          GoRoute(
            path: '/notifications/:index',
            name: 'notifications',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _notificationsKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                  settings: const RouteSettings(name: 'notifications-root'),
                ),
              ),
            ),
          ),

          // PROFILE tab subtree
          // Note: /profile/me/:index is handled by ProfileScreenRouter detecting "me" and redirecting
          GoRoute(
            path: '/profile/:npub/:index',
            name: 'profile',
            pageBuilder: (ctx, st) {
              // ProfileScreenRouter gets npub from pageContext (router-driven)
              // Use MaterialPage for swipe-back gesture support
              return MaterialPage(
                key: st.pageKey,
                child: const ProfileScreenRouter(),
              );
            },
          ),

          // SEARCH route - empty search
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: const ValueKey('search-page'),
              child: Navigator(
                key: _searchKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'search-root'),
                ),
              ),
            ),
          ),

          // SEARCH route - with term, grid mode
          GoRoute(
            path: '/search/:searchTerm',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: const ValueKey('search-page'),
              child: Navigator(
                key: _searchKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'search-root'),
                ),
              ),
            ),
          ),

          // SEARCH route - with term and index, feed mode
          GoRoute(
            path: '/search/:searchTerm/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: const ValueKey('search-page'),
              child: Navigator(
                key: _searchKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'search-root'),
                ),
              ),
            ),
          ),

          // HASHTAG route - grid mode (no index)
          GoRoute(
            path: '/hashtag/:tag',
            name: 'hashtag',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: const ValueKey('hashtag-page'),
              child: Navigator(
                key: _hashtagKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HashtagScreenRouter(),
                  settings: const RouteSettings(name: 'hashtag-root'),
                ),
              ),
            ),
          ),

          // HASHTAG route - feed mode (with video index)
          GoRoute(
            path: '/hashtag/:tag/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: const ValueKey('hashtag-page'),
              child: Navigator(
                key: _hashtagKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HashtagScreenRouter(),
                  settings: const RouteSettings(name: 'hashtag-root'),
                ),
              ),
            ),
          ),
        ],
      ),

      // Non-tab routes outside the shell (camera/settings/editor/video)
      GoRoute(
        path: '/camera',
        builder: (_, __) => const UniversalCameraScreenPure(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      // Video detail route (for deep links)
      GoRoute(
        path: '/video/:id',
        name: 'video',
        builder: (ctx, st) {
          final videoId = st.pathParameters['id'];
          if (videoId == null || videoId.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(
                child: Text('Invalid video ID'),
              ),
            );
          }
          return VideoDetailScreen(videoId: videoId);
        },
      ),
      // Video editor route (requires video passed via extra)
      GoRoute(
        path: '/edit-video',
        name: 'edit-video',
        builder: (ctx, st) {
          final video = st.extra as VideoEvent?;
          if (video == null) {
            // If no video provided, show error screen
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(
                child: Text('No video selected for editing'),
              ),
            );
          }
          return VideoEditorScreen(video: video);
        },
      ),
    ],
  );
});
