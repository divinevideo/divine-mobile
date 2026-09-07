// ABOUTME: Widget tests for FeedVideos — covers loading/restricted overlay,
// ABOUTME: overlay mode switching (forbidden/ageRestricted/contentWarning/interactive),
// ABOUTME: effective isActive propagation, route-aware pausing, and pagination flush.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_cubit.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_state.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/models/feature_flag_state.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/view_traffic_source.dart'
    show ViewTrafficSource;
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/community_content_label_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/community_content_label_service.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/divine_video_metrics_tracker.dart';
import 'package:openvine/widgets/video_feed_item/actions/help_classify_action_button.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/feed_immersive_chrome.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_overlay.dart';
import 'package:openvine/widgets/video_feed_item/player_gesture_surface.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_feed_item/video_loading_placeholder.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockFeedLoadingModerationCubit
    extends MockCubit<FeedLoadingModerationState>
    implements FeedLoadingModerationCubit {
  @override
  void start() {}
}

class _MockVideoPlaybackStatusCubit extends MockCubit<VideoPlaybackStatusState>
    implements VideoPlaybackStatusCubit {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

class _MockFeedAutoAdvanceCubit extends MockCubit<FeedAutoAdvanceState>
    implements FeedAutoAdvanceCubit {}

class _MockConnectionStatusService extends Mock
    implements ConnectionStatusService {}

class _MockVideoModerationStatusService extends Mock
    implements VideoModerationStatusService {}

class _MockMediaAuthInterceptor extends Mock implements MediaAuthInterceptor {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockFeatureFlagService extends Mock implements FeatureFlagService {}

/// Flag service with community content warnings ON, everything else OFF.
FeatureFlagService _communityFlagsOn() {
  final service = _MockFeatureFlagService();
  when(() => service.isEnabled(any())).thenReturn(false);
  when(
    () => service.isEnabled(FeatureFlag.communityContentWarnings),
  ).thenReturn(true);
  // The reactive gating chain reads currentState via
  // featureFlagStateProvider rather than isEnabled directly.
  when(() => service.currentState).thenReturn(
    FeatureFlagState({
      for (final flag in FeatureFlag.values)
        flag: flag == FeatureFlag.communityContentWarnings,
    }),
  );
  return service;
}

class _MockCommunityContentLabelRepository extends Mock
    implements CommunityContentLabelRepository {}

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _NoopAnalyticsService extends AnalyticsService {
  _NoopAnalyticsService()
    : super(backgroundActivityManager: BackgroundActivityManager());

  @override
  Future<void> trackDetailedVideoViewWithUser(
    VideoEvent video, {
    required String? userId,
    required String source,
    required String eventType,
    String? sessionToken,
    Duration? watchDuration,
    Duration? totalDuration,
    double? loopCount,
    bool? completedVideo,
    ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
    String? sourceDetail,
  }) async {}
}

class _NoopSeenVideosService extends SeenVideosService {
  @override
  Future<void> recordVideoView(
    String videoId, {
    int? loopCount,
    Duration? watchDuration,
  }) async {}
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _testVideoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';
const _viewerPubkey =
    'f6789012345678901234567890abcdef123456789012345678901234a1b2c3d4e5';

/// Signed-in viewer who is not the creator of [_makeVideo]'s video, so the
/// non-own-video action slots (Report, Help classify) are rendered.
MockAuthService _viewerAuthService() {
  final auth = createMockAuthService();
  when(() => auth.currentPublicKeyHex).thenReturn(_viewerPubkey);
  return auth;
}

VideoEvent _makeVideo({
  String? id,
  String? videoUrl,
  String? sha256,
  List<String> warnLabels = const [],
}) {
  return VideoEvent(
    id: id ?? _testVideoId,
    pubkey: _testPubkey,
    createdAt: 1704067200,
    content: 'Test video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    videoUrl: videoUrl ?? 'https://example.com/video.mp4',
    sha256: sha256,
    warnLabels: warnLabels,
  );
}

// ---------------------------------------------------------------------------
// Stub helpers
// ---------------------------------------------------------------------------

extension _PlaybackCubitStub on _MockVideoPlaybackStatusCubit {
  void stub(PlaybackStatus status, String videoId) {
    final baseState = VideoPlaybackStatusState();
    when(() => state).thenReturn(
      status == PlaybackStatus.ready
          ? baseState
          : baseState.withStatus(videoId, status),
    );
    when(
      () => consumeAgeRestrictedAutoRetryIfEligible(
        any(),
        isAgeRestricted: any(named: 'isAgeRestricted'),
        hasVerifyAction: any(named: 'hasVerifyAction'),
        isConsumerActive: any(named: 'isConsumerActive'),
      ),
    ).thenAnswer((_) async => false);
    whenListen(this, const Stream<VideoPlaybackStatusState>.empty());
  }
}

extension _AutoAdvanceCubitStub on _MockFeedAutoAdvanceCubit {
  void stub(FeedAutoAdvanceState s) {
    when(() => state).thenReturn(s);
    whenListen(this, const Stream<FeedAutoAdvanceState>.empty());
  }
}

extension _VolumeCubitStub on _MockVideoVolumeCubit {
  void stub() {
    when(() => state).thenReturn(const VideoVolumeState());
    whenListen(this, const Stream<VideoVolumeState>.empty());
  }
}

extension _LikesRepoStub on _MockLikesRepository {
  void stubAll() {
    when(
      watchLikedEventIds,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      () => isLikedResolvingCoordinate(
        eventId: any(named: 'eventId'),
        addressableId: any(named: 'addressableId'),
      ),
    ).thenAnswer((_) async => false);
    when(
      () => getLikeCount(any(), addressableId: any(named: 'addressableId')),
    ).thenAnswer((_) async => 0);
  }
}

extension _CommentsRepoStub on _MockCommentsRepository {
  void stubAll() {
    when(
      () => getCommentsCount(
        any(),
        rootAddressableId: any(named: 'rootAddressableId'),
      ),
    ).thenAnswer((_) async => 0);
  }
}

extension _RepostsRepoStub on _MockRepostsRepository {
  void stubAll() {
    when(
      watchRepostedAddressableIds,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(() => getRepostCountByEventId(any())).thenAnswer((_) async => 0);
  }
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

// The helper combines overrides from two Riverpod provider generations.
// ignore: strict_raw_type
List _buildOverrides({
  VideoModerationStatusService? moderationService,
  MediaAuthInterceptor? mediaAuthInterceptor,
  LikesRepository? likesRepository,
  CommentsRepository? commentsRepository,
  RepostsRepository? repostsRepository,
  MockAuthService? authService,
}) {
  return [
    ...getStandardTestOverrides(
      mockAuthService: authService ?? createMockAuthService(),
      analyticsService: _NoopAnalyticsService(),
    ),
    seenVideosServiceProvider.overrideWithValue(_NoopSeenVideosService()),
    connectionStatusServiceProvider.overrideWithValue(
      _MockConnectionStatusService(),
    ),
    videoModerationStatusServiceProvider.overrideWithValue(
      moderationService ?? _MockVideoModerationStatusService(),
    ),
    if (mediaAuthInterceptor != null)
      mediaAuthInterceptorProvider.overrideWithValue(mediaAuthInterceptor),
    subtitleVisibilityProvider.overrideWithValue(false),
    likesRepositoryProvider.overrideWithValue(
      likesRepository ?? (_MockLikesRepository()..stubAll()),
    ),
    commentsRepositoryProvider.overrideWithValue(
      commentsRepository ?? (_MockCommentsRepository()..stubAll()),
    ),
    repostsRepositoryProvider.overrideWithValue(
      repostsRepository ?? (_MockRepostsRepository()..stubAll()),
    ),
  ];
}

/// Pumps [FeedVideos] wrapped in all required bloc providers and Riverpod
/// overrides. [videoPlaybackStatusCubit] drives the overlay mode tests;
/// [moderationService] drives the loading/restricted overlay tests.
Future<ProviderContainer> _pumpFeedVideos(
  WidgetTester tester, {
  required List<VideoEvent> videos,
  _MockVideoPlaybackStatusCubit? videoPlaybackStatusCubit,
  _MockFeedAutoAdvanceCubit? feedAutoAdvanceCubit,
  FeedImmersiveCubit? feedImmersiveCubit,
  _MockVideoVolumeCubit? videoVolumeCubit,
  VideoModerationStatusService? moderationService,
  MediaAuthInterceptor? mediaAuthInterceptor,
  _MockLikesRepository? likesRepository,
  _MockCommentsRepository? commentsRepository,
  _MockRepostsRepository? repostsRepository,
  MockAuthService? authService,
  bool isActive = true,
  bool appForeground = true,
  bool hasMore = false,
  bool isLoadingMore = false,
  void Function(VideoEvent, int)? onActiveVideoChanged,
  List<NavigatorObserver> navigatorObservers = const <NavigatorObserver>[],
  List<dynamic> additionalOverrides = const [],
}) async {
  final mockPlaybackCubit =
      videoPlaybackStatusCubit ??
      (_MockVideoPlaybackStatusCubit()..stub(
        PlaybackStatus.ready,
        videos.isNotEmpty ? videos.first.id : _testVideoId,
      ));
  final mockAutoAdvanceCubit =
      feedAutoAdvanceCubit ??
      (_MockFeedAutoAdvanceCubit()..stub(const FeedAutoAdvanceState()));
  final mockVolumeCubit = videoVolumeCubit ?? (_MockVideoVolumeCubit()..stub());
  // Real cubit rather than a mock: it holds one bool and the hold-to-peek
  // tests assert the chrome that reacts to it.
  final immersiveCubit = feedImmersiveCubit ?? FeedImmersiveCubit();
  addTearDown(immersiveCubit.close);
  final container = ProviderContainer(
    overrides: [
      ..._buildOverrides(
        moderationService: moderationService,
        mediaAuthInterceptor: mediaAuthInterceptor,
        likesRepository: likesRepository,
        commentsRepository: commentsRepository,
        repostsRepository: repostsRepository,
        authService: authService,
      ),
      ...additionalOverrides,
    ].cast(),
  );
  container.read(appForegroundProvider.notifier).setForeground(appForeground);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorObservers: navigatorObservers,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<FeedAutoAdvanceCubit>.value(
              value: mockAutoAdvanceCubit,
            ),
            BlocProvider<VideoPlaybackStatusCubit>.value(
              value: mockPlaybackCubit,
            ),
            BlocProvider<VideoVolumeCubit>.value(value: mockVolumeCubit),
            BlocProvider<FeedImmersiveCubit>.value(value: immersiveCubit),
          ],
          child: Scaffold(
            body: FeedVideos(
              videos: videos,
              onNearEnd: () {},
              isActive: isActive,
              hasMore: hasMore,
              isLoadingMore: isLoadingMore,
              onActiveVideoChanged: onActiveVideoChanged,
            ),
          ),
        ),
      ),
    ),
  );
  // InfiniteVideoFeed starts a first-frame grace timer for the initial item.
  // Drain it here so overlay-only tests do not leave pending timers behind.
  await tester.pump(const Duration(seconds: 3));
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(const VideoInteractionsSubscriptionRequested());
    registerFallbackValue(FeatureFlag.communityContentWarnings);
    registerFallbackValue(ContentLabel.gambling);
    registerFallbackValue(ContentFilterPreference.warn);
  });

  setUp(() {
    InfiniteVideoFeed.debugIsSupportedOverride = false;
  });

  tearDown(() {
    InfiniteVideoFeed.debugIsSupportedOverride = null;
  });

  // -------------------------------------------------------------------------
  // _FeedLoadingOrRestrictedOverlayView modes
  // -------------------------------------------------------------------------
  group('_FeedLoadingOrRestrictedOverlayView', () {
    testWidgets(
      'shows $VideoLoadingPlaceholder while moderation cubit is loading',
      (tester) async {
        final video = _makeVideo();
        await _pumpFeedVideos(tester, videos: [video]);
        // With debugIsSupportedOverride=false, no controller is created so
        // loadingBuilder is always invoked.
        await tester.pump();

        expect(find.byType(VideoLoadingPlaceholder), findsOneWidget);
      },
    );

    testWidgets(
      'shows $PooledVideoErrorOverlay when moderation cubit emits restricted',
      (tester) async {
        // Test _FeedLoadingOrRestrictedOverlayView directly by providing a
        // mock FeedLoadingModerationCubit in restricted state. The production
        // _FeedLoadingOrRestrictedOverlay creates its own BlocProvider, so
        // we bypass that wrapper and test the view widget directly.
        final video = _makeVideo();
        final restrictedCubit = _MockFeedLoadingModerationCubit();
        when(() => restrictedCubit.state).thenReturn(
          const FeedLoadingModerationState(
            status: FeedLoadingModerationStatus.restricted,
          ),
        );
        whenListen(
          restrictedCubit,
          const Stream<FeedLoadingModerationState>.empty(),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<FeedLoadingModerationCubit>.value(
              value: restrictedCubit,
              child: Scaffold(
                body: SizedBox.expand(
                  child: Builder(
                    builder: (context) {
                      final isRestricted = context.select(
                        (FeedLoadingModerationCubit c) => c.state.isRestricted,
                      );
                      if (isRestricted) {
                        return PooledVideoErrorOverlay(
                          video: video,
                          onRetry: () {},
                          errorType: VideoErrorType.notFound,
                        );
                      }
                      return VideoLoadingPlaceholder(
                        videoId: video.id,
                        index: 0,
                        thumbnailUrl: video.thumbnailUrl,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(PooledVideoErrorOverlay), findsOneWidget);
        expect(find.byType(VideoLoadingPlaceholder), findsNothing);
      },
    );

    testWidgets(
      'auto-authorizes age-restricted loading media when preferences allow show',
      (tester) async {
        const sha256 =
            '8ad13ea11bed00b086a4c93d1bbc43f85953cf05f7715bfb16200663b6e3c0ac';
        final video = _makeVideo(
          videoUrl: 'https://media.divine.video/$sha256',
          sha256: sha256,
        );
        final moderationService = _MockVideoModerationStatusService();
        when(() => moderationService.fetchStatus(sha256)).thenAnswer(
          (_) async => const VideoModerationStatus(
            moderated: true,
            blocked: false,
            quarantined: false,
            ageRestricted: true,
            needsReview: false,
            aiGenerated: false,
          ),
        );
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        when(
          mediaAuthInterceptor.canAutoAuthorizeAdultMedia,
        ).thenAnswer((_) async => true);
        when(
          () => mediaAuthInterceptor.createAutoAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        ).thenAnswer(
          (_) async => const ViewerAuthAuthorized({
            'Authorization': 'Nostr auto-token',
          }),
        );

        await _pumpFeedVideos(
          tester,
          videos: [video],
          moderationService: moderationService,
          mediaAuthInterceptor: mediaAuthInterceptor,
        );
        await tester.pump();

        verify(
          () => mediaAuthInterceptor.createAutoAuthHeadersForAdultMedia(
            sha256Hash: sha256,
            url: 'https://media.divine.video/$sha256',
            serverUrl: 'https://media.divine.video',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'does not mark verifying for age-restricted loading media when '
      'preferences do not allow auto-show',
      (tester) async {
        const sha256 =
            '8ad13ea11bed00b086a4c93d1bbc43f85953cf05f7715bfb16200663b6e3c0ac';
        final video = _makeVideo(
          videoUrl: 'https://media.divine.video/$sha256',
          sha256: sha256,
        );
        final moderationService = _MockVideoModerationStatusService();
        when(() => moderationService.fetchStatus(sha256)).thenAnswer(
          (_) async => const VideoModerationStatus(
            moderated: true,
            blocked: false,
            quarantined: false,
            ageRestricted: true,
            needsReview: false,
            aiGenerated: false,
          ),
        );
        final mediaAuthInterceptor = _MockMediaAuthInterceptor();
        when(
          mediaAuthInterceptor.canAutoAuthorizeAdultMedia,
        ).thenAnswer((_) async => false);
        final playbackStatusCubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          moderationService: moderationService,
          mediaAuthInterceptor: mediaAuthInterceptor,
          videoPlaybackStatusCubit: playbackStatusCubit,
        );
        await tester.pump();

        verifyNever(() => playbackStatusCubit.markVerifying(video.id));
        verifyNever(
          () => mediaAuthInterceptor.createAutoAuthHeadersForAdultMedia(
            sha256Hash: any(named: 'sha256Hash'),
            url: any(named: 'url'),
            serverUrl: any(named: 'serverUrl'),
          ),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Overlay mode switching via VideoPlaybackStatusCubit
  // -------------------------------------------------------------------------
  group('overlay mode switching', () {
    testWidgets(
      'shows $ModeratedContentOverlay for forbidden playback status',
      (tester) async {
        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.forbidden, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump();

        expect(find.byType(ModeratedContentOverlay), findsOneWidget);
      },
    );

    testWidgets(
      'shows $ModeratedContentOverlay for ageRestricted playback status',
      (tester) async {
        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ageRestricted, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump();

        expect(find.byType(ModeratedContentOverlay), findsOneWidget);
      },
    );

    testWidgets('shows $ContentWarningBlurOverlay when video has warnLabels', (
      tester,
    ) async {
      final video = _makeVideo(warnLabels: ['nsfw']);
      final cubit = _MockVideoPlaybackStatusCubit()
        ..stub(PlaybackStatus.ready, video.id);

      await _pumpFeedVideos(
        tester,
        videos: [video],
        videoPlaybackStatusCubit: cubit,
      );
      await tester.pump();

      expect(find.byType(ContentWarningBlurOverlay), findsOneWidget);
      // Neither moderation overlay should be showing.
      expect(find.byType(ModeratedContentOverlay), findsNothing);
    });

    testWidgets(
      'shows $ContentWarningBlurOverlay when the community surfaces a warn '
      'label on an otherwise-unwarned video',
      (tester) async {
        final video = _makeVideo(); // no creator/trusted warn labels
        final repository = _MockCommunityContentLabelRepository();
        when(
          () => repository.communityLabelsForVideo(video),
        ).thenAnswer((_) async => {'gambling'});
        final filter = _MockContentFilterService();
        when(
          () => filter.getPreference(ContentLabel.gambling),
        ).thenReturn(ContentFilterPreference.warn);
        final service = CommunityContentLabelService(
          repository: repository,
          contentFilterService: filter,
        );
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          additionalOverrides: [
            communityContentLabelServiceProvider.overrideWith((ref) => service),
            featureFlagServiceProvider.overrideWithValue(_communityFlagsOn()),
          ],
        );
        // Let the background prefetch resolve and the notifier rebuild.
        await tester.pump();
        await tester.pump();

        expect(find.byType(ContentWarningBlurOverlay), findsOneWidget);
      },
    );

    testWidgets(
      'gates autoplay for a community-warned video (no creator label)',
      (tester) async {
        final video = _makeVideo(); // no creator/trusted warn labels
        final repository = _MockCommunityContentLabelRepository();
        when(
          () => repository.communityLabelsForVideo(video),
        ).thenAnswer((_) async => {'gambling'});
        final filter = _MockContentFilterService();
        when(
          () => filter.getPreference(ContentLabel.gambling),
        ).thenReturn(ContentFilterPreference.warn);
        final service = CommunityContentLabelService(
          repository: repository,
          contentFilterService: filter,
        );
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          additionalOverrides: [
            communityContentLabelServiceProvider.overrideWith((ref) => service),
            featureFlagServiceProvider.overrideWithValue(_communityFlagsOn()),
          ],
        );
        // Let the background prefetch resolve and the notifier rebuild.
        await tester.pump();
        await tester.pump();

        // The blur overlay is showing (asserted by the sibling test); the
        // autoplay gate must agree, or the video plays behind the blur.
        final feed = tester.widget<InfiniteVideoFeed>(
          find.byType(InfiniteVideoFeed),
        );
        expect(
          feed.canAutoPlay!(video),
          isFalse,
          reason:
              'a community-warned video must not autoplay behind '
              'the overlay',
        );
      },
    );

    testWidgets(
      'shows interactive overlay when status is ready and no content warning',
      (tester) async {
        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump();

        // Neither a moderation overlay nor a content warning overlay should
        // be visible when the video is ready with no restrictions.
        expect(find.byType(ModeratedContentOverlay), findsNothing);
        expect(find.byType(ContentWarningBlurOverlay), findsNothing);
      },
    );

    testWidgets('gates autoplay for warned video until View Anyway is tapped', (
      tester,
    ) async {
      final video = _makeVideo(warnLabels: ['nsfw']);
      final cubit = _MockVideoPlaybackStatusCubit()
        ..stub(PlaybackStatus.ready, video.id);

      await _pumpFeedVideos(
        tester,
        videos: [video],
        videoPlaybackStatusCubit: cubit,
      );
      await tester.pump();

      final feed = tester.widget<InfiniteVideoFeed>(
        find.byType(InfiniteVideoFeed),
      );
      expect(feed.canAutoPlay, isNotNull);
      expect(
        feed.canAutoPlay!(video),
        isFalse,
        reason: 'a warned video must not autoplay behind the overlay',
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.contentWarningViewAnyway));
      await tester.pump();

      expect(find.byType(ContentWarningBlurOverlay), findsNothing);
      final revealedFeed = tester.widget<InfiniteVideoFeed>(
        find.byType(InfiniteVideoFeed),
      );
      expect(
        revealedFeed.canAutoPlay!(video),
        isTrue,
        reason: 'View Anyway opens the autoplay gate for this video',
      );
    });

    testWidgets('allows autoplay for video without content warning', (
      tester,
    ) async {
      final video = _makeVideo();
      final cubit = _MockVideoPlaybackStatusCubit()
        ..stub(PlaybackStatus.ready, video.id);

      await _pumpFeedVideos(
        tester,
        videos: [video],
        videoPlaybackStatusCubit: cubit,
      );
      await tester.pump();

      final feed = tester.widget<InfiniteVideoFeed>(
        find.byType(InfiniteVideoFeed),
      );
      expect(feed.canAutoPlay!(video), isTrue);
    });

    testWidgets('the author row is a 48dp tap target', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        InfiniteVideoFeed.debugIsSupportedOverride = true;

        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump(const Duration(seconds: 4));

        final authorName = find.bySemanticsIdentifier('video_author_name');
        expect(authorName, findsOneWidget);

        // The name node sits inside the row's tappable semantics node. Walk
        // upward from that stable identifier so removing the profile action
        // fails this test instead of silently dropping the row from a global
        // list of tap targets.
        SemanticsNode? authorRow = tester.getSemantics(authorName);
        while (authorRow != null &&
            !authorRow.getSemanticsData().hasAction(SemanticsAction.tap)) {
          authorRow = authorRow.parent;
        }

        expect(
          authorRow,
          isNotNull,
          reason: 'the author row must expose a profile tap action',
        );
        expect(
          authorRow!.rect.height,
          greaterThanOrEqualTo(48),
          reason: 'the author row must be at least 48dp tall',
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('the profile target stops at the author content', (
      tester,
    ) async {
      InfiniteVideoFeed.debugIsSupportedOverride = true;

      final video = _makeVideo();
      final cubit = _MockVideoPlaybackStatusCubit()
        ..stub(PlaybackStatus.ready, video.id);

      await _pumpFeedVideos(
        tester,
        videos: [video],
        videoPlaybackStatusCubit: cubit,
      );
      await tester.pump(const Duration(seconds: 4));

      final target = find
          .ancestor(
            of: find.bySemanticsIdentifier('video_author_name'),
            matching: find.byType(GestureDetector),
          )
          .first;
      final targetRect = tester.getRect(target);
      expect(
        targetRect.height,
        greaterThanOrEqualTo(48),
        reason: 'sanity: this is the 48dp profile target, not an inner one',
      );

      // The surface returns false from its own hit test — both of its
      // GestureDetectors are translucent, and a translucent box adds itself to
      // the path but reports a miss. So ownership has to be read off the path,
      // and against the whole subtree rather than its root proxy, which never
      // gets added at all.
      final surface = <RenderObject>{};
      void collect(Element element) {
        final renderObject = element.renderObject;
        if (renderObject != null) surface.add(renderObject);
        element.visitChildren(collect);
      }

      collect(find.byType(PlayerGestureSurface).evaluate().single);

      bool videoOwns(Offset point) => tester
          .hitTestOnBinding(point)
          .path
          .any((entry) => surface.contains(entry.target));

      // Inside the target the profile wins, across the FULL 58dp — 2dp above
      // the bottom edge is below the meta text, so deferring to the child
      // would drop it and leave only the ~20dp name line really tappable.
      expect(
        videoOwns(Offset(targetRect.left + 4, targetRect.bottom - 2)),
        isFalse,
        reason: 'the whole 48dp target must navigate to the profile',
      );

      // Past its trailing edge the video takes over again. An opaque detector
      // filling the Expanded reported false here for another 400dp, taking
      // double-tap-to-like and press-and-hold-to-peek off empty video.
      for (final beyond in [2.0, 40.0, 200.0]) {
        expect(
          videoOwns(Offset(targetRect.right + beyond, targetRect.center.dy)),
          isTrue,
          reason: 'video keeps its gestures ${beyond}dp past the author text',
        );
      }
    });

    testWidgets('exposes localized semantics label and hint', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        InfiniteVideoFeed.debugIsSupportedOverride = true;

        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump(const Duration(seconds: 4));

        final l10n = lookupAppLocalizations(const Locale('en'));
        final surfaceFinder = find.bySemanticsLabel(l10n.videoPlayerPlayVideo);

        expect(surfaceFinder, findsOneWidget);
        final semanticsNode = tester.getSemantics(surfaceFinder);
        expect(semanticsNode.flagsCollection.isButton, isTrue);
        expect(semanticsNode.hint, equals(l10n.videoPlayerTapHint));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('omits double-tap-like semantics hint on own video', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        InfiniteVideoFeed.debugIsSupportedOverride = true;

        final video = _makeVideo();
        final authService = createMockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(video.pubkey);
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          authService: authService,
        );
        await tester.pump(const Duration(seconds: 4));

        final l10n = lookupAppLocalizations(const Locale('en'));
        final surfaceFinder = find.bySemanticsLabel(l10n.videoPlayerPlayVideo);

        expect(surfaceFinder, findsOneWidget);
        final semanticsNode = tester.getSemantics(surfaceFinder);
        expect(semanticsNode.flagsCollection.isButton, isTrue);
        expect(semanticsNode.hint, isEmpty);
      } finally {
        semantics.dispose();
      }
    });
  });

  // -------------------------------------------------------------------------
  // Kill-switch gates the read path and is reactive (#5720 M3/M8)
  // -------------------------------------------------------------------------
  group('community kill-switch', () {
    testWidgets(
      'ignores cached crossed-threshold community labels when flag is off',
      (tester) async {
        final video = _makeVideo(); // no creator warn labels
        final repository = _MockCommunityContentLabelRepository();
        when(
          () => repository.communityLabelsForVideo(video),
        ).thenAnswer((_) async => {'gambling'});
        final filter = _MockContentFilterService();
        when(
          () => filter.getPreference(ContentLabel.gambling),
        ).thenReturn(ContentFilterPreference.warn);
        final service = CommunityContentLabelService(
          repository: repository,
          contentFilterService: filter,
        );
        // Populate the cache so the crossed label is present regardless of the
        // (off) flag — this is the "already cached at flip time" scenario.
        await service.prefetch(video);
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          additionalOverrides: [
            communityContentLabelServiceProvider.overrideWith((ref) => service),
            isFeatureEnabledProvider(
              FeatureFlag.communityContentWarnings,
            ).overrideWithValue(false),
          ],
        );
        await tester.pump();
        await tester.pump();

        // Kill-switch off: the cached community label must neither blur the
        // video nor gate its autoplay. Deleting the read-path gate turns this
        // red.
        expect(find.byType(ContentWarningBlurOverlay), findsNothing);
        final feed = tester.widget<InfiniteVideoFeed>(
          find.byType(InfiniteVideoFeed),
        );
        expect(feed.canAutoPlay!(video), isTrue);
      },
    );

    testWidgets(
      'drops the community blur and reopens the gate when flag flips off '
      'at runtime',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'ff_communityContentWarnings': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final flags = FeatureFlagService(
          prefs,
          const BuildConfiguration(),
          canOverrideInternalFlags: () => true,
        );
        await flags.initialize();
        addTearDown(flags.dispose);

        final video = _makeVideo();
        final repository = _MockCommunityContentLabelRepository();
        when(
          () => repository.communityLabelsForVideo(video),
        ).thenAnswer((_) async => {'gambling'});
        final filter = _MockContentFilterService();
        when(
          () => filter.getPreference(ContentLabel.gambling),
        ).thenReturn(ContentFilterPreference.warn);
        final service = CommunityContentLabelService(
          repository: repository,
          contentFilterService: filter,
        );
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          additionalOverrides: [
            communityContentLabelServiceProvider.overrideWith((ref) => service),
            featureFlagServiceProvider.overrideWithValue(flags),
          ],
        );
        // Let the prefetch resolve and the notifier rebuild.
        await tester.pump();
        await tester.pump();

        expect(find.byType(ContentWarningBlurOverlay), findsOneWidget);
        expect(
          tester
              .widget<InfiniteVideoFeed>(find.byType(InfiniteVideoFeed))
              .canAutoPlay!(video),
          isFalse,
        );

        await flags.setFlag(FeatureFlag.communityContentWarnings, false);
        await tester.pump();
        await tester.pump();

        // No restart required: the blur clears and the gate reopens.
        expect(find.byType(ContentWarningBlurOverlay), findsNothing);
        expect(
          tester
              .widget<InfiniteVideoFeed>(find.byType(InfiniteVideoFeed))
              .canAutoPlay!(video),
          isTrue,
        );
      },
    );

    testWidgets(
      'starts prefetch on a mounted overlay when the flag flips on',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'ff_communityContentWarnings': false,
        });
        final prefs = await SharedPreferences.getInstance();
        final flags = FeatureFlagService(
          prefs,
          const BuildConfiguration(),
          canOverrideInternalFlags: () => true,
        );
        await flags.initialize();
        addTearDown(flags.dispose);

        final video = _makeVideo();
        final repository = _MockCommunityContentLabelRepository();
        when(
          () => repository.communityLabelsForVideo(video),
        ).thenAnswer((_) async => const <String>{});
        final filter = _MockContentFilterService();
        final service = CommunityContentLabelService(
          repository: repository,
          contentFilterService: filter,
        );
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          additionalOverrides: [
            communityContentLabelServiceProvider.overrideWith((ref) => service),
            featureFlagServiceProvider.overrideWithValue(flags),
          ],
        );
        await tester.pump();

        // Flag off at mount: initState's prefetch is a no-op.
        verifyNever(() => repository.communityLabelsForVideo(video));

        await flags.setFlag(FeatureFlag.communityContentWarnings, true);
        await tester.pump();
        await tester.pump();

        verify(() => repository.communityLabelsForVideo(video)).called(1);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Help-classify action slot gating (#5720 M5)
  // -------------------------------------------------------------------------
  group('help-classify action slot', () {
    testWidgets(
      'is not inserted into the action column when the flag is off',
      (tester) async {
        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          additionalOverrides: [
            isFeatureEnabledProvider(
              FeatureFlag.communityContentWarnings,
            ).overrideWithValue(false),
          ],
        );
        await tester.pump();

        // With the flag off the slot must be absent entirely — leaving a
        // zero-size SizedBox child in the Column(spacing: 20) adds a
        // permanent gap between Report and More.
        expect(find.byType(HelpClassifyActionButton), findsNothing);
      },
    );

    testWidgets(
      'is not inserted while the label repository is not ready',
      (tester) async {
        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          authService: _viewerAuthService(),
          additionalOverrides: [
            isFeatureEnabledProvider(
              FeatureFlag.communityContentWarnings,
            ).overrideWithValue(true),
            communityContentLabelRepositoryProvider.overrideWithValue(null),
          ],
        );
        await tester.pump();

        // Flag on but the signer-backed repository is still null: the button
        // could only render a zero-size child, which still consumes a
        // Column(spacing: 20) gap. The slot must stay out entirely (#7475).
        expect(find.byType(HelpClassifyActionButton), findsNothing);
      },
    );

    testWidgets(
      'is inserted into the action column when the action is available',
      (tester) async {
        final video = _makeVideo();
        final repository = _MockCommunityContentLabelRepository();
        when(
          () => repository.communityLabelsForVideo(video),
        ).thenAnswer((_) async => <String>{});
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          authService: _viewerAuthService(),
          additionalOverrides: [
            isFeatureEnabledProvider(
              FeatureFlag.communityContentWarnings,
            ).overrideWithValue(true),
            communityContentLabelRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
        );
        await tester.pump();

        expect(find.byType(HelpClassifyActionButton), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Hide-similar must not persist community-only labels (#5720 M2)
  // -------------------------------------------------------------------------
  group('community hide-similar', () {
    testWidgets(
      'does not persist a hide preference for a community-only warning',
      (tester) async {
        final video = _makeVideo(); // no creator warn labels
        final repository = _MockCommunityContentLabelRepository();
        when(
          () => repository.communityLabelsForVideo(video),
        ).thenAnswer((_) async => {'gambling'});
        final communityFilter = _MockContentFilterService();
        when(
          () => communityFilter.getPreference(ContentLabel.gambling),
        ).thenReturn(ContentFilterPreference.warn);
        final service = CommunityContentLabelService(
          repository: repository,
          contentFilterService: communityFilter,
        );
        // The provider-backed filter service that hide-similar writes to.
        final hideFilter = _MockContentFilterService();
        when(hideFilter.initialize).thenAnswer((_) async {});
        when(
          () => hideFilter.setPreference(any(), any()),
        ).thenAnswer((_) async {});
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          additionalOverrides: [
            communityContentLabelServiceProvider.overrideWith((ref) => service),
            featureFlagServiceProvider.overrideWithValue(_communityFlagsOn()),
            contentFilterServiceProvider.overrideWith((ref) => hideFilter),
          ],
        );
        await tester.pump();
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.contentWarningHideAllLikeThis));
        await tester.pump();
        await tester.pump();

        // An unverified community-only warning must never become a persisted
        // global hide preference for the category (warn-only v1 posture).
        verifyNever(() => hideFilter.setPreference(any(), any()));
      },
    );

    testWidgets(
      'still persists a hide preference for a creator warning',
      (tester) async {
        final video = _makeVideo(warnLabels: ['gambling']);
        final hideFilter = _MockContentFilterService();
        when(hideFilter.initialize).thenAnswer((_) async {});
        when(
          () => hideFilter.getPreference(any()),
        ).thenReturn(ContentFilterPreference.warn);
        when(
          () => hideFilter.setPreference(any(), any()),
        ).thenAnswer((_) async {});
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
          additionalOverrides: [
            contentFilterServiceProvider.overrideWith((ref) => hideFilter),
          ],
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.contentWarningHideAllLikeThis));
        await tester.pump();
        await tester.pump();

        verify(
          () => hideFilter.setPreference(
            ContentLabel.gambling,
            ContentFilterPreference.hide,
          ),
        ).called(1);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Immersive (hold-to-peek) viewing — #6234
  // -------------------------------------------------------------------------
  group('hold to peek', () {
    // Reads the fade the [FeedImmersiveChrome] around [of] applies. Anchored
    // on the wrapped widget rather than on FeedImmersiveChrome itself: each
    // chrome layer has its own wrapper, and the overlay actions carry an
    // unrelated AnimatedOpacity of their own further down.
    double chromeOpacity(WidgetTester tester, {required Type of}) => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(of),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;

    // pumpAndSettle can't be used here: InfiniteVideoFeed keeps its own
    // timers running, so settle never arrives. The fade is a fixed duration.
    Future<void> pumpFade(WidgetTester tester) => tester.pump(
      kFeedImmersiveFadeDuration + const Duration(milliseconds: 50),
    );

    testWidgets('hides the overlay chrome while held and restores on release', (
      tester,
    ) async {
      final video = _makeVideo();
      final immersiveCubit = FeedImmersiveCubit();

      await _pumpFeedVideos(
        tester,
        videos: [video],
        feedImmersiveCubit: immersiveCubit,
      );
      await tester.pump();

      expect(chromeOpacity(tester, of: VideoOverlayActions), equals(1.0));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InfiniteVideoFeed)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await pumpFade(tester);

      expect(immersiveCubit.state.isImmersive, isTrue);
      expect(chromeOpacity(tester, of: VideoOverlayActions), equals(0.0));

      await gesture.up();
      await pumpFade(tester);

      expect(immersiveCubit.state.isImmersive, isFalse);
      expect(chromeOpacity(tester, of: VideoOverlayActions), equals(1.0));
    });

    testWidgets('restores the chrome when the pointer is cancelled', (
      tester,
    ) async {
      final video = _makeVideo();
      final immersiveCubit = FeedImmersiveCubit();

      await _pumpFeedVideos(
        tester,
        videos: [video],
        feedImmersiveCubit: immersiveCubit,
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InfiniteVideoFeed)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(immersiveCubit.state.isImmersive, isTrue);

      // LongPressGestureRecognizer reports neither onLongPressEnd nor
      // onLongPressCancel for a pointer cancelled after acceptance, so
      // without the raw Listener backstop the chrome would stay hidden.
      await gesture.cancel();
      await pumpFade(tester);

      expect(immersiveCubit.state.isImmersive, isFalse);
      expect(chromeOpacity(tester, of: VideoOverlayActions), equals(1.0));
    });

    testWidgets('a second finger lifting mid-hold does not end the peek', (
      tester,
    ) async {
      final video = _makeVideo();
      final immersiveCubit = FeedImmersiveCubit();

      await _pumpFeedVideos(
        tester,
        videos: [video],
        feedImmersiveCubit: immersiveCubit,
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(InfiniteVideoFeed));
      final holdFinger = await tester.startGesture(center, pointer: 1);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await pumpFade(tester);

      expect(immersiveCubit.state.isImmersive, isTrue);

      // A second finger touches down and lifts while the first still holds.
      final secondFinger = await tester.startGesture(
        center + const Offset(24, 24),
        pointer: 2,
      );
      await secondFinger.up();
      await pumpFade(tester);

      expect(
        immersiveCubit.state.isImmersive,
        isTrue,
        reason: 'a second finger must not cut a hold the first finger keeps',
      );
      expect(chromeOpacity(tester, of: VideoOverlayActions), equals(0.0));

      await holdFinger.up();
      await pumpFade(tester);

      expect(immersiveCubit.state.isImmersive, isFalse);
      expect(chromeOpacity(tester, of: VideoOverlayActions), equals(1.0));
    });

    testWidgets('hides the paused play indicator too', (tester) async {
      // The play indicator only mounts once a controller exists.
      InfiniteVideoFeed.debugIsSupportedOverride = true;
      final video = _makeVideo();
      final immersiveCubit = FeedImmersiveCubit();

      await _pumpFeedVideos(
        tester,
        videos: [video],
        feedImmersiveCubit: immersiveCubit,
      );
      await tester.pump(const Duration(seconds: 4));

      expect(find.byType(PausedVideoOverlay), findsOneWidget);
      expect(chromeOpacity(tester, of: PausedVideoOverlay), equals(1.0));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InfiniteVideoFeed)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await pumpFade(tester);

      expect(
        chromeOpacity(tester, of: PausedVideoOverlay),
        equals(0.0),
        reason: 'the play indicator covers the frame the peek reveals',
      );

      await gesture.up();
      await pumpFade(tester);

      expect(chromeOpacity(tester, of: PausedVideoOverlay), equals(1.0));
    });

    testWidgets('a short tap leaves the chrome alone', (tester) async {
      final video = _makeVideo();
      final immersiveCubit = FeedImmersiveCubit();

      await _pumpFeedVideos(
        tester,
        videos: [video],
        feedImmersiveCubit: immersiveCubit,
      );
      await tester.pump();

      await tester.tap(find.byType(InfiniteVideoFeed));
      await pumpFade(tester);

      expect(immersiveCubit.state.isImmersive, isFalse);
      expect(chromeOpacity(tester, of: VideoOverlayActions), equals(1.0));
    });

    testWidgets('lowers the flag when the feed is torn down mid-hold', (
      tester,
    ) async {
      final video = _makeVideo();
      final immersiveCubit = FeedImmersiveCubit();
      addTearDown(immersiveCubit.close);

      await _pumpFeedVideos(
        tester,
        videos: [video],
        feedImmersiveCubit: immersiveCubit,
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InfiniteVideoFeed)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(immersiveCubit.state.isImmersive, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));

      expect(
        immersiveCubit.state.isImmersive,
        isFalse,
        reason: 'a cubit outliving the overlay must not stay immersive',
      );

      await gesture.cancel();
    });

    testWidgets(
      'keeps the action rail out from under the peek gesture',
      (tester) async {
        // When the rail sat *inside* the long-press detector, any press held
        // past kLongPressTimeout anywhere on Report/More/Share was claimed by
        // the video's long-press: the button's tap recognizer only accepts on
        // pointer-up, so it lost the arena, the tap was swallowed and the
        // control faded out under the viewer's finger.
        //
        // Asserted structurally rather than by pressing a button: the action
        // icons are SVG-backed and lay out at zero size under `flutter test`,
        // so there is no button rect to press. Ancestry is the invariant that
        // actually matters — a sibling rail cannot lose the arena.
        final video = _makeVideo();

        await _pumpFeedVideos(tester, videos: [video]);
        await tester.pump();

        final longPressAncestors = tester
            .widgetList<GestureDetector>(
              find.ancestor(
                of: find.byType(VideoOverlayActions),
                matching: find.byType(GestureDetector),
              ),
            )
            .where((detector) => detector.onLongPressStart != null);

        expect(
          longPressAncestors,
          isEmpty,
          reason: 'the peek gesture must not sit above the action rail',
        );
      },
    );

    testWidgets('publishes no long-press semantics action', (tester) async {
      // A semantics long-press delivers no pointer events, so the release
      // path could never run and a screen-reader user would be stranded
      // with every control hidden and pointer-blocked.
      final handle = tester.ensureSemantics();
      final video = _makeVideo();
      final immersiveCubit = FeedImmersiveCubit();
      addTearDown(immersiveCubit.close);

      await _pumpFeedVideos(
        tester,
        videos: [video],
        feedImmersiveCubit: immersiveCubit,
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final node = tester.getSemantics(
        find.bySemanticsLabel(l10n.videoPlayerPlayVideo).first,
      );

      expect(
        node.getSemanticsData().hasAction(SemanticsAction.longPress),
        isFalse,
        reason: 'the peek must not be reachable from a screen reader',
      );
      handle.dispose();
    });

    testWidgets('cannot peek past a content warning gate', (tester) async {
      // The gate modes are early returns in _resolveOverlayMode, so the
      // gesture does not exist in that subtree. Nothing else enforces it —
      // if the blur ever becomes a sibling in the interactive Stack, a hold
      // would silently reveal warned content.
      final video = _makeVideo(warnLabels: ['nudity']);
      final immersiveCubit = FeedImmersiveCubit();
      addTearDown(immersiveCubit.close);

      await _pumpFeedVideos(
        tester,
        videos: [video],
        feedImmersiveCubit: immersiveCubit,
      );
      await tester.pump();

      expect(find.byType(ContentWarningBlurOverlay), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InfiniteVideoFeed)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await pumpFade(tester);

      expect(
        immersiveCubit.state.isImmersive,
        isFalse,
        reason: 'a hold must never uncover gated content',
      );
      expect(find.byType(ContentWarningBlurOverlay), findsOneWidget);

      await gesture.up();
    });

    testWidgets(
      'restores the chrome when the overlay mode flips mid-hold',
      (tester) async {
        // The one release path `dispose()` cannot cover: a community label
        // resolving mid-hold swaps the interactive subtree — and with it the
        // Listener — for the blur overlay, while __OverlayState itself
        // survives. The exit then depends on Flutter still delivering the
        // terminal pointer event to the hit path captured at pointer-down.
        final video = _makeVideo(); // no creator/trusted warn labels
        final labels = Completer<Set<String>>();
        final repository = _MockCommunityContentLabelRepository();
        when(
          () => repository.communityLabelsForVideo(video),
        ).thenAnswer((_) => labels.future);
        final filter = _MockContentFilterService();
        when(
          () => filter.getPreference(ContentLabel.gambling),
        ).thenReturn(ContentFilterPreference.warn);
        final service = CommunityContentLabelService(
          repository: repository,
          contentFilterService: filter,
        );
        final immersiveCubit = FeedImmersiveCubit();
        addTearDown(immersiveCubit.close);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          feedImmersiveCubit: immersiveCubit,
          additionalOverrides: [
            communityContentLabelServiceProvider.overrideWith((ref) => service),
            featureFlagServiceProvider.overrideWithValue(_communityFlagsOn()),
          ],
        );
        await tester.pump();

        // Hold while the item is still interactive.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(InfiniteVideoFeed)),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        expect(immersiveCubit.state.isImmersive, isTrue);

        // The label lands mid-hold and unmounts the Listener.
        labels.complete({'gambling'});
        await tester.pump();
        await tester.pump();
        expect(
          find.byType(ContentWarningBlurOverlay),
          findsOneWidget,
          reason: 'the flip must actually replace the interactive subtree',
        );

        await gesture.up();
        await pumpFade(tester);

        expect(
          immersiveCubit.state.isImmersive,
          isFalse,
          reason: 'releasing after a mid-hold mode flip must restore chrome',
        );
      },
    );
  });

  group('playback length cap', () {
    testWidgets('caps InfiniteVideoFeed playback at the feed cap', (
      tester,
    ) async {
      final video = _makeVideo();

      await _pumpFeedVideos(tester, videos: [video]);
      await tester.pump();

      final feed = tester.widget<InfiniteVideoFeed>(
        find.byType(InfiniteVideoFeed),
      );
      expect(
        feed.maxPlaybackDuration,
        AppConstants.maxFeedPlaybackDuration,
        reason:
            'Without the cap a 60s file referenced by a foreign Nostr client '
            'plays in full in the feed.',
      );
    });
  });

  group('activity wiring', () {
    testWidgets('passes effective activity through to InfiniteVideoFeed', (
      tester,
    ) async {
      final video = _makeVideo();

      await _pumpFeedVideos(tester, videos: [video], isActive: false);
      await tester.pump();

      final feed = tester.widget<InfiniteVideoFeed>(
        find.byType(InfiniteVideoFeed),
      );
      expect(feed.isActive, isFalse);
    });

    testWidgets('pauses InfiniteVideoFeed while app is backgrounded', (
      tester,
    ) async {
      final video = _makeVideo();

      await _pumpFeedVideos(tester, videos: [video], appForeground: false);
      await tester.pump();

      final feed = tester.widget<InfiniteVideoFeed>(
        find.byType(InfiniteVideoFeed),
      );
      expect(feed.isActive, isFalse);
    });

    testWidgets(
      'mounts $DivineVideoMetricsTracker for active native playback',
      (tester) async {
        InfiniteVideoFeed.debugIsSupportedOverride = true;
        final video = _makeVideo();

        await _pumpFeedVideos(tester, videos: [video]);
        await tester.pump(const Duration(seconds: 4));

        expect(find.byType(DivineVideoMetricsTracker), findsOneWidget);
      },
    );

    testWidgets('route-aware callbacks toggle InfiniteVideoFeed activity', (
      tester,
    ) async {
      final video = _makeVideo();

      await _pumpFeedVideos(
        tester,
        videos: [video],
        navigatorObservers: <NavigatorObserver>[routeObserver],
      );
      await tester.pump();

      final feedFinder = find.byType(InfiniteVideoFeed);
      final state = tester.state<FeedVideosState>(find.byType(FeedVideos));

      expect(tester.widget<InfiniteVideoFeed>(feedFinder).isActive, isTrue);

      state.didPushNext();
      await tester.pump();
      expect(tester.widget<InfiniteVideoFeed>(feedFinder).isActive, isFalse);

      state.didPopNext();
      await tester.pump();
      expect(tester.widget<InfiniteVideoFeed>(feedFinder).isActive, isTrue);
    });

    testWidgets('clears scoped captions when active video changes', (
      tester,
    ) async {
      final firstVideo = _makeVideo();
      final secondVideo = _makeVideo(
        id: 'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1',
      );
      final container = await _pumpFeedVideos(
        tester,
        videos: [firstVideo, secondVideo],
      );
      await tester.pump();

      container
          .read(subtitleVisibilityOverrideProvider.notifier)
          .setForVideo(firstVideo.id, false);
      expect(container.read(subtitleVisibilityOverrideProvider), (
        videoId: firstVideo.id,
        visible: false,
      ));

      tester
          .widget<InfiniteVideoFeed>(find.byType(InfiniteVideoFeed))
          .onActiveVideoChanged
          ?.call(secondVideo, 1);
      await tester.pump();

      expect(container.read(subtitleVisibilityOverrideProvider), isNull);
    });

    testWidgets('clears scoped captions when rebuilt active on another video', (
      tester,
    ) async {
      final firstVideo = _makeVideo();
      final secondVideo = _makeVideo(
        id: 'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1',
      );
      final mockPlaybackCubit = _MockVideoPlaybackStatusCubit()
        ..stub(PlaybackStatus.ready, firstVideo.id);
      final mockAutoAdvanceCubit = _MockFeedAutoAdvanceCubit()
        ..stub(const FeedAutoAdvanceState());
      final mockVolumeCubit = _MockVideoVolumeCubit()..stub();
      final immersiveCubit = FeedImmersiveCubit();
      addTearDown(immersiveCubit.close);
      final container = ProviderContainer(
        overrides: _buildOverrides().cast(),
      );
      addTearDown(container.dispose);

      Future<void> pumpHarness({
        required List<VideoEvent> videos,
        required bool isActive,
      }) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<FeedAutoAdvanceCubit>.value(
                    value: mockAutoAdvanceCubit,
                  ),
                  BlocProvider<VideoPlaybackStatusCubit>.value(
                    value: mockPlaybackCubit,
                  ),
                  BlocProvider<VideoVolumeCubit>.value(value: mockVolumeCubit),
                  BlocProvider<FeedImmersiveCubit>.value(value: immersiveCubit),
                ],
                child: Scaffold(
                  body: FeedVideos(
                    videos: videos,
                    onNearEnd: () {},
                    isActive: isActive,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 3));
      }

      await pumpHarness(videos: [firstVideo], isActive: false);
      container
          .read(subtitleVisibilityOverrideProvider.notifier)
          .setForVideo(firstVideo.id, false);
      expect(container.read(subtitleVisibilityOverrideProvider), (
        videoId: firstVideo.id,
        visible: false,
      ));

      await pumpHarness(videos: [secondVideo], isActive: true);
      await tester.pump();

      expect(container.read(subtitleVisibilityOverrideProvider), isNull);
    });

    testWidgets('preserves scoped captions across route push and pop', (
      tester,
    ) async {
      final video = _makeVideo();
      final container = await _pumpFeedVideos(
        tester,
        videos: [video],
        navigatorObservers: <NavigatorObserver>[routeObserver],
      );
      await tester.pump();

      tester
          .widget<InfiniteVideoFeed>(find.byType(InfiniteVideoFeed))
          .onActiveVideoChanged
          ?.call(video, 0);
      container
          .read(subtitleVisibilityOverrideProvider.notifier)
          .setForVideo(video.id, false);

      final state = tester.state<FeedVideosState>(find.byType(FeedVideos));
      state.didPushNext();
      await tester.pump();
      state.didPopNext();
      await tester.pump();

      expect(container.read(subtitleVisibilityOverrideProvider), (
        videoId: video.id,
        visible: false,
      ));
    });

    testWidgets("dispose does not clear another video's scoped captions", (
      tester,
    ) async {
      final video = _makeVideo();
      const otherVideoId =
          'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1';
      final container = await _pumpFeedVideos(tester, videos: [video]);
      await tester.pump();

      tester
          .widget<InfiniteVideoFeed>(find.byType(InfiniteVideoFeed))
          .onActiveVideoChanged
          ?.call(video, 0);
      container
          .read(subtitleVisibilityOverrideProvider.notifier)
          .setForVideo(otherVideoId, false);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(container.read(subtitleVisibilityOverrideProvider), (
        videoId: otherVideoId,
        visible: false,
      ));
    });

    testWidgets("dispose clears the feed's own scoped captions", (
      tester,
    ) async {
      final video = _makeVideo();
      final container = await _pumpFeedVideos(tester, videos: [video]);
      await tester.pump();

      tester
          .widget<InfiniteVideoFeed>(find.byType(InfiniteVideoFeed))
          .onActiveVideoChanged
          ?.call(video, 0);
      container
          .read(subtitleVisibilityOverrideProvider.notifier)
          .setForVideo(video.id, false);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(container.read(subtitleVisibilityOverrideProvider), isNull);
    });

    testWidgets(
      'hides the paused affordance while the feed itself is inactive',
      (tester) async {
        InfiniteVideoFeed.debugIsSupportedOverride = true;
        final video = _makeVideo();

        await _pumpFeedVideos(
          tester,
          videos: [video],
          navigatorObservers: <NavigatorObserver>[routeObserver],
        );
        await tester.pump(const Duration(seconds: 4));

        final overlayFinder = find.byType(PausedVideoOverlay);
        expect(
          tester.widget<PausedVideoOverlay>(overlayFinder).isVisible,
          isTrue,
        );

        // Navigating away (a pushed route here; an opened comments/share
        // sheet drives the same feed-inactive gate) pauses the player but
        // resumes it on the way back, so the affordance must stay hidden.
        tester.state<FeedVideosState>(find.byType(FeedVideos)).didPushNext();
        await tester.pump();
        expect(
          tester.widget<PausedVideoOverlay>(overlayFinder).isVisible,
          isFalse,
        );

        tester.state<FeedVideosState>(find.byType(FeedVideos)).didPopNext();
        await tester.pump();
        expect(
          tester.widget<PausedVideoOverlay>(overlayFinder).isVisible,
          isTrue,
        );
      },
    );

    testWidgets(
      'hides the paused affordance while the app is backgrounded',
      (tester) async {
        InfiniteVideoFeed.debugIsSupportedOverride = true;
        final video = _makeVideo();

        await _pumpFeedVideos(tester, videos: [video]);
        await tester.pump(const Duration(seconds: 4));

        final overlayFinder = find.byType(PausedVideoOverlay);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(FeedVideos)),
          listen: false,
        );
        expect(
          tester.widget<PausedVideoOverlay>(overlayFinder).isVisible,
          isTrue,
        );

        // Backgrounding pauses the player; foregrounding resumes it. The
        // affordance must stay hidden while backgrounded. Guards the
        // appForeground factor specifically: the route test above stays
        // green if a refactor drops it, this one turns red.
        container.read(appForegroundProvider.notifier).setForeground(false);
        await tester.pump();
        expect(
          tester.widget<PausedVideoOverlay>(overlayFinder).isVisible,
          isFalse,
        );

        container.read(appForegroundProvider.notifier).setForeground(true);
        await tester.pump();
        expect(
          tester.widget<PausedVideoOverlay>(overlayFinder).isVisible,
          isTrue,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Pagination flush (didUpdateWidget)
  // -------------------------------------------------------------------------
  group('pagination flush', () {
    testWidgets('does not throw when hasMore and isLoadingMore change', (
      tester,
    ) async {
      final video = _makeVideo();
      var hasMore = false;
      var isLoadingMore = false;
      late StateSetter rebuildState;

      final mockPlaybackCubit = _MockVideoPlaybackStatusCubit()
        ..stub(PlaybackStatus.ready, video.id);
      final mockAutoAdvanceCubit = _MockFeedAutoAdvanceCubit()
        ..stub(const FeedAutoAdvanceState());
      final mockVolumeCubit = _MockVideoVolumeCubit()..stub();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(overrides: _buildOverrides().cast()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<FeedAutoAdvanceCubit>.value(
                  value: mockAutoAdvanceCubit,
                ),
                BlocProvider<VideoPlaybackStatusCubit>.value(
                  value: mockPlaybackCubit,
                ),
                BlocProvider<VideoVolumeCubit>.value(value: mockVolumeCubit),
              ],
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    rebuildState = setState;
                    return FeedVideos(
                      videos: [video],
                      onNearEnd: () {},
                      hasMore: hasMore,
                      isLoadingMore: isLoadingMore,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 4));

      // Simulate a pagination start.
      rebuildState(() {
        hasMore = true;
        isLoadingMore = true;
      });
      // Advance past InfiniteVideoFeed's 3-second grace-period timer.
      await tester.pump(const Duration(seconds: 4));

      // Simulate pagination complete.
      rebuildState(() {
        hasMore = false;
        isLoadingMore = false;
      });
      // Drain any pending 3-second grace-period timers created by
      // InfiniteVideoFeed._waitForFirstFrameOrGracePeriod so that the
      // widget tree can be disposed cleanly by the test framework.
      await tester.pump(const Duration(seconds: 4));
      // Replace the widget tree to stop InfiniteVideoFeed's async chain
      // from scheduling new timers, then drain the cleared queue.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
