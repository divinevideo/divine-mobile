// ABOUTME: List routes (NIP-51 curated video lists + people lists), feature-flag gated
// ABOUTME: Split from app_router.dart (#4508)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/view/add_people_to_list_screen.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:unified_logger/unified_logger.dart';

List<RouteBase> listsRoutes(Ref ref) {
  return [
    // BOOKMARKS route (NIP-51 kind 10003 global bookmarks)
    // Outside shell so the screen's own AppBar is shown without the shell one
    GoRoute(
      path: SavedVideosScreen.path,
      name: SavedVideosScreen.routeName,
      builder: (_, _) => const SavedVideosScreen(),
    ),
    // CURATED LIST route (NIP-51 kind 30005 video lists)
    // Outside shell so the screen's own AppBar is shown without the shell AppBar
    GoRoute(
      path: CuratedListFeedScreen.path,
      name: CuratedListFeedScreen.routeName,
      builder: (ctx, st) {
        final listId = st.pathParameters['listId'];
        if (listId == null || listId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidListId);
        }
        // Extra data contains listName, videoIds, authorPubkey
        final extra = extraAs<CuratedListRouteExtra>(st.extra);
        return CuratedListFeedScreen(
          listId: listId,
          listName: extra?.listName ?? ctx.l10n.routeDefaultListName,
          videoIds: extra?.videoIds,
          authorPubkey: extra?.authorPubkey,
        );
      },
    ),

    // CURATED LIST BY AUTHOR route — web-canonical /list/:pubkey/:listId
    // universal-link shape. Resolves the list from relays by author + d-tag,
    // so deep links work for lists that are not in local storage.
    GoRoute(
      path: CuratedListByAuthorScreen.path,
      name: CuratedListByAuthorScreen.routeName,
      builder: (ctx, st) {
        final pubkey = st.pathParameters['pubkey'];
        final listId = st.pathParameters['listId'];
        if (pubkey == null ||
            pubkey.isEmpty ||
            listId == null ||
            listId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidListId);
        }
        return CuratedListByAuthorScreen(authorPubkey: pubkey, listId: listId);
      },
    ),

    // DISCOVER LISTS is absorbed by the Explore Lists tab: the tab IS the
    // discovery surface now. The old URL keeps working for bookmarks and
    // shared links by landing on that tab.
    GoRoute(
      path: RoutePaths.discoverLists,
      redirect: (context, state) => ExploreScreen.pathForTab('lists'),
    ),

    // CREATE PEOPLE LIST route. Must come before /people-lists/:listId so
    // the literal `new` segment is not captured as a list id.
    // `initialPubkey` query param lets callers (e.g., the share-video
    // "Add to list" sheet) seed the new list with a target person in
    // the same submit so the URL remains reloadable.
    // Gated on FeatureFlag.curatedLists — a deep link here with the flag
    // off would open a feature the user turned off, so redirect home.
    GoRoute(
      path: CreatePeopleListPage.path,
      name: CreatePeopleListPage.routeName,
      redirect: (context, state) => _peopleListsRedirectIfDisabled(ref, state),
      builder: (context, state) => CreatePeopleListPage(
        initialPubkey: state.uri.queryParameters['initialPubkey'],
      ),
    ),

    // PEOPLE LIST MEMBERS route (NIP-51 kind 30000 people lists).
    // Addressed by list id so the screen can select the current list
    // from PeopleListsBloc and react to repository updates without a
    // route rebuild. Outside shell — the screen owns its own AppBar.
    // Gated on FeatureFlag.curatedLists (see CreatePeopleListPage route).
    GoRoute(
      path: UserListPeopleScreen.path,
      name: UserListPeopleScreen.routeName,
      redirect: (context, state) => _peopleListsRedirectIfDisabled(ref, state),
      builder: (context, state) {
        final listId = state.pathParameters['listId'];
        if (listId == null || listId.isEmpty) {
          return RouteErrorScreen(
            message: context.l10n.routeInvalidListId,
            title: context.l10n.peopleListsRouteTitle,
            showBackButton: true,
          );
        }
        return UserListPeopleScreen(
          listId: listId,
          ownerPubkey: state.uri.queryParameters['owner'],
        );
      },
    ),

    // ADD PEOPLE TO LIST route. Full-screen picker that batches add
    // requests for the list identified by [listId].
    // Gated on FeatureFlag.curatedLists (see CreatePeopleListPage route).
    GoRoute(
      path: AddPeopleToListScreen.path,
      name: AddPeopleToListScreen.routeName,
      redirect: (context, state) => _peopleListsRedirectIfDisabled(ref, state),
      builder: (context, state) {
        final listId = state.pathParameters['listId'];
        if (listId == null || listId.isEmpty) {
          return RouteErrorScreen(
            message: context.l10n.routeInvalidListId,
            title: context.l10n.peopleListsAddPeopleTitle,
            showBackButton: true,
          );
        }
        return AddPeopleToListScreen(listId: listId);
      },
    ),
  ];
}

/// Redirects deep links for people-lists routes to the home feed when the
/// [FeatureFlag.curatedLists] feature flag is off.
///
/// Without this guard a deep link / push / saved URL would open the
/// people-lists screens even though the user turned the feature off.
/// Returns `null` (no redirect) when the flag is on.
String? _peopleListsRedirectIfDisabled(Ref ref, GoRouterState state) {
  final enabled = ref.read(isFeatureEnabledProvider(FeatureFlag.curatedLists));
  if (enabled) return null;
  Log.info(
    'Router redirect: ${state.matchedLocation} — '
    'FeatureFlag.curatedLists is off, redirecting to home',
    name: 'AppRouter',
    category: LogCategory.ui,
  );
  return VideoFeedPage.pathForIndex(0);
}
