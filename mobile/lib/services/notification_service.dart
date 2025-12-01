// ABOUTME: Service for showing user notifications about upload status and publishing
// ABOUTME: Handles local notifications and in-app messages for video processing updates

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Types of notifications
enum NotificationType {
  uploadComplete,
  videoPublished,
  uploadFailed,
  processingStarted,
}

/// Notification data structure
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class AppNotification {
  AppNotification({
    required this.title,
    required this.body,
    required this.type,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create notification for successful video publishing
  factory AppNotification.videoPublished({
    required String videoTitle,
    required String nostrEventId,
    String? videoUrl,
  }) => AppNotification(
    title: 'Video Published!',
    body: videoTitle.isEmpty
        ? 'Your vine is now live on Nostr'
        : '"$videoTitle" is now live on Nostr',
    type: NotificationType.videoPublished,
    data: {
      'event_id': nostrEventId,
      'video_url': videoUrl,
      'action': 'open_feed',
    },
  );

  /// Create notification for upload completion
  factory AppNotification.uploadComplete({required String videoTitle}) =>
      AppNotification(
        title: 'Upload Complete',
        body: videoTitle.isEmpty
            ? 'Your video is processing'
            : '"$videoTitle" is being processed',
        type: NotificationType.uploadComplete,
        data: {'action': 'open_uploads'},
      );

  /// Create notification for upload failure
  factory AppNotification.uploadFailed({
    required String videoTitle,
    required String reason,
  }) => AppNotification(
    title: 'Upload Failed',
    body: videoTitle.isEmpty
        ? 'Video upload failed: $reason'
        : '"$videoTitle" failed: $reason',
    type: NotificationType.uploadFailed,
    data: {'action': 'retry_upload', 'reason': reason},
  );

  /// Create notification for processing start
  factory AppNotification.processingStarted({required String videoTitle}) =>
      AppNotification(
        title: 'Processing Started',
        body: videoTitle.isEmpty
            ? 'Your video is being processed'
            : 'Processing "$videoTitle"',
        type: NotificationType.processingStarted,
        data: {'action': 'show_progress'},
      );
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
}

/// Service for managing app notifications
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class NotificationService {
  /// Factory constructor that returns the singleton instance
  factory NotificationService() => instance;

  NotificationService._();
  static NotificationService? _instance;

  /// Singleton instance
  static NotificationService get instance {
    if (_instance == null || _instance!._disposed) {
      _instance = NotificationService._();
    }
    return _instance!;
  }

  final List<AppNotification> _notifications = [];
  bool _permissionsGranted = false;
  bool _disposed = false;

  // Flutter local notifications plugin instance
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _pluginInitialized = false;

  /// List of recent notifications
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  /// Check if notification permissions are granted
  bool get hasPermissions => _permissionsGranted;

  /// Initialize notification service
  ///
  /// Call this from main.dart after runApp() to set up notifications:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   runApp(MyApp());
  ///
  ///   // Initialize notifications (optional - will auto-init on first use)
  ///   await NotificationService().initialize();
  /// }
  /// ```
  Future<void> initialize() async {
    Log.debug(
      '🔧 Initializing NotificationService',
      name: 'NotificationService',
      category: LogCategory.system,
    );

    try {
      // Request notification permissions
      await _requestPermissions();

      Log.info(
        'NotificationService initialized',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize notifications: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    }
  }

  /// Show a notification
  Future<void> show(AppNotification notification) async {
    Log.debug(
      '📱 Showing notification: ${notification.title}',
      name: 'NotificationService',
      category: LogCategory.system,
    );

    // Add to internal list
    _addNotification(notification);

    try {
      if (_permissionsGranted) {
        // Show platform notification
        await _showPlatformNotification(notification);
      } else {
        // Show in-app notification only
        Log.warning(
          'No notification permissions, showing in-app only',
          name: 'NotificationService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to show notification: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    }
  }

  /// Show notification for video publishing success
  Future<void> showVideoPublished({
    required String videoTitle,
    required String nostrEventId,
    String? videoUrl,
  }) async {
    final notification = AppNotification.videoPublished(
      videoTitle: videoTitle,
      nostrEventId: nostrEventId,
      videoUrl: videoUrl,
    );

    await show(notification);
  }

  /// Show notification for upload completion
  Future<void> showUploadComplete({required String videoTitle}) async {
    final notification = AppNotification.uploadComplete(videoTitle: videoTitle);
    await show(notification);
  }

  /// Show notification for upload failure
  Future<void> showUploadFailed({
    required String videoTitle,
    required String reason,
  }) async {
    final notification = AppNotification.uploadFailed(
      videoTitle: videoTitle,
      reason: reason,
    );

    await show(notification);
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();

    Log.debug(
      '📱️ Cleared all notifications',
      name: 'NotificationService',
      category: LogCategory.system,
    );
  }

  /// Clear notifications older than specified duration
  void clearOlderThan(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    final initialCount = _notifications.length;

    _notifications.removeWhere(
      (notification) => notification.timestamp.isBefore(cutoff),
    );

    final removedCount = initialCount - _notifications.length;
    if (removedCount > 0) {
      Log.debug(
        '📱️ Cleared $removedCount old notifications',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    }
  }

  /// Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) =>
      _notifications.where((n) => n.type == type).toList();

  /// Ensure notification permissions are granted
  /// Public method to request permissions explicitly
  Future<void> ensurePermission() async {
    // Skip if already granted
    if (_permissionsGranted) {
      Log.debug(
        'Notification permissions already granted',
        name: 'NotificationService',
        category: LogCategory.system,
      );
      return;
    }

    // Web platform doesn't support flutter_local_notifications fully
    if (kIsWeb) {
      Log.debug(
        'Web platform: skipping native notification permissions',
        name: 'NotificationService',
        category: LogCategory.system,
      );
      _permissionsGranted = true; // Allow in-app notifications
      return;
    }

    try {
      // Initialize plugin if not already done
      if (!_pluginInitialized) {
        await _initializePlugin();
      }

      // Check if we're in a test environment (plugin initialization failed)
      // This happens when flutter_local_notifications can't access platform channels
      bool isTestEnvironment = false;
      try {
        // Try to access platform implementation - this will fail in tests
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
      } catch (e) {
        isTestEnvironment = true;
      }

      if (isTestEnvironment) {
        // In test mode, auto-grant permissions for testing
        _permissionsGranted = true;
        Log.debug(
          'Test environment: auto-granting notification permissions',
          name: 'NotificationService',
          category: LogCategory.system,
        );
        return;
      }

      // Request iOS permissions
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final granted =
            await _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;

        _permissionsGranted = granted;
        Log.info(
          'iOS notification permissions ${granted ? "granted" : "denied"}',
          name: 'NotificationService',
          category: LogCategory.system,
        );
      }
      // Request Android permissions (Android 13+)
      else if (defaultTargetPlatform == TargetPlatform.android) {
        final granted =
            await _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            true; // Pre-Android 13 doesn't need runtime permission

        _permissionsGranted = granted;
        Log.info(
          'Android notification permissions ${granted ? "granted" : "denied"}',
          name: 'NotificationService',
          category: LogCategory.system,
        );
      } else {
        // Other platforms (Linux, Windows) don't require runtime permissions
        _permissionsGranted = true;
        Log.info(
          'Platform notification permissions auto-granted',
          name: 'NotificationService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      // In case of any error (including test environment), grant permissions
      // to allow in-app notifications to work
      _permissionsGranted = true;
      Log.error(
        'Failed to request notification permissions: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    }
  }

  /// Initialize the flutter_local_notifications plugin
  Future<void> _initializePlugin() async {
    if (_pluginInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false, // We'll request explicitly
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const macosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: macosSettings,
        linux: linuxSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _pluginInitialized = true;
      Log.debug(
        'Flutter local notifications plugin initialized',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    } catch (e) {
      // In test environment or platforms without native support, gracefully degrade
      Log.error(
        'Failed to initialize notification plugin: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
      // Mark as "initialized" even on failure to prevent repeated attempts
      _pluginInitialized = true;
    }
  }

  /// Handle notification tap
  ///
  /// TODO: Implement navigation based on notification action:
  /// - 'open_feed': Navigate to home feed screen
  /// - 'open_uploads': Navigate to uploads screen
  /// - 'retry_upload': Navigate to failed upload and show retry UI
  /// - 'show_progress': Navigate to upload progress screen
  void _onNotificationTapped(NotificationResponse response) {
    Log.debug(
      'Notification tapped: ${response.payload}',
      name: 'NotificationService',
      category: LogCategory.system,
    );
    // TODO: Handle notification actions (navigate to relevant screen)
    // Example implementation:
    // final data = jsonDecode(response.payload ?? '{}');
    // final action = data['action'];
    // switch (action) {
    //   case 'open_feed': navigatorKey.currentState?.pushNamed('/feed');
    //   case 'retry_upload': navigatorKey.currentState?.pushNamed('/uploads');
    // }
  }

  /// Send a local notification with title and body
  Future<void> sendLocal({required String title, required String body}) async {
    Log.debug(
      '📱 Sending local notification: $title',
      name: 'NotificationService',
      category: LogCategory.system,
    );

    // Create AppNotification for internal tracking
    final notification = AppNotification(
      title: title,
      body: body,
      type: NotificationType.processingStarted, // Default type
    );

    // Add to internal list
    _addNotification(notification);

    // Skip platform notification on web or without permissions
    if (kIsWeb || !_permissionsGranted) {
      Log.debug(
        'Skipping platform notification (web: $kIsWeb, permissions: $_permissionsGranted)',
        name: 'NotificationService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // Initialize plugin if needed
      if (!_pluginInitialized) {
        await _initializePlugin();
      }

      // Define Android notification details
      // Note: To add more notification channels (e.g., for different notification types),
      // create separate AndroidNotificationDetails with different channel IDs:
      // - 'openvine_uploads': Upload-related notifications
      // - 'openvine_social': Likes, comments, follows
      // - 'openvine_system': App updates, announcements
      const androidDetails = AndroidNotificationDetails(
        'openvine_default', // channel ID - stable, do not change
        'OpenVine Notifications', // channel name - user-visible
        channelDescription: 'Notifications for video uploads and publishing',
        importance: Importance.high, // Shows at top of notification shade
        priority: Priority.high, // Affects heads-up notification display
        showWhen: true, // Shows timestamp on notification
      );

      // Define iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Define macOS notification details
      const macosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: macosDetails,
      );

      // Show the notification
      await _flutterLocalNotificationsPlugin.show(
        notification.timestamp.millisecondsSinceEpoch %
            100000, // Unique ID from timestamp
        title,
        body,
        notificationDetails,
      );

      Log.debug(
        'Platform notification sent successfully',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to send platform notification: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    }
  }

  /// Request notification permissions from platform
  Future<void> _requestPermissions() async {
    // Delegate to public ensurePermission method
    await ensurePermission();
  }

  /// Show platform-specific notification
  Future<void> _showPlatformNotification(AppNotification notification) async {
    try {
      // Use sendLocal to display the notification (but it will add to list again)
      // So we need to just show the platform notification without adding to list
      await _sendPlatformNotification(
        title: notification.title,
        body: notification.body,
      );

      // Provide haptic feedback for important notifications
      if (notification.type == NotificationType.videoPublished) {
        HapticFeedback.mediumImpact();
      } else if (notification.type == NotificationType.uploadFailed) {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      Log.error(
        'Failed to show platform notification: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    }
  }

  /// Send platform notification without adding to internal list
  /// Internal method used by _showPlatformNotification
  Future<void> _sendPlatformNotification({
    required String title,
    required String body,
  }) async {
    Log.debug(
      '📱 Sending platform notification: $title',
      name: 'NotificationService',
      category: LogCategory.system,
    );

    // Skip platform notification on web or without permissions
    if (kIsWeb || !_permissionsGranted) {
      Log.debug(
        'Skipping platform notification (web: $kIsWeb, permissions: $_permissionsGranted)',
        name: 'NotificationService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // Initialize plugin if needed
      if (!_pluginInitialized) {
        await _initializePlugin();
      }

      // Define Android notification details
      // Note: To add more notification channels (e.g., for different notification types),
      // create separate AndroidNotificationDetails with different channel IDs:
      // - 'openvine_uploads': Upload-related notifications
      // - 'openvine_social': Likes, comments, follows
      // - 'openvine_system': App updates, announcements
      const androidDetails = AndroidNotificationDetails(
        'openvine_default', // channel ID - stable, do not change
        'OpenVine Notifications', // channel name - user-visible
        channelDescription: 'Notifications for video uploads and publishing',
        importance: Importance.high, // Shows at top of notification shade
        priority: Priority.high, // Affects heads-up notification display
        showWhen: true, // Shows timestamp on notification
      );

      // Define iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Define macOS notification details
      const macosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: macosDetails,
      );

      // Show the notification with unique ID from timestamp
      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
      );

      Log.debug(
        'Platform notification sent successfully',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to send platform notification: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    }
  }

  /// Add notification to internal list
  void _addNotification(AppNotification notification) {
    _notifications.insert(0, notification); // Add to beginning (newest first)

    // Keep only recent notifications to avoid memory issues
    if (_notifications.length > 100) {
      _notifications.removeRange(100, _notifications.length);
    }
  }

  /// Get notification statistics
  Map<String, int> get stats {
    final stats = <String, int>{};

    for (final type in NotificationType.values) {
      stats[type.name] = getNotificationsByType(type).length;
    }

    return stats;
  }

  void dispose() {
    // Check if already disposed to prevent double disposal
    if (_disposed) return;

    _disposed = true;
    _notifications.clear();
  }

  /// Check if this service is still mounted/active
  bool get mounted => !_disposed;
}
