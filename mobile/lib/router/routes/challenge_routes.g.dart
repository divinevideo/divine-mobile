// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$challengesRouteData, $challengeRouteData];

RouteBase get $challengesRouteData => GoRouteData.$route(
  path: '/challenges',
  hasOverriddenOnExit: false,
  factory: $ChallengesRouteData._fromState,
);

mixin $ChallengesRouteData on GoRouteData {
  static ChallengesRouteData _fromState(GoRouterState state) =>
      const ChallengesRouteData();

  @override
  String get location => GoRouteData.$location('/challenges');

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

RouteBase get $challengeRouteData => GoRouteData.$route(
  path: '/challenges/:naddr',
  hasOverriddenOnExit: false,
  factory: $ChallengeRouteData._fromState,
);

mixin $ChallengeRouteData on GoRouteData {
  static ChallengeRouteData _fromState(GoRouterState state) =>
      ChallengeRouteData(naddr: state.pathParameters['naddr']!);

  ChallengeRouteData get _self => this as ChallengeRouteData;

  @override
  String get location =>
      GoRouteData.$location('/challenges/${Uri.encodeComponent(_self.naddr)}');

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
