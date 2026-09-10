// ABOUTME: Feed-level test that a community warning crossing the threshold
// ABOUTME: pauses the already-playing current video (#5720 M1, #6899).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/models/feature_flag_state.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/view_traffic_source.dart'
    show ViewTrafficSource;
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/community_content_label_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/community_content_label_service.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoPlaybackStatusCubit extends MockCubit<VideoPlaybackStatusState>
    implements VideoPlaybackStatusCubit {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

class _MockFeedAutoAdvanceCubit extends MockCubit<FeedAutoAdvanceState>
    implements FeedAutoAdvanceCubit {}

class _MockFeatureFlagService extends Mock implements FeatureFlagService {}

class _MockCommunityContentLabelRepository extends Mock
    implements CommunityContentLabelRepository {}

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockConnectionStatusService extends Mock
    implements ConnectionStatusService {}

class _MockVideoModerationStatusService extends Mock
    implements VideoModerationStatusService {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

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

FeatureFlagService _communityFlagsOn() {
  final service = _MockFeatureFlagService();
  when(() => service.isEnabled(any())).thenReturn(false);
  when(
    () => service.isEnabled(FeatureFlag.communityContentWarnings),
  ).thenReturn(true);
  when(() => service.currentState).thenReturn(
    FeatureFlagState({
      for (final flag in FeatureFlag.values)
        flag: flag == FeatureFlag.communityContentWarnings,
    }),
  );
  return service;
}

/// Counts native player method calls so a `pause` can be observed.
class _NativePlayerHarness {
  _NativePlayerHarness(this.tester);

  final WidgetTester tester;
  final List<String> methodCalls = <String>[];
  final Set<int> _installedPlayerIds = <int>{};

  static const _globalChannel = MethodChannel('divine_video_player');
  static const _codec = StandardMethodCodec();

  void install({Iterable<int> playerIds = const <int>[0]}) {
    DivineVideoPlayerController.resetIdCounterForTesting();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _globalChannel,
      (call) async => call.method == 'create' ? <Object?, Object?>{} : null,
    );

    for (final playerId in playerIds) {
      _installedPlayerIds.add(playerId);
      final playerChannel = MethodChannel(
        'divine_video_player/player_$playerId',
      );
      final eventChannelName = 'divine_video_player/player_$playerId/events';

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        playerChannel,
        (call) async {
          methodCalls.add(call.method);
          return null;
        },
      );

      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        eventChannelName,
        (message) async {
          final call = _codec.decodeMethodCall(message);
          if (call.method == 'listen') {
            scheduleMicrotask(() async {
              await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
                eventChannelName,
                _codec.encodeSuccessEnvelope(const <Object?, Object?>{
                  'status': 'ready',
                  'videoWidth': 1280,
                  'videoHeight': 720,
                  'isFirstFrameRendered': true,
                }),
                (_) {},
              );
            });
          }
          return _codec.encodeSuccessEnvelope(null);
        },
      );
    }
  }

  int countCalls(String method) =>
      methodCalls.where((call) => call == method).length;

  Future<void> dispose() async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _globalChannel,
      null,
    );
    for (final playerId in _installedPlayerIds) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('divine_video_player/player_$playerId'),
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'divine_video_player/player_$playerId/events',
        null,
      );
    }
    _installedPlayerIds.clear();
  }
}

const _testVideoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

VideoEvent _makeVideo() => VideoEvent(
  id: _testVideoId,
  pubkey: _testPubkey,
  createdAt: 1704067200,
  content: 'Test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
  videoUrl: 'https://example.com/video.mp4',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const VideoInteractionsSubscriptionRequested());
    registerFallbackValue(FeatureFlag.communityContentWarnings);
    InfiniteVideoFeed.debugIsSupportedOverride = true;
  });

  tearDownAll(() {
    InfiniteVideoFeed.debugIsSupportedOverride = null;
  });

  group('community warning pause', () {
    testWidgets(
      'pauses the already-playing current video when a community warning '
      'crosses the threshold',
      (tester) async {
        final harness = _NativePlayerHarness(tester);
        harness.install();
        addTearDown(harness.dispose);

        final video = _makeVideo();
        final repository = _MockCommunityContentLabelRepository();
        // Gate the aggregation so the video starts playing before the label
        // crosses — the exact race M1 fixes.
        final labelGate = Completer<Set<String>>();
        when(
          () => repository.communityLabelsForVideo(video),
        ).thenAnswer((_) => labelGate.future);
        final filter = _MockContentFilterService();
        when(
          () => filter.getPreference(ContentLabel.gambling),
        ).thenReturn(ContentFilterPreference.warn);
        final service = CommunityContentLabelService(
          repository: repository,
          contentFilterService: filter,
        );

        final likes = _MockLikesRepository();
        when(
          likes.watchLikedEventIds,
        ).thenAnswer((_) => const Stream<List<String>>.empty());
        when(
          () => likes.isLikedResolvingCoordinate(
            eventId: any(named: 'eventId'),
            addressableId: any(named: 'addressableId'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => likes.getLikeCount(
            any(),
            addressableId: any(named: 'addressableId'),
          ),
        ).thenAnswer((_) async => 0);
        final comments = _MockCommentsRepository();
        when(
          () => comments.getCommentsCount(
            any(),
            rootAddressableId: any(named: 'rootAddressableId'),
          ),
        ).thenAnswer((_) async => 0);
        final reposts = _MockRepostsRepository();
        when(
          reposts.watchRepostedAddressableIds,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());
        when(
          () => reposts.getRepostCountByEventId(any()),
        ).thenAnswer((_) async => 0);

        final playbackCubit = _MockVideoPlaybackStatusCubit();
        when(() => playbackCubit.state).thenReturn(VideoPlaybackStatusState());
        whenListen(
          playbackCubit,
          const Stream<VideoPlaybackStatusState>.empty(),
        );
        final autoAdvanceCubit = _MockFeedAutoAdvanceCubit();
        when(
          () => autoAdvanceCubit.state,
        ).thenReturn(const FeedAutoAdvanceState());
        whenListen(
          autoAdvanceCubit,
          const Stream<FeedAutoAdvanceState>.empty(),
        );
        final volumeCubit = _MockVideoVolumeCubit();
        when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
        whenListen(volumeCubit, const Stream<VideoVolumeState>.empty());

        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(
              mockAuthService: createMockAuthService(),
              analyticsService: _NoopAnalyticsService(),
            ),
            seenVideosServiceProvider.overrideWithValue(
              _NoopSeenVideosService(),
            ),
            connectionStatusServiceProvider.overrideWithValue(
              _MockConnectionStatusService(),
            ),
            videoModerationStatusServiceProvider.overrideWithValue(
              _MockVideoModerationStatusService(),
            ),
            subtitleVisibilityProvider.overrideWithValue(false),
            likesRepositoryProvider.overrideWithValue(likes),
            commentsRepositoryProvider.overrideWithValue(comments),
            repostsRepositoryProvider.overrideWithValue(reposts),
            communityContentLabelServiceProvider.overrideWith((ref) => service),
            featureFlagServiceProvider.overrideWithValue(_communityFlagsOn()),
          ].cast(),
        );
        container.read(appForegroundProvider.notifier).setForeground(true);
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<FeedAutoAdvanceCubit>.value(
                    value: autoAdvanceCubit,
                  ),
                  BlocProvider<VideoPlaybackStatusCubit>.value(
                    value: playbackCubit,
                  ),
                  BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
                ],
                child: Scaffold(
                  body: FeedVideos(videos: [video], onNearEnd: () {}),
                ),
              ),
            ),
          ),
        );
        // Let the controller initialize and start playing.
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));

        expect(
          harness.countCalls('play'),
          greaterThanOrEqualTo(1),
          reason: 'the ungated video should start playing first',
        );
        final pausesBeforeCrossing = harness.countCalls('pause');

        // Community warning crosses the threshold while the video plays.
        labelGate.complete({'gambling'});
        await tester.pump();
        await tester.pump();

        expect(find.byType(ContentWarningBlurOverlay), findsOneWidget);
        expect(
          harness.countCalls('pause'),
          greaterThan(pausesBeforeCrossing),
          reason:
              'a newly-crossed community warning must pause the '
              'already-playing controller, not just close the autoplay gate',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
