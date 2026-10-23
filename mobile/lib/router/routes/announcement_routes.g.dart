// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$announcementDetailRouteData];

RouteBase get $announcementDetailRouteData => GoRouteData.$route(
  path: '/announcements/:id',
  name: 'announcement-detail',
  hasOverriddenOnExit: false,
  factory: $AnnouncementDetailRouteData._fromState,
);

mixin $AnnouncementDetailRouteData on GoRouteData {
  static AnnouncementDetailRouteData _fromState(GoRouterState state) =>
      AnnouncementDetailRouteData(id: state.pathParameters['id']!);

  AnnouncementDetailRouteData get _self => this as AnnouncementDetailRouteData;

  @override
  String get location =>
      GoRouteData.$location('/announcements/${Uri.encodeComponent(_self.id)}');

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
