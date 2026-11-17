import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

const _videoId =
    '1111111111111111111111111111111111111111111111111111111111111111';
final _video = VideoEvent(
  id: _videoId,
  pubkey: '2222222222222222222222222222222222222222222222222222222222222222',
  createdAt: 1,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
  videoUrl: 'https://example.com/video.mp4',
);

void main() {
  late AnalyticsService analytics;
  late List<ClassicFeedFeedback> outcomes;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics = AnalyticsService(
      backgroundActivityManager: BackgroundActivityManager(),
      disableNostrPublishing: true,
    );
    outcomes = [];
    final subscription = analytics.recommendationFeedback.listen(outcomes.add);
    addTearDown(subscription.cancel);
    addTearDown(analytics.dispose);
  });

  test(
    'no feedback before initialized consent, and none after withdrawal',
    () async {
      analytics.recordRecommendationInteraction(
        const ClassicFeedInteraction(
          videoId: _videoId,
          signal: ClassicFeedSignal.positive,
        ),
      );
      expect(outcomes, isEmpty);
      await analytics.initialize();
      analytics.recordRecommendationInteraction(
        const ClassicFeedInteraction(
          videoId: _videoId,
          signal: ClassicFeedSignal.positive,
        ),
      );
      await Future<void>.value();
      expect(outcomes, hasLength(1));
      await analytics.setAnalyticsEnabled(false);
      analytics.recordRecommendationInteraction(
        const ClassicFeedInteraction(
          videoId: _videoId,
          signal: ClassicFeedSignal.positive,
        ),
      );
      await Future<void>.value();
      expect(outcomes, hasLength(1));
    },
  );

  test('queued feedback cannot cross an identity boundary', () async {
    await analytics.initialize();
    final requests = <ClassicRecommendationsRequest>[];
    final session = ClassicFeedSession(
      feedback: analytics.recommendationFeedback,
      privacyChanges: analytics.privacyChanges,
      canPersonalize: () => analytics.initializedAnalyticsConsent,
      loadPage: (request) async {
        requests.add(request);
        return HomeFeedResult(
          videos: [_video],
          hasMore: true,
          paginationCursor: 'next',
          recommendationPageCount: 1,
        );
      },
    );
    addTearDown(session.dispose);
    await session.loadInitial();
    analytics.recordRecommendationInteraction(
      const ClassicFeedInteraction(
        videoId: _videoId,
        signal: ClassicFeedSignal.positive,
      ),
    );
    await analytics.handleIdentityChange();
    await session.settled;
    expect(requests.last.seed, isNot(requests.first.seed));
    expect(requests.last.recentInteractions, isEmpty);
  });

  test(
    'playback outcomes use existing 0.75 and 1.25 loop boundaries',
    () async {
      await analytics.initialize();
      for (final loops in [0.5, 0.75, 1.25, 1.5]) {
        await analytics.trackDetailedVideoViewWithUser(
          _video,
          userId: null,
          source: 'mobile',
          eventType: 'view_end',
          loopCount: loops,
          watchDuration: Duration(milliseconds: (6000 * loops).round()),
          totalDuration: const Duration(seconds: 6),
        );
      }
      await Future<void>.value();
      expect(
        outcomes.whereType<ClassicFeedInteraction>().map((v) => v.signal),
        [
          ClassicFeedSignal.skip,
          ClassicFeedSignal.completed,
          ClassicFeedSignal.completed,
          ClassicFeedSignal.replay,
        ],
      );
    },
  );

  test(
    'unknown duration and missing loops cannot create a negative signal',
    () async {
      await analytics.initialize();
      await analytics.trackDetailedVideoViewWithUser(
        _video,
        userId: null,
        source: 'mobile',
        eventType: 'view_end',
        watchDuration: const Duration(seconds: 1),
      );
      expect(outcomes, isEmpty);
    },
  );

  test(
    'confirmed likes tune recommendations while share intent does not',
    () async {
      await analytics.initialize();
      final tracker = ConsumptionAnalyticsTracker(analytics: () => analytics);
      await tracker.reactionSent(targetVideoId: _videoId);
      await tracker.shareTapped(targetVideoId: _videoId);
      await Future<void>.value();
      expect(
        outcomes.whereType<ClassicFeedInteraction>().map((v) => v.signal),
        [ClassicFeedSignal.positive],
      );
      tracker.reactionRetracted(targetVideoId: _videoId);
      await Future<void>.value();
      expect(outcomes.last, isA<ClassicFeedInteractionRetracted>());
    },
  );
}
