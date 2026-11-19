// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'find_people_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$findPeopleRouteData];

RouteBase get $findPeopleRouteData => GoRouteData.$route(
  path: '/find-people',
  hasOverriddenOnExit: false,
  factory: $FindPeopleRouteData._fromState,
);

mixin $FindPeopleRouteData on GoRouteData {
  static FindPeopleRouteData _fromState(GoRouterState state) =>
      FindPeopleRouteData(source: state.uri.queryParameters['source']);

  FindPeopleRouteData get _self => this as FindPeopleRouteData;

  @override
  String get location => GoRouteData.$location(
    '/find-people',
    queryParams: {if (_self.source != null) 'source': _self.source},
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
