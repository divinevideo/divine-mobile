// ABOUTME: Tests discovery adapters against the real consent-gated event service.
// ABOUTME: Pins canonical source/action mapping and the identity-free payload.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/people_discovery_analytics.dart';
import 'package:openvine/services/product_event_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingQueue extends Fake implements ProductEventQueue {
  final events = <ProductAnalyticsV2Event>[];

  @override
  Future<void> enqueue(
    ProductAnalyticsV2Event event, {
    String? ownerPubkey,
  }) async => events.add(event);

  @override
  Future<void> clear() async => events.clear();

  @override
  void setSendingEnabled(bool enabled) {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> recoverPublishingAndFlush() async {}
}

void main() {
  group('people discovery analytics adapter', () {
    late _RecordingQueue queue;
    late AnalyticsService analytics;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      queue = _RecordingQueue();
      analytics = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        productEventQueue: queue,
        productAnalyticsEnabled: true,
        consumptionAnalyticsEnabled: true,
        disableNostrPublishing: true,
        currentUserPubkey: () => 'a' * 64,
      );
    });

    tearDown(() => analytics.dispose());

    test(
      'maps every surface and action to only canonical properties',
      () async {
        await analytics.initialize();
        const sources = {
          'findPeople': 'find_people',
          'onboarding': 'onboarding',
          'feed': 'feed_card',
        };
        for (final source in sources.entries) {
          for (final action in ['exposed', 'followed', 'dismissed']) {
            await recordPeopleDiscoveryAction(
              analytics,
              source: source.key,
              action: action,
              position: 0,
            );
            final event = queue.events.last;
            expect(event.eventName, 'people_suggestion_recorded');
            expect(event.propertiesJson, {
              'discovery_source': source.value,
              'action': action,
              'position': 0,
            });
          }
        }
        expect(queue.events, hasLength(9));
      },
    );

    test('default release gate withholds follow identity outcomes', () async {
      analytics.dispose();
      analytics = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        productEventQueue: queue,
        productAnalyticsEnabled: true,
        disableNostrPublishing: true,
        currentUserPubkey: () => 'a' * 64,
      );
      await analytics.initialize();
      for (final action in ['exposed', 'followed', 'dismissed']) {
        await recordPeopleDiscoveryAction(
          analytics,
          source: 'feed',
          action: action,
          position: 1,
        );
      }
      expect(
        queue.events.map((event) => event.propertiesJson['action']),
        ['exposed', 'dismissed'],
      );
    });

    test(
      'rejects unknown actions and positions outside the contract',
      () async {
        await analytics.initialize();
        for (final input in [
          (action: 'opened', position: 0),
          (action: 'followed', position: -1),
          (action: 'exposed', position: 10001),
        ]) {
          await recordPeopleDiscoveryAction(
            analytics,
            source: 'feed',
            action: input.action,
            position: input.position,
          );
        }
        expect(queue.events, isEmpty);
        await recordPeopleDiscoveryAction(
          analytics,
          source: 'feed',
          action: 'exposed',
          position: 10000,
        );
        expect(queue.events.single.propertiesJson['position'], 10000);
      },
    );

    test('records a deliberate optional onboarding skip', () async {
      await analytics.initialize();
      await recordPeopleDiscoveryOnboardingSkip(analytics);
      final event = queue.events.single;
      expect(event.eventName, 'onboarding_step_recorded');
      expect(event.propertiesJson, {
        'flow': 'viewer_setup',
        'step': 'follow_suggestions',
        'result': 'skipped',
        'reason': 'dismissed',
      });
    });

    test('both adapters obey startup consent and subsequent opt-out', () async {
      Future<void> recordBoth() async {
        await recordPeopleDiscoveryAction(
          analytics,
          source: 'feed',
          action: 'followed',
          position: 1,
        );
        await recordPeopleDiscoveryOnboardingSkip(analytics);
      }

      await recordBoth();
      expect(queue.events, isEmpty);
      await analytics.initialize();
      await recordBoth();
      expect(queue.events, hasLength(2));
      await analytics.setAnalyticsEnabled(false);
      expect(queue.events, isEmpty);
      await recordBoth();
      expect(queue.events, isEmpty);
    });
  });
}
