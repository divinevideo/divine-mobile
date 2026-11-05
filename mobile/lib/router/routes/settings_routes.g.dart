// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$badgeVideosRouteData];

RouteBase get $badgeVideosRouteData => GoRouteData.$route(
  path: '/badges/b/:naddr/videos',
  name: 'badgeVideos',
  hasOverriddenOnExit: false,
  factory: $BadgeVideosRouteData._fromState,
);

mixin $BadgeVideosRouteData on GoRouteData {
  static BadgeVideosRouteData _fromState(GoRouterState state) =>
      BadgeVideosRouteData(
        naddr: state.pathParameters['naddr']!,
        $extra: state.extra as Object?,
      );

  BadgeVideosRouteData get _self => this as BadgeVideosRouteData;

  @override
  String get location => GoRouteData.$location(
    '/badges/b/${Uri.encodeComponent(_self.naddr)}/videos',
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}
