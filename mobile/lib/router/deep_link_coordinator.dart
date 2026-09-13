// ABOUTME: Handles deep links delivered while the app is already running
// ABOUTME: Extracted from a 414-line closure inside main.dart's build() (#3337)

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

/// Describes the router action to take when navigating to a video deep link.
@visibleForTesting
enum VideoDeepLinkNavAction {
  /// Navigate to the route, keeping the current route in the back stack.
  push,

  /// Replace the current route in-place (already on a video route).
  go,

  /// Re-trigger the current route with [autoOpenComments] set to `true`.
  ///
  /// Used when the user is already on the target video but a reply
  /// notification tap needs the comments sheet to open.
  goSameRouteWithComments,

  /// The router is already on the target route with nothing new to do.
  skip,
}

/// Determines which router action to take for a video deep-link navigation
/// given the current router location and the incoming [DeepLink].
///
/// Extracted for testability — the caller executes the action; this function
/// only decides what action that should be.
@visibleForTesting
VideoDeepLinkNavAction resolveVideoDeepLinkNavAction({
  required String currentLocation,
  required String targetPath,
  required bool autoOpenComments,
}) {
  if (currentLocation == targetPath) {
    // Already on the exact target route.
    if (autoOpenComments) {
      // Reply notification tap while the video is already visible — retrigger
      // the route with autoOpenComments so the comments sheet opens.
      return VideoDeepLinkNavAction.goSameRouteWithComments;
    }
    // Duplicate navigation with nothing new to do (e.g. getInitialLink +
    // uriLinkStream both fire for the same URL). Safe to skip.
    return VideoDeepLinkNavAction.skip;
  }
  if (currentLocation.startsWith('${VideoDetailScreen.basePath}/')) {
    // A different video is already showing — replace it in-place.
    return VideoDeepLinkNavAction.go;
  }
  // Coming from a non-video route — push so back returns home.
  return VideoDeepLinkNavAction.push;
}

/// Describes the router action for deep links that have no special route
/// extras.
@visibleForTesting
enum DeepLinkNavAction {
  /// Navigate to the route, keeping the current route in the back stack.
  push,

  /// Replace the current route in-place (already on the same route family).
  go,

  /// The router is already on the target route with nothing new to do.
  skip,
}

/// Determines which router action to take for a non-video deep-link
/// navigation. The caller supplies the route-family predicate because each
/// surface has a different set of route shapes.
@visibleForTesting
DeepLinkNavAction resolveDeepLinkNavAction({
  required String currentLocation,
  required String targetPath,
  required bool Function(String location) isRouteFamilyLocation,
}) {
  if (currentLocation == targetPath) {
    // Already on the exact target route. Duplicate navigation with nothing new
    // to do (e.g. GoRouter's universal-link redirect already navigated here, or
    // getInitialLink + uriLinkStream both fire for the same URL). Safe to skip.
    return DeepLinkNavAction.skip;
  }
  if (isRouteFamilyLocation(currentLocation)) {
    return DeepLinkNavAction.go;
  }
  return DeepLinkNavAction.push;
}

/// Routes a deep link that arrives while the app is already running.
///
/// This is deliberately *not* the only path a deep link takes: `appRouterRedirect`
/// resolves the same URL through GoRouter, because Android can deliver a custom
/// scheme to the router before the app-links stream sees it. Both are idempotent
/// and both are required — the router side also carries the minor-account and
/// auth gates (#5195, #7146). Do not "de-duplicate" them.
class DeepLinkCoordinator {
  const DeepLinkCoordinator({
    required GoRouter router,
    required AuthService authService,
  }) : _router = router,
       _authService = authService;

  final GoRouter _router;
  final AuthService _authService;

  /// Handles one event from the deep-link stream.
  void handle(AsyncValue<DeepLink> next) {
    Log.info(
      '🔗 Deep link event received - AsyncValue state: ${next.runtimeType}',
      name: 'DeepLinkHandler',
      category: LogCategory.ui,
    );

    next.when(
      data: (deepLink) {
        Log.info(
          '🔗 Processing deep link: $deepLink',
          name: 'DeepLinkHandler',
          category: LogCategory.ui,
        );

        final router = _router;
        final currentLocation = router.routeInformationProvider.value.uri
            .toString();
        Log.info(
          '🔗 Current router location: '
          '${redactUriStringForLogs(currentLocation)}',
          name: 'DeepLinkHandler',
          category: LogCategory.ui,
        );

        switch (deepLink.type) {
          case DeepLinkType.video:
            if (deepLink.videoRef != null) {
              final targetPath = VideoDetailScreen.pathForId(
                deepLink.videoRef!,
              );
              Log.info(
                '📱 Navigating to video: $targetPath'
                '${deepLink.autoOpenComments ? " (open comments)" : ""}',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
              try {
                final routeExtra = deepLink.autoOpenComments
                    ? const VideoDetailRouteExtra(autoOpenComments: true)
                    : null;
                final action = resolveVideoDeepLinkNavAction(
                  currentLocation: currentLocation,
                  targetPath: targetPath,
                  autoOpenComments: deepLink.autoOpenComments,
                );
                switch (action) {
                  case VideoDeepLinkNavAction.skip:
                    break;
                  case VideoDeepLinkNavAction.goSameRouteWithComments:
                    // Already on the video — retrigger so the comments
                    // sheet opens in response to a reply notification tap.
                    router.go(targetPath, extra: routeExtra);
                  case VideoDeepLinkNavAction.go:
                    // When another shared video is opened while a shared
                    // video route is already visible, replace the current
                    // detail route instead of stacking it.
                    router.go(targetPath, extra: routeExtra);
                  case VideoDeepLinkNavAction.push:
                    // Keep the home route underneath the first shared video
                    // so back navigation returns to the main screen.
                    router.push(targetPath, extra: routeExtra);
                }
                Log.info(
                  '✅ Navigation completed to: $targetPath',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              } catch (e) {
                Log.error(
                  '❌ Navigation failed: $e',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            } else {
              Log.warning(
                '⚠️ Video deep link missing videoRef',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
            }
          case DeepLinkType.profile:
            if (deepLink.npub != null) {
              // Mirror universalLinkToRouterPath: no index → grid mode
              // (/profile/<npub>), explicit index → feed mode
              // (/profile/<npub>/<index>). The old `index ?? 0` form always
              // produced a feed-mode path, which disagreed with the
              // resolver's grid-mode redirect for index-less universal links
              // and caused a spurious second navigation.
              final index = deepLink.index;
              final targetPath = index != null
                  ? ProfileScreenRouter.pathForIndex(deepLink.npub!, index)
                  : ProfileScreenRouter.pathForNpub(deepLink.npub!);
              Log.info(
                '📱 Navigating to profile: $targetPath',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
              try {
                final action = resolveDeepLinkNavAction(
                  currentLocation: currentLocation,
                  targetPath: targetPath,
                  isRouteFamilyLocation: (location) =>
                      location.startsWith('${ProfileScreenRouter.path}/'),
                );
                switch (action) {
                  case DeepLinkNavAction.skip:
                    // GoRouter's universal-link redirect may have already
                    // navigated here; skip the duplicate navigation to avoid
                    // a second navigation frame on the same target.
                    break;
                  case DeepLinkNavAction.go:
                    // Another profile is already showing — replace it
                    // in-place instead of stacking it.
                    router.go(targetPath);
                  case DeepLinkNavAction.push:
                    // Keep the current route underneath so back returns to
                    // wherever the user was instead of wiping the stack.
                    router.push(targetPath);
                }
                Log.info(
                  '✅ Navigation completed to: $targetPath',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              } catch (e) {
                Log.error(
                  '❌ Navigation failed: $e',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            } else {
              Log.warning(
                '⚠️ Profile deep link missing npub',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
            }
          case DeepLinkType.hashtag:
            if (deepLink.hashtag != null) {
              final targetPath = HashtagScreenRouter.pathForTag(
                deepLink.hashtag!,
              );
              Log.info(
                '📱 Navigating to hashtag: $targetPath',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
              try {
                final action = resolveDeepLinkNavAction(
                  currentLocation: currentLocation,
                  targetPath: targetPath,
                  isRouteFamilyLocation: (location) =>
                      location.startsWith('${HashtagScreenRouter.basePath}/'),
                );
                switch (action) {
                  case DeepLinkNavAction.skip:
                    // GoRouter's universal-link redirect may have already
                    // navigated here; skip the duplicate navigation to avoid
                    // a second navigation frame on the same target.
                    break;
                  case DeepLinkNavAction.go:
                    // Another hashtag is already showing — replace it
                    // in-place instead of stacking it.
                    router.go(targetPath);
                  case DeepLinkNavAction.push:
                    // Keep the current route underneath so back returns to
                    // wherever the user was instead of wiping the stack.
                    router.push(targetPath);
                }
                Log.info(
                  '✅ Navigation completed to: $targetPath',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              } catch (e) {
                Log.error(
                  '❌ Navigation failed: $e',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            } else {
              Log.warning(
                '⚠️ Hashtag deep link missing hashtag',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
            }
          case DeepLinkType.search:
            if (deepLink.searchTerm != null) {
              final targetPath = SearchResultsPage.pathForQuery(
                deepLink.searchTerm!,
                requestFocusOnMount: false,
              );
              Log.info(
                '📱 Navigating to search: $targetPath',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
              try {
                final action = resolveDeepLinkNavAction(
                  currentLocation: currentLocation,
                  targetPath: targetPath,
                  isRouteFamilyLocation: (location) =>
                      location == SearchResultsPage.emptyPath ||
                      location.startsWith('${SearchResultsPage.pathPrefix}/') ||
                      location.startsWith('${SearchResultsPage.emptyPath}?'),
                );
                switch (action) {
                  case DeepLinkNavAction.skip:
                    // GoRouter's universal-link redirect may have already
                    // navigated here; skip the duplicate navigation to avoid
                    // a second navigation frame on the same target.
                    break;
                  case DeepLinkNavAction.go:
                    // Already on the search surface (empty search, another
                    // query, or ?focus=1) — replace it in-place instead of
                    // stacking search on top of search.
                    router.go(targetPath);
                  case DeepLinkNavAction.push:
                    // Keep the current route underneath so back returns to
                    // wherever the user was instead of wiping the stack.
                    router.push(targetPath);
                }
                Log.info(
                  '✅ Navigation completed to: $targetPath',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              } catch (e) {
                Log.error(
                  '❌ Navigation failed: $e',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            } else {
              Log.warning(
                '⚠️ Search deep link missing search term',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
            }
          case DeepLinkType.list:
            final listPubkey = deepLink.listPubkey;
            final listId = deepLink.listId;
            if (listId != null && listId.isNotEmpty) {
              final targetPath = listPubkey == null || listPubkey.isEmpty
                  ? CuratedListFeedScreen.pathForId(listId)
                  : CuratedListByAuthorScreen.pathFor(
                      pubkey: listPubkey,
                      listId: listId,
                    );
              Log.info(
                '📱 Navigating to list: $targetPath',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
              try {
                final action = resolveDeepLinkNavAction(
                  currentLocation: currentLocation,
                  targetPath: targetPath,
                  isRouteFamilyLocation: (location) =>
                      location.startsWith('${CuratedListFeedScreen.basePath}/'),
                );
                switch (action) {
                  case DeepLinkNavAction.skip:
                    // GoRouter's universal-link redirect may have already
                    // navigated here; skip the duplicate navigation to avoid
                    // a second navigation frame on the same target.
                    Log.info(
                      '⏭️ Already on $targetPath — skipping duplicate '
                      'list navigation',
                      name: 'DeepLinkHandler',
                      category: LogCategory.ui,
                    );
                  case DeepLinkNavAction.go:
                    // Another list is already showing — replace it
                    // in-place instead of stacking it.
                    router.go(targetPath);
                    Log.info(
                      '✅ Navigation completed to: $targetPath',
                      name: 'DeepLinkHandler',
                      category: LogCategory.ui,
                    );
                  case DeepLinkNavAction.push:
                    // Keep the current route underneath so back returns to
                    // wherever the user was instead of wiping the stack.
                    router.push(targetPath);
                    Log.info(
                      '✅ Navigation completed to: $targetPath',
                      name: 'DeepLinkHandler',
                      category: LogCategory.ui,
                    );
                }
              } catch (e) {
                Log.error(
                  '❌ Navigation failed: $e',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            } else {
              Log.warning(
                '⚠️ List deep link missing list id',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
            }
          case DeepLinkType.savedVideos:
            const targetPath = SavedVideosScreen.path;
            Log.info(
              '📱 Navigating to saved videos: $targetPath',
              name: 'DeepLinkHandler',
              category: LogCategory.ui,
            );
            try {
              final action = resolveDeepLinkNavAction(
                currentLocation: currentLocation,
                targetPath: targetPath,
                isRouteFamilyLocation: (location) => location == targetPath,
              );
              switch (action) {
                case DeepLinkNavAction.skip:
                case DeepLinkNavAction.go:
                  // Already on Saved Videos — GoRouter's custom-scheme
                  // redirect got there first. Nothing to do: this family is
                  // a single path, so `go` cannot mean "replace a sibling"
                  // the way it does for /profile/*.
                  break;
                case DeepLinkNavAction.push:
                  // Keep the current route underneath so back returns to
                  // wherever the user was instead of wiping the stack.
                  router.push(targetPath);
              }
              Log.info(
                '✅ Navigation completed to: $targetPath',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
            } catch (e) {
              Log.error(
                '❌ Saved videos navigation failed: $e',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
            }
          case DeepLinkType.signerCallback:
            Log.info(
              '📱 Signer callback - triggering relay reconnection',
              name: 'DeepLinkHandler',
              category: LogCategory.auth,
            );
            _authService.onSignerCallbackReceived(
              relayUrl: deepLink.signerCallbackRelay,
            );
          case DeepLinkType.unknown:
            Log.warning(
              '📱 Unknown deep link type',
              name: 'DeepLinkHandler',
              category: LogCategory.ui,
            );
        }
      },
      loading: () {
        Log.info(
          '🔗 Deep link loading...',
          name: 'DeepLinkHandler',
          category: LogCategory.ui,
        );
      },
      error: (error, stack) {
        Log.error(
          '🔗 Deep link error: $error',
          name: 'DeepLinkHandler',
          category: LogCategory.ui,
        );
      },
    );
  }
}
