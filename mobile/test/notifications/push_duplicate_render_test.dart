// ABOUTME: Tests the background push de-duplication guard — the app must not
// ABOUTME: render a local notification when the OS already presents one (#4731).

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/notifications/notification_tap_router.dart' as app;

void main() {
  group('shouldRenderLocalPushNotification', () {
    // Unit-tests the pure decision predicate only. The background handler that
    // consumes it (_firebaseMessagingBackgroundHandler) calls
    // Firebase.initializeApp() and the local-notifications plugin, so its
    // early-return is verified on-device, not here (#4731).
    test('does not render when the OS already presents the notification — an '
        'iOS alert push surfaces RemoteMessage.notification', () {
      const message = RemoteMessage(
        notification: RemoteNotification(
          title: 'New like',
          body: 'alice liked your video',
        ),
        data: {'body': 'alice liked your video', 'type': 'like'},
      );

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });

    test('renders for a data-only message that carries a body '
        '(Android / iOS data push)', () {
      const message = RemoteMessage(
        data: {'title': 'New like', 'body': 'alice liked your video'},
      );

      expect(app.shouldRenderLocalPushNotification(message), isTrue);
    });

    test('does not render a data-only message with no body', () {
      const message = RemoteMessage(data: {'type': 'like'});

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });

    test('OS presentation wins even when the data payload also carries a '
        'body', () {
      const message = RemoteMessage(
        notification: RemoteNotification(title: 't', body: 'b'),
        data: {'body': 'b'},
      );

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });

    test(
      'does not render a data-only message whose body is an empty string',
      () {
        const message = RemoteMessage(data: {'body': '', 'type': 'like'});

        expect(app.shouldRenderLocalPushNotification(message), isFalse);
      },
    );

    test('does not render when the data body is not a string', () {
      const message = RemoteMessage(data: <String, dynamic>{'body': 1});

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });

    test('does not render when the OS presents the alert and the data '
        'carries no body', () {
      const message = RemoteMessage(
        notification: RemoteNotification(title: 'New follower', body: 'bob'),
        data: {'type': 'follow'},
      );

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });
  });

  group('handleFirebaseMessagingBackgroundMessage', () {
    test('an iOS alert preloads without rendering a second banner', () async {
      var warmed = 0;
      var rendered = 0;
      await app.handleFirebaseMessagingBackgroundMessage(
        const RemoteMessage(
          notification: RemoteNotification(title: 'New like', body: 'A like'),
          data: {'type': 'like'},
        ),
        initializeFirebase: () async {},
        preloadContent: (_) async {
          warmed++;
        },
        renderLocalPush:
            ({
              required id,
              required title,
              required body,
              required data,
            }) async {
              rendered++;
            },
      );
      expect(warmed, 1);
      expect(rendered, 0);
    });

    test('preload failure does not prevent a data-only alert', () async {
      var rendered = 0;
      await app.handleFirebaseMessagingBackgroundMessage(
        const RemoteMessage(data: {'title': 'New like', 'body': 'A like'}),
        initializeFirebase: () async {},
        preloadContent: (_) async => throw StateError('offline'),
        renderLocalPush:
            ({
              required id,
              required title,
              required body,
              required data,
            }) async {
              rendered++;
            },
      );
      expect(rendered, 1);
    });

    test('still renders a data-only local notification when Firebase init '
        'fails', () async {
      const message = RemoteMessage(
        data: {'title': 'New like', 'body': 'alice liked your video'},
      );
      final rendered =
          <({String? title, String body, Map<String, dynamic> data})>[];

      await app.handleFirebaseMessagingBackgroundMessage(
        message,
        initializeFirebase: () async => throw StateError('init failed'),
        preloadContent: (_) async {},
        renderLocalPush:
            ({
              required int id,
              required String? title,
              required String body,
              required Map<String, dynamic> data,
            }) async {
              rendered.add((title: title, body: body, data: data));
            },
      );

      expect(rendered, hasLength(1));
      expect(rendered.single.title, 'New like');
      expect(rendered.single.body, 'alice liked your video');
      expect(rendered.single.data, message.data);
    });
  });
}
