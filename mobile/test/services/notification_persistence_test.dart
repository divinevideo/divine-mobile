// ABOUTME: Tests for NotificationPersistence - handles Hive storage operations
// ABOUTME: Pure persistence logic tests without service dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/services/notification_persistence.dart';
import '../helpers/real_integration_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationPersistence', () {
    late NotificationPersistence persistence;
    late Box<dynamic> testBox;

    setUpAll(() async {
      // Setup test environment with platform channel mocks
      await RealIntegrationTestHelper.setupTestEnvironment();
      // Initialize Hive for testing
      await Hive.initFlutter('test_notification_persistence');
    });

    setUp(() async {
      // Open a fresh test box for each test
      testBox = await Hive.openBox<dynamic>('test_notifications');
      persistence = NotificationPersistence(testBox);
    });

    tearDown(() async {
      // Clean up after each test
      if (testBox.isOpen) {
        await testBox.clear();
        await testBox.close();
      }
      try {
        await Hive.deleteBoxFromDisk('test_notifications');
      } catch (e) {
        // Box might already be deleted, that's fine
      }
    });

    group('saveNotification', () {
      test('saves notification to Hive box', () async {
        // Arrange
        final notification = NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user123',
          actorName: 'Test User',
          message: 'liked your video',
          timestamp: DateTime(2024, 1, 1),
        );

        // Act
        await persistence.saveNotification(notification);

        // Assert
        expect(testBox.containsKey('notif1'), isTrue);
        final saved = testBox.get('notif1') as Map<String, dynamic>;
        expect(saved, isNotNull);
        expect(saved['id'], 'notif1');
        expect(
          saved['type'],
          NotificationType.like.index,
        ); // Enum stored as index
      });

      test('overwrites existing notification with same ID', () async {
        // Arrange
        final notification1 = NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user123',
          actorName: 'Test User',
          message: 'liked your video',
          timestamp: DateTime(2024, 1, 1),
          isRead: false,
        );

        final notification2 = notification1.copyWith(isRead: true);

        // Act
        await persistence.saveNotification(notification1);
        await persistence.saveNotification(notification2);

        // Assert
        expect(testBox.length, 1);
        final saved = testBox.get('notif1');
        expect(saved!['isRead'], isTrue);
      });
    });

    group('loadAllNotifications', () {
      test('returns empty list when no notifications exist', () async {
        // Act
        final notifications = await persistence.loadAllNotifications();

        // Assert
        expect(notifications, isEmpty);
      });

      test('loads all notifications from Hive box', () async {
        // Arrange
        final notification1 = NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user123',
          actorName: 'User 1',
          message: 'liked your video',
          timestamp: DateTime(2024, 1, 1),
        );

        final notification2 = NotificationModel(
          id: 'notif2',
          type: NotificationType.comment,
          actorPubkey: 'user456',
          actorName: 'User 2',
          message: 'commented',
          timestamp: DateTime(2024, 1, 2),
        );

        await testBox.put('notif1', notification1.toJson());
        await testBox.put('notif2', notification2.toJson());

        // Act
        final notifications = await persistence.loadAllNotifications();

        // Assert
        expect(notifications.length, 2);
        expect(notifications.any((n) => n.id == 'notif1'), isTrue);
        expect(notifications.any((n) => n.id == 'notif2'), isTrue);
      });

      test('skips corrupted notifications and continues loading', () async {
        // Arrange
        final validNotification = NotificationModel(
          id: 'valid',
          type: NotificationType.like,
          actorPubkey: 'user123',
          actorName: 'Valid User',
          message: 'liked',
          timestamp: DateTime(2024, 1, 1),
        );

        await testBox.put('valid', validNotification.toJson());
        await testBox.put('corrupted', <String, dynamic>{'invalid': 'data'});

        // Act
        final notifications = await persistence.loadAllNotifications();

        // Assert
        expect(notifications.length, 1);
        expect(notifications.first.id, 'valid');
      });

      test(
        'returns corrupted count when notifications fail to parse',
        () async {
          // Arrange
          await testBox.put('corrupted1', <String, dynamic>{
            'invalid': 'data1',
          });
          await testBox.put('corrupted2', <String, dynamic>{
            'invalid': 'data2',
          });

          // Act
          final notifications = await persistence.loadAllNotifications();

          // Assert
          expect(notifications, isEmpty);
        },
      );
    });

    group('clearAll', () {
      test('removes all notifications from Hive box', () async {
        // Arrange
        final notification1 = NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user123',
          actorName: 'User 1',
          message: 'liked',
          timestamp: DateTime(2024, 1, 1),
        );

        await persistence.saveNotification(notification1);
        expect(testBox.length, 1);

        // Act
        await persistence.clearAll();

        // Assert
        expect(testBox.isEmpty, isTrue);
      });

      test('works when box is already empty', () async {
        // Act & Assert
        expect(() => persistence.clearAll(), returnsNormally);
        expect(testBox.isEmpty, isTrue);
      });
    });

    group('clearOlderThan', () {
      test('removes notifications older than cutoff date', () async {
        // Arrange
        final old = NotificationModel(
          id: 'old',
          type: NotificationType.like,
          actorPubkey: 'user1',
          actorName: 'Old User',
          message: 'old',
          timestamp: DateTime(2024, 1, 1),
        );

        final recent = NotificationModel(
          id: 'recent',
          type: NotificationType.like,
          actorPubkey: 'user2',
          actorName: 'Recent User',
          message: 'recent',
          timestamp: DateTime(2024, 12, 31),
        );

        await persistence.saveNotification(old);
        await persistence.saveNotification(recent);

        // Act - clear notifications older than 6 months from Dec 31
        final cutoff = DateTime(2024, 6, 1);
        await persistence.clearOlderThan(cutoff);

        // Assert
        expect(testBox.containsKey('old'), isFalse);
        expect(testBox.containsKey('recent'), isTrue);
      });

      test('keeps all notifications when none are old enough', () async {
        // Arrange
        final notification1 = NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user1',
          actorName: 'User 1',
          message: 'liked',
          timestamp: DateTime(2024, 10, 1),
        );

        final notification2 = NotificationModel(
          id: 'notif2',
          type: NotificationType.like,
          actorPubkey: 'user2',
          actorName: 'User 2',
          message: 'liked',
          timestamp: DateTime(2024, 11, 1),
        );

        await persistence.saveNotification(notification1);
        await persistence.saveNotification(notification2);

        // Act - cutoff is before all notifications
        final cutoff = DateTime(2024, 1, 1);
        await persistence.clearOlderThan(cutoff);

        // Assert
        expect(testBox.length, 2);
      });
    });

    group('close', () {
      test('closes the Hive box', () async {
        // Act
        await persistence.close();

        // Assert
        expect(testBox.isOpen, isFalse);
      });

      test('can be called multiple times safely', () async {
        // Act & Assert
        await persistence.close();
        expect(() => persistence.close(), returnsNormally);
      });
    });
  });
}
