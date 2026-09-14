// ABOUTME: The single back-navigation decision shared by every back affordance
// ABOUTME: Pure - takes a route context and navigator facts, returns a BackAction

import 'package:openvine/router/navigation/back_action.dart';
import 'package:openvine/router/navigation/tab_identity.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';

/// Full-screen flows that are always pushed, so backing out always pops.
const Set<RouteType> _pushedEditorFlows = {
  RouteType.videoRecorder,
  RouteType.videoEditor,
  RouteType.videoMetadata,
  RouteType.videoEdit,
  RouteType.subtitleEdit,
};

/// Decides what a back gesture should do from [context].
///
/// [canPop] is the navigator's own answer, [previousTab] the tab below the
/// current one in tab history, [lastIndexForPreviousTab] that tab's remembered
/// feed position, and [currentUserNpub] the signed-in npub (null when signed
/// out, which is why the profile tab needs a fallback).
///
/// The order is deliberate: a route's own in-page "go back to the grid" step
/// runs *before* popping, so backing out of a hashtag video returns to that
/// hashtag's grid instead of leaving the hashtag entirely.
BackAction resolveBackAction({
  required RouteContext? context,
  required bool canPop,
  int? previousTab,
  int? lastIndexForPreviousTab,
  String? currentUserNpub,
}) {
  if (context == null) return const BackUnhandled();

  if (context.isCampaignFollowing) {
    // The campaign landing renders the home branch's Following feed and is a
    // cold-start destination, not a push from another screen. Reporting the
    // press unhandled would close the app on Android (#3337), so back goes to
    // the normal home feed.
    return canPop ? const BackPop() : BackGoTo(RoutePaths.videoFeedForIndex(0));
  }

  if (_pushedEditorFlows.contains(context.type)) {
    // These are always pushed, so popping is the normal answer. Reaching one
    // with nothing beneath it takes a cold entry the deep-link parser cannot
    // produce, but reporting the press unhandled there would close the app on
    // Android — the failure this policy exists to prevent — so fall back to
    // home instead. (The previous code popped unconditionally and threw
    // GoError('There is nothing to pop').)
    return canPop ? const BackPop() : BackGoTo(RoutePaths.videoFeedForIndex(0));
  }

  if (context.type == RouteType.categoryGallery) {
    return canPop ? const BackPop() : const BackGoTo(RoutePaths.explore);
  }

  if (context.type == RouteType.hashtag && !_isAboveBaseState(context)) {
    // A hashtag grid is pushed from Explore, so popping returns the user
    // wherever they came from rather than assuming it was the Explore grid.
    return canPop ? const BackPop() : const BackGoTo(RoutePaths.explore);
  }

  if (_isAboveBaseState(context)) {
    return BackGoTo(_baseLocationFor(context));
  }

  if (canPop) return const BackPop();

  if (previousTab != null) {
    return BackGoTo(
      _tabLocation(
        previousTab,
        lastIndex: lastIndexForPreviousTab,
        currentUserNpub: currentUserNpub,
      ),
      consumesTabHistory: true,
    );
  }

  final currentTab = tabIndexFromRouteType(context.type);
  if (currentTab != null && currentTab != 0) {
    return BackGoTo(RoutePaths.videoFeedForIndex(0));
  }

  return const BackUnhandled();
}

/// Whether [context] shows a video feed above its route's own base state.
///
/// Home and notifications base out at index 0; explore, profile and hashtag
/// base out at a grid that carries no index at all. Treating index 0 as
/// "above base" for the latter three is what used to strand the user, and
/// treating any index as above base for the former two would loop.
bool _isAboveBaseState(RouteContext context) => switch (context.type) {
  RouteType.home || RouteType.notifications =>
    context.videoIndex != null && context.videoIndex != 0,
  RouteType.explore ||
  RouteType.profile ||
  RouteType.hashtag => context.videoIndex != null,
  _ => false,
};

/// The grid/base location for the route [context] is currently in feed mode on.
String _baseLocationFor(RouteContext context) {
  switch (context.type) {
    case RouteType.home:
      return RoutePaths.videoFeedForIndex(0);
    case RouteType.notifications:
      return RoutePaths.notificationsForIndex(0);
    case RouteType.explore:
      return RoutePaths.explore;
    case RouteType.profile:
      return RoutePaths.profileForNpub(context.npub ?? 'me');
    case RouteType.hashtag:
      final tag = context.hashtag;
      return tag == null || tag.isEmpty
          ? RoutePaths.explore
          : RoutePaths.hashtagForTag(tag);
    default:
      return RoutePaths.explore;
  }
}

/// Where tab [tab] resumes, at its remembered position when it has one.
String _tabLocation(int tab, {int? lastIndex, String? currentUserNpub}) =>
    switch (tab) {
      0 => RoutePaths.videoFeedForIndex(lastIndex ?? 0),
      1 => RoutePaths.exploreForIndex(lastIndex),
      // Tab 2 is the inbox branch. It resumes a notification feed only when
      // the user actually opened one; otherwise its home is the inbox.
      2 =>
        lastIndex != null
            ? RoutePaths.notificationsForIndex(lastIndex)
            : RoutePaths.inbox,
      // Signed out there is no profile to return to, so fall back to home
      // rather than doing nothing at all.
      3 =>
        currentUserNpub != null
            ? RoutePaths.profileForNpub(currentUserNpub)
            : RoutePaths.videoFeedForIndex(0),
      _ => RoutePaths.videoFeedForIndex(0),
    };
