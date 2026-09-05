// ABOUTME: Tests for NotificationService permission handling and local notification display
// ABOUTME: Verifies platform-specific permission requests and notification sending functionality

import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/notification_helpers.dart'
    show localNotificationTapPayload;
import 'package:openvine/services/notification_service.dart';

class _MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _MockAndroidFlutterLocalNotificationsPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  });

  group('NotificationService Permission Tests', () {
    late NotificationService notificationService;

    setUp(() {
      notificationService = NotificationService();
    });

    tearDown(() {
      notificationService.dispose();
    });

    test(
      'ensurePermission requests platform permissions on first call',
      () async {
        // Initially permissions should be false (not yet granted)
        expect(notificationService.hasPermissions, isFalse);

        // Request permissions
        await notificationService.ensurePermission();

        // After requesting, permissions should be granted
        // Note: In test environment, this will simulate granting permissions
        expect(notificationService.hasPermissions, isTrue);
      },
    );

    test(
      'ensurePermission skips re-request if permissions already granted',
      () async {
        // Grant permissions first time
        await notificationService.ensurePermission();
        expect(notificationService.hasPermissions, isTrue);

        // Second call should not throw or change state
        await notificationService.ensurePermission();
        expect(notificationService.hasPermissions, isTrue);
      },
    );

    test('ensurePermission handles permission denial gracefully', () async {
      // This test verifies that even if permissions are denied,
      // the service doesn't crash and sets state correctly
      await notificationService.ensurePermission();

      // Service should be in a valid state regardless of permission result
      expect(notificationService.mounted, isTrue);
    });

    test('sendLocal shows notification with title and body', () async {
      // Ensure permissions are granted first
      await notificationService.ensurePermission();

      // Send a local notification
      await notificationService.sendLocal(
        title: 'Test Notification',
        body: 'This is a test notification body',
      );

      // Verify notification was added to internal list
      expect(notificationService.notifications.length, equals(1));
      expect(
        notificationService.notifications.first.title,
        equals('Test Notification'),
      );
      expect(
        notificationService.notifications.first.body,
        equals('This is a test notification body'),
      );
    });

    test(
      'sendLocal adds to internal list while resolving permissions',
      () async {
        // Do NOT call ensurePermission first: sendLocal should resolve the
        // unknown permission state itself before deciding on platform delivery.
        expect(notificationService.hasPermissions, isFalse);

        await notificationService.sendLocal(
          title: 'Unknown Permission Test',
          body: 'Should always show in-app',
        );

        expect(notificationService.notifications.length, equals(1));
        expect(
          notificationService.notifications.first.title,
          equals('Unknown Permission Test'),
        );
      },
    );

    test(
      'sendLocal resolves unknown permission state before platform delivery',
      () async {
        final plugin = _MockFlutterLocalNotificationsPlugin();
        when(
          () => plugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse: any(
              named: 'onDidReceiveNotificationResponse',
            ),
            onDidReceiveBackgroundNotificationResponse: any(
              named: 'onDidReceiveBackgroundNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => plugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async {});

        final androidPlugin = _MockAndroidFlutterLocalNotificationsPlugin();
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(androidPlugin);
        when(
          androidPlugin.areNotificationsEnabled,
        ).thenAnswer((_) async => true);

        notificationService.debugConfigurePlugin(
          plugin,
          permissionsGranted: null,
          pluginInitialized: false,
        );

        await notificationService.sendLocal(
          title: 'Unknown Permission',
          body: 'Should initialize before deciding',
        );

        verify(
          () => plugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse: any(
              named: 'onDidReceiveNotificationResponse',
            ),
            onDidReceiveBackgroundNotificationResponse: any(
              named: 'onDidReceiveBackgroundNotificationResponse',
            ),
          ),
        ).called(1);
        verify(
          () => plugin.show(
            id: any(named: 'id'),
            title: 'Unknown Permission',
            body: 'Should initialize before deciding',
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          ),
        ).called(1);
        expect(notificationService.hasPermissions, isTrue);
        verifyNever(androidPlugin.requestNotificationsPermission);
      },
    );

    test(
      'sendLocal with denied permissions does not call platform show',
      () async {
        final plugin = _MockFlutterLocalNotificationsPlugin();
        final androidPlugin = _MockAndroidFlutterLocalNotificationsPlugin();
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(androidPlugin);
        when(
          androidPlugin.areNotificationsEnabled,
        ).thenAnswer((_) async => false);

        notificationService.debugConfigurePlugin(
          plugin,
          permissionsGranted: false,
        );

        await notificationService.sendLocal(
          title: 'Denied Permission',
          body: 'Should stay in-app only',
        );

        verifyNever(
          () => plugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          ),
        );
        expect(notificationService.notifications, hasLength(1));
        expect(notificationService.hasPermissions, isFalse);
        verifyNever(androidPlugin.requestNotificationsPermission);
      },
    );

    test(
      'sendLocal picks up a permission granted from system settings',
      () async {
        final plugin = _MockFlutterLocalNotificationsPlugin();
        final androidPlugin = _MockAndroidFlutterLocalNotificationsPlugin();
        when(
          () => plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >(),
        ).thenReturn(androidPlugin);
        when(
          () => plugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async {});
        when(
          androidPlugin.areNotificationsEnabled,
        ).thenAnswer((_) async => false);

        notificationService.debugConfigurePlugin(
          plugin,
          permissionsGranted: false,
        );

        await notificationService.sendLocal(
          title: 'Still Denied',
          body: 'Stays in-app',
        );
        expect(notificationService.hasPermissions, isFalse);

        // The user enables notifications in system settings. Without a
        // re-check, `denied` would stick until the process restarts.
        when(
          androidPlugin.areNotificationsEnabled,
        ).thenAnswer((_) async => true);

        await notificationService.sendLocal(
          title: 'Now Allowed',
          body: 'Reaches the platform',
        );

        expect(notificationService.hasPermissions, isTrue);
        verify(
          () => plugin.show(
            id: any(named: 'id'),
            title: 'Now Allowed',
            body: 'Reaches the platform',
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          ),
        ).called(1);
        verifyNever(androidPlugin.requestNotificationsPermission);
      },
    );

    test('sendLocal handles empty title and body', () async {
      await notificationService.ensurePermission();

      // Send notification with empty strings
      await notificationService.sendLocal(title: '', body: '');

      // Should not crash and should add to list
      expect(notificationService.notifications.length, equals(1));
    });

    test('sendLocal adds multiple notifications in order', () async {
      await notificationService.ensurePermission();

      await notificationService.sendLocal(
        title: 'First',
        body: 'First notification',
      );
      await notificationService.sendLocal(
        title: 'Second',
        body: 'Second notification',
      );
      await notificationService.sendLocal(
        title: 'Third',
        body: 'Third notification',
      );

      expect(notificationService.notifications.length, equals(3));
      // Newest first (inserted at beginning)
      expect(notificationService.notifications[0].title, equals('Third'));
      expect(notificationService.notifications[1].title, equals('Second'));
      expect(notificationService.notifications[2].title, equals('First'));
    });
  });

  group('NotificationService.initialize', () {
    late NotificationService service;
    late _MockFlutterLocalNotificationsPlugin plugin;
    late _MockAndroidFlutterLocalNotificationsPlugin androidPlugin;

    setUp(() {
      service = NotificationService();
      plugin = _MockFlutterLocalNotificationsPlugin();
      androidPlugin = _MockAndroidFlutterLocalNotificationsPlugin();
      when(
        () => plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >(),
      ).thenReturn(androidPlugin);
      service.debugConfigurePlugin(plugin, permissionsGranted: null);
    });

    tearDown(() {
      service.dispose();
    });

    test('resolves a granted permission state without prompting', () async {
      when(
        () => androidPlugin.areNotificationsEnabled(),
      ).thenAnswer((_) async => true);

      await service.initialize();

      expect(service.hasPermissions, isTrue);
      verify(() => androidPlugin.areNotificationsEnabled()).called(1);
      verifyNever(() => androidPlugin.requestNotificationsPermission());
    });

    test('resolves a denied permission state without prompting', () async {
      when(
        () => androidPlugin.areNotificationsEnabled(),
      ).thenAnswer((_) async => false);

      await service.initialize();

      // Denied, not unknown: the delivery decision now has a real answer.
      expect(service.hasPermissions, isFalse);
      verify(() => androidPlugin.areNotificationsEnabled()).called(1);
      verifyNever(() => androidPlugin.requestNotificationsPermission());
    });

    test(
      'leaves the state unresolved when the platform cannot answer',
      () async {
        when(
          () => androidPlugin.areNotificationsEnabled(),
        ).thenAnswer((_) async => null);

        await service.initialize();

        expect(service.hasPermissions, isFalse);
        verifyNever(androidPlugin.requestNotificationsPermission);
      },
    );
  });

  group('NotificationService Web Platform Tests', () {
    test('ensurePermission no-ops gracefully on web', () async {
      final service = NotificationService();

      // On web, this should not crash
      await service.ensurePermission();

      // Service should be in valid state
      expect(service.mounted, isTrue);

      service.dispose();
    });

    test('sendLocal works on web with limited functionality', () async {
      final service = NotificationService();

      await service.ensurePermission();
      await service.sendLocal(title: 'Web Test', body: 'Web notification');

      // Should at least add to internal list
      expect(service.notifications.isNotEmpty, isTrue);

      service.dispose();
    });
  });

  group('NotificationService.notificationTapStream', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    tearDown(() {
      service.dispose();
    });

    // The FCM data map from divine-push-service uses 'type' (not 'notificationType').
    // _firebaseMessagingBackgroundHandler re-encodes it into our internal JSON
    // payload as 'notificationType' so the local notification tap handler can
    // read it back with the consistent internal key name.
    // See: docs/superpowers/specs/2026-04-07-push-notifications-design.md
    test('emits eventId and type from JSON payload', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      service.handleNotificationTapPayload(
        jsonEncode({
          'referencedEventId': 'abc123',
          'notificationType': 'reply',
        }),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.referencedEventId, equals('abc123'));
      expect(events.single.notificationType, equals('reply'));
    });

    test(
      'a tap handled by another service does not reach this stream',
      () async {
        final other = NotificationService();
        addTearDown(other.dispose);
        final events = <NotificationTapEvent>[];
        final sub = service.notificationTapStream.listen(events.add);
        addTearDown(sub.cancel);

        other.handleNotificationTapPayload(
          jsonEncode({
            'referencedEventId': 'abc123',
            'notificationType': 'reply',
          }),
        );

        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
      },
    );

    test(
      'emits the authoritative referencedAddress from JSON payload',
      () async {
        final events = <NotificationTapEvent>[];
        final sub = service.notificationTapStream.listen(events.add);
        addTearDown(sub.cancel);

        service.handleNotificationTapPayload(
          jsonEncode({
            'referencedEventId': 'video_event',
            'referencedAddress': '34236:owner_hex:my-vine-id',
            'notificationType': 'like',
          }),
        );

        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(
          events.single.referencedAddress,
          equals('34236:owner_hex:my-vine-id'),
        );
      },
    );

    test('routes a payload that carries only referencedAddress', () async {
      // The coordinate alone is a valid video target — it must still emit.
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      service.handleNotificationTapPayload(
        jsonEncode({'referencedAddress': '34236:owner_hex:vine-id'}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(
        events.single.referencedAddress,
        equals('34236:owner_hex:vine-id'),
      );
    });

    test('emits null type when notificationType missing', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      service.handleNotificationTapPayload(
        jsonEncode({'referencedEventId': 'def456'}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.referencedEventId, equals('def456'));
      expect(events.single.notificationType, isNull);
    });

    test('does not emit and does not throw on non-JSON payload', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      expect(
        () => service.handleNotificationTapPayload('not-json-at-all'),
        returnsNormally,
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test(
      'does not emit and does not throw when JSON is not an object',
      () async {
        final events = <NotificationTapEvent>[];
        final sub = service.notificationTapStream.listen(events.add);
        addTearDown(sub.cancel);

        // A JSON array is valid JSON but not a Map<String, dynamic>.
        expect(
          () => service.handleNotificationTapPayload('[1,2,3]'),
          returnsNormally,
        );

        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
      },
    );

    test(
      'does not emit and does not throw when referencedEventId is not a string',
      () async {
        final events = <NotificationTapEvent>[];
        final sub = service.notificationTapStream.listen(events.add);
        addTearDown(sub.cancel);

        // referencedEventId is a number, not a String — field() returns null,
        // and the emit guard should suppress without throwing.
        expect(
          () => service.handleNotificationTapPayload(
            jsonEncode({'referencedEventId': 12345}),
          ),
          returnsNormally,
        );

        await Future<void>.delayed(Duration.zero);

        expect(events, isEmpty);
      },
    );

    test('does not emit when payload is null', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      service.handleNotificationTapPayload(null);

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('does not emit when nothing routable is present', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      // No referencedEventId, eventId, or senderPubkey → nothing to route.
      service.handleNotificationTapPayload(
        jsonEncode({'notificationType': 'comment'}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
    });

    test('emits a follow tap via senderPubkey (no referencedEventId)', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      // Follows carry senderPubkey + eventId but no referencedEventId; the tap
      // must still emit so the router can open the actor's profile.
      service.handleNotificationTapPayload(
        jsonEncode({
          'notificationType': 'follow',
          'eventId': 'contact_list_event',
          'senderPubkey': 'follower_hex',
        }),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.referencedEventId, isNull);
      expect(events.single.senderPubkey, equals('follower_hex'));
      expect(events.single.eventId, equals('contact_list_event'));
      expect(events.single.notificationType, equals('follow'));
    });

    test('a foreground-built local payload round-trips to a routable tap '
        'event', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      // The exact payload the foreground path now attaches (built from FCM
      // data via the shared helper); tapping it must yield a routable event.
      final payload = jsonEncode(
        localNotificationTapPayload(const {
          'type': 'follow',
          'eventId': 'contact_event',
          'senderPubkey': 'follower_hex',
        }),
      );
      service.handleNotificationTapPayload(payload);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.notificationType, equals('follow'));
      expect(events.single.senderPubkey, equals('follower_hex'));
      expect(events.single.eventId, equals('contact_event'));
      expect(events.single.referencedEventId, isNull);
    });

    test('a campaign local payload round-trips its app-route target', () async {
      final events = <NotificationTapEvent>[];
      final sub = service.notificationTapStream.listen(events.add);
      addTearDown(sub.cancel);

      final payload = jsonEncode(
        localNotificationTapPayload(const {
          'type': 'campaign',
          'tapTargetType': 'app_route',
          'tapTargetValue': '/following/new',
        }),
      );
      service.handleNotificationTapPayload(payload);
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single.notificationType, equals('campaign'));
      expect(events.single.tapTargetType, equals('app_route'));
      expect(events.single.tapTargetValue, equals('/following/new'));
    });

    test('no-ops gracefully when the stream has no listeners', () {
      expect(
        () => service.handleNotificationTapPayload(
          jsonEncode({
            'referencedEventId': 'abc',
            'notificationType': 'reply',
          }),
        ),
        returnsNormally,
      );
    });
  });

  group('sendLocal payload forwarding', () {
    late NotificationService service;
    late _MockFlutterLocalNotificationsPlugin plugin;

    setUp(() {
      service = NotificationService();
      plugin = _MockFlutterLocalNotificationsPlugin();
    });

    tearDown(() {
      service.dispose();
    });

    test('forwards the tap payload to the plugin show() call', () async {
      when(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      service.debugConfigurePlugin(plugin);

      final payload = jsonEncode(
        localNotificationTapPayload(const {
          'type': 'comment',
          'eventId': 'comment_event',
          'referencedEventId': 'video_event',
          'senderPubkey': 'actor_hex',
        }),
      );

      await service.sendLocal(
        title: 'New comment',
        body: 'alice commented',
        payload: payload,
      );

      // The exact payload reaches the plugin's show(payload:) — the seam this
      // change adds. The round-trip test above proves the payload then parses
      // back to a routable tap event.
      final captured = verify(
        () => plugin.show(
          id: any(named: 'id'),
          title: 'New comment',
          body: 'alice commented',
          notificationDetails: any(named: 'notificationDetails'),
          payload: captureAny(named: 'payload'),
        ),
      ).captured;
      expect(captured.single, equals(payload));
    });

    test(
      'omits the payload (null) when sendLocal is called without one',
      () async {
        when(
          () => plugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async {});

        service.debugConfigurePlugin(plugin);

        await service.sendLocal(title: 'Upload complete', body: 'done');

        final captured = verify(
          () => plugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: captureAny(named: 'payload'),
          ),
        ).captured;
        expect(captured.single, isNull);
      },
    );
  });

  group('takeLaunchNotificationTap', () {
    late NotificationService service;
    late _MockFlutterLocalNotificationsPlugin plugin;

    setUp(() {
      service = NotificationService();
      plugin = _MockFlutterLocalNotificationsPlugin();
    });

    tearDown(() {
      service.dispose();
    });

    test(
      'routes a local notification that launched the app (cold start)',
      () async {
        when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => NotificationAppLaunchDetails(
            true,
            notificationResponse: NotificationResponse(
              notificationResponseType:
                  NotificationResponseType.selectedNotification,
              payload: jsonEncode(
                localNotificationTapPayload(const {
                  'type': 'follow',
                  'eventId': 'contact_event',
                  'senderPubkey': 'follower_hex',
                }),
              ),
            ),
          ),
        );

        service.debugConfigurePlugin(plugin);

        final tap = await service.takeLaunchNotificationTap();

        expect(tap, isNotNull);
        expect(tap!.notificationType, equals('follow'));
        expect(tap.senderPubkey, equals('follower_hex'));
        expect(tap.eventId, equals('contact_event'));
        expect(tap.referencedEventId, isNull);
      },
    );

    test(
      'returns null when the app was not launched by a notification',
      () async {
        when(() => plugin.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => const NotificationAppLaunchDetails(false),
        );

        service.debugConfigurePlugin(plugin);

        expect(await service.takeLaunchNotificationTap(), isNull);
      },
    );

    test('returns null when there are no launch details', () async {
      when(
        () => plugin.getNotificationAppLaunchDetails(),
      ).thenAnswer((_) async => null);

      service.debugConfigurePlugin(plugin);

      expect(await service.takeLaunchNotificationTap(), isNull);
    });
  });

  group('NotificationTapEvent', () {
    test('uses value equality for event comparisons', () {
      const first = NotificationTapEvent(
        referencedEventId: 'abc123',
        referencedAddress: '34236:owner:vine',
        notificationType: 'reply',
        tapTargetType: 'app_route',
        tapTargetValue: '/following/new',
      );
      const second = NotificationTapEvent(
        referencedEventId: 'abc123',
        referencedAddress: '34236:owner:vine',
        notificationType: 'reply',
        tapTargetType: 'app_route',
        tapTargetValue: '/following/new',
      );
      const third = NotificationTapEvent(
        referencedEventId: 'xyz789',
        notificationType: 'reply',
      );
      const differsByAddress = NotificationTapEvent(
        referencedEventId: 'abc123',
        referencedAddress: '34236:owner:other-vine',
        notificationType: 'reply',
      );
      const differsByTarget = NotificationTapEvent(
        referencedEventId: 'abc123',
        referencedAddress: '34236:owner:vine',
        notificationType: 'reply',
        tapTargetType: 'app_route',
        tapTargetValue: '/notifications',
      );

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
      expect(first, isNot(equals(third)));
      expect(first, isNot(equals(differsByAddress)));
      expect(first, isNot(equals(differsByTarget)));
    });
  });
}
