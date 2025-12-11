// ABOUTME: Data Access Object for notification persistence operations.
// ABOUTME: Provides CRUD with timestamp-based cleanup.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'notifications_dao.g.dart';

@DriftAccessor(tables: [Notifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationsDaoMixin {
  NotificationsDao(super.attachedDatabase);

  /// Upsert a notification
  Future<void> upsertNotification({
    required String id,
    required String type,
    required String fromPubkey,
    required int timestamp,
    String? targetEventId,
    String? targetPubkey,
    String? content,
    bool isRead = false,
  }) {
    return into(notifications).insertOnConflictUpdate(
      NotificationsCompanion.insert(
        id: id,
        type: type,
        fromPubkey: fromPubkey,
        timestamp: timestamp,
        targetEventId: Value(targetEventId),
        targetPubkey: Value(targetPubkey),
        content: Value(content),
        isRead: Value(isRead),
        cachedAt: DateTime.now(),
      ),
    );
  }

  /// Get all notifications sorted by timestamp (newest first)
  Future<List<NotificationRow>> getAllNotifications({int? limit}) {
    final query = select(notifications)
      ..orderBy([
        (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    final query = selectOnly(notifications)
      ..where(notifications.isRead.equals(false))
      ..addColumns([notifications.id.count()]);
    final result = await query.getSingle();
    return result.read(notifications.id.count()) ?? 0;
  }

  /// Mark notification as read
  Future<bool> markAsRead(String id) async {
    final rowsAffected =
        await (update(notifications)..where((t) => t.id.equals(id))).write(
          const NotificationsCompanion(isRead: Value(true)),
        );
    return rowsAffected > 0;
  }

  /// Mark all notifications as read
  Future<int> markAllAsRead() {
    return update(notifications).write(
      const NotificationsCompanion(isRead: Value(true)),
    );
  }

  /// Delete notification by ID
  Future<int> deleteNotification(String id) {
    return (delete(notifications)..where((t) => t.id.equals(id))).go();
  }

  /// Delete notifications older than a timestamp
  Future<int> deleteOlderThan(int timestamp) {
    return (delete(
      notifications,
    )..where((t) => t.timestamp.isSmallerThan(Variable(timestamp)))).go();
  }

  /// Watch all notifications (reactive stream)
  Stream<List<NotificationRow>> watchAllNotifications({int? limit}) {
    final query = select(notifications)
      ..orderBy([
        (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  /// Watch unread count (reactive stream)
  Stream<int> watchUnreadCount() {
    final query = selectOnly(notifications)
      ..where(notifications.isRead.equals(false))
      ..addColumns([notifications.id.count()]);
    return query.watchSingle().map(
      (row) => row.read(notifications.id.count()) ?? 0,
    );
  }

  /// Clear all notifications
  Future<int> clearAll() {
    return delete(notifications).go();
  }
}
