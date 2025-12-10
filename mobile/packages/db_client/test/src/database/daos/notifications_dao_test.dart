// ABOUTME: Unit tests for NotificationsDao with read status and cleanup
// ABOUTME: operations. Tests upsertNotification, getAllNotifications,
// ABOUTME: markAsRead, deleteOlderThan.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late NotificationsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkeys for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const testPubkey2 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  /// Valid 64-char hex event ID for testing
  const testEventId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.notificationsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('NotificationsDao', () {
    group('upsertNotification', () {
      test('inserts new notification', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
          targetEventId: testEventId,
          content: 'liked your video',
        );

        final results = await dao.getAllNotifications();
        expect(results, hasLength(1));
        expect(results.first.id, equals('notif_1'));
        expect(results.first.type, equals('like'));
        expect(results.first.fromPubkey, equals(testPubkey));
        expect(results.first.timestamp, equals(1700000000));
        expect(results.first.targetEventId, equals(testEventId));
        expect(results.first.content, equals('liked your video'));
        expect(results.first.isRead, isFalse);
      });

      test('updates existing notification with same ID', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );

        await dao.upsertNotification(
          id: 'notif_1',
          type: 'follow',
          fromPubkey: testPubkey2,
          timestamp: 1700000001,
        );

        final results = await dao.getAllNotifications();
        expect(results, hasLength(1));
        expect(results.first.type, equals('follow'));
        expect(results.first.fromPubkey, equals(testPubkey2));
      });

      test('handles null optional fields', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );

        final results = await dao.getAllNotifications();
        expect(results.first.targetEventId, isNull);
        expect(results.first.targetPubkey, isNull);
        expect(results.first.content, isNull);
      });

      test('sets cachedAt timestamp', () async {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        final after = DateTime.now().add(const Duration(seconds: 1));

        final results = await dao.getAllNotifications();
        expect(results.first.cachedAt.isAfter(before), isTrue);
        expect(results.first.cachedAt.isBefore(after), isTrue);
      });
    });

    group('getAllNotifications', () {
      test('returns notifications sorted by timestamp descending', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_2',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000002,
        );
        await dao.upsertNotification(
          id: 'notif_3',
          type: 'comment',
          fromPubkey: testPubkey,
          timestamp: 1700000001,
        );

        final results = await dao.getAllNotifications();
        expect(results[0].id, equals('notif_2'));
        expect(results[1].id, equals('notif_3'));
        expect(results[2].id, equals('notif_1'));
      });

      test('respects limit parameter', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_2',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000001,
        );
        await dao.upsertNotification(
          id: 'notif_3',
          type: 'comment',
          fromPubkey: testPubkey,
          timestamp: 1700000002,
        );

        final results = await dao.getAllNotifications(limit: 2);
        expect(results, hasLength(2));
      });

      test('returns empty list when no notifications exist', () async {
        final results = await dao.getAllNotifications();
        expect(results, isEmpty);
      });
    });

    group('getUnreadCount', () {
      test('returns count of unread notifications', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_2',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000001,
          isRead: true,
        );
        await dao.upsertNotification(
          id: 'notif_3',
          type: 'comment',
          fromPubkey: testPubkey,
          timestamp: 1700000002,
        );

        final count = await dao.getUnreadCount();
        expect(count, equals(2));
      });

      test('returns 0 when all are read', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
          isRead: true,
        );

        final count = await dao.getUnreadCount();
        expect(count, equals(0));
      });

      test('returns 0 when no notifications exist', () async {
        final count = await dao.getUnreadCount();
        expect(count, equals(0));
      });
    });

    group('markAsRead', () {
      test('marks notification as read', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );

        final result = await dao.markAsRead('notif_1');

        expect(result, isTrue);
        final notifications = await dao.getAllNotifications();
        expect(notifications.first.isRead, isTrue);
      });

      test('returns false for non-existent notification', () async {
        final result = await dao.markAsRead('nonexistent');
        expect(result, isFalse);
      });

      test('does not affect other notifications', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_2',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000001,
        );

        await dao.markAsRead('notif_1');

        final count = await dao.getUnreadCount();
        expect(count, equals(1));
      });
    });

    group('markAllAsRead', () {
      test('marks all notifications as read', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_2',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000001,
        );

        final updated = await dao.markAllAsRead();

        expect(updated, equals(2));
        final count = await dao.getUnreadCount();
        expect(count, equals(0));
      });

      test(
        'returns count of all rows '
        '(UPDATE touches all rows regardless of current value)',
        () async {
          await dao.upsertNotification(
            id: 'notif_1',
            type: 'like',
            fromPubkey: testPubkey,
            timestamp: 1700000000,
            isRead: true,
          );

          final updated = await dao.markAllAsRead();
          expect(updated, equals(1));
        },
      );
    });

    group('deleteNotification', () {
      test('deletes notification by ID', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_2',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000001,
        );

        final deleted = await dao.deleteNotification('notif_1');

        expect(deleted, equals(1));
        final results = await dao.getAllNotifications();
        expect(results, hasLength(1));
        expect(results.first.id, equals('notif_2'));
      });

      test('returns 0 for non-existent notification', () async {
        final deleted = await dao.deleteNotification('nonexistent');
        expect(deleted, equals(0));
      });
    });

    group('deleteOlderThan', () {
      test('deletes notifications older than timestamp', () async {
        await dao.upsertNotification(
          id: 'notif_old',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_new',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000002,
        );

        final deleted = await dao.deleteOlderThan(1700000001);

        expect(deleted, equals(1));
        final results = await dao.getAllNotifications();
        expect(results, hasLength(1));
        expect(results.first.id, equals('notif_new'));
      });

      test('keeps all when none are older', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );

        final deleted = await dao.deleteOlderThan(1699999999);

        expect(deleted, equals(0));
        final results = await dao.getAllNotifications();
        expect(results, hasLength(1));
      });
    });

    group('watchAllNotifications', () {
      test('emits initial list', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );

        final stream = dao.watchAllNotifications();
        final results = await stream.first;

        expect(results, hasLength(1));
        expect(results.first.id, equals('notif_1'));
      });

      test('respects limit parameter', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_2',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000001,
        );

        final stream = dao.watchAllNotifications(limit: 1);
        final results = await stream.first;

        expect(results, hasLength(1));
      });
    });

    group('watchUnreadCount', () {
      test('emits initial count', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_2',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000001,
          isRead: true,
        );

        final stream = dao.watchUnreadCount();
        final count = await stream.first;

        expect(count, equals(1));
      });

      test('emits 0 when all read', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
          isRead: true,
        );

        final stream = dao.watchUnreadCount();
        final count = await stream.first;

        expect(count, equals(0));
      });
    });

    group('clearAll', () {
      test('deletes all notifications', () async {
        await dao.upsertNotification(
          id: 'notif_1',
          type: 'like',
          fromPubkey: testPubkey,
          timestamp: 1700000000,
        );
        await dao.upsertNotification(
          id: 'notif_2',
          type: 'follow',
          fromPubkey: testPubkey,
          timestamp: 1700000001,
        );

        final deleted = await dao.clearAll();

        expect(deleted, equals(2));
        final results = await dao.getAllNotifications();
        expect(results, isEmpty);
      });

      test('returns 0 when table is empty', () async {
        final deleted = await dao.clearAll();
        expect(deleted, equals(0));
      });
    });
  });
}
