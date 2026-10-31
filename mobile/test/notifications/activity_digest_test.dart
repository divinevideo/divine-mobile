import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/notifications/notification_tap_router.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/services/notification_helpers.dart';

void main() {
  group('activity digest display and tap', () {
    for (final osAlert in [false, true]) {
      test(
        osAlert
            ? 'uses the iOS alert without duplicating it'
            : 'renders an Android data alert with its inbox tap',
        () async {
          final data = {
            'type': 'activityDigest',
            'title': 'New activity',
            'body': 'Your videos received 4 likes and 2 reposts',
            'eventId': 'a' * 64,
            'receiverPubkey': 'b' * 64,
            'timestamp': '1793253600',
          };
          var renders = 0;
          await handleFirebaseMessagingBackgroundMessage(
            RemoteMessage(
              data: data,
              notification: osAlert
                  ? const RemoteNotification(
                      title: 'New activity',
                      body: 'Your videos received 4 likes and 2 reposts',
                    )
                  : null,
            ),
            initializeFirebase: () async {},
            preloadContent: (_) async {},
            renderLocalPush:
                ({
                  required id,
                  required title,
                  required body,
                  required data,
                }) async {
                  renders++;
                  expect(title, 'New activity');
                  expect(body, 'Your videos received 4 likes and 2 reposts');
                  expect(
                    localNotificationTapPayload(data)['notificationType'],
                    'activityDigest',
                  );
                },
          );
          expect(renders, osAlert ? 0 : 1);
          final payload = parseFcmPayload(localNotificationTapPayload(data))!;
          final result = pushNotificationTapTarget(
            referencedAddress: payload.referencedAddress,
            referencedEventId: payload.referencedEventId,
            eventId: payload.eventId,
            notificationType: payload.notificationType,
            senderPubkey: payload.senderPubkey,
            tapTargetType: payload.tapTargetType,
            tapTargetValue: payload.tapTargetValue,
          );
          expect(result.target, const OpenInboxTarget());
          expect(result.targetEventId, isNull);
        },
      );
    }
  });
}
