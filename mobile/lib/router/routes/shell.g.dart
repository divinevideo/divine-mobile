// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shell.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$appShellRouteData];

RouteBase get $appShellRouteData => StatefulShellRouteData.$route(
  navigatorContainerBuilder: AppShellRouteData.$navigatorContainerBuilder,
  factory: $AppShellRouteDataExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      navigatorKey: HomeBranchData.$navigatorKey,
      initialLocation: HomeBranchData.$initialLocation,
      routes: [
        GoRouteData.$route(
          path: '/following/new',
          hasOverriddenOnExit: false,
          factory: $FollowingNewRouteData._fromState,
        ),
        GoRouteData.$route(
          path: '/home/:index',
          name: 'home',
          hasOverriddenOnExit: false,
          factory: $HomeFeedRouteData._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      navigatorKey: ExploreBranchData.$navigatorKey,
      initialLocation: ExploreBranchData.$initialLocation,
      routes: [
        GoRouteData.$route(
          path: '/explore',
          name: 'explore',
          hasOverriddenOnExit: false,
          factory: $ExploreRouteData._fromState,
        ),
        GoRouteData.$route(
          path: '/explore/tab/:name',
          hasOverriddenOnExit: false,
          factory: $ExploreTabRouteData._fromState,
        ),
        GoRouteData.$route(
          path: '/explore/:index',
          hasOverriddenOnExit: false,
          factory: $ExploreFeedRouteData._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      navigatorKey: InboxBranchData.$navigatorKey,
      initialLocation: InboxBranchData.$initialLocation,
      routes: [
        GoRouteData.$route(
          path: '/notifications/:index',
          name: 'notifications',
          hasOverriddenOnExit: false,
          factory: $NotificationsRouteData._fromState,
        ),
        GoRouteData.$route(
          path: '/inbox',
          name: 'inbox',
          hasOverriddenOnExit: false,
          factory: $InboxRouteData._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      navigatorKey: ProfileBranchData.$navigatorKey,
      initialLocation: ProfileBranchData.$initialLocation,
      routes: [
        GoRouteData.$route(
          path: '/profile/:npub/unavailable-pins',
          hasOverriddenOnExit: false,
          factory: $ProfileUnavailablePinsRouteData._fromState,
        ),
        GoRouteData.$route(
          path: '/profile',
          name: 'profile',
          hasOverriddenOnExit: false,
          factory: $ProfileRouteData._fromState,
        ),
        GoRouteData.$route(
          path: '/profile/:npub',
          hasOverriddenOnExit: false,
          factory: $ProfileGridRouteData._fromState,
        ),
        GoRouteData.$route(
          path: '/profile/:npub/:index',
          hasOverriddenOnExit: false,
          factory: $ProfileFeedRouteData._fromState,
        ),
      ],
    ),
  ],
);

extension $AppShellRouteDataExtension on AppShellRouteData {
  static AppShellRouteData _fromState(GoRouterState state) =>
      const AppShellRouteData();
}

mixin $FollowingNewRouteData on GoRouteData {
  static FollowingNewRouteData _fromState(GoRouterState state) =>
      const FollowingNewRouteData();

  @override
  String get location => GoRouteData.$location('/following/new');

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

mixin $HomeFeedRouteData on GoRouteData {
  static HomeFeedRouteData _fromState(GoRouterState state) =>
      HomeFeedRouteData(index: state.pathParameters['index']!);

  HomeFeedRouteData get _self => this as HomeFeedRouteData;

  @override
  String get location =>
      GoRouteData.$location('/home/${Uri.encodeComponent(_self.index)}');

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

mixin $ExploreRouteData on GoRouteData {
  static ExploreRouteData _fromState(GoRouterState state) =>
      const ExploreRouteData();

  @override
  String get location => GoRouteData.$location('/explore');

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

mixin $ExploreTabRouteData on GoRouteData {
  static ExploreTabRouteData _fromState(GoRouterState state) =>
      ExploreTabRouteData(name: state.pathParameters['name']!);

  ExploreTabRouteData get _self => this as ExploreTabRouteData;

  @override
  String get location =>
      GoRouteData.$location('/explore/tab/${Uri.encodeComponent(_self.name)}');

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

mixin $ExploreFeedRouteData on GoRouteData {
  static ExploreFeedRouteData _fromState(GoRouterState state) =>
      ExploreFeedRouteData(index: state.pathParameters['index']!);

  ExploreFeedRouteData get _self => this as ExploreFeedRouteData;

  @override
  String get location =>
      GoRouteData.$location('/explore/${Uri.encodeComponent(_self.index)}');

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

mixin $NotificationsRouteData on GoRouteData {
  static NotificationsRouteData _fromState(GoRouterState state) =>
      NotificationsRouteData(index: state.pathParameters['index']!);

  NotificationsRouteData get _self => this as NotificationsRouteData;

  @override
  String get location => GoRouteData.$location(
    '/notifications/${Uri.encodeComponent(_self.index)}',
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

mixin $InboxRouteData on GoRouteData {
  static InboxRouteData _fromState(GoRouterState state) =>
      const InboxRouteData();

  @override
  String get location => GoRouteData.$location('/inbox');

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

mixin $ProfileUnavailablePinsRouteData on GoRouteData {
  static ProfileUnavailablePinsRouteData _fromState(GoRouterState state) =>
      ProfileUnavailablePinsRouteData(npub: state.pathParameters['npub']!);

  ProfileUnavailablePinsRouteData get _self =>
      this as ProfileUnavailablePinsRouteData;

  @override
  String get location => GoRouteData.$location(
    '/profile/${Uri.encodeComponent(_self.npub)}/unavailable-pins',
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

mixin $ProfileRouteData on GoRouteData {
  static ProfileRouteData _fromState(GoRouterState state) =>
      const ProfileRouteData();

  @override
  String get location => GoRouteData.$location('/profile');

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

mixin $ProfileGridRouteData on GoRouteData {
  static ProfileGridRouteData _fromState(GoRouterState state) =>
      ProfileGridRouteData(npub: state.pathParameters['npub']!);

  ProfileGridRouteData get _self => this as ProfileGridRouteData;

  @override
  String get location =>
      GoRouteData.$location('/profile/${Uri.encodeComponent(_self.npub)}');

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

mixin $ProfileFeedRouteData on GoRouteData {
  static ProfileFeedRouteData _fromState(GoRouterState state) =>
      ProfileFeedRouteData(
        npub: state.pathParameters['npub']!,
        index: state.pathParameters['index']!,
      );

  ProfileFeedRouteData get _self => this as ProfileFeedRouteData;

  @override
  String get location => GoRouteData.$location(
    '/profile/${Uri.encodeComponent(_self.npub)}/${Uri.encodeComponent(_self.index)}',
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
