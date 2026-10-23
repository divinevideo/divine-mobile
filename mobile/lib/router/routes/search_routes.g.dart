// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $followedHashtagsRouteData,
  $hashtagRouteData,
  $searchRouteData,
  $searchQueryRouteData,
  $categoryGalleryRouteData,
];

RouteBase get $followedHashtagsRouteData => GoRouteData.$route(
  path: '/followed-hashtags',
  hasOverriddenOnExit: false,
  parentNavigatorKey: FollowedHashtagsRouteData.$parentNavigatorKey,
  factory: $FollowedHashtagsRouteData._fromState,
);

mixin $FollowedHashtagsRouteData on GoRouteData {
  static FollowedHashtagsRouteData _fromState(GoRouterState state) =>
      const FollowedHashtagsRouteData();

  @override
  String get location => GoRouteData.$location('/followed-hashtags');

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

RouteBase get $hashtagRouteData => GoRouteData.$route(
  path: '/hashtag/:tag',
  name: 'hashtag',
  hasOverriddenOnExit: false,
  parentNavigatorKey: HashtagRouteData.$parentNavigatorKey,
  factory: $HashtagRouteData._fromState,
);

mixin $HashtagRouteData on GoRouteData {
  static HashtagRouteData _fromState(GoRouterState state) =>
      HashtagRouteData(tag: state.pathParameters['tag']!);

  HashtagRouteData get _self => this as HashtagRouteData;

  @override
  String get location =>
      GoRouteData.$location('/hashtag/${Uri.encodeComponent(_self.tag)}');

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

RouteBase get $searchRouteData => GoRouteData.$route(
  path: '/search-results',
  hasOverriddenOnExit: false,
  parentNavigatorKey: SearchRouteData.$parentNavigatorKey,
  factory: $SearchRouteData._fromState,
);

mixin $SearchRouteData on GoRouteData {
  static SearchRouteData _fromState(GoRouterState state) =>
      SearchRouteData(focus: state.uri.queryParameters['focus']);

  SearchRouteData get _self => this as SearchRouteData;

  @override
  String get location => GoRouteData.$location(
    '/search-results',
    queryParams: {if (_self.focus != null) 'focus': _self.focus},
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

RouteBase get $searchQueryRouteData => GoRouteData.$route(
  path: '/search-results/:query',
  hasOverriddenOnExit: false,
  parentNavigatorKey: SearchQueryRouteData.$parentNavigatorKey,
  factory: $SearchQueryRouteData._fromState,
);

mixin $SearchQueryRouteData on GoRouteData {
  static SearchQueryRouteData _fromState(GoRouterState state) =>
      SearchQueryRouteData(
        query: state.pathParameters['query']!,
        focus: state.uri.queryParameters['focus'],
      );

  SearchQueryRouteData get _self => this as SearchQueryRouteData;

  @override
  String get location => GoRouteData.$location(
    '/search-results/${Uri.encodeComponent(_self.query)}',
    queryParams: {if (_self.focus != null) 'focus': _self.focus},
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

RouteBase get $categoryGalleryRouteData => GoRouteData.$route(
  path: '/categories/:categoryName',
  name: 'category-gallery',
  hasOverriddenOnExit: false,
  factory: $CategoryGalleryRouteData._fromState,
);

mixin $CategoryGalleryRouteData on GoRouteData {
  static CategoryGalleryRouteData _fromState(GoRouterState state) =>
      CategoryGalleryRouteData(
        categoryName: state.pathParameters['categoryName']!,
        $extra: state.extra as Object?,
      );

  CategoryGalleryRouteData get _self => this as CategoryGalleryRouteData;

  @override
  String get location => GoRouteData.$location(
    '/categories/${Uri.encodeComponent(_self.categoryName)}',
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
