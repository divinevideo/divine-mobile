// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interactive_sticker_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $questionAnswerRouteData,
  $videoRepliesRouteData,
];

RouteBase get $questionAnswerRouteData => GoRouteData.$route(
  path: '/question-answer/:pubkey',
  name: 'question-answer',
  hasOverriddenOnExit: false,
  factory: $QuestionAnswerRouteData._fromState,
);

mixin $QuestionAnswerRouteData on GoRouteData {
  static QuestionAnswerRouteData _fromState(GoRouterState state) =>
      QuestionAnswerRouteData(
        pubkey: state.pathParameters['pubkey']!,
        videoId: state.uri.queryParameters['video'],
        dTag: state.uri.queryParameters['d'],
        question: state.uri.queryParameters['q'],
      );

  QuestionAnswerRouteData get _self => this as QuestionAnswerRouteData;

  @override
  String get location => GoRouteData.$location(
    '/question-answer/${Uri.encodeComponent(_self.pubkey)}',
    queryParams: {
      if (_self.videoId != null) 'video': _self.videoId,
      if (_self.dTag != null) 'd': _self.dTag,
      if (_self.question != null) 'q': _self.question,
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

RouteBase get $videoRepliesRouteData => GoRouteData.$route(
  path: '/video-replies/:videoId',
  name: 'video-replies',
  hasOverriddenOnExit: false,
  factory: $VideoRepliesRouteData._fromState,
);

mixin $VideoRepliesRouteData on GoRouteData {
  static VideoRepliesRouteData _fromState(GoRouterState state) =>
      VideoRepliesRouteData(
        videoId: state.pathParameters['videoId']!,
        address: state.uri.queryParameters['address'],
      );

  VideoRepliesRouteData get _self => this as VideoRepliesRouteData;

  @override
  String get location => GoRouteData.$location(
    '/video-replies/${Uri.encodeComponent(_self.videoId)}',
    queryParams: {if (_self.address != null) 'address': _self.address},
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
