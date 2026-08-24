// ABOUTME: Verifies the GA4 contract for consumption and engagement events.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';
import 'package:openvine/models/view_traffic_source.dart';

void main() {
  late _RecordingAnalytics analytics;
  late ConsumptionAnalyticsTracker tracker;

  setUp(() {
    analytics = _RecordingAnalytics();
    tracker = ConsumptionAnalyticsTracker(analytics: analytics);
  });

  group(ConsumptionAnalyticsTracker, () {
    test('records the requested video consumption parameters', () async {
      await tracker.videoStarted(
        video: _video,
        trafficSource: ViewTrafficSource.home,
        position: 4,
      );
      await tracker.videoCompleted(
        videoId: _video.id,
        watchMs: 6200,
        pctWatched: 103.3,
        loops: 1,
      );
      await tracker.videoSkipped(
        videoId: _video.id,
        watchMs: 800,
        position: 4,
      );
      await tracker.feedScrolled(
        trafficSource: ViewTrafficSource.home,
        depth: 5,
      );

      expect(analytics.events.map((event) => event.name), [
        'video_started',
        'video_completed',
        'video_skipped',
        'feed_scrolled',
      ]);
      expect(analytics.events[0].parameters, {
        'video_id': 'video_id',
        'author_pubkey': 'creator_pubkey',
        'feed_type': 'home',
        'position_in_feed': 4,
        'is_archive': 0,
      });
      expect(analytics.events[1].parameters, {
        'video_id': 'video_id',
        'watch_ms': 6200,
        'pct_watched': 103.3,
        'loops': 1,
      });
      expect(analytics.events[2].parameters, {
        'video_id': 'video_id',
        'watch_ms': 800,
        'position_in_feed': 4,
      });
      expect(analytics.events[3].parameters, {
        'feed_type': 'home',
        'depth': 5,
      });
    });

    test('records engagement targets', () async {
      await tracker.reactionSent(
        targetVideoId: _video.id,
        targetPubkey: _video.pubkey,
      );
      await tracker.commentSent(
        targetVideoId: _video.id,
        targetPubkey: _video.pubkey,
      );
      await tracker.shareTapped(
        targetVideoId: _video.id,
        targetPubkey: _video.pubkey,
      );
      await tracker.followAdded(targetPubkey: _video.pubkey);

      expect(analytics.events.map((event) => event.name), [
        'reaction_sent',
        'comment_sent',
        'share_tapped',
        'follow_added',
      ]);
      expect(
        analytics.events.first.parameters,
        {'target_video_id': 'video_id', 'target_pubkey': 'creator_pubkey'},
      );
      expect(analytics.events.last.parameters, {
        'target_pubkey': 'creator_pubkey',
      });
    });

    test('uses the existing feed performance vocabulary', () async {
      await tracker.videoStarted(
        video: _video,
        trafficSource: ViewTrafficSource.home,
        sourceDetail: 'foryou',
        position: 0,
      );
      await tracker.feedScrolled(
        trafficSource: ViewTrafficSource.discoveryNew,
        depth: 2,
      );
      await tracker.feedScrolled(
        trafficSource: ViewTrafficSource.discoveryPopular,
        depth: 3,
      );

      expect(analytics.events[0].parameters['feed_type'], 'forYou');
      expect(analytics.events[1].parameters['feed_type'], 'new_vines');
      expect(analytics.events[2].parameters['feed_type'], 'popular');
    });

    test('does not let sink failures escape into product actions', () async {
      final failingTracker = ConsumptionAnalyticsTracker(
        analytics: _ThrowingAnalytics(),
      );

      await expectLater(
        failingTracker.followAdded(targetPubkey: _video.pubkey),
        completes,
      );
    });
  });
}

typedef _RecordedEvent = ({String name, Map<String, Object> parameters});

class _RecordingAnalytics extends NoOpAnalyticsEventSink {
  final events = <_RecordedEvent>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }
}

class _ThrowingAnalytics extends NoOpAnalyticsEventSink {
  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) => Future.error(StateError('analytics unavailable'));
}

final _video = VideoEvent(
  id: 'video_id',
  pubkey: 'creator_pubkey',
  createdAt: 1700000000,
  content: 'test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);
