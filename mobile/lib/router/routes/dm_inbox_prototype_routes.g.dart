// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dm_inbox_prototype_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$dmInboxPrototypeRouteData];

RouteBase get $dmInboxPrototypeRouteData => GoRouteData.$route(
  path: '/developer-options/dm-inbox-tabs',
  name: 'dm-inbox-tabs-prototype',
  hasOverriddenOnExit: false,
  factory: $DmInboxPrototypeRouteData._fromState,
);

mixin $DmInboxPrototypeRouteData on GoRouteData {
  static DmInboxPrototypeRouteData _fromState(GoRouterState state) =>
      const DmInboxPrototypeRouteData();

  @override
  String get location =>
      GoRouteData.$location('/developer-options/dm-inbox-tabs');

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
