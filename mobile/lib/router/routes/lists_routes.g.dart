// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lists_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $savedVideosRouteData,
  $curatedListFeedRouteData,
  $curatedListByAuthorRouteData,
  $discoverListsRouteData,
  $createPeopleListRouteData,
  $peopleListRouteData,
  $peopleListMembersRouteData,
  $editPeopleListRouteData,
  $addPeopleToListRouteData,
];

RouteBase get $savedVideosRouteData => GoRouteData.$route(
  path: '/saved-videos',
  name: 'savedVideos',
  hasOverriddenOnExit: false,
  factory: $SavedVideosRouteData._fromState,
);

mixin $SavedVideosRouteData on GoRouteData {
  static SavedVideosRouteData _fromState(GoRouterState state) =>
      const SavedVideosRouteData();

  @override
  String get location => GoRouteData.$location('/saved-videos');

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

RouteBase get $curatedListFeedRouteData => GoRouteData.$route(
  path: '/list/:listId',
  name: 'list',
  hasOverriddenOnExit: false,
  factory: $CuratedListFeedRouteData._fromState,
);

mixin $CuratedListFeedRouteData on GoRouteData {
  static CuratedListFeedRouteData _fromState(GoRouterState state) =>
      CuratedListFeedRouteData(
        listId: state.pathParameters['listId']!,
        $extra: state.extra as Object?,
      );

  CuratedListFeedRouteData get _self => this as CuratedListFeedRouteData;

  @override
  String get location =>
      GoRouteData.$location('/list/${Uri.encodeComponent(_self.listId)}');

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

RouteBase get $curatedListByAuthorRouteData => GoRouteData.$route(
  path: '/list/:pubkey/:listId',
  name: 'listByAuthor',
  hasOverriddenOnExit: false,
  factory: $CuratedListByAuthorRouteData._fromState,
);

mixin $CuratedListByAuthorRouteData on GoRouteData {
  static CuratedListByAuthorRouteData _fromState(GoRouterState state) =>
      CuratedListByAuthorRouteData(
        pubkey: state.pathParameters['pubkey']!,
        listId: state.pathParameters['listId']!,
        $extra: state.extra as Object?,
      );

  CuratedListByAuthorRouteData get _self =>
      this as CuratedListByAuthorRouteData;

  @override
  String get location => GoRouteData.$location(
    '/list/${Uri.encodeComponent(_self.pubkey)}/${Uri.encodeComponent(_self.listId)}',
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

RouteBase get $discoverListsRouteData => GoRouteData.$route(
  path: '/discover-lists',
  hasOverriddenOnExit: false,
  factory: $DiscoverListsRouteData._fromState,
);

mixin $DiscoverListsRouteData on GoRouteData {
  static DiscoverListsRouteData _fromState(GoRouterState state) =>
      const DiscoverListsRouteData();

  @override
  String get location => GoRouteData.$location('/discover-lists');

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

RouteBase get $createPeopleListRouteData => GoRouteData.$route(
  path: '/people-lists/new',
  name: 'people-list-create',
  hasOverriddenOnExit: false,
  factory: $CreatePeopleListRouteData._fromState,
);

mixin $CreatePeopleListRouteData on GoRouteData {
  static CreatePeopleListRouteData _fromState(GoRouterState state) =>
      CreatePeopleListRouteData(
        initialPubkey: state.uri.queryParameters['initialPubkey'],
      );

  CreatePeopleListRouteData get _self => this as CreatePeopleListRouteData;

  @override
  String get location => GoRouteData.$location(
    '/people-lists/new',
    queryParams: {
      if (_self.initialPubkey != null) 'initialPubkey': _self.initialPubkey,
    },
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

RouteBase get $peopleListRouteData => GoRouteData.$route(
  path: '/people-lists/:listId',
  name: 'people-list-members',
  hasOverriddenOnExit: false,
  factory: $PeopleListRouteData._fromState,
);

mixin $PeopleListRouteData on GoRouteData {
  static PeopleListRouteData _fromState(GoRouterState state) =>
      PeopleListRouteData(
        listId: state.pathParameters['listId']!,
        owner: state.uri.queryParameters['owner'],
      );

  PeopleListRouteData get _self => this as PeopleListRouteData;

  @override
  String get location => GoRouteData.$location(
    '/people-lists/${Uri.encodeComponent(_self.listId)}',
    queryParams: {if (_self.owner != null) 'owner': _self.owner},
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

RouteBase get $peopleListMembersRouteData => GoRouteData.$route(
  path: '/people-lists/:listId/members',
  name: 'people-list-roster',
  hasOverriddenOnExit: false,
  factory: $PeopleListMembersRouteData._fromState,
);

mixin $PeopleListMembersRouteData on GoRouteData {
  static PeopleListMembersRouteData _fromState(GoRouterState state) =>
      PeopleListMembersRouteData(
        listId: state.pathParameters['listId']!,
        owner: state.uri.queryParameters['owner'],
      );

  PeopleListMembersRouteData get _self => this as PeopleListMembersRouteData;

  @override
  String get location => GoRouteData.$location(
    '/people-lists/${Uri.encodeComponent(_self.listId)}/members',
    queryParams: {if (_self.owner != null) 'owner': _self.owner},
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

RouteBase get $editPeopleListRouteData => GoRouteData.$route(
  path: '/people-lists/:listId/edit',
  name: 'people-list-edit',
  hasOverriddenOnExit: false,
  factory: $EditPeopleListRouteData._fromState,
);

mixin $EditPeopleListRouteData on GoRouteData {
  static EditPeopleListRouteData _fromState(GoRouterState state) =>
      EditPeopleListRouteData(
        listId: state.pathParameters['listId']!,
        owner: state.uri.queryParameters['owner'],
      );

  EditPeopleListRouteData get _self => this as EditPeopleListRouteData;

  @override
  String get location => GoRouteData.$location(
    '/people-lists/${Uri.encodeComponent(_self.listId)}/edit',
    queryParams: {if (_self.owner != null) 'owner': _self.owner},
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

RouteBase get $addPeopleToListRouteData => GoRouteData.$route(
  path: '/people-lists/:listId/add-people',
  name: 'people-list-add-people',
  hasOverriddenOnExit: false,
  factory: $AddPeopleToListRouteData._fromState,
);

mixin $AddPeopleToListRouteData on GoRouteData {
  static AddPeopleToListRouteData _fromState(GoRouterState state) =>
      AddPeopleToListRouteData(
        listId: state.pathParameters['listId']!,
        owner: state.uri.queryParameters['owner'],
      );

  AddPeopleToListRouteData get _self => this as AddPeopleToListRouteData;

  @override
  String get location => GoRouteData.$location(
    '/people-lists/${Uri.encodeComponent(_self.listId)}/add-people',
    queryParams: {if (_self.owner != null) 'owner': _self.owner},
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
