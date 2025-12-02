// ABOUTME: Handles notification persistence using Hive storage
// ABOUTME: Abstracts all Hive operations for notifications from service layer

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Handles persistence of notifications to Hive storage
class NotificationPersistence {
  final Box<dynamic> _box;

  NotificationPersistence(this._box);

  /// Save a notification to storage
  Future<void> saveNotification(NotificationModel notification) async {
    try {
      await _box.put(notification.id, notification.toJson());
    } catch (e) {
      Log.error(
        'Failed to save notification: $e',
        name: 'NotificationPersistence',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Load all notifications from storage
  /// Returns list of successfully loaded notifications, skipping corrupted entries
  Future<List<NotificationModel>> loadAllNotifications() async {
    try {
      final notifications = <NotificationModel>[];
      int corruptedCount = 0;

      for (final data in _box.values) {
        try {
          // Ensure proper Map<String, dynamic> type casting
          final jsonData = Map<String, dynamic>.from(data as Map);
          final notification = NotificationModel.fromJson(jsonData);
          notifications.add(notification);
        } catch (e) {
          // Log corrupted notification and continue with others
          Log.warning(
            'Skipping corrupted notification: $e',
            name: 'NotificationPersistence',
            category: LogCategory.system,
          );
          corruptedCount++;
        }
      }

      if (corruptedCount > 0) {
        Log.debug(
          'Loaded ${notifications.length} notifications ($corruptedCount corrupted entries skipped)',
          name: 'NotificationPersistence',
          category: LogCategory.system,
        );
      }

      return notifications;
    } catch (e) {
      Log.error(
        'Failed to load notifications: $e',
        name: 'NotificationPersistence',
        category: LogCategory.system,
      );
      return [];
    }
  }

  /// Clear all notifications from storage
  Future<void> clearAll() async {
    try {
      await _box.clear();
    } catch (e) {
      Log.error(
        'Failed to clear notifications: $e',
        name: 'NotificationPersistence',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Clear notifications older than the specified cutoff date
  Future<void> clearOlderThan(DateTime cutoff) async {
    try {
      final keysToRemove = <String>[];

      for (final entry in _box.toMap().entries) {
        try {
          final notification = NotificationModel.fromJson(entry.value);
          if (notification.timestamp.isBefore(cutoff)) {
            keysToRemove.add(entry.key);
          }
        } catch (e) {
          // If we can't parse it, mark for removal
          Log.warning(
            'Removing unparseable notification during cleanup: $e',
            name: 'NotificationPersistence',
            category: LogCategory.system,
          );
          keysToRemove.add(entry.key);
        }
      }

      if (keysToRemove.isNotEmpty) {
        await _box.deleteAll(keysToRemove);
        Log.debug(
          'Removed ${keysToRemove.length} old notifications',
          name: 'NotificationPersistence',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to clear old notifications: $e',
        name: 'NotificationPersistence',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Close the storage box
  Future<void> close() async {
    if (_box.isOpen) {
      await _box.close();
    }
  }
}
