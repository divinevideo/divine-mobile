// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $verifyRouteData,
  $editProfileRouteData,
  $setupProfileRouteData,
  $followersRouteData,
  $followingRouteData,
  $otherProfileRouteData,
];

RouteBase get $verifyRouteData => GoRouteData.$route(
  path: '/verify',
  name: 'verify',
  hasOverriddenOnExit: false,
  factory: $VerifyRouteData._fromState,
  routes: [
    GoRouteData.$route(
      path: 'connect/:platform',
      name: 'verify-connect',
      hasOverriddenOnExit: false,
      factory: $VerifyConnectRouteData._fromState,
    ),
  ],
);

mixin $VerifyRouteData on GoRouteData {
  static VerifyRouteData _fromState(GoRouterState state) =>
      const VerifyRouteData();

  @override
  String get location => GoRouteData.$location('/verify');

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

mixin $VerifyConnectRouteData on GoRouteData {
  static VerifyConnectRouteData _fromState(GoRouterState state) =>
      VerifyConnectRouteData(
        platform: state.pathParameters['platform']!,
        replacing: state.uri.queryParameters['replacing'],
      );

  VerifyConnectRouteData get _self => this as VerifyConnectRouteData;

  @override
  String get location => GoRouteData.$location(
    '/verify/connect/${Uri.encodeComponent(_self.platform)}',
    queryParams: {if (_self.replacing != null) 'replacing': _self.replacing},
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

RouteBase get $editProfileRouteData => GoRouteData.$route(
  path: '/edit-profile',
  name: 'edit-profile',
  hasOverriddenOnExit: false,
  factory: $EditProfileRouteData._fromState,
);

mixin $EditProfileRouteData on GoRouteData {
  static EditProfileRouteData _fromState(GoRouterState state) =>
      const EditProfileRouteData();

  @override
  String get location => GoRouteData.$location('/edit-profile');

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

RouteBase get $setupProfileRouteData => GoRouteData.$route(
  path: '/setup-profile',
  name: 'setup-profile',
  hasOverriddenOnExit: false,
  factory: $SetupProfileRouteData._fromState,
);

mixin $SetupProfileRouteData on GoRouteData {
  static SetupProfileRouteData _fromState(GoRouterState state) =>
      const SetupProfileRouteData();

  @override
  String get location => GoRouteData.$location('/setup-profile');

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

RouteBase get $followersRouteData => GoRouteData.$route(
  path: '/followers/:pubkey',
  name: 'followers',
  hasOverriddenOnExit: false,
  factory: $FollowersRouteData._fromState,
);

mixin $FollowersRouteData on GoRouteData {
  static FollowersRouteData _fromState(GoRouterState state) =>
      FollowersRouteData(
        pubkey: state.pathParameters['pubkey']!,
        $extra: state.extra as Object?,
      );

  FollowersRouteData get _self => this as FollowersRouteData;

  @override
  String get location =>
      GoRouteData.$location('/followers/${Uri.encodeComponent(_self.pubkey)}');

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

RouteBase get $followingRouteData => GoRouteData.$route(
  path: '/following/:pubkey',
  name: 'following',
  hasOverriddenOnExit: false,
  factory: $FollowingRouteData._fromState,
);

mixin $FollowingRouteData on GoRouteData {
  static FollowingRouteData _fromState(GoRouterState state) =>
      FollowingRouteData(
        pubkey: state.pathParameters['pubkey']!,
        $extra: state.extra as Object?,
      );

  FollowingRouteData get _self => this as FollowingRouteData;

  @override
  String get location =>
      GoRouteData.$location('/following/${Uri.encodeComponent(_self.pubkey)}');

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

RouteBase get $otherProfileRouteData => GoRouteData.$route(
  path: '/profile-view/:npub',
  name: 'profile-view',
  hasOverriddenOnExit: false,
  factory: $OtherProfileRouteData._fromState,
);

mixin $OtherProfileRouteData on GoRouteData {
  static OtherProfileRouteData _fromState(GoRouterState state) =>
      OtherProfileRouteData(
        npub: state.pathParameters['npub']!,
        $extra: state.extra as Object?,
      );

  OtherProfileRouteData get _self => this as OtherProfileRouteData;

  @override
  String get location =>
      GoRouteData.$location('/profile-view/${Uri.encodeComponent(_self.npub)}');

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
