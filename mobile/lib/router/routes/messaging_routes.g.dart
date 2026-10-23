// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messaging_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $conversationRouteData,
  $messageRequestsRouteData,
  $requestPreviewRouteData,
];

RouteBase get $conversationRouteData => GoRouteData.$route(
  path: '/inbox/conversation/:id',
  name: 'conversation',
  hasOverriddenOnExit: false,
  factory: $ConversationRouteData._fromState,
);

mixin $ConversationRouteData on GoRouteData {
  static ConversationRouteData _fromState(GoRouterState state) =>
      ConversationRouteData(
        id: state.pathParameters['id']!,
        $extra: state.extra as Object?,
      );

  ConversationRouteData get _self => this as ConversationRouteData;

  @override
  String get location => GoRouteData.$location(
    '/inbox/conversation/${Uri.encodeComponent(_self.id)}',
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

RouteBase get $messageRequestsRouteData => GoRouteData.$route(
  path: '/inbox/message-requests',
  name: 'messageRequests',
  hasOverriddenOnExit: false,
  parentNavigatorKey: MessageRequestsRouteData.$parentNavigatorKey,
  factory: $MessageRequestsRouteData._fromState,
);

mixin $MessageRequestsRouteData on GoRouteData {
  static MessageRequestsRouteData _fromState(GoRouterState state) =>
      const MessageRequestsRouteData();

  @override
  String get location => GoRouteData.$location('/inbox/message-requests');

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

RouteBase get $requestPreviewRouteData => GoRouteData.$route(
  path: '/inbox/message-requests/:id',
  name: 'requestPreview',
  hasOverriddenOnExit: false,
  parentNavigatorKey: RequestPreviewRouteData.$parentNavigatorKey,
  factory: $RequestPreviewRouteData._fromState,
);

mixin $RequestPreviewRouteData on GoRouteData {
  static RequestPreviewRouteData _fromState(GoRouterState state) =>
      RequestPreviewRouteData(
        id: state.pathParameters['id']!,
        $extra: state.extra as Object?,
      );

  RequestPreviewRouteData get _self => this as RequestPreviewRouteData;

  @override
  String get location => GoRouteData.$location(
    '/inbox/message-requests/${Uri.encodeComponent(_self.id)}',
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
