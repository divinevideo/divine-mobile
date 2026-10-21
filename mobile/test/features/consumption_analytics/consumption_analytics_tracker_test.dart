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

    test('preserves session identity and normalized feed types', () async {
      const session = '55555555-5555-4555-8555-555555555555';
      const cases = [
        (ViewTrafficSource.home, null, 'home'),
        (ViewTrafficSource.home, 'foryou', 'for_you'),
        (ViewTrafficSource.home, 'following', 'following'),
        (ViewTrafficSource.home, 'list', 'list'),
        (ViewTrafficSource.home, 'new', 'new_vines'),
        (ViewTrafficSource.home, 'classic', 'classics'),
        (ViewTrafficSource.discoveryForYou, null, 'for_you'),
        (ViewTrafficSource.discoveryNew, null, 'new_vines'),
        (ViewTrafficSource.discoveryClassic, null, 'classics'),
        (ViewTrafficSource.discoveryPopular, null, 'popular'),
        (ViewTrafficSource.discoveryFeatured, 'private-theme', 'featured'),
        (ViewTrafficSource.profile, null, 'profile'),
        (ViewTrafficSource.share, null, 'share'),
        (ViewTrafficSource.search, null, 'search'),
        (ViewTrafficSource.unknown, null, 'unknown'),
      ];
      for (final (source, detail, _) in cases) {
        await tracker.feedDepthReached(
          trafficSource: source,
          sourceDetail: detail,
          feedSessionId: session,
          depth: 2,
        );
      }
      expect(analytics.eventNames, everyElement('feed_depth_recorded'));
      expect(analytics.parameters, [
        for (final (_, _, feedType) in cases)
          {'feed_session_id': session, 'feed_type': feedType, 'depth': 2},
      ]);
    });

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
