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
import 'package:openvine/router/router.dart';
import 'package:openvine/services/notification_helpers.dart';

class _MockGoRouter extends Mock implements GoRouter {}

class _RecordingSink extends NoOpAnalyticsEventSink {
  final events = <Map<String, Object>>[];
  final logged = Completer<void>();

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add({'name': name, ...parameters});
    if (!logged.isCompleted) logged.complete();
  }
}

void main() {
  const destination = '/following/new';
  const campaignTap = <String, dynamic>{
    NotificationPayloadKeys.wireType: NotificationWireValues.campaign,
    NotificationPayloadKeys.tapTargetType: 'app_route',
    NotificationPayloadKeys.tapTargetValue: destination,
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
      await sink.logged.future;
      expect(sink.events.single['open_source'], source.wireValue);
      verify(() => routerA.go(destination)).called(1);
    });
  }

  group('routeBackgroundPushTap', () {
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
      await sink.logged.future;
      expect(sink.events, [
        {
          'name': 'push_notification_opened',
          'notification_type': 'campaign',
          'open_source': 'os_background',
        },
      ]);
    });

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
