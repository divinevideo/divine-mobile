// ABOUTME: GoRouter configuration with ShellRoute for per-tab state preservation
// ABOUTME: URL is source of truth, bottom nav bound to routes

import 'package:firebase_analytics/firebase_analytics.dart';
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
import 'package:openvine/screens/followers_screen.dart';
import 'package:openvine/screens/following_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor_screen.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/services/video_stop_navigator_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Navigator keys for per-tab state preservation
final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _exploreGridKey = GlobalKey<NavigatorState>(debugLabel: 'explore-grid');
final _exploreFeedKey = GlobalKey<NavigatorState>(debugLabel: 'explore-feed');
final _notificationsKey = GlobalKey<NavigatorState>(debugLabel: 'notifications');
final _searchEmptyKey = GlobalKey<NavigatorState>(debugLabel: 'search-empty');
final _searchGridKey = GlobalKey<NavigatorState>(debugLabel: 'search-grid');
final _searchFeedKey = GlobalKey<NavigatorState>(debugLabel: 'search-feed');
final _hashtagGridKey = GlobalKey<NavigatorState>(debugLabel: 'hashtag-grid');
final _hashtagFeedKey = GlobalKey<NavigatorState>(debugLabel: 'hashtag-feed');

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

// Track if we've done initial navigation to avoid redirect loops
bool _hasNavigated = false;

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home/0',
    observers: [
      VideoStopNavigatorObserver(),
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) async {
      final location = state.matchedLocation;

      // Check TOS acceptance first (before any other routes except /welcome)
      if (!location.startsWith('/welcome')) {
        final prefs = await SharedPreferences.getInstance();
        final hasAcceptedTerms = prefs.getBool('age_verified_16_plus') ?? false;

        if (!hasAcceptedTerms) {
          return '/welcome';
        }
      }

      // Only redirect to explore on very first navigation if user follows nobody
      // After that, let users navigate to home freely (they'll see a message to follow people)
      if (!_hasNavigated && location.startsWith('/home')) {
        _hasNavigated = true;

        try {
          final socialState = ref.read(socialProvider);

          // Only redirect if social state is initialized and user follows 0 people
          if (socialState.isInitialized && socialState.followingPubkeys.isEmpty) {
            return '/explore';
          }
        } catch (e) {
          // If social provider isn't ready, let the route proceed
        }
      }

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
                  settings: const RouteSettings(name: 'HomeScreen'),
                ),
              ),
            ),
          ),

          // EXPLORE tab - grid mode (no index)
          GoRoute(
            path: '/explore',
            name: 'explore',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _exploreGridKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ExploreScreen(),
                  settings: const RouteSettings(name: 'ExploreScreen'),
                ),
              ),
            ),
          ),

          // EXPLORE tab - feed mode (with video index)
          GoRoute(
            path: '/explore/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _exploreFeedKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const ExploreScreen(),
                  settings: const RouteSettings(name: 'ExploreScreen'),
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
                  settings: const RouteSettings(name: 'NotificationsScreen'),
                ),
              ),
            ),
          ),

          // PROFILE tab subtree - grid mode (no index)
          GoRoute(
            path: '/profile/:npub',
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

          // PROFILE tab subtree - feed mode (with video index)
          // Note: /profile/me/:index is handled by ProfileScreenRouter detecting "me" and redirecting
          GoRoute(
            path: '/profile/:npub/:index',
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
              key: st.pageKey,
              child: Navigator(
                key: _searchEmptyKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'SearchScreen'),
                ),
              ),
            ),
          ),

          // SEARCH route - with term, grid mode
          GoRoute(
            path: '/search/:searchTerm',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _searchGridKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'SearchScreen'),
                ),
              ),
            ),
          ),

          // SEARCH route - with term and index, feed mode
          GoRoute(
            path: '/search/:searchTerm/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _searchFeedKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const SearchScreenPure(embedded: true),
                  settings: const RouteSettings(name: 'SearchScreen'),
                ),
              ),
            ),
          ),

          // HASHTAG route - grid mode (no index)
          GoRoute(
            path: '/hashtag/:tag',
            name: 'hashtag',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _hashtagGridKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HashtagScreenRouter(),
                  settings: const RouteSettings(name: 'HashtagScreen'),
                ),
              ),
            ),
          ),

          // HASHTAG route - feed mode (with video index)
          GoRoute(
            path: '/hashtag/:tag/:index',
            pageBuilder: (ctx, st) => NoTransitionPage(
              key: st.pageKey,
              child: Navigator(
                key: _hashtagFeedKey,
                onGenerateRoute: (r) => MaterialPageRoute(
                  builder: (_) => const HashtagScreenRouter(),
                  settings: const RouteSettings(name: 'HashtagScreen'),
                ),
              ),
            ),
          ),
        ],
      ),

      // Non-tab routes outside the shell (camera/settings/editor/video/welcome)
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (_, __) => const UniversalCameraScreenPure(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (_, __) => const ProfileSetupScreen(isNewUser: false),
      ),
      GoRoute(
        path: '/setup-profile',
        name: 'setup-profile',
        builder: (_, __) => const ProfileSetupScreen(isNewUser: true),
      ),
      // Followers screen
      GoRoute(
        path: '/followers/:pubkey',
        name: 'followers',
        builder: (ctx, st) {
          final pubkey = st.pathParameters['pubkey'];
          final displayName = st.extra as String? ?? 'User';
          if (pubkey == null || pubkey.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(
                child: Text('Invalid user ID'),
              ),
            );
          }
          return FollowersScreen(pubkey: pubkey, displayName: displayName);
        },
      ),
      // Following screen
      GoRoute(
        path: '/following/:pubkey',
        name: 'following',
        builder: (ctx, st) {
          final pubkey = st.pathParameters['pubkey'];
          final displayName = st.extra as String? ?? 'User';
          if (pubkey == null || pubkey.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(
                child: Text('Invalid user ID'),
              ),
            );
          }
          return FollowingScreen(pubkey: pubkey, displayName: displayName);
        },
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
