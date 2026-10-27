// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'short_link_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$shortLinkRouteData];

RouteBase get $shortLinkRouteData => GoRouteData.$route(
  path: '/l/:code',
  name: 'short-link',
  hasOverriddenOnExit: false,
  factory: $ShortLinkRouteData._fromState,
);

mixin $ShortLinkRouteData on GoRouteData {
  static ShortLinkRouteData _fromState(GoRouterState state) =>
      ShortLinkRouteData(code: state.pathParameters['code']!);

  ShortLinkRouteData get _self => this as ShortLinkRouteData;

  @override
  String get location =>
      GoRouteData.$location('/l/${Uri.encodeComponent(_self.code)}');

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
