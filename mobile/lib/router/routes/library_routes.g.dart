// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $libraryDraftsRouteData,
  $libraryClipsRouteData,
  $libraryClipsOnlyRouteData,
  $librarySoundsRouteData,
];

RouteBase get $libraryDraftsRouteData => GoRouteData.$route(
  path: '/drafts',
  name: 'drafts',
  hasOverriddenOnExit: false,
  factory: $LibraryDraftsRouteData._fromState,
);

mixin $LibraryDraftsRouteData on GoRouteData {
  static LibraryDraftsRouteData _fromState(GoRouterState state) =>
      const LibraryDraftsRouteData();

  @override
  String get location => GoRouteData.$location('/drafts');

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

RouteBase get $libraryClipsRouteData => GoRouteData.$route(
  path: '/clips',
  name: 'clips',
  hasOverriddenOnExit: false,
  factory: $LibraryClipsRouteData._fromState,
);

mixin $LibraryClipsRouteData on GoRouteData {
  static LibraryClipsRouteData _fromState(GoRouterState state) =>
      const LibraryClipsRouteData();

  @override
  String get location => GoRouteData.$location('/clips');

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

RouteBase get $libraryClipsOnlyRouteData => GoRouteData.$route(
  path: '/clips-only',
  name: 'clipsOnly',
  hasOverriddenOnExit: false,
  factory: $LibraryClipsOnlyRouteData._fromState,
);

mixin $LibraryClipsOnlyRouteData on GoRouteData {
  static LibraryClipsOnlyRouteData _fromState(GoRouterState state) =>
      LibraryClipsOnlyRouteData(type: state.uri.queryParameters['type']);

  LibraryClipsOnlyRouteData get _self => this as LibraryClipsOnlyRouteData;

  @override
  String get location => GoRouteData.$location(
    '/clips-only',
    queryParams: {if (_self.type != null) 'type': _self.type},
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

RouteBase get $librarySoundsRouteData => GoRouteData.$route(
  path: '/sounds',
  name: 'sounds',
  hasOverriddenOnExit: false,
  factory: $LibrarySoundsRouteData._fromState,
  routes: [
    GoRouteData.$route(
      path: 'add',
      name: 'add-sound',
      hasOverriddenOnExit: false,
      factory: $AddSoundRouteData._fromState,
    ),
  ],
);

mixin $LibrarySoundsRouteData on GoRouteData {
  static LibrarySoundsRouteData _fromState(GoRouterState state) =>
      const LibrarySoundsRouteData();

  @override
  String get location => GoRouteData.$location('/sounds');

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

mixin $AddSoundRouteData on GoRouteData {
  static AddSoundRouteData _fromState(GoRouterState state) =>
      const AddSoundRouteData();

  @override
  String get location => GoRouteData.$location('/sounds/add');

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
