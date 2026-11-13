// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $videoRecorderRouteData,
  $creatorAnalyticsRouteData,
  $videoDetailRouteData,
  $soundDetailRouteData,
  $originalSoundDetailRouteData,
  $videoEditorRouteData,
  $videoEditorDraftRouteData,
  $videoMetadataRouteData,
  $videoMetadataEditRouteData,
  $subtitleEditorRouteData,
  $pooledFullscreenVideoFeedRouteData,
  $videoLikersRouteData,
  $videoRepostersRouteData,
];

RouteBase get $videoRecorderRouteData => GoRouteData.$route(
  path: '/video-recorder',
  name: 'video-recorder',
  hasOverriddenOnExit: false,
  factory: $VideoRecorderRouteData._fromState,
);

mixin $VideoRecorderRouteData on GoRouteData {
  static VideoRecorderRouteData _fromState(GoRouterState state) =>
      VideoRecorderRouteData(
        challengeRecording: state.uri.queryParameters['challenge_recording'],
        entryPoint: state.uri.queryParameters['entry_point'],
        $extra: state.extra as Object?,
      );

  VideoRecorderRouteData get _self => this as VideoRecorderRouteData;

  @override
  String get location => GoRouteData.$location(
    '/video-recorder',
    queryParams: {
      if (_self.challengeRecording != null)
        'challenge_recording': _self.challengeRecording,
      if (_self.entryPoint != null) 'entry_point': _self.entryPoint,
    },
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

RouteBase get $creatorAnalyticsRouteData => GoRouteData.$route(
  path: '/creator-analytics',
  name: 'creator-analytics',
  hasOverriddenOnExit: false,
  parentNavigatorKey: CreatorAnalyticsRouteData.$parentNavigatorKey,
  factory: $CreatorAnalyticsRouteData._fromState,
  routes: [
    GoRouteData.$route(
      path: ':videoId',
      name: 'creator-analytics-post',
      hasOverriddenOnExit: false,
      parentNavigatorKey: PostAnalyticsDetailRouteData.$parentNavigatorKey,
      factory: $PostAnalyticsDetailRouteData._fromState,
    ),
  ],
);

mixin $CreatorAnalyticsRouteData on GoRouteData {
  static CreatorAnalyticsRouteData _fromState(GoRouterState state) =>
      const CreatorAnalyticsRouteData();

  @override
  String get location => GoRouteData.$location('/creator-analytics');

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

mixin $PostAnalyticsDetailRouteData on GoRouteData {
  static PostAnalyticsDetailRouteData _fromState(GoRouterState state) =>
      PostAnalyticsDetailRouteData(
        videoId: state.pathParameters['videoId']!,
        $extra: state.extra as Object?,
      );

  PostAnalyticsDetailRouteData get _self =>
      this as PostAnalyticsDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/creator-analytics/${Uri.encodeComponent(_self.videoId)}',
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

RouteBase get $videoDetailRouteData => GoRouteData.$route(
  path: '/video/:id',
  name: 'video',
  hasOverriddenOnExit: false,
  factory: $VideoDetailRouteData._fromState,
);

mixin $VideoDetailRouteData on GoRouteData {
  static VideoDetailRouteData _fromState(GoRouterState state) =>
      VideoDetailRouteData(
        id: state.pathParameters['id']!,
        author: state.uri.queryParameters['author'],
        $extra: state.extra as Object?,
      );

  VideoDetailRouteData get _self => this as VideoDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/video/${Uri.encodeComponent(_self.id)}',
    queryParams: {if (_self.author != null) 'author': _self.author},
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

RouteBase get $soundDetailRouteData => GoRouteData.$route(
  path: '/sound/:id',
  name: 'sound',
  hasOverriddenOnExit: false,
  factory: $SoundDetailRouteData._fromState,
);

mixin $SoundDetailRouteData on GoRouteData {
  static SoundDetailRouteData _fromState(GoRouterState state) =>
      SoundDetailRouteData(
        id: state.pathParameters['id']!,
        $extra: state.extra as Object?,
      );

  SoundDetailRouteData get _self => this as SoundDetailRouteData;

  @override
  String get location =>
      GoRouteData.$location('/sound/${Uri.encodeComponent(_self.id)}');

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

RouteBase get $originalSoundDetailRouteData => GoRouteData.$route(
  path: '/original-sound/:pubkey',
  name: 'originalSound',
  hasOverriddenOnExit: false,
  factory: $OriginalSoundDetailRouteData._fromState,
);

mixin $OriginalSoundDetailRouteData on GoRouteData {
  static OriginalSoundDetailRouteData _fromState(GoRouterState state) =>
      OriginalSoundDetailRouteData(
        pubkey: state.pathParameters['pubkey']!,
        $extra: state.extra as Object?,
      );

  OriginalSoundDetailRouteData get _self =>
      this as OriginalSoundDetailRouteData;

  @override
  String get location => GoRouteData.$location(
    '/original-sound/${Uri.encodeComponent(_self.pubkey)}',
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

RouteBase get $videoEditorRouteData => GoRouteData.$route(
  path: '/video-editor',
  name: 'video-editor',
  hasOverriddenOnExit: false,
  factory: $VideoEditorRouteData._fromState,
);

mixin $VideoEditorRouteData on GoRouteData {
  static VideoEditorRouteData _fromState(GoRouterState state) =>
      VideoEditorRouteData(from: state.uri.queryParameters['from']);

  VideoEditorRouteData get _self => this as VideoEditorRouteData;

  @override
  String get location => GoRouteData.$location(
    '/video-editor',
    queryParams: {if (_self.from != null) 'from': _self.from},
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

RouteBase get $videoEditorDraftRouteData => GoRouteData.$route(
  path: '/video-editor/:draftId',
  name: 'video-editor-draft',
  hasOverriddenOnExit: false,
  factory: $VideoEditorDraftRouteData._fromState,
);

mixin $VideoEditorDraftRouteData on GoRouteData {
  static VideoEditorDraftRouteData _fromState(GoRouterState state) =>
      VideoEditorDraftRouteData(
        draftId: state.pathParameters['draftId']!,
        from: state.uri.queryParameters['from'],
      );

  VideoEditorDraftRouteData get _self => this as VideoEditorDraftRouteData;

  @override
  String get location => GoRouteData.$location(
    '/video-editor/${Uri.encodeComponent(_self.draftId)}',
    queryParams: {if (_self.from != null) 'from': _self.from},
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

RouteBase get $videoMetadataRouteData => GoRouteData.$route(
  path: '/video-metadata',
  name: 'video-metadata',
  hasOverriddenOnExit: false,
  factory: $VideoMetadataRouteData._fromState,
);

mixin $VideoMetadataRouteData on GoRouteData {
  static VideoMetadataRouteData _fromState(GoRouterState state) =>
      VideoMetadataRouteData(mode: state.uri.queryParameters['mode']);

  VideoMetadataRouteData get _self => this as VideoMetadataRouteData;

  @override
  String get location => GoRouteData.$location(
    '/video-metadata',
    queryParams: {if (_self.mode != null) 'mode': _self.mode},
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

RouteBase get $videoMetadataEditRouteData => GoRouteData.$route(
  path: '/video-edit/:videoId',
  name: 'video-edit',
  hasOverriddenOnExit: false,
  factory: $VideoMetadataEditRouteData._fromState,
);

mixin $VideoMetadataEditRouteData on GoRouteData {
  static VideoMetadataEditRouteData _fromState(GoRouterState state) =>
      VideoMetadataEditRouteData(
        videoId: state.pathParameters['videoId']!,
        $extra: state.extra as Object?,
      );

  VideoMetadataEditRouteData get _self => this as VideoMetadataEditRouteData;

  @override
  String get location => GoRouteData.$location(
    '/video-edit/${Uri.encodeComponent(_self.videoId)}',
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

RouteBase get $subtitleEditorRouteData => GoRouteData.$route(
  path: '/subtitle-edit/:videoId',
  name: 'subtitle-edit',
  hasOverriddenOnExit: false,
  factory: $SubtitleEditorRouteData._fromState,
);

mixin $SubtitleEditorRouteData on GoRouteData {
  static SubtitleEditorRouteData _fromState(GoRouterState state) =>
      SubtitleEditorRouteData(
        videoId: state.pathParameters['videoId']!,
        $extra: state.extra as Object?,
      );

  SubtitleEditorRouteData get _self => this as SubtitleEditorRouteData;

  @override
  String get location => GoRouteData.$location(
    '/subtitle-edit/${Uri.encodeComponent(_self.videoId)}',
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

RouteBase get $pooledFullscreenVideoFeedRouteData => GoRouteData.$route(
  path: '/pooled-video-feed',
  name: 'pooled-video-feed',
  hasOverriddenOnExit: false,
  factory: $PooledFullscreenVideoFeedRouteData._fromState,
);

mixin $PooledFullscreenVideoFeedRouteData on GoRouteData {
  static PooledFullscreenVideoFeedRouteData _fromState(GoRouterState state) =>
      PooledFullscreenVideoFeedRouteData(
        video: state.uri.queryParameters['video'],
        $extra: state.extra as Object?,
      );

  PooledFullscreenVideoFeedRouteData get _self =>
      this as PooledFullscreenVideoFeedRouteData;

  @override
  String get location => GoRouteData.$location(
    '/pooled-video-feed',
    queryParams: {if (_self.video != null) 'video': _self.video},
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

RouteBase get $videoLikersRouteData => GoRouteData.$route(
  path: '/video/:eventId/likers',
  name: 'videoLikers',
  hasOverriddenOnExit: false,
  factory: $VideoLikersRouteData._fromState,
);

mixin $VideoLikersRouteData on GoRouteData {
  static VideoLikersRouteData _fromState(GoRouterState state) =>
      VideoLikersRouteData(
        eventId: state.pathParameters['eventId']!,
        a: state.uri.queryParameters['a'],
      );

  VideoLikersRouteData get _self => this as VideoLikersRouteData;

  @override
  String get location => GoRouteData.$location(
    '/video/${Uri.encodeComponent(_self.eventId)}/likers',
    queryParams: {if (_self.a != null) 'a': _self.a},
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

RouteBase get $videoRepostersRouteData => GoRouteData.$route(
  path: '/video/:eventId/reposters',
  name: 'videoReposters',
  hasOverriddenOnExit: false,
  factory: $VideoRepostersRouteData._fromState,
);

mixin $VideoRepostersRouteData on GoRouteData {
  static VideoRepostersRouteData _fromState(GoRouterState state) =>
      VideoRepostersRouteData(
        eventId: state.pathParameters['eventId']!,
        a: state.uri.queryParameters['a'],
      );

  VideoRepostersRouteData get _self => this as VideoRepostersRouteData;

  @override
  String get location => GoRouteData.$location(
    '/video/${Uri.encodeComponent(_self.eventId)}/reposters',
    queryParams: {if (_self.a != null) 'a': _self.a},
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
