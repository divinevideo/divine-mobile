// ABOUTME: Keyboard commands on the feed: the arrows page, Space plays or
// ABOUTME: pauses the video on screen the way a tap does, and M mutes

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
import 'package:media_cache/media_cache.dart' show CancellableCacheOperation;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart'
    show ViewTrafficSource;
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/connection_status_service.dart';
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

/// Stands in for the native players: counts their method calls and reports
/// the status a real player would after `play` and `pause`.
class _NativePlayerHarness {
  _NativePlayerHarness(this.tester);

  final WidgetTester tester;
  final Map<int, List<String>> callsByPlayer = <int, List<String>>{};
  final Set<int> _installedPlayerIds = <int>{};

  static const _globalChannel = MethodChannel('divine_video_player');
  static const _codec = StandardMethodCodec();

  void install({Iterable<int> playerIds = const <int>[0, 1, 2]}) {
    DivineVideoPlayerController.resetIdCounterForTesting();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _globalChannel,
      (call) async => call.method == 'create' ? <Object?, Object?>{} : null,
    );

    for (final playerId in playerIds) {
      _installedPlayerIds.add(playerId);
      final eventChannelName = 'divine_video_player/player_$playerId/events';

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('divine_video_player/player_$playerId'),
        (call) async {
          (callsByPlayer[playerId] ??= <String>[]).add(call.method);
          if (call.method == 'play') _report(eventChannelName, 'playing');
          if (call.method == 'pause') _report(eventChannelName, 'paused');
          return null;
        },
      );

      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        eventChannelName,
        (message) async {
          final call = _codec.decodeMethodCall(message);
          if (call.method == 'listen') _report(eventChannelName, 'ready');
          return _codec.encodeSuccessEnvelope(null);
        },
      );
    }
  }

  void _report(String eventChannelName, String status) {
    scheduleMicrotask(() async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        eventChannelName,
        _codec.encodeSuccessEnvelope(<Object?, Object?>{
          'status': status,
          'videoWidth': 1280,
          'videoHeight': 720,
          'isFirstFrameRendered': true,
        }),
        (_) {},
      );
    });
  }

  int countCalls(String method) => callsByPlayer.values
      .expand((calls) => calls)
      .where((call) => call == method)
      .length;

  void dispose() {
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

const _testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

VideoEvent _makeVideo(int index, {List<String> warnLabels = const []}) =>
    VideoEvent(
      id: index.toRadixString(16).padLeft(64, 'a'),
      pubkey: _testPubkey,
      createdAt: 1704067200 + index,
      content: 'Video $index',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
      videoUrl: 'https://example.com/video$index.mp4',
      warnLabels: warnLabels,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const VideoInteractionsSubscriptionRequested());
    InfiniteVideoFeed.debugIsSupportedOverride = true;
  });

  tearDownAll(() {
    InfiniteVideoFeed.debugIsSupportedOverride = null;
  });

  group('FeedVideos keyboard', () {
    late _NativePlayerHarness harness;
    late _MockVideoVolumeCubit volumeCubit;
    late List<int> activeIndices;

    Future<void> pumpFeed(WidgetTester tester, List<VideoEvent> videos) async {
      harness = _NativePlayerHarness(tester)..install();
      addTearDown(harness.dispose);
      activeIndices = <int>[];

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
      whenListen(autoAdvanceCubit, const Stream<FeedAutoAdvanceState>.empty());
      volumeCubit = _MockVideoVolumeCubit();
      when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
      whenListen(volumeCubit, const Stream<VideoVolumeState>.empty());

      // Three videos prefetch their neighbours to disk.
      final cache = createMockMediaCacheManager();
      when(
        () => cache.cacheFileCancellable(
          any(),
          key: any(named: 'key'),
          authHeaders: any(named: 'authHeaders'),
        ),
      ).thenAnswer(
        (_) => CancellableCacheOperation.fromStream(const Stream.empty()),
      );

      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(
            mockAuthService: createMockAuthService(),
            analyticsService: _NoopAnalyticsService(),
            mockMediaCacheManager: cache,
          ),
          seenVideosServiceProvider.overrideWithValue(_NoopSeenVideosService()),
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
        ].cast(),
      );
      container.read(appForegroundProvider.notifier).setForeground(true);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
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
                body: FeedVideos(
                  videos: videos,
                  onNearEnd: () {},
                  onActiveVideoChanged: (_, index) => activeIndices.add(index),
                ),
              ),
            ),
          ),
        ),
      );
      // Let the current player start and the feed take the focus.
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
    }

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      // A page animation starts on the next frame, then runs its course.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    testWidgets('Down moves to the next video and Up back', (tester) async {
      await pumpFeed(tester, [_makeVideo(0), _makeVideo(1), _makeVideo(2)]);

      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowUp);

      expect(activeIndices, equals([1, 0]));
      await unmount(tester);
    });

    testWidgets('Space pauses the video on screen and plays it again', (
      tester,
    ) async {
      await pumpFeed(tester, [_makeVideo(0)]);
      expect(harness.countCalls('play'), greaterThanOrEqualTo(1));
      final plays = harness.countCalls('play');
      final pauses = harness.countCalls('pause');

      await press(tester, LogicalKeyboardKey.space);
      expect(harness.countCalls('pause'), equals(pauses + 1));

      await press(tester, LogicalKeyboardKey.space);
      expect(harness.countCalls('play'), equals(plays + 1));
      await unmount(tester);
    });

    testWidgets('Space pauses the video paged to, not the one before', (
      tester,
    ) async {
      await pumpFeed(tester, [_makeVideo(0), _makeVideo(1)]);
      await press(tester, LogicalKeyboardKey.arrowDown);
      final plays = harness.countCalls('play');
      final pauses = harness.countCalls('pause');

      await press(tester, LogicalKeyboardKey.space);

      expect(harness.countCalls('pause'), equals(pauses + 1));
      expect(harness.countCalls('play'), equals(plays));
      await unmount(tester);
    });

    testWidgets('Space does not start a video behind a content warning', (
      tester,
    ) async {
      await pumpFeed(tester, [
        _makeVideo(0, warnLabels: const ['nsfw']),
      ]);
      expect(find.byType(ContentWarningBlurOverlay), findsOneWidget);

      await press(tester, LogicalKeyboardKey.space);

      expect(harness.countCalls('play'), equals(0));
      await unmount(tester);
    });

    testWidgets('M mutes', (tester) async {
      await pumpFeed(tester, [_makeVideo(0)]);

      await press(tester, LogicalKeyboardKey.keyM);

      verify(() => volumeCubit.toggleMute()).called(1);
      await unmount(tester);
    });
  });
}
