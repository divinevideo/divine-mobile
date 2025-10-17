// ABOUTME: GoRouter configuration with ShellRoute for per-tab state preservation
// ABOUTME: URL is source of truth, bottom nav bound to routes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_shell.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/video_editor_screen.dart';
import 'package:openvine/utils/nostr_encoding.dart';

// Navigator keys for per-tab state preservation
final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _exploreGridKey = GlobalKey<NavigatorState>(debugLabel: 'explore-grid');
final _exploreFeedKey = GlobalKey<NavigatorState>(debugLabel: 'explore-feed');
final _notificationsKey = GlobalKey<NavigatorState>(debugLabel: 'notifications');
final _profileKey = GlobalKey<NavigatorState>(debugLabel: 'profile');
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
  // Get auth service to resolve "me" placeholder
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home/0',
    redirect: (context, state) {
      // Handle /profile/me/:index redirect
      final uri = state.uri;
      if (uri.pathSegments.length >= 2 &&
          uri.pathSegments[0] == 'profile' &&
          uri.pathSegments[1] == 'me') {
        // Check if user is authenticated
        if (!authService.isAuthenticated || authService.currentPublicKeyHex == null) {
          // Redirect to home if not authenticated
          return '/home/0';
        }

        // Convert current user's hex to npub and redirect
        final userNpub = NostrEncoding.encodePublicKey(authService.currentPublicKeyHex!);
        final index = uri.pathSegments.length >= 3 ? uri.pathSegments[2] : '0';
        return '/profile/$userNpub/$index';
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

          // EXPLORE tab subtree - grid mode (no index)
          GoRoute(
            path: '/explore',
            name: 'explore-grid',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _exploreGridKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ExploreScreen(),
                  settings: const RouteSettings(name: 'explore-root'),
                ),
              ),
            ),
          ),

          // EXPLORE tab subtree - feed mode (with index)
          GoRoute(
            path: '/explore/:index',
            name: 'explore-feed',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _exploreFeedKey,
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
          GoRoute(
            path: '/profile/:npub/:index',
            name: 'profile',
            pageBuilder: (ctx, st) {
              // ProfileScreenRouter gets npub from pageContext (router-driven)
              return NoTransitionPage(
                key: st.pageKey,
                child: Navigator(
                  key: _profileKey,
                  onGenerateRoute: (r) => MaterialPageRoute(
                    builder: (_) => const ProfileScreenRouter(),
                    settings: const RouteSettings(name: 'profile-root'),
                  ),
                ),
              );
            },
          ),

          // SEARCH route (inside shell for AppBar, but hides bottom nav)
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _searchKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'search-root'),
                ),
              ),
            ),
          ),

          // HASHTAG routes (inside shell to preserve explore tab and bottom nav)
          GoRoute(
            path: '/hashtag/:tag',
            name: 'hashtag-grid',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _hashtagKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HashtagScreenRouter(),
                  settings: const RouteSettings(name: 'hashtag-root'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/hashtag/:tag/:index',
            name: 'hashtag-feed',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
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

      // Non-tab routes outside the shell (camera/settings/editor)
      GoRoute(
        path: '/camera',
        builder: (_, __) => const UniversalCameraScreenPure(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
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
