// ABOUTME: Enhanced notification service with Nostr integration for social notifications
// ABOUTME: Handles likes, comments, follows, mentions, and video-related notifications

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:synchronized/synchronized.dart';

/// Enhanced notification service with social features
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class NotificationServiceEnhanced {
  /// Factory constructor that returns the singleton instance
  factory NotificationServiceEnhanced() => instance;

  NotificationServiceEnhanced._();
  static NotificationServiceEnhanced? _instance;

  /// Singleton instance
  static NotificationServiceEnhanced get instance {
    if (_instance == null || _instance!._disposed) {
      _instance = NotificationServiceEnhanced._();
    }
    return _instance!;
  }

  final List<NotificationModel> _notifications = [];
  final Map<String, StreamSubscription> _subscriptions = {};
  final Lock _notificationLock = Lock(); // Mutex for atomic deduplication

  INostrService? _nostrService;
  UserProfileService? _profileService;
  VideoEventService? _videoService;
  Box<Map<String, dynamic>>? _notificationBox;

  bool _permissionsGranted = false;
  bool _disposed = false;
  int _unreadCount = 0;

  /// List of recent notifications
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  /// Number of unread notifications
  int get unreadCount => _unreadCount;

  /// Check if notification permissions are granted
  bool get hasPermissions => _permissionsGranted;

  /// Initialize notification service
  Future<void> initialize({
    required INostrService nostrService,
    required UserProfileService profileService,
    required VideoEventService videoService,
  }) async {
    Log.debug(
      '🔧 Initializing Enhanced NotificationService',
      name: 'NotificationServiceEnhanced',
      category: LogCategory.system,
    );

    _nostrService = nostrService;
    _profileService = profileService;
    _videoService = videoService;

    try {
      // Initialize Hive for notification storage
      _notificationBox = await Hive.openBox<Map<String, dynamic>>(
        'notifications',
      );

      // Load cached notifications
      await _loadCachedNotifications();

      // Request notification permissions
      await _requestPermissions();

      // Subscribe to Nostr events for notifications
      await _subscribeToNostrEvents();

      Log.info(
        'Enhanced NotificationService initialized',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize enhanced notifications: $e',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
    }
  }

  /// Subscribe to Nostr events for real-time notifications
  Future<void> _subscribeToNostrEvents() async {
    if (_nostrService == null || !_nostrService!.hasKeys) {
      Log.warning(
        'Cannot subscribe to events without Nostr keys',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
      return;
    }

    final userPubkey = _nostrService!.publicKey!;

    // Subscribe to reactions (likes) on user's videos
    _subscribeToReactions(userPubkey);

    // Subscribe to comments on user's videos
    _subscribeToComments(userPubkey);

    // Subscribe to follows
    _subscribeToFollows(userPubkey);

    // Subscribe to mentions
    _subscribeToMentions(userPubkey);

    // Subscribe to reposts
    _subscribeToReposts(userPubkey);
  }

  /// Subscribe to reactions (likes) on user's videos
  void _subscribeToReactions(String userPubkey) {
    final filter = Filter(
      kinds: [7], // Kind 7 = Reactions (NIP-25)
      // NO h filter - we query all relays
    );

    final subscription = _nostrService!
        .subscribeToEvents(filters: [filter])
        .listen((event) async {
          await _handleReactionEvent(event);
        });

    _subscriptions['reactions'] = subscription;
  }

  /// Subscribe to comments on user's videos
  void _subscribeToComments(String userPubkey) {
    final filter = Filter(
      kinds: [1], // Kind 1 = Text notes (comments)
      // NO h filter - we query all relays
    );

    final subscription = _nostrService!
        .subscribeToEvents(filters: [filter])
        .listen((event) async {
          await _handleCommentEvent(event);
        });

    _subscriptions['comments'] = subscription;
  }

  /// Subscribe to follows
  void _subscribeToFollows(String userPubkey) {
    final filter = Filter(
      kinds: [3], // Kind 3 = Contact list (follows)
      // NO h filter - we query all relays
    );

    final subscription = _nostrService!
        .subscribeToEvents(filters: [filter])
        .listen((event) async {
          await _handleFollowEvent(event);
        });

    _subscriptions['follows'] = subscription;
  }

  /// Subscribe to mentions
  void _subscribeToMentions(String userPubkey) {
    final filter = Filter(
      kinds: [1, 30023], // Text notes and long-form content
      // NO h filter - we query all relays
    );

    final subscription = _nostrService!
        .subscribeToEvents(filters: [filter])
        .listen((event) async {
          await _handleMentionEvent(event);
        });

    _subscriptions['mentions'] = subscription;
  }

  /// Subscribe to reposts
  void _subscribeToReposts(String userPubkey) {
    final filter = Filter(
      kinds: [16], // Kind 16 = Generic Reposts (NIP-18)
      // NO h filter - we query all relays
    );

    final subscription = _nostrService!
        .subscribeToEvents(filters: [filter])
        .listen((event) async {
          await _handleRepostEvent(event);
        });

    _subscriptions['reposts'] = subscription;
  }

  /// Handle reaction (like) events
  Future<void> _handleReactionEvent(Event event) async {
    // Check if this is a like (+ reaction)
    if (event.content != '+') return;

    // Get the video that was liked
    String? videoEventId;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
        videoEventId = tag[1];
        break;
      }
    }
    if (videoEventId == null) return;

    // Get video info
    final videoEvent = _videoService?.getVideoEventById(videoEventId);

    // CRITICAL: Only create notification if this is the current user's video
    if (videoEvent == null || videoEvent.pubkey != _nostrService?.publicKey) {
      return;
    }

    // Get actor info - try multiple profile fields
    final actorProfile = await _profileService?.fetchProfile(event.pubkey);
    final actorName =
        actorProfile?.name ??
        actorProfile?.displayName ??
        actorProfile?.nip05?.split('@').first ??
        'Unknown user';

    final notification = NotificationModel(
      id: event.id,
      type: NotificationType.like,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName liked your video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      targetEventId: videoEventId,
      targetVideoUrl: videoEvent.videoUrl,
      targetVideoThumbnail: videoEvent.thumbnailUrl,
    );

    await _addNotification(notification);
  }

  /// Handle comment events
  Future<void> _handleCommentEvent(Event event) async {
    // Check if this is a reply to a video
    String? videoEventId;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
        videoEventId = tag[1];
        break;
      }
    }
    if (videoEventId == null) return;

    // Get video info
    final videoEvent = _videoService?.getVideoEventById(videoEventId);

    // CRITICAL: Only create notification if this is the current user's video
    if (videoEvent == null || videoEvent.pubkey != _nostrService?.publicKey) {
      return;
    }

    // Get actor info - try multiple profile fields
    final actorProfile = await _profileService?.fetchProfile(event.pubkey);
    final actorName =
        actorProfile?.name ??
        actorProfile?.displayName ??
        actorProfile?.nip05?.split('@').first ??
        'Unknown user';

    final notification = NotificationModel(
      id: event.id,
      type: NotificationType.comment,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName commented on your video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      targetEventId: videoEventId,
      targetVideoUrl: videoEvent.videoUrl,
      targetVideoThumbnail: videoEvent.thumbnailUrl,
      metadata: {'comment': event.content},
    );

    await _addNotification(notification);
  }

  /// Handle follow events
  Future<void> _handleFollowEvent(Event event) async {
    // CRITICAL: Check if the contact list includes the current user
    final currentUserPubkey = _nostrService?.publicKey;
    if (currentUserPubkey == null) return;

    // Check if current user is in the 'p' tags (meaning event.pubkey is following them)
    bool isFollowingCurrentUser = false;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
        if (tag[1] == currentUserPubkey) {
          isFollowingCurrentUser = true;
          break;
        }
      }
    }

    // Only create notification if this contact list includes the current user
    if (!isFollowingCurrentUser) return;

    // Get actor info - try multiple profile fields
    final actorProfile = await _profileService?.fetchProfile(event.pubkey);
    final actorName =
        actorProfile?.name ??
        actorProfile?.displayName ??
        actorProfile?.nip05?.split('@').first ??
        'Unknown user';

    final notification = NotificationModel(
      id: event.id,
      type: NotificationType.follow,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName started following you',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
    );

    await _addNotification(notification);
  }

  /// Handle mention events
  Future<void> _handleMentionEvent(Event event) async {
    // CRITICAL: Check if the event mentions the current user
    final currentUserPubkey = _nostrService?.publicKey;
    if (currentUserPubkey == null) return;

    // Check if current user is mentioned in 'p' tags
    bool mentionsCurrentUser = false;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
        if (tag[1] == currentUserPubkey) {
          mentionsCurrentUser = true;
          break;
        }
      }
    }

    // Only create notification if this event mentions the current user
    if (!mentionsCurrentUser) return;

    // Get actor info - try multiple profile fields
    final actorProfile = await _profileService?.fetchProfile(event.pubkey);
    final actorName =
        actorProfile?.name ??
        actorProfile?.displayName ??
        actorProfile?.nip05?.split('@').first ??
        'Unknown user';

    final notification = NotificationModel(
      id: event.id,
      type: NotificationType.mention,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName mentioned you',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      metadata: {'text': event.content},
    );

    await _addNotification(notification);
  }

  /// Handle repost events
  Future<void> _handleRepostEvent(Event event) async {
    // Get the video that was reposted
    String? videoEventId;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
        videoEventId = tag[1];
        break;
      }
    }
    if (videoEventId == null) return;

    // Get video info
    final videoEvent = _videoService?.getVideoEventById(videoEventId);

    // CRITICAL: Only create notification if this is the current user's video
    if (videoEvent == null || videoEvent.pubkey != _nostrService?.publicKey) {
      return;
    }

    // Get actor info - try multiple profile fields
    final actorProfile = await _profileService?.fetchProfile(event.pubkey);
    final actorName =
        actorProfile?.name ??
        actorProfile?.displayName ??
        actorProfile?.nip05?.split('@').first ??
        'Unknown user';

    final notification = NotificationModel(
      id: event.id,
      type: NotificationType.repost,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName reposted your video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      targetEventId: videoEventId,
      targetVideoUrl: videoEvent.videoUrl,
      targetVideoThumbnail: videoEvent.thumbnailUrl,
    );

    await _addNotification(notification);
  }

  /// Add a notification
  /// Uses mutex lock to prevent race condition when same notification arrives via multiple handlers
  Future<void> _addNotification(NotificationModel notification) async {
    // Use synchronized lock to make check-and-insert atomic
    // This prevents duplicates when the same event triggers multiple handlers concurrently
    await _notificationLock.synchronized(() async {
      // Check if we already have this notification (now atomic with insert)
      if (_notifications.any((n) => n.id == notification.id)) {
        return;
      }

      // Add to list
      _notifications.insert(0, notification);

      // Update unread count
      _updateUnreadCount();

      // Save to cache
      await _saveNotificationToCache(notification);

      // Show platform notification if permissions granted
      if (_permissionsGranted && !notification.isRead) {
        await _showPlatformNotification(notification);
      }

      // Keep only recent notifications
      if (_notifications.length > 100) {
        _notifications.removeRange(100, _notifications.length);
      }
    });
  }

  /// Add notification for testing (exposes private _addNotification for tests)
  @visibleForTesting
  Future<void> addNotificationForTesting(NotificationModel notification) async {
    await _addNotification(notification);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _updateUnreadCount();
      await _saveNotificationToCache(_notifications[index]);
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        await _saveNotificationToCache(_notifications[i]);
      }
    }
    _updateUnreadCount();
  }

  /// Handle notification tap/click for navigation
  Future<void> handleNotificationTap(String notificationId) async {
    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () =>
          throw ArgumentError('Notification not found: $notificationId'),
    );

    // Mark as read
    await markAsRead(notificationId);

    // Log the navigation action for debugging
    Log.info(
      '🔔 Notification tapped: ${notification.navigationAction} -> ${notification.navigationTarget}',
      name: 'NotificationServiceEnhanced',
      category: LogCategory.system,
    );

    // Navigation will be handled by the UI layer based on navigationAction and navigationTarget
    // This could be extended to use Navigator or a routing service if needed
  }

  /// Update unread count
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

  /// Get notifications by type
  List<NotificationModel> getNotificationsByType(NotificationType type) =>
      _notifications.where((n) => n.type == type).toList();

  /// Load cached notifications from Hive
  Future<void> _loadCachedNotifications() async {
    if (_notificationBox == null) return;

    try {
      final cached = _notificationBox!.values.toList();
      int loadedCount = 0;
      int corruptedCount = 0;

      for (final data in cached) {
        try {
          // Ensure proper Map<String, dynamic> type casting
          // Note: Despite Hive typing, corruption can cause unexpected types
          final jsonData = Map<String, dynamic>.from(data as Map);

          final notification = NotificationModel.fromJson(jsonData);
          _notifications.add(notification);
          loadedCount++;
        } catch (e) {
          // Log corrupted notification and continue with others
          Log.warning(
            'Skipping corrupted notification: $e',
            name: 'NotificationServiceEnhanced',
            category: LogCategory.system,
          );
          corruptedCount++;
        }
      }

      // Sort by timestamp (newest first)
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Update unread count
      _updateUnreadCount();

      Log.debug(
        '📱 Loaded $loadedCount cached notifications${corruptedCount > 0 ? " ($corruptedCount corrupted entries skipped)" : ""}',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );

      // If many notifications are corrupted, clear the cache
      if (corruptedCount > loadedCount && corruptedCount > 10) {
        Log.warning(
          'Too many corrupted notifications ($corruptedCount), clearing cache',
          name: 'NotificationServiceEnhanced',
          category: LogCategory.system,
        );
        await _clearCorruptedCache();
      }
    } catch (e) {
      Log.error(
        'Failed to load cached notifications: $e',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
      // Try to clear corrupted cache and continue
      await _clearCorruptedCache();
    }
  }

  /// Clear corrupted cache data
  Future<void> _clearCorruptedCache() async {
    try {
      await _notificationBox?.clear();
      _notifications.clear();
      _updateUnreadCount();
      Log.info(
        'Cleared corrupted notification cache',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to clear corrupted cache: $e',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
    }
  }

  /// Save notification to cache
  Future<void> _saveNotificationToCache(NotificationModel notification) async {
    if (_notificationBox == null) return;

    try {
      await _notificationBox!.put(notification.id, notification.toJson());
    } catch (e) {
      Log.error(
        'Failed to cache notification: $e',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
    }
  }

  /// Request notification permissions from platform
  /// FUTURE: Integrate flutter_local_notifications for real platform notifications
  /// Required: Platform-specific permission handling (iOS/Android/macOS)
  Future<void> _requestPermissions() async {
    try {
      // Currently simulating granted permissions
      // Real implementation needs:
      // - flutter_local_notifications package integration
      // - iOS: Info.plist configuration + UNUserNotificationCenter
      // - Android: AndroidManifest.xml permissions + NotificationManager
      // - macOS: Entitlements + UNUserNotificationCenter
      _permissionsGranted = true;
      Log.info(
        'Notification permissions granted (simulated)',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
    } catch (e) {
      _permissionsGranted = false;
      Log.error(
        'Failed to get notification permissions: $e',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
    }
  }

  /// Show platform-specific notification
  /// FUTURE: Integrate flutter_local_notifications for real platform notifications
  Future<void> _showPlatformNotification(NotificationModel notification) async {
    try {
      // Currently using debug logging instead of real notifications
      // Real implementation needs flutter_local_notifications integration
      Log.debug(
        '📱 Platform notification: ${notification.typeIcon} ${notification.message}',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );

      // Simulate haptic feedback
      HapticFeedback.mediumImpact();
    } catch (e) {
      Log.error(
        'Failed to show platform notification: $e',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    _unreadCount = 0;

    // Clear cache
    await _notificationBox?.clear();

    Log.debug(
      '📱️ Cleared all notifications',
      name: 'NotificationServiceEnhanced',
      category: LogCategory.system,
    );
  }

  /// Clear notifications older than specified duration
  Future<void> clearOlderThan(Duration duration) async {
    final cutoff = DateTime.now().subtract(duration);
    final initialCount = _notifications.length;

    // Remove old notifications
    _notifications.removeWhere(
      (notification) => notification.timestamp.isBefore(cutoff),
    );

    // Update cache
    if (_notificationBox != null) {
      final keysToRemove = <String>[];
      for (final entry in _notificationBox!.toMap().entries) {
        final notification = NotificationModel.fromJson(entry.value);
        if (notification.timestamp.isBefore(cutoff)) {
          keysToRemove.add(entry.key);
        }
      }
      await _notificationBox!.deleteAll(keysToRemove);
    }

    final removedCount = initialCount - _notifications.length;
    if (removedCount > 0) {
      _updateUnreadCount();

      Log.debug(
        '📱️ Cleared $removedCount old notifications',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
    }
  }

  /// Refresh notifications by re-subscribing to Nostr events
  Future<void> refreshNotifications() async {
    if (_nostrService == null || !_nostrService!.hasKeys) {
      Log.warning(
        'Cannot refresh notifications without Nostr keys',
        name: 'NotificationServiceEnhanced',
        category: LogCategory.system,
      );
      return;
    }

    Log.debug(
      '🔄 Refreshing notifications',
      name: 'NotificationServiceEnhanced',
      category: LogCategory.system,
    );

    // Cancel existing subscriptions
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Re-subscribe to Nostr events for fresh notifications
    await _subscribeToNostrEvents();

    Log.info(
      '📱 Notifications refreshed',
      name: 'NotificationServiceEnhanced',
      category: LogCategory.system,
    );
  }

  void dispose() {
    if (_disposed) return;

    _disposed = true;

    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Clear notifications
    _notifications.clear();

    // Close Hive box
    _notificationBox?.close();
  }

  /// Check if this service is still mounted/active
  bool get mounted => !_disposed;
}
