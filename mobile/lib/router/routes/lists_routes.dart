// ABOUTME: List routes (NIP-51 curated video lists + people lists), feature-flag gated
// ABOUTME: Split from app_router.dart (#4508)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/view/add_people_to_list_screen.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/features/people_lists/view/edit_people_list_page.dart';
import 'package:openvine/features/people_lists/view/people_list_members_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/utils/people_list_owner.dart';
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
          discoveredList: extra?.list,
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
        return CuratedListByAuthorScreen(
          authorPubkey: pubkey,
          listId: listId,
          discoveredList: extraAs<CuratedListRouteExtra>(st.extra)?.list,
        );
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
    // unqualified `new` remains creation; owner-qualified `new` opens a list.
    // `initialPubkey` query param lets callers (e.g., the share-video
    // "Add to list" sheet) seed the new list with a target person in
    // the same submit so the URL remains reloadable.
    // Gated on FeatureFlag.curatedLists — a deep link here with the flag
    // off would open a feature the user turned off, so redirect home.
    GoRoute(
      path: CreatePeopleListPage.path,
      name: CreatePeopleListPage.routeName,
      redirect: (context, state) => _peopleListsRedirectIfDisabled(ref, state),
      builder: (context, state) {
        // `new` is a creation action only when no author was supplied. It is
        // also a valid NIP-51 d-tag, so an addressed list keeps its identity.
        if (state.uri.queryParametersAll.containsKey('owner')) {
          return _buildPeopleList(context, state, listId: 'new');
        }
        return CreatePeopleListPage(
          initialPubkey: state.uri.queryParameters['initialPubkey'],
        );
      },
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
        return _buildPeopleList(
          context,
          state,
          listId: state.pathParameters['listId'],
        );
      },
    ),

    // PEOPLE LIST ROSTER route: every member, behind the list's "View all".
    // Resolves the list the same two ways the members route does, so a
    // discovered list's `owner` query param carries over.
    // Gated on FeatureFlag.curatedLists (see CreatePeopleListPage route).
    GoRoute(
      path: PeopleListMembersScreen.path,
      name: PeopleListMembersScreen.routeName,
      redirect: (context, state) => _peopleListsRedirectIfDisabled(ref, state),
      builder: (context, state) {
        return _buildPeopleList(
          context,
          state,
          listId: state.pathParameters['listId'],
          roster: true,
        );
      },
    ),

    GoRoute(
      path: EditPeopleListPage.path,
      name: EditPeopleListPage.routeName,
      redirect: (context, state) => _peopleListsRedirectIfDisabled(ref, state),
      builder: (context, state) {
        final listId = state.pathParameters['listId'];
        final owner = _peopleListOwner(state.uri);
        final currentOwner = ref.read(authServiceProvider).currentPublicKeyHex;
        if (listId == null ||
            listId.isEmpty ||
            currentOwner == null ||
            currentOwner.isEmpty ||
            owner.invalid ||
            (owner.pubkey != null &&
                owner.pubkey != currentOwner.toLowerCase())) {
          return RouteErrorScreen(
            message: context.l10n.routeInvalidListId,
            title: context.l10n.listEditTitle,
            showBackButton: true,
          );
        }
        return EditPeopleListPage(listId: listId);
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
        final owner = _peopleListOwner(state.uri);
        final currentOwner = ref.read(authServiceProvider).currentPublicKeyHex;
        if (listId == null ||
            listId.isEmpty ||
            owner.invalid ||
            (owner.pubkey != null &&
                owner.pubkey != currentOwner?.toLowerCase())) {
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

/// Absent author selects the legacy own-list route. An explicit invalid or
/// ambiguous author must never silently select a same-ID list from that cache.
({String? pubkey, bool invalid}) _peopleListOwner(Uri uri) {
  final owners = uri.queryParametersAll['owner'];
  if (owners == null) return (pubkey: null, invalid: false);
  if (owners.length != 1) return (pubkey: null, invalid: true);
  final normalized = normalizePeopleListOwner(owners.single);
  if (normalized == null) {
    return (pubkey: null, invalid: true);
  }
  return (pubkey: normalized, invalid: false);
}

Widget _buildPeopleList(
  BuildContext context,
  GoRouterState state, {
  required String? listId,
  bool roster = false,
}) {
  final owner = _peopleListOwner(state.uri);
  if (listId == null || listId.isEmpty || owner.invalid) {
    return RouteErrorScreen(
      message: context.l10n.routeInvalidListId,
      title: context.l10n.peopleListsRouteTitle,
      showBackButton: true,
    );
  }
  if (roster) {
    return PeopleListMembersScreen(listId: listId, ownerPubkey: owner.pubkey);
  }
  return UserListPeopleScreen(listId: listId, ownerPubkey: owner.pubkey);
}
