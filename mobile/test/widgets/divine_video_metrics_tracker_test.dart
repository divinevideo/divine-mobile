// ABOUTME: Lifecycle tests for DivineVideoMetricsTracker view analytics
// ABOUTME: Verifies native player active/inactive, dispose, and video changes

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/widgets/divine_video_metrics_tracker.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDivineVideoPlayerController extends Mock
    implements DivineVideoPlayerController {}

class _RecordingAnalyticsService extends AnalyticsService {
  _RecordingAnalyticsService()
    : super(backgroundActivityManager: BackgroundActivityManager());

  final events = <_TrackedAnalyticsEvent>[];
  final impressions = <_RecordedImpression>[];
  final playbackSessions = <_RecordedPlaybackSession>[];

  @override
  Future<String?> recordContentImpression({
    required String contentId,
    required ProductAnalyticsV2Surface surface,
    required int position,
    required int visibleMs,
    String? recommendationId,
  }) async {
    impressions.add(
      _RecordedImpression(
        contentId: contentId,
        surface: surface,
        position: position,
        visibleMs: visibleMs,
      ),
    );
    return 'impression-id';
  }

  @override
  Future<String?> recordPlaybackSession({
    required String playbackSessionId,
    required String contentId,
    required ProductAnalyticsV2Surface surface,
    required int durationMs,
    required int watchedMs,
    required int loopCount,
    required bool completed,
    required ProductAnalyticsV2PlaybackEndReason endReason,
  }) async {
    playbackSessions.add(
      _RecordedPlaybackSession(
        playbackSessionId: playbackSessionId,
        contentId: contentId,
        surface: surface,
        durationMs: durationMs,
        watchedMs: watchedMs,
        loopCount: loopCount,
        completed: completed,
        endReason: endReason,
      ),
    );
    return 'playback-id';
  }

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
  }) async {
    events.add(
      _TrackedAnalyticsEvent(
        video: video,
        userId: userId,
        source: source,
        eventType: eventType,
        sessionToken: sessionToken,
        watchDuration: watchDuration,
        totalDuration: totalDuration,
        loopCount: loopCount,
        completedVideo: completedVideo,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
      ),
    );
  }
}

/// Fails every publish, so an unguarded fire-and-forget call surfaces as an
/// unhandled zone error and fails the test.
class _ThrowingAnalyticsService extends _RecordingAnalyticsService {
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
  }) async {
    await super.trackDetailedVideoViewWithUser(
      video,
      userId: userId,
      source: source,
      eventType: eventType,
      sessionToken: sessionToken,
      watchDuration: watchDuration,
      totalDuration: totalDuration,
      loopCount: loopCount,
      completedVideo: completedVideo,
      trafficSource: trafficSource,
      sourceDetail: sourceDetail,
    );
    throw StateError('publish failed');
  }
}

class _RecordingSeenVideosService extends SeenVideosService {
  final records = <_SeenVideoRecord>[];

  @override
  Future<void> recordVideoView(
    String videoId, {
    int? loopCount,
    Duration? watchDuration,
  }) async {
    // Mirrors SeenVideoMetrics.updateSession: one entry per video, and
    // repeat calls accumulate onto it. Recording raw calls instead would
    // make a per-segment flush look like a duplicate seen entry.
    for (final record in records) {
      if (record.videoId != videoId) continue;
      record.loopCount += loopCount ?? 0;
      record.watchDuration += watchDuration ?? Duration.zero;
      return;
    }
    records.add(
      _SeenVideoRecord(
        videoId: videoId,
        loopCount: loopCount ?? 0,
        watchDuration: watchDuration ?? Duration.zero,
      ),
    );
  }
}

class _TrackedAnalyticsEvent {
  const _TrackedAnalyticsEvent({
    required this.video,
    required this.userId,
    required this.source,
    required this.eventType,
    required this.sessionToken,
    required this.watchDuration,
    required this.totalDuration,
    required this.loopCount,
    required this.completedVideo,
    required this.trafficSource,
    required this.sourceDetail,
  });

  final VideoEvent video;
  final String? userId;
  final String source;
  final String eventType;
  final String? sessionToken;
  final Duration? watchDuration;
  final Duration? totalDuration;
  final double? loopCount;
  final bool? completedVideo;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;
}

class _SeenVideoRecord {
  _SeenVideoRecord({
    required this.videoId,
    required this.loopCount,
    required this.watchDuration,
  });

  final String videoId;
  int loopCount;
  Duration watchDuration;
}

class _RecordedImpression {
  const _RecordedImpression({
    required this.contentId,
    required this.surface,
    required this.position,
    required this.visibleMs,
  });

  final String contentId;
  final ProductAnalyticsV2Surface surface;
  final int position;
  final int visibleMs;
}

class _RecordedPlaybackSession {
  const _RecordedPlaybackSession({
    required this.playbackSessionId,
    required this.contentId,
    required this.surface,
    required this.durationMs,
    required this.watchedMs,
    required this.loopCount,
    required this.completed,
    required this.endReason,
  });

  final String playbackSessionId;
  final String contentId;
  final ProductAnalyticsV2Surface surface;
  final int durationMs;
  final int watchedMs;
  final int loopCount;
  final bool completed;
  final ProductAnalyticsV2PlaybackEndReason endReason;
}

void main() {
  group(DivineVideoMetricsTracker, () {
    late _MockAuthService authService;
    late _RecordingAnalyticsService analyticsService;
    late _RecordingSeenVideosService seenVideosService;
    late DateTime now;

    setUp(() {
      authService = _MockAuthService();
      analyticsService = _RecordingAnalyticsService();
      seenVideosService = _RecordingSeenVideosService();
      now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      when(() => authService.currentPublicKeyHex).thenReturn('viewer_pubkey');
    });

    testWidgets('active tracker sends view_start once playback starts', (
      tester,
    ) async {
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          isActive: true,
          clock: () => now,
        ),
      );

      expect(
        analyticsService.events.map((event) => event.eventType),
        contains('view_start'),
      );

      await controller.close();
    });

    testWidgets('records one impression after one visible second', (
      tester,
    ) async {
      final controller = _stubController(isPlaying: false);

      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          isActive: true,
          clock: () => now,
        ),
      );
      await tester.pump(const Duration(milliseconds: 999));
      expect(analyticsService.impressions, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(seconds: 2));

      expect(analyticsService.impressions, hasLength(1));
      expect(analyticsService.impressions.single.contentId, _video.id);
      expect(
        analyticsService.impressions.single.surface,
        ProductAnalyticsV2Surface.feed,
      );
      expect(analyticsService.impressions.single.position, 0);
      expect(analyticsService.impressions.single.visibleMs, 1000);
      expect(analyticsService.events, isEmpty);

      await controller.close();
    });

    testWidgets('records aggregate playback when navigation interrupts it', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final isFeedVisible = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(
        isPlaying: true,
        duration: const Duration(seconds: 6),
      );

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          isFeedVisible: isFeedVisible,
          clock: () => now,
        ),
      );
      now = now.add(const Duration(milliseconds: 2500));

      isFeedVisible.value = false;
      await tester.pump();

      expect(analyticsService.playbackSessions, hasLength(1));
      final playback = analyticsService.playbackSessions.single;
      expect(playback.contentId, _video.id);
      expect(playback.surface, ProductAnalyticsV2Surface.feed);
      expect(playback.durationMs, 6000);
      expect(playback.watchedMs, 2500);
      expect(playback.loopCount, 0);
      expect(playback.completed, isFalse);
      expect(
        playback.endReason,
        ProductAnalyticsV2PlaybackEndReason.navigation,
      );
      expect(playback.playbackSessionId, isNotEmpty);

      isActive.dispose();
      isFeedVisible.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets('a failing publish does not escape either phase', (
      tester,
    ) async {
      final failingAnalytics = _ThrowingAnalyticsService();
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: failingAnalytics,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          isActive: true,
          clock: () => now,
        ),
      );

      // Dispose flushes an end segment, so both phases attempt a publish.
      now = now.add(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        failingAnalytics.events.map((event) => event.eventType),
        containsAll(<String>['view_start', 'view_end']),
      );

      await controller.close();
    });

    testWidgets('active to inactive after one second sends one view_end', (
      tester,
    ) async {
      final consumptionSink = _RecordingEventSink();
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
          consumptionAnalytics: ConsumptionAnalyticsTracker(
            analytics: consumptionSink,
          ),
        ),
      );

      now = now.add(const Duration(milliseconds: 1100));
      isActive.value = false;
      await tester.pump();

      expect(consumptionSink.eventNames, ['video_started', 'video_skipped']);

      final viewEndEvents = _viewEndEvents(analyticsService);
      expect(viewEndEvents, hasLength(1));
      expect(viewEndEvents.single.video.id, equals('video_id'));
      expect(viewEndEvents.single.userId, equals('viewer_pubkey'));
      expect(
        viewEndEvents.single.watchDuration,
        const Duration(seconds: 1),
      );
      expect(viewEndEvents.single.totalDuration, const Duration(seconds: 5));
      expect(viewEndEvents.single.trafficSource, ViewTrafficSource.home);
      expect(seenVideosService.records.single.videoId, equals('video_id'));

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets(
      'active to inactive under one second records a partial-loop view',
      (tester) async {
        final isActive = ValueNotifier(true);
        final video = ValueNotifier(_video);
        final controller = _stubController(isPlaying: true);

        await tester.pumpWidget(
          _buildTrackerHarness(
            authService: authService,
            analyticsService: analyticsService,
            seenVideosService: seenVideosService,
            controller: controller.controller,
            video: video,
            isActive: isActive,
            clock: () => now,
          ),
        );

        now = now.add(const Duration(milliseconds: 900));
        isActive.value = false;
        await tester.pump();

        expect(_viewEndEvents(analyticsService), hasLength(1));
        expect(seenVideosService.records, hasLength(1));
        expect(seenVideosService.records.single.videoId, equals('video_id'));
        expect(
          seenVideosService.records.single.watchDuration,
          const Duration(milliseconds: 900),
        );

        isActive.dispose();
        video.dispose();
        await controller.close();
      },
    );

    testWidgets(
      'fling-speed active session records a partial-loop view and seen state',
      (tester) async {
        final isActive = ValueNotifier(true);
        final video = ValueNotifier(_video);
        final controller = _stubController(isPlaying: true);

        await tester.pumpWidget(
          _buildTrackerHarness(
            authService: authService,
            analyticsService: analyticsService,
            seenVideosService: seenVideosService,
            controller: controller.controller,
            video: video,
            isActive: isActive,
            clock: () => now,
          ),
        );

        now = now.add(const Duration(milliseconds: 400));
        isActive.value = false;
        await tester.pump();

        expect(_viewEndEvents(analyticsService), hasLength(1));
        expect(seenVideosService.records, hasLength(1));
        expect(seenVideosService.records.single.videoId, equals('video_id'));
        expect(seenVideosService.records.single.loopCount, equals(0));
        expect(
          seenVideosService.records.single.watchDuration,
          const Duration(milliseconds: 400),
        );

        isActive.dispose();
        video.dispose();
        await controller.close();
      },
    );

    testWidgets('zero-duration active session records nothing', (tester) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      isActive.value = false;
      await tester.pump();

      expect(_viewEndEvents(analyticsService), isEmpty);
      expect(seenVideosService.records, isEmpty);

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets('dispose under one second records seen once', (tester) async {
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          isActive: true,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 900));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const SizedBox.shrink());

      expect(_viewEndEvents(analyticsService), hasLength(1));
      expect(seenVideosService.records, hasLength(1));
      expect(
        seenVideosService.records.single.watchDuration,
        const Duration(milliseconds: 900),
      );

      await controller.close();
    });

    testWidgets('dispose after one second sends one view_end', (tester) async {
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          isActive: true,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1200));
      await tester.pumpWidget(const SizedBox.shrink());

      final viewEndEvents = _viewEndEvents(analyticsService);
      expect(viewEndEvents, hasLength(1));
      // Whole seconds: the wire format carries seconds, so the tracker
      // truncates once and keeps the 200ms remainder for the next segment
      // rather than letting every segment drop its own tail.
      expect(viewEndEvents.single.watchDuration, const Duration(seconds: 1));
      expect(seenVideosService.records, hasLength(1));

      await controller.close();
    });

    testWidgets('active video that never plays records seen only (no view)', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: false);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 900));
      isActive.value = false;
      await tester.pump();

      expect(_viewEndEvents(analyticsService), isEmpty);
      expect(seenVideosService.records, hasLength(1));
      expect(seenVideosService.records.single.videoId, equals('video_id'));
      expect(seenVideosService.records.single.watchDuration, Duration.zero);

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets('inactive then dispose does not duplicate view_end', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1100));
      isActive.value = false;
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());

      expect(_viewEndEvents(analyticsService), hasLength(1));
      expect(seenVideosService.records, hasLength(1));

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets('sub-second session finalizes once', (tester) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      // A glance counts because playback started, even without a full loop.
      now = now.add(const Duration(milliseconds: 300));
      isActive.value = false;
      await tester.pump();

      expect(_viewEndEvents(analyticsService), hasLength(1));
      expect(seenVideosService.records, hasLength(1));
      expect(
        seenVideosService.records.single.watchDuration,
        const Duration(milliseconds: 300),
      );
      expect(seenVideosService.records.single.videoId, equals('video_id'));

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets('reactivation starts a new view session', (tester) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      // A partial loop still counts because playback started.
      now = now.add(const Duration(milliseconds: 700));
      isActive.value = false;
      await tester.pump();

      expect(_viewEndEvents(analyticsService), hasLength(1));
      expect(seenVideosService.records, hasLength(1));

      // The inactive gap ends the first continuous viewing session. Returning
      // to the same video starts another session and must publish another view.
      analyticsService.events.clear();
      isActive.value = true;
      await tester.pump();
      now = now.add(const Duration(seconds: 5));
      isActive.value = false;
      await tester.pump();

      final viewEndEvents = _viewEndEvents(analyticsService);
      expect(viewEndEvents, hasLength(1));
      expect(viewEndEvents.single.watchDuration, const Duration(seconds: 5));
      expect(
        analyticsService.events.where(
          (event) => event.eventType == 'view_start',
        ),
        hasLength(1),
      );
      // Seen-video history remains deduplicated across playback sessions.
      expect(seenVideosService.records, hasLength(1));

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets('reactivation without playback does not publish a view_end', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 700));
      isActive.value = false;
      await tester.pump();

      expect(_viewEndEvents(analyticsService), hasLength(1));
      expect(seenVideosService.records, hasLength(1));

      analyticsService.events.clear();
      controller.setState(
        const DivineVideoPlayerState(
          status: PlaybackStatus.ready,
          duration: Duration(seconds: 5),
          isFirstFrameRendered: true,
        ),
      );
      isActive.value = true;
      await tester.pump();
      now = now.add(const Duration(seconds: 5));
      isActive.value = false;
      await tester.pump();

      expect(_viewEndEvents(analyticsService), isEmpty);
      expect(seenVideosService.records, hasLength(1));

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets(
      'covering the feed (comment sheet) flushes one segment and keeps the '
      'session — later loops still publish',
      (tester) async {
        final isActive = ValueNotifier(true);
        final isFeedVisible = ValueNotifier(true);
        final video = ValueNotifier(_video);
        final controller = _stubController(isPlaying: true);

        await tester.pumpWidget(
          _buildTrackerHarness(
            authService: authService,
            analyticsService: analyticsService,
            seenVideosService: seenVideosService,
            controller: controller.controller,
            video: video,
            isActive: isActive,
            isFeedVisible: isFeedVisible,
            clock: () => now,
          ),
        );

        // 2s watched, then a sheet covers the feed. The item is still the
        // current one — only the feed stopped being visible.
        now = now.add(const Duration(seconds: 2));
        isFeedVisible.value = false;
        await tester.pump();

        // Back from the sheet, 2s more, then dispose.
        isFeedVisible.value = true;
        await tester.pump();
        now = now.add(const Duration(seconds: 2));
        await tester.pumpWidget(const SizedBox.shrink());

        final starts = analyticsService.events
            .where((event) => event.eventType == 'view_start')
            .toList();
        expect(starts, hasLength(1));
        expect(starts.single.sessionToken, isNotNull);

        final ends = _viewEndEvents(analyticsService);
        expect(ends, hasLength(2));
        expect(ends[0].watchDuration, const Duration(seconds: 2));
        expect(ends[1].watchDuration, const Duration(seconds: 2));
        // Fractional loops per segment: 2s of a 5s video = 0.4.
        expect(ends[0].loopCount, 0.4);
        expect(ends[1].loopCount, 0.4);
        expect(seenVideosService.records, hasLength(1));

        isActive.dispose();
        isFeedVisible.dispose();
        video.dispose();
        await controller.close();
      },
    );

    testWidgets(
      'scrolling away ends the session — returning counts a new view',
      (tester) async {
        final isActive = ValueNotifier(true);
        final isFeedVisible = ValueNotifier(true);
        final video = ValueNotifier(_video);
        final controller = _stubController(isPlaying: true);

        await tester.pumpWidget(
          _buildTrackerHarness(
            authService: authService,
            analyticsService: analyticsService,
            seenVideosService: seenVideosService,
            controller: controller.controller,
            video: video,
            isActive: isActive,
            isFeedVisible: isFeedVisible,
            clock: () => now,
          ),
        );

        // 2s watched, then the viewer scrolls to another video. Unlike a
        // cover, this ends the session outright.
        now = now.add(const Duration(seconds: 2));
        isActive.value = false;
        await tester.pump();

        // Scrolling back is a fresh watch and must report its own start.
        isActive.value = true;
        controller.setState(
          const DivineVideoPlayerState(
            status: PlaybackStatus.playing,
            duration: Duration(seconds: 5),
            isFirstFrameRendered: true,
          ),
        );
        await tester.pump();
        now = now.add(const Duration(seconds: 2));
        await tester.pumpWidget(const SizedBox.shrink());

        final starts = analyticsService.events
            .where((event) => event.eventType == 'view_start')
            .toList();
        expect(starts, hasLength(2));
        // A new session means a new token, or the dedupe would swallow it.
        expect(starts[0].sessionToken, isNot(equals(starts[1].sessionToken)));

        isActive.dispose();
        isFeedVisible.dispose();
        video.dispose();
        await controller.close();
      },
    );

    testWidgets(
      'an interrupted session reports the same loops as an uninterrupted one',
      (tester) async {
        final isActive = ValueNotifier(true);
        final isFeedVisible = ValueNotifier(true);
        final video = ValueNotifier(_video);
        final controller = _stubController(
          isPlaying: true,
          duration: const Duration(seconds: 6),
        );

        await tester.pumpWidget(
          _buildTrackerHarness(
            authService: authService,
            analyticsService: analyticsService,
            seenVideosService: seenVideosService,
            controller: controller.controller,
            video: video,
            isActive: isActive,
            isFeedVisible: isFeedVisible,
            clock: () => now,
          ),
        );

        Future<void> wrapOnce() async {
          for (final position in const [
            Duration(milliseconds: 5900),
            Duration(milliseconds: 50),
          ]) {
            controller.setState(
              DivineVideoPlayerState(
                status: PlaybackStatus.playing,
                duration: const Duration(seconds: 6),
                position: position,
                isFirstFrameRendered: true,
              ),
            );
            await tester.pump();
          }
        }

        // 15s watched, two wrap-arounds seen.
        now = now.add(const Duration(seconds: 15));
        await wrapOnce();
        await wrapOnce();

        isFeedVisible.value = false;
        await tester.pump();
        isFeedVisible.value = true;
        await tester.pump();

        // 15s more, three further wrap-arounds.
        now = now.add(const Duration(seconds: 15));
        await wrapOnce();
        await wrapOnce();
        await wrapOnce();

        await tester.pumpWidget(const SizedBox.shrink());

        final total = _viewEndEvents(
          analyticsService,
        ).fold<double>(0, (sum, event) => sum + (event.loopCount ?? 0));

        // 30s of a 6s video is 5 loops however the session is split. Taking
        // the larger of wraps and watch-ratio *per segment* instead of
        // splitting the cumulative figure reports 2.5 + 3.0 = 5.5.
        expect(total, closeTo(5, 0.001));

        isActive.dispose();
        isFeedVisible.dispose();
        video.dispose();
        await controller.close();
      },
    );

    testWidgets(
      'sub-second remainders carry across flushes instead of being dropped',
      (tester) async {
        final isActive = ValueNotifier(true);
        final isFeedVisible = ValueNotifier(true);
        final video = ValueNotifier(_video);
        final controller = _stubController(isPlaying: true);

        await tester.pumpWidget(
          _buildTrackerHarness(
            authService: authService,
            analyticsService: analyticsService,
            seenVideosService: seenVideosService,
            controller: controller.controller,
            video: video,
            isActive: isActive,
            isFeedVisible: isFeedVisible,
            clock: () => now,
          ),
        );

        // Four 1.5s stretches, each interrupted by a cover: 6s watched.
        for (var i = 0; i < 4; i++) {
          now = now.add(const Duration(milliseconds: 1500));
          isFeedVisible.value = false;
          await tester.pump();
          isFeedVisible.value = true;
          await tester.pump();
        }

        final reported = _viewEndEvents(analyticsService).fold<int>(
          0,
          (sum, event) => sum + (event.watchDuration?.inSeconds ?? 0),
        );

        // The wire carries whole seconds. Truncating each 1.5s segment on its
        // own reports 1+1+1+1 = 4s of the 6s actually watched; carrying the
        // remainder reports the full 6.
        expect(reported, equals(6));

        isActive.dispose();
        isFeedVisible.dispose();
        video.dispose();
        await controller.close();
      },
    );

    testWidgets('video id change finalizes old video and starts new one', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1300));
      video.value = _secondVideo;
      await tester.pump();

      final viewEndEvents = _viewEndEvents(analyticsService);
      expect(viewEndEvents, hasLength(1));
      expect(viewEndEvents.single.video.id, equals('video_id'));
      expect(
        analyticsService.events.where(
          (event) => event.eventType == 'view_start',
        ),
        hasLength(2),
      );
      expect(seenVideosService.records.single.videoId, equals('video_id'));

      isActive.dispose();
      video.dispose();
      await controller.close();
    });
  });
}

Widget _buildTracker({
  required AuthService authService,
  required AnalyticsService analyticsService,
  required SeenVideosService seenVideosService,
  required DivineVideoPlayerController controller,
  required bool isActive,
  required DateTime Function() clock,
  ConsumptionAnalyticsTracker? consumptionAnalytics,
}) {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      analyticsServiceProvider.overrideWithValue(analyticsService),
      seenVideosServiceProvider.overrideWithValue(seenVideosService),
      consumptionAnalyticsTrackerProvider.overrideWithValue(
        consumptionAnalytics ??
            ConsumptionAnalyticsTracker(
              analytics: const NoOpAnalyticsEventSink(),
            ),
      ),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: DivineVideoMetricsTracker(
        video: _video,
        controller: controller,
        isActive: isActive,
        trafficSource: ViewTrafficSource.home,
        clock: clock,
        child: const SizedBox.shrink(),
      ),
    ),
  );
}

/// Shared always-visible feed signal for tests that only vary scroll position.
final _alwaysFeedVisible = ValueNotifier<bool>(true);

Widget _buildTrackerHarness({
  required AuthService authService,
  required AnalyticsService analyticsService,
  required SeenVideosService seenVideosService,
  required DivineVideoPlayerController controller,
  required ValueListenable<VideoEvent> video,
  required ValueListenable<bool> isActive,
  required DateTime Function() clock,
  ValueListenable<bool>? isFeedVisible,
  ConsumptionAnalyticsTracker? consumptionAnalytics,
}) {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      analyticsServiceProvider.overrideWithValue(analyticsService),
      seenVideosServiceProvider.overrideWithValue(seenVideosService),
      consumptionAnalyticsTrackerProvider.overrideWithValue(
        consumptionAnalytics ??
            ConsumptionAnalyticsTracker(
              analytics: const NoOpAnalyticsEventSink(),
            ),
      ),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder<VideoEvent>(
        valueListenable: video,
        builder: (context, currentVideo, _) => ValueListenableBuilder<bool>(
          valueListenable: isActive,
          builder: (context, active, _) => ValueListenableBuilder<bool>(
            valueListenable: isFeedVisible ?? _alwaysFeedVisible,
            builder: (context, feedVisible, _) => DivineVideoMetricsTracker(
              video: currentVideo,
              controller: controller,
              isActive: active,
              isFeedVisible: feedVisible,
              trafficSource: ViewTrafficSource.home,
              clock: clock,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RecordingEventSink extends NoOpAnalyticsEventSink {
  final eventNames = <String>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    eventNames.add(name);
  }
}

List<_TrackedAnalyticsEvent> _viewEndEvents(
  _RecordingAnalyticsService analyticsService,
) => analyticsService.events
    .where((event) => event.eventType == 'view_end')
    .toList();

({
  DivineVideoPlayerController controller,
  void Function(DivineVideoPlayerState state) setState,
  Future<void> Function() close,
})
_stubController({
  required bool isPlaying,
  Duration duration = const Duration(seconds: 5),
}) {
  final controller = _MockDivineVideoPlayerController();
  final stateController = StreamController<DivineVideoPlayerState>.broadcast();
  var state = DivineVideoPlayerState(
    status: isPlaying ? PlaybackStatus.playing : PlaybackStatus.ready,
    duration: duration,
    isFirstFrameRendered: true,
  );

  when(() => controller.isInitialized).thenReturn(true);
  when(() => controller.state).thenAnswer((_) => state);
  when(() => controller.stateStream).thenAnswer((_) => stateController.stream);

  return (
    controller: controller,
    setState: (DivineVideoPlayerState next) {
      state = next;
      stateController.add(next);
    },
    close: () async {
      await stateController.close();
      state = const DivineVideoPlayerState();
    },
  );
}

final _video = VideoEvent(
  id: 'video_id',
  pubkey: 'creator_pubkey',
  createdAt: 1700000000,
  content: 'test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

final _secondVideo = VideoEvent(
  id: 'second_video_id',
  pubkey: 'creator_pubkey',
  createdAt: 1700000001,
  content: 'second test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000001000),
);
