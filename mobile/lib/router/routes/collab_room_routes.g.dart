// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collab_room_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $collabRoomRouteData,
  $collabRoomPartRouteData,
];

RouteBase get $collabRoomRouteData => GoRouteData.$route(
  path: '/collab-room/:roomId',
  name: 'collab-room',
  hasOverriddenOnExit: false,
  parentNavigatorKey: CollabRoomRouteData.$parentNavigatorKey,
  factory: $CollabRoomRouteData._fromState,
);

mixin $CollabRoomRouteData on GoRouteData {
  static CollabRoomRouteData _fromState(GoRouterState state) =>
      CollabRoomRouteData(roomId: state.pathParameters['roomId']!);

  CollabRoomRouteData get _self => this as CollabRoomRouteData;

  @override
  String get location => GoRouteData.$location(
    '/collab-room/${Uri.encodeComponent(_self.roomId)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $collabRoomPartRouteData => GoRouteData.$route(
  path: '/collab-room/:roomId/part',
  name: 'collab-room-part',
  hasOverriddenOnExit: false,
  parentNavigatorKey: CollabRoomPartRouteData.$parentNavigatorKey,
  factory: $CollabRoomPartRouteData._fromState,
);

mixin $CollabRoomPartRouteData on GoRouteData {
  static CollabRoomPartRouteData _fromState(GoRouterState state) =>
      CollabRoomPartRouteData(roomId: state.pathParameters['roomId']!);

  CollabRoomPartRouteData get _self => this as CollabRoomPartRouteData;

  @override
  String get location => GoRouteData.$location(
    '/collab-room/${Uri.encodeComponent(_self.roomId)}/part',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
