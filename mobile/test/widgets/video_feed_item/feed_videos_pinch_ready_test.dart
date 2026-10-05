// ABOUTME: Pinch-to-pin and press-and-hold tests on a ready player, where the
// ABOUTME: tap and double-tap recognizers exist and playback can be observed.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController;
import 'package:flutter/gestures.dart'
    show kDoubleTapTimeout, kLongPressTimeout;
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
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart'
    show ViewTrafficSource;
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';
import 'package:openvine/widgets/video_feed_item/feed_immersive_chrome.dart';
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

/// Counts native player method calls so a play or pause can be observed.
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

  /// Pushes a native player state with [status], as the platform does when
  /// playback starts or stops.
  Future<void> emitStatus(String status, {int playerId = 0}) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'divine_video_player/player_$playerId/events',
      _codec.encodeSuccessEnvelope(<Object?, Object?>{
        'status': status,
        'videoWidth': 1280,
        'videoHeight': 720,
        'isFirstFrameRendered': true,
      }),
      (_) {},
    );
    await tester.pump();
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

class _Rig {
  _Rig({
    required this.harness,
    required this.immersive,
    required this.likes,
    required this.container,
  });

  final _NativePlayerHarness harness;
  final ProviderContainer container;
  final FeedImmersiveCubit immersive;
  final _MockLikesRepository likes;
}

/// The like publish the feed asks of [likes], for any video.
Future<bool> _toggleLike(_MockLikesRepository likes) => likes.toggleLike(
  eventId: any(named: 'eventId'),
  authorPubkey: any(named: 'authorPubkey'),
  addressableId: any(named: 'addressableId'),
  targetKind: any(named: 'targetKind'),
);

/// Pumps a one-video [FeedVideos] whose player has rendered its first frame,
/// so the tap and double-tap recognizers exist before any finger lands.
Future<_Rig> _pumpReadyFeed(WidgetTester tester) async {
  final harness = _NativePlayerHarness(tester)..install();
  addTearDown(harness.dispose);

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
    () => likes.getLikeCount(any(), addressableId: any(named: 'addressableId')),
  ).thenAnswer((_) async => 0);
  when(() => _toggleLike(likes)).thenAnswer((_) async => true);
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
  when(() => reposts.getRepostCountByEventId(any())).thenAnswer((_) async => 0);

  final playbackCubit = _MockVideoPlaybackStatusCubit();
  when(() => playbackCubit.state).thenReturn(VideoPlaybackStatusState());
  whenListen(playbackCubit, const Stream<VideoPlaybackStatusState>.empty());
  final autoAdvanceCubit = _MockFeedAutoAdvanceCubit();
  when(() => autoAdvanceCubit.state).thenReturn(const FeedAutoAdvanceState());
  whenListen(autoAdvanceCubit, const Stream<FeedAutoAdvanceState>.empty());
  final volumeCubit = _MockVideoVolumeCubit();
  when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
  whenListen(volumeCubit, const Stream<VideoVolumeState>.empty());
  final immersive = FeedImmersiveCubit();
  addTearDown(immersive.close);

  final container = ProviderContainer(
    overrides: [
      ...getStandardTestOverrides(
        mockAuthService: createMockAuthService(),
        analyticsService: _NoopAnalyticsService(),
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
            BlocProvider<FeedAutoAdvanceCubit>.value(value: autoAdvanceCubit),
            BlocProvider<VideoPlaybackStatusCubit>.value(value: playbackCubit),
            BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
            BlocProvider<FeedImmersiveCubit>.value(value: immersive),
          ],
          child: Scaffold(
            body: FeedVideos(videos: [_makeVideo()], onNearEnd: () {}),
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
    reason: 'the video must be playing before a gesture can toggle playback',
  );
  return _Rig(
    harness: harness,
    immersive: immersive,
    likes: likes,
    container: container,
  );
}

/// Unmounts the feed so its timers do not outlive the test.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// The play button and toggles shown over a video the viewer paused.
Finder get _pausedControls =>
    find.byKey(const ValueKey('paused-playback-controls'));

/// Pumps [duration] in short frames, asserting that no play or pause control
/// is on screen in any of them — a flash between two checkpoints is the bug.
Future<void> _expectNoPlaybackControlsFor(
  WidgetTester tester,
  Duration duration,
) async {
  const frame = Duration(milliseconds: 20);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += frame) {
    await tester.pump(frame);
    expect(find.byType(CenterPlaybackControl), findsNothing);
  }
}

/// Lets a tap resolve past the double-tap window and the chrome fade finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 100));
  await tester.pump(kFeedImmersiveFadeDuration);
}

/// Taps [position] with an explicit [pointer] id.
///
/// The id must differ from any finger whose gesture arena is still open (a
/// pinch lifted moments ago), or the arena rejects the reused id.
Future<void> _tap(
  WidgetTester tester,
  Offset position, {
  required int pointer,
}) async {
  final gesture = await tester.startGesture(position, pointer: pointer);
  await gesture.up();
}

/// Lands two fingers 40 apart on [center] and spreads them.
///
/// With [anchored] the first finger stays put, as a thumb resting on the
/// screen does, so only the second finger travels: its tap recognizer sees a
/// finger that never left touch slop.
Future<void> _pinch(
  WidgetTester tester,
  Offset center, {
  required bool anchored,
  int basePointer = 1,
}) async {
  final first = await tester.startGesture(
    center - const Offset(20, 0),
    pointer: basePointer,
  );
  final second = await tester.startGesture(
    center + const Offset(20, 0),
    pointer: basePointer + 1,
  );
  await tester.pump();
  if (!anchored) await first.moveTo(center - const Offset(140, 0));
  await second.moveTo(center + const Offset(140, 0));
  await tester.pump();
  await second.up();
  await first.up();
}

void main() {
  setUpAll(() {
    registerFallbackValue(const VideoInteractionsSubscriptionRequested());
    InfiniteVideoFeed.debugIsSupportedOverride = true;
  });

  tearDownAll(() {
    InfiniteVideoFeed.debugIsSupportedOverride = null;
  });

  group('pinch on a ready player', () {
    testWidgets('a pinch anchored by a still finger keeps its pin', (
      tester,
    ) async {
      final rig = await _pumpReadyFeed(tester);
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));

      await _pinch(tester, center, anchored: true);
      expect(
        rig.immersive.state.isPinned,
        isTrue,
        reason: 'the spread itself must pin the chrome',
      );

      await _settle(tester);

      expect(
        rig.immersive.state.isPinned,
        isTrue,
        reason: "the still finger's leftover tap must not clear the pin",
      );
      await _unmount(tester);
    });

    testWidgets('a pinch anchored by a still finger that restores the chrome '
        'toggles no playback', (tester) async {
      final rig = await _pumpReadyFeed(tester);
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));

      await _pinch(tester, center, anchored: false);
      await _settle(tester);
      expect(rig.immersive.state.isPinned, isTrue);
      final playsBefore = rig.harness.countCalls('play');
      final pausesBefore = rig.harness.countCalls('pause');

      await _pinch(tester, center, anchored: true, basePointer: 3);
      await _settle(tester);

      expect(rig.immersive.state.isPinned, isFalse);
      expect(
        rig.harness.countCalls('pause') - pausesBefore,
        isZero,
        reason: 'a pinch must not pause the video',
      );
      expect(
        rig.harness.countCalls('play') - playsBefore,
        isZero,
        reason: 'a pinch must not resume the video',
      );
      await _unmount(tester);
    });

    testWidgets('a quick tap after a pinch publishes no like', (tester) async {
      final rig = await _pumpReadyFeed(tester);
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));

      await _pinch(tester, center, anchored: true);
      await tester.pump(const Duration(milliseconds: 100));
      // Inside the double-tap window and slop, so the still finger's leftover
      // tap and this one would read as a double tap.
      await _tap(tester, center - const Offset(20, 0), pointer: 5);
      await _settle(tester);

      verifyNever(() => _toggleLike(rig.likes));
      await _unmount(tester);
    });

    testWidgets('a double tap still publishes a like', (tester) async {
      final rig = await _pumpReadyFeed(tester);
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));

      await _tap(tester, center, pointer: 1);
      await tester.pump(const Duration(milliseconds: 100));
      await _tap(tester, center, pointer: 2);
      await _settle(tester);

      verify(() => _toggleLike(rig.likes)).called(1);
      await _unmount(tester);
    });

    testWidgets('a tap restores the chrome without toggling playback', (
      tester,
    ) async {
      final rig = await _pumpReadyFeed(tester);
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));

      await _pinch(tester, center, anchored: false);
      await _settle(tester);
      expect(rig.immersive.state.isPinned, isTrue);
      final playsBefore = rig.harness.countCalls('play');
      final pausesBefore = rig.harness.countCalls('pause');

      await _tap(tester, center, pointer: 5);
      await _settle(tester);

      expect(rig.immersive.state.isPinned, isFalse);
      expect(
        rig.harness.countCalls('pause') - pausesBefore,
        isZero,
        reason: 'the restore tap must not also pause the video',
      );
      expect(rig.harness.countCalls('play') - playsBefore, isZero);
      await _unmount(tester);
    });
  });

  group('press and hold on a ready player', () {
    testWidgets('pauses a playing video and resumes it on release', (
      tester,
    ) async {
      final rig = await _pumpReadyFeed(tester);
      await rig.harness.emitStatus('playing');
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));
      final playsBefore = rig.harness.countCalls('play');
      final pausesBefore = rig.harness.countCalls('pause');

      final gesture = await tester.startGesture(center, pointer: 1);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

      expect(rig.immersive.state.isHolding, isTrue);
      expect(rig.harness.countCalls('pause') - pausesBefore, equals(1));
      expect(rig.harness.countCalls('play') - playsBefore, isZero);

      await rig.harness.emitStatus('paused');
      await gesture.up();
      await tester.pump();

      expect(rig.immersive.state.isHolding, isFalse);
      expect(rig.harness.countCalls('play') - playsBefore, equals(1));
      await _unmount(tester);
    });

    testWidgets('resumes the video when the hold is cancelled', (tester) async {
      final rig = await _pumpReadyFeed(tester);
      await rig.harness.emitStatus('playing');
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));
      final playsBefore = rig.harness.countCalls('play');

      final gesture = await tester.startGesture(center, pointer: 1);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await rig.harness.emitStatus('paused');
      await gesture.cancel();
      await tester.pump();

      expect(rig.immersive.state.isHolding, isFalse);
      expect(rig.harness.countCalls('play') - playsBefore, equals(1));
      await _unmount(tester);
    });

    testWidgets('leaves a video the viewer paused paused after release', (
      tester,
    ) async {
      final rig = await _pumpReadyFeed(tester);
      await rig.harness.emitStatus('paused');
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));
      final playsBefore = rig.harness.countCalls('play');
      final pausesBefore = rig.harness.countCalls('pause');

      final gesture = await tester.startGesture(center, pointer: 1);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(rig.immersive.state.isHolding, isTrue);
      await gesture.up();
      await tester.pump();

      expect(rig.harness.countCalls('pause') - pausesBefore, isZero);
      expect(rig.harness.countCalls('play') - playsBefore, isZero);
      await _unmount(tester);
    });

    testWidgets('does not resume when the feed goes inactive mid-hold', (
      tester,
    ) async {
      final rig = await _pumpReadyFeed(tester);
      await rig.harness.emitStatus('playing');
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));
      final playsBefore = rig.harness.countCalls('play');

      final gesture = await tester.startGesture(center, pointer: 1);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await rig.harness.emitStatus('paused');
      // An incoming call or the app switcher backgrounds the app mid-hold.
      rig.container.read(appForegroundProvider.notifier).setForeground(false);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(rig.immersive.state.isHolding, isFalse);
      expect(
        rig.harness.countCalls('play') - playsBefore,
        isZero,
        reason: 'a backgrounded feed must not start playing on release',
      );
      await _unmount(tester);
    });

    testWidgets('shows no playback controls while a hold pauses and resumes', (
      tester,
    ) async {
      final rig = await _pumpReadyFeed(tester);
      await rig.harness.emitStatus('playing');
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));

      final gesture = await tester.startGesture(center, pointer: 1);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await rig.harness.emitStatus('paused');
      // The chrome is still fading out here, so a play button would show.
      await _expectNoPlaybackControlsFor(tester, kFeedImmersiveFadeDuration);

      await gesture.up();
      // Released, but the player has not reported playing yet.
      await _expectNoPlaybackControlsFor(
        tester,
        const Duration(milliseconds: 60),
      );
      await rig.harness.emitStatus('playing');
      // Long enough to cover the chrome fading back in and the pause flash
      // an ordinary resume shows.
      await _expectNoPlaybackControlsFor(
        tester,
        const Duration(milliseconds: 600),
      );
      await _unmount(tester);
    });

    testWidgets('keeps the play button on a video the viewer paused', (
      tester,
    ) async {
      final rig = await _pumpReadyFeed(tester);
      await rig.harness.emitStatus('playing');
      await rig.harness.emitStatus('paused');
      await tester.pump(const Duration(milliseconds: 400));
      expect(_pausedControls, findsOneWidget);
      final center = tester.getCenter(find.byType(InfiniteVideoFeed));

      final gesture = await tester.startGesture(center, pointer: 1);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();
      await tester.pump(kFeedImmersiveFadeDuration);

      expect(_pausedControls, findsOneWidget);
      await _unmount(tester);
    });
  });
}
