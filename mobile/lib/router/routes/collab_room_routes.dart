// ABOUTME: Collaborative room routes: the room, and handing in your part
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:dm_repository/dm_repository.dart' show isValidCollabRoomId;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/collab_room/view/collab_room_page.dart';
import 'package:openvine/collab_room/view/collab_room_part_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';

part 'collab_room_routes.g.dart';

List<RouteBase> collabRoomRoutes() => $appRoutes;

/// A collaborative room, opened from the Together camera mode or an invite.
@TypedGoRoute<CollabRoomRouteData>(
  path: RoutePaths.collabRoom,
  name: CollabRoomPage.routeName,
)
class CollabRoomRouteData extends GoRouteData with $CollabRoomRouteData {
  const CollabRoomRouteData({required this.roomId});

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  final String roomId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (!isValidCollabRoomId(roomId)) {
      return RouteErrorScreen(message: context.l10n.collabRoomMissing);
    }
    return CollabRoomPage(roomId: roomId);
  }
}

/// Reviewing and handing in your edited part, reached from the editor's Done.
@TypedGoRoute<CollabRoomPartRouteData>(
  path: RoutePaths.collabRoomPart,
  name: CollabRoomPartPage.routeName,
)
class CollabRoomPartRouteData extends GoRouteData
    with $CollabRoomPartRouteData {
  const CollabRoomPartRouteData({required this.roomId});

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  final String roomId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (!isValidCollabRoomId(roomId)) {
      return RouteErrorScreen(message: context.l10n.collabRoomMissing);
    }
    return CollabRoomPartPage(roomId: roomId);
  }
}
