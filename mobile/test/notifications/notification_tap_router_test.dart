// ABOUTME: Tests routeBackgroundPushTap routes a tapped push through the
// ABOUTME: account container that is live when the tap arrives.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/notifications/notification_tap_router.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/notification_helpers.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

class _MockGoRouter extends Mock implements GoRouter {}

class _RecordingSink extends NoOpAnalyticsEventSink {
  final events = <Map<String, Object>>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add({'name': name, ...parameters});
  }
}

void main() {
  const destination = '/following/new';
  const campaignTap = <String, dynamic>{
    NotificationPayloadKeys.wireType: NotificationWireValues.campaign,
    NotificationPayloadKeys.tapTargetType: 'app_route',
    NotificationPayloadKeys.tapTargetValue: destination,
  };
  const revision = '12345678-1234-4234-8234-123456789abc';
  // Kept apart from [campaignTap]: a revision becomes the deduplication key,
  // which would hide a dropped message ID from the message-ID tests.
  const revisionCampaignTap = <String, dynamic>{
    ...campaignTap,
    NotificationPayloadKeys.campaignRevisionId: revision,
  };

  late _MockGoRouter routerA;
  late _MockGoRouter routerB;
  late ProviderContainer containerA;
  late ProviderContainer containerB;

  NotificationAnalyticsTracker disabledTracker() =>
      NotificationAnalyticsTracker(
        sink: const NoOpAnalyticsEventSink(),
        collectionAllowed: () async => false,
        privacyBoundary: () => 'test',
      );

  setUp(() {
    routerA = _MockGoRouter();
    routerB = _MockGoRouter();
    containerA = ProviderContainer(
      overrides: [
        goRouterProvider.overrideWithValue(routerA),
        notificationAnalyticsTrackerProvider.overrideWithValue(
          disabledTracker(),
        ),
      ],
    );
    containerB = ProviderContainer(
      overrides: [
        goRouterProvider.overrideWithValue(routerB),
        notificationAnalyticsTrackerProvider.overrideWithValue(
          disabledTracker(),
        ),
      ],
    );
  });

  tearDown(() => containerB.dispose());

  group('routeNotificationTap', () {
    for (final source in NotificationOpenSource.values) {
      test('shared tap router records ${source.wireValue}', () async {
        final sink = _RecordingSink();
        final container = ProviderContainer(
          overrides: [
            goRouterProvider.overrideWithValue(routerA),
            notificationAnalyticsTrackerProvider.overrideWithValue(
              NotificationAnalyticsTracker(
                sink: sink,
                collectionAllowed: () async => true,
                privacyBoundary: () => 'test',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        containerA.dispose();
        await routeNotificationTap(
          messageId: 'transport-message-1',
          openSource: source,
          referencedAddress: null,
          referencedEventId: null,
          eventId: null,
          notificationType: 'campaign',
          senderPubkey: null,
          container: container,
          tapTargetType: 'app_route',
          tapTargetValue: destination,
        );
        await pumpEventQueue();
        expect(sink.events.single['open_source'], source.wireValue);
        verify(() => routerA.go(destination)).called(1);
      });
    }

    group('follow tap', () {
      Future<void> tapFollowFrom(String actorHex) async {
        final container = ProviderContainer(
          overrides: [
            goRouterProvider.overrideWithValue(routerA),
            notificationAnalyticsTrackerProvider.overrideWithValue(
              disabledTracker(),
            ),
            authServiceProvider.overrideWithValue(
              createMockAuthService(currentPublicKeyHex: syntheticTestPubkey),
            ),
          ],
        );
        addTearDown(container.dispose);
        containerA.dispose();
        when(() => routerA.push<void>(any())).thenAnswer((_) async {});

        await routeNotificationTap(
          openSource: NotificationOpenSource.osBackground,
          referencedAddress: null,
          referencedEventId: null,
          eventId: null,
          notificationType: 'follow',
          senderPubkey: actorHex,
          container: container,
          tapTargetType: null,
          tapTargetValue: null,
        );
      }

      // A notification left in the tray from before an account switch can
      // name the account now signed in; pushing your own viewer route stacks
      // a second tab shell (#11097).
      test('opens your own Profile tab when you are the actor', () async {
        await tapFollowFrom(syntheticTestPubkey);

        verify(
          () => routerA.go(ProfileScreenRouter.pathForNpub(syntheticTestNpub)),
        ).called(1);
        verifyNever(() => routerA.push<void>(any()));
      });

      test("pushes another actor's profile viewer", () async {
        await tapFollowFrom(syntheticOtherTestPubkey);

        verify(
          () => routerA.push<void>(
            OtherProfileScreen.pathForNpub(syntheticOtherTestNpub),
          ),
        ).called(1);
        verifyNever(() => routerA.go(any()));
      });
    });
  });

  group('routeBackgroundPushTap', () {
    ProviderContainer revisionContainer(_RecordingSink sink) {
      final container = ProviderContainer(
        overrides: [
          goRouterProvider.overrideWithValue(routerA),
          notificationAnalyticsTrackerProvider.overrideWithValue(
            NotificationAnalyticsTracker(
              sink: sink,
              collectionAllowed: () async => true,
              privacyBoundary: () => 'test',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      containerA.dispose();
      return container;
    }

    test('a campaign open carries its revision to analytics', () async {
      final sink = _RecordingSink();
      final container = revisionContainer(sink);
      await routeBackgroundPushTap(
        revisionCampaignTap,
        liveContainer: () => container,
      );
      await pumpEventQueue();
      expect(sink.events.single['campaign_revision_id'], revision);
    });

    test('duplicate callbacks for one revision record one open', () async {
      final sink = _RecordingSink();
      final container = revisionContainer(sink);
      for (var tap = 0; tap < 2; tap++) {
        await routeBackgroundPushTap(
          revisionCampaignTap,
          liveContainer: () => container,
        );
      }
      await pumpEventQueue();
      expect(sink.events, hasLength(1));
    });

    test('routes immediately while analytics waits for consent', () async {
      final consent = Completer<bool>();
      final sink = _RecordingSink();
      final container = ProviderContainer(
        overrides: [
          goRouterProvider.overrideWithValue(routerA),
          notificationAnalyticsTrackerProvider.overrideWithValue(
            NotificationAnalyticsTracker(
              sink: sink,
              collectionAllowed: () => consent.future,
              privacyBoundary: () => 'test',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      containerA.dispose();

      await routeBackgroundPushTap(campaignTap, liveContainer: () => container);
      verify(() => routerA.go(destination)).called(1);
      expect(sink.events, isEmpty);

      consent.complete(true);
      await pumpEventQueue();
      expect(sink.events, [
        {
          'name': 'push_notification_opened',
          'notification_type': 'campaign',
          'open_source': 'os_background',
        },
      ]);
    });

    test(
      'deduplicates a repeated background tap by its transport message ID',
      () async {
        final sink = _RecordingSink();
        final container = ProviderContainer(
          overrides: [
            goRouterProvider.overrideWithValue(routerA),
            notificationAnalyticsTrackerProvider.overrideWithValue(
              NotificationAnalyticsTracker(
                sink: sink,
                collectionAllowed: () async => true,
                privacyBoundary: () => 'test',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        containerA.dispose();
        final tap = fcmPayloadWithMessageId(campaignTap, 'transport-message-1');

        await routeBackgroundPushTap(tap, liveContainer: () => container);
        await routeBackgroundPushTap(tap, liveContainer: () => container);
        await pumpEventQueue();

        // Campaigns carry no event ID, so only the message ID can merge these.
        expect(sink.events, hasLength(1));
      },
    );

    test(
      'routes a background tap through the container that is live when it '
      'arrives',
      () async {
        var live = containerA;
        ProviderContainer resolve() => live;

        await routeBackgroundPushTap(campaignTap, liveContainer: resolve);
        verify(() => routerA.go(destination)).called(1);

        // An in-place account switch: the new container goes live and the
        // one the listener was registered with is disposed.
        live = containerB;
        containerA.dispose();
        await routeBackgroundPushTap(campaignTap, liveContainer: resolve);

        verify(() => routerB.go(destination)).called(1);
        verifyNever(() => routerA.go(destination));
      },
    );
  });
}
