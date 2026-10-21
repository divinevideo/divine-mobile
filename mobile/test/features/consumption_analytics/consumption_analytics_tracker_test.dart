// ABOUTME: Verifies governed consumption calls omit raw relationship pubkeys.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';
import 'package:openvine/models/view_traffic_source.dart';

import '../../helpers/recording_consumption_analytics.dart';

void main() {
  group(ConsumptionAnalyticsTracker, () {
    late RecordingConsumptionAnalytics analytics;
    late ConsumptionAnalyticsTracker tracker;

    setUp(() {
      analytics = RecordingConsumptionAnalytics();
      tracker = ConsumptionAnalyticsTracker(analytics: () => analytics);
      addTearDown(analytics.dispose);
    });

    test('records engagement with video context and no raw creator or target pubkeys', () async {
      await tracker.reactionSent(targetVideoId: 'a' * 64);
      await tracker.commentSent(targetVideoId: 'a' * 64);
      await tracker.shareTapped(targetVideoId: 'a' * 64);
      await tracker.followAdded(targetVideoId: 'a' * 64);

      expect(analytics.eventNames, everyElement('engagement_recorded'));
      expect(analytics.parameters, [
        for (final action in [
          'reaction_sent',
          'comment_sent',
          'share_tapped',
          'follow_added',
        ])
          {'action': action, 'content_id': 'a' * 64},
      ]);
    });

    test('non-video follows contain no relationship target', () async {
      await tracker.followAdded();
      expect(analytics.parameters.single, {'action': 'follow_added'});
    });

    test(
      'preserves surface when Home and Explore feed types collide',
      () async {
        const session = '55555555-5555-4555-8555-555555555555';
        const cases = [
          (ViewTrafficSource.home, null, 'home', 'feed'),
          (ViewTrafficSource.home, 'foryou', 'for_you', 'feed'),
          (ViewTrafficSource.home, 'following', 'following', 'feed'),
          (ViewTrafficSource.home, 'list', 'list', 'feed'),
          (ViewTrafficSource.home, 'new', 'new_vines', 'feed'),
          (ViewTrafficSource.home, 'classic', 'classics', 'feed'),
          (ViewTrafficSource.discoveryForYou, null, 'for_you', 'discovery'),
          (ViewTrafficSource.discoveryNew, null, 'new_vines', 'discovery'),
          (ViewTrafficSource.discoveryClassic, null, 'classics', 'discovery'),
          (ViewTrafficSource.discoveryPopular, null, 'popular', 'discovery'),
          (
            ViewTrafficSource.discoveryFeatured,
            'private-theme',
            'featured',
            'discovery',
          ),
          (ViewTrafficSource.profile, null, 'profile', 'profile'),
          (ViewTrafficSource.share, null, 'share', 'unknown'),
          (ViewTrafficSource.search, null, 'search', 'search_results'),
          (ViewTrafficSource.unknown, null, 'unknown', 'unknown'),
        ];
        for (final (source, detail, _, _) in cases) {
          await tracker.feedDepthReached(
            trafficSource: source,
            sourceDetail: detail,
            feedSessionId: session,
            depth: 2,
          );
        }
        expect(analytics.eventNames, everyElement('feed_depth_recorded'));
        expect(analytics.parameters, [
          for (final (_, _, feedType, surface) in cases)
            {
              'feed_session_id': session,
              'feed_type': feedType,
              'surface': surface,
              'depth': 2,
            },
        ]);
      },
    );

    test('delivery failures never escape into product actions', () async {
      final service = RecordingConsumptionAnalytics(
        failure: StateError('analytics unavailable'),
      );
      addTearDown(service.dispose);
      final failing = ConsumptionAnalyticsTracker(analytics: () => service);
      await expectLater(failing.followAdded(), completes);
      await expectLater(
        failing.feedDepthReached(
          trafficSource: ViewTrafficSource.home,
          feedSessionId: '55555555-5555-4555-8555-555555555555',
          depth: 2,
        ),
        completes,
      );
    });
  });
}
