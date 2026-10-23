// ABOUTME: List routes (NIP-51 curated video lists + people lists)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/utils/people_list_owner.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';

part 'lists_routes.g.dart';

/// Curated video lists (NIP-51 kind 30005) and people lists (kind 30000).
///
/// Every route sits outside the shell so each screen shows its own app bar.
/// Declaration order is match order: `/people-lists/new` is declared before
/// `/people-lists/:listId` so a literal `new` stays the creation action.
List<RouteBase> listsRoutes() => $appRoutes;

/// The viewer's bookmarks (NIP-51 kind 10003).
@TypedGoRoute<SavedVideosRouteData>(
  path: SavedVideosScreen.path,
  name: SavedVideosScreen.routeName,
)
class SavedVideosRouteData extends GoRouteData with $SavedVideosRouteData {
  const SavedVideosRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SavedVideosScreen();
}

/// A curated video list by id, the shape local and legacy links use.
@TypedGoRoute<CuratedListFeedRouteData>(
  path: CuratedListFeedScreen.path,
  name: CuratedListFeedScreen.routeName,
)
class CuratedListFeedRouteData extends GoRouteData
    with $CuratedListFeedRouteData {
  const CuratedListFeedRouteData({required this.listId, this.$extra});

  final String listId;

  /// A [CuratedListRouteExtra] hint (name, video ids, author, the discovered
  /// list), read through [extraAs]; absent after a deep link, when the videos
  /// resolve from the id and the title waits for the local list.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (listId.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidListId);
    }
    final extra = extraAs<CuratedListRouteExtra>($extra);
    return CuratedListFeedScreen(
      listId: listId,
      listName: extra?.listName ?? context.l10n.routeDefaultListName,
      videoIds: extra?.videoIds,
      authorPubkey: extra?.authorPubkey,
      discoveredList: extra?.list,
    );
  }
}

/// A curated video list at the web's address, `/list/:pubkey/:listId`,
/// resolved from relays by author and d-tag so a link to a list the device
/// has never stored still opens.
@TypedGoRoute<CuratedListByAuthorRouteData>(
  path: CuratedListByAuthorScreen.path,
  name: CuratedListByAuthorScreen.routeName,
)
class CuratedListByAuthorRouteData extends GoRouteData
    with $CuratedListByAuthorRouteData {
  const CuratedListByAuthorRouteData({
    required this.pubkey,
    required this.listId,
    this.$extra,
  });

  /// The author as hex in either case, an `npub1` or an `nprofile1`.
  final String pubkey;

  final String listId;

  /// A [CuratedListRouteExtra] hint whose discovered list warms the screen,
  /// read through [extraAs]; absent after a deep link.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    // Relays only accept a lowercase hex author, so an npub, an nprofile or
    // uppercase hex is resolved here and anything else is refused.
    final author = normalizePublicIdentifier(pubkey)?.hexPubkey;
    if (author == null || listId.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidListId);
    }
    return CuratedListByAuthorScreen(
      authorPubkey: author,
      listId: listId,
      discoveredList: extraAs<CuratedListRouteExtra>($extra)?.list,
    );
  }
}

/// The old Discover Lists address. The Explore Lists tab is the discovery
/// surface now, so bookmarks and shared links land there.
@TypedGoRoute<DiscoverListsRouteData>(path: RoutePaths.discoverLists)
class DiscoverListsRouteData extends GoRouteData with $DiscoverListsRouteData {
  const DiscoverListsRouteData();

  /// Always redirects, so [build] is never reached.
  @override
  String redirect(BuildContext context, GoRouterState state) =>
      ExploreScreen.pathForTab('lists');
}

/// Creates a people list.
///
/// `new` is also a valid NIP-51 d-tag, so with an `owner` query this address
/// is that author's list called `new`, and the builder opens it instead.
@TypedGoRoute<CreatePeopleListRouteData>(
  path: CreatePeopleListPage.path,
  name: CreatePeopleListPage.routeName,
)
class CreatePeopleListRouteData extends GoRouteData
    with $CreatePeopleListRouteData {
  const CreatePeopleListRouteData({
    @TypedQueryParameter(name: 'initialPubkey') this.initialPubkey,
  });

  /// A person to seed the new list with on submit, so a share sheet's
  /// "Add to list" is one reloadable URL.
  final String? initialPubkey;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (state.uri.queryParametersAll.containsKey('owner')) {
      return _buildPeopleList(context, state, listId: 'new');
    }
    return CreatePeopleListPage(initialPubkey: initialPubkey);
  }
}

/// A people list's members, selected from PeopleListsBloc by id so the screen
/// follows repository updates without a route rebuild.
@TypedGoRoute<PeopleListRouteData>(
  path: UserListPeopleScreen.path,
  name: UserListPeopleScreen.routeName,
)
class PeopleListRouteData extends GoRouteData with $PeopleListRouteData {
  const PeopleListRouteData({
    required this.listId,
    @TypedQueryParameter(name: 'owner') this.owner,
  });

  final String listId;

  /// The list author as lowercase hex, which resolves a list the viewer does
  /// not own from relays; absent, the route opens the viewer's own list. The
  /// builder reads it back from `state.uri`, where a repeated or malformed
  /// author is refused rather than falling back to an own list of the same id.
  final String? owner;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      _buildPeopleList(context, state, listId: listId);
}

/// Every member of a people list, behind the list's "View all".
@TypedGoRoute<PeopleListMembersRouteData>(
  path: PeopleListMembersScreen.path,
  name: PeopleListMembersScreen.routeName,
)
class PeopleListMembersRouteData extends GoRouteData
    with $PeopleListMembersRouteData {
  const PeopleListMembersRouteData({
    required this.listId,
    @TypedQueryParameter(name: 'owner') this.owner,
  });

  final String listId;

  /// See [PeopleListRouteData.owner].
  final String? owner;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      _buildPeopleList(context, state, listId: listId, roster: true);
}

/// The metadata editor for the viewer's own people list.
@TypedGoRoute<EditPeopleListRouteData>(
  path: EditPeopleListPage.path,
  name: EditPeopleListPage.routeName,
)
class EditPeopleListRouteData extends GoRouteData
    with $EditPeopleListRouteData {
  const EditPeopleListRouteData({
    required this.listId,
    @TypedQueryParameter(name: 'owner') this.owner,
  });

  final String listId;

  /// See [PeopleListRouteData.owner]. Only the signed-in account is accepted.
  final String? owner;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final author = _peopleListOwner(state.uri);
    final currentOwner = _currentPublicKeyHex(context);
    if (listId.isEmpty ||
        currentOwner == null ||
        currentOwner.isEmpty ||
        author.invalid ||
        (author.pubkey != null &&
            author.pubkey != currentOwner.toLowerCase())) {
      return RouteErrorScreen(
        message: context.l10n.routeInvalidListId,
        title: context.l10n.listEditTitle,
        showBackButton: true,
      );
    }
    return EditPeopleListPage(listId: listId);
  }
}

/// The full-screen picker that batches add requests for one of the viewer's
/// own people lists.
@TypedGoRoute<AddPeopleToListRouteData>(
  path: AddPeopleToListScreen.path,
  name: AddPeopleToListScreen.routeName,
)
class AddPeopleToListRouteData extends GoRouteData
    with $AddPeopleToListRouteData {
  const AddPeopleToListRouteData({
    required this.listId,
    @TypedQueryParameter(name: 'owner') this.owner,
  });

  final String listId;

  /// See [PeopleListRouteData.owner]. Only the signed-in account is accepted.
  final String? owner;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final author = _peopleListOwner(state.uri);
    final currentOwner = _currentPublicKeyHex(context);
    if (listId.isEmpty ||
        author.invalid ||
        (author.pubkey != null &&
            author.pubkey != currentOwner?.toLowerCase())) {
      return RouteErrorScreen(
        message: context.l10n.routeInvalidListId,
        title: context.l10n.peopleListsAddPeopleTitle,
        showBackButton: true,
      );
    }
    return AddPeopleToListScreen(listId: listId);
  }
}

/// The signed-in account, read through the widget tree: a typed route has no
/// `Ref`.
String? _currentPublicKeyHex(BuildContext context) => ProviderScope.containerOf(
  context,
  listen: false,
).read(authServiceProvider).currentPublicKeyHex;

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
  required String listId,
  bool roster = false,
}) {
  final owner = _peopleListOwner(state.uri);
  if (listId.isEmpty || owner.invalid) {
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
