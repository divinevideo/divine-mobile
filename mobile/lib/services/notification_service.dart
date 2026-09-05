// ABOUTME: Service for showing user notifications about upload status and publishing
// ABOUTME: Handles local notifications and in-app messages for video processing updates

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/services/notification_helpers.dart'
    show NotificationPayloadKeys;
import 'package:unified_logger/unified_logger.dart';

/// Types of notifications
enum NotificationType {
  uploadComplete,
  videoPublished,
  uploadFailed,
  processingStarted,
}

enum _NotificationPermissionState { unknown, granted, denied }

/// Normalized notification-tap payload emitted by [NotificationService].
@immutable
class NotificationTapEvent {
  const NotificationTapEvent({
    this.referencedEventId,
    this.referencedAddress,
    this.eventId,
    this.notificationType,
    this.senderPubkey,
    this.tapTargetType,
    this.tapTargetValue,
  });

  /// The event acted upon (present for like/comment/repost). Null for
  /// follow/mention, which the push service sends without an `e` tag.
  final String? referencedEventId;

  /// Authoritative NIP-33 coordinate (`kind:pubkey:d-tag`) of the referenced
  /// video, taken from the source event's signed `a`/`A` tag. Preferred over
  /// [referencedEventId] for routing because it is stable across NIP-33
  /// replacements. Null when the source event carried no `a`/`A` tag.
  final String? referencedAddress;

  /// The source event itself (the like/comment/follow/mention event).
  final String? eventId;
  final String? notificationType;

  /// Hex pubkey of the actor — used to route follows (and unresolved taps)
  /// to a profile.
  final String? senderPubkey;

  /// Campaign destination type, currently `app_route`.
  final String? tapTargetType;

  /// Campaign destination value, such as an absolute in-app route.
  final String? tapTargetValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationTapEvent &&
          referencedEventId == other.referencedEventId &&
          referencedAddress == other.referencedAddress &&
          eventId == other.eventId &&
          notificationType == other.notificationType &&
          senderPubkey == other.senderPubkey &&
          tapTargetType == other.tapTargetType &&
          tapTargetValue == other.tapTargetValue;

  @override
  int get hashCode => Object.hash(
    referencedEventId,
    referencedAddress,
    eventId,
    notificationType,
    senderPubkey,
    tapTargetType,
    tapTargetValue,
  );
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

  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
}

/// Service for managing app notifications
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
///
/// The app owns one instance through `notificationServiceProvider`, which
/// constructs it and disposes it with the container (#8618).
class NotificationService {
  NotificationService();

  final List<AppNotification> _notifications = [];
  _NotificationPermissionState _permissionState =
      _NotificationPermissionState.unknown;
  Future<void>? _permissionRequest;
  bool _disposed = false;

  // Flutter local notifications plugin instance
  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _pluginInitialized = false;
  StreamController<NotificationTapEvent>? _notificationTapController;

  /// List of recent notifications
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  /// Check if notification permissions are granted
  bool get hasPermissions =>
      _permissionState == _NotificationPermissionState.granted;

  /// Stream of local-notification taps emitted after payload parsing.
  Stream<NotificationTapEvent> get notificationTapStream =>
      (_notificationTapController ??=
              StreamController<NotificationTapEvent>.broadcast())
          .stream;

  /// Test seam: swap in a mock [plugin] and configure the plugin/permission
  /// state so notification flows can run without real platform channels.
  @visibleForTesting
  void debugConfigurePlugin(
    FlutterLocalNotificationsPlugin plugin, {
    bool? permissionsGranted = true,
    bool pluginInitialized = true,
  }) {
    _flutterLocalNotificationsPlugin = plugin;
    _pluginInitialized = pluginInitialized;
    _permissionState = switch (permissionsGranted) {
      true => _NotificationPermissionState.granted,
      false => _NotificationPermissionState.denied,
      null => _NotificationPermissionState.unknown,
    };
  }

  /// Initialize notification service
  ///
  /// Resolves the current platform permission state *without prompting*, so
  /// [sendLocal] starts from a real answer instead of the uninitialized
  /// [_NotificationPermissionState.unknown]. Showing the permission dialog
  /// stays with the sign-in-gated push registration flow in
  /// `PushNotificationSessionCoordinator`, which is the only place the app is
  /// allowed to interrupt the user for it.
  ///
  /// `notificationServiceProvider` calls this when it creates the app-owned
  /// service. Callers should read that provider instead of constructing a
  /// second instance.
  Future<void> initialize() async {
    Log.debug(
      '🔧 Initializing NotificationService',
      name: 'NotificationService',
      category: LogCategory.system,
    );

    try {
      await refreshPermissionState();

      Log.info(
        'NotificationService initialized '
        '(permissionState: ${_permissionState.name})',
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
  ///
  /// Prompts the user when the platform has not decided yet. Production code
  /// should prefer [refreshPermissionState] and leave prompting to the
  /// sign-in-gated push registration flow.
  Future<void> ensurePermission() => _runPermissionOperation(_ensurePermission);

  /// Re-read the platform permission state without ever prompting.
  ///
  /// Resolves [_NotificationPermissionState.unknown] at startup, and re-checks
  /// a stale `denied` so notifications enabled from system settings take
  /// effect without an app restart.
  Future<void> refreshPermissionState() =>
      _runPermissionOperation(_refreshPermissionState);

  /// Serializes permission work so concurrent callers share one platform
  /// round-trip instead of racing to overwrite [_permissionState].
  Future<void> _runPermissionOperation(
    Future<void> Function() operation,
  ) async {
    final activeRequest = _permissionRequest;
    if (activeRequest != null) {
      await activeRequest;
      return;
    }

    final request = operation();
    _permissionRequest = request;
    try {
      await request;
    } finally {
      if (identical(_permissionRequest, request)) {
        _permissionRequest = null;
      }
    }
  }

  Future<void> _refreshPermissionState() async {
    // Screenshot capture runs must never touch the permission surface — see
    // [_ensurePermission] for why the iOS dialog deadlocks captures.
    if (ScreenshotMode.enabled) return;

    if (kIsWeb) {
      _permissionState =
          _NotificationPermissionState.granted; // Allow in-app notifications
      return;
    }

    try {
      if (!_pluginInitialized) {
        await _initializePlugin();
      }

      final bool? enabled;
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        enabled =
            (await _flutterLocalNotificationsPlugin
                    .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin
                    >()
                    ?.checkPermissions())
                ?.isEnabled;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        enabled = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled();
      } else {
        // Other platforms (Linux, Windows) don't require runtime permissions
        _permissionState = _NotificationPermissionState.granted;
        return;
      }

      if (enabled == null) {
        // No platform implementation answered (test environment, or a host
        // without native support). Leave the state unresolved rather than
        // guessing a grant we cannot back up.
        Log.debug(
          'Notification permission state unresolved by platform',
          name: 'NotificationService',
          category: LogCategory.system,
        );
        return;
      }

      _permissionState = enabled
          ? _NotificationPermissionState.granted
          : _NotificationPermissionState.denied;
      Log.info(
        'Notification permissions ${enabled ? "enabled" : "disabled"}',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    } catch (e) {
      // Leave the state unresolved so a later attempt can retry, and so the
      // skip log distinguishes "could not read" from a real denial.
      Log.error(
        'Failed to read notification permission state: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _ensurePermission() async {
    // Screenshot capture runs must never surface the iOS permission
    // dialog — XCUITest interruption monitors don't fire on bare
    // waitForExistence, so the alert would deadlock every capture.
    if (ScreenshotMode.enabled) {
      Log.debug(
        'Screenshot mode: skipping notification permission prompt',
        name: 'NotificationService',
        category: LogCategory.system,
      );
      return;
    }

    // Skip if already granted
    if (_permissionState == _NotificationPermissionState.granted) {
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
      _permissionState =
          _NotificationPermissionState.granted; // Allow in-app notifications
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
        _permissionState = _NotificationPermissionState.granted;
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

        _permissionState = granted
            ? _NotificationPermissionState.granted
            : _NotificationPermissionState.denied;
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

        _permissionState = granted
            ? _NotificationPermissionState.granted
            : _NotificationPermissionState.denied;
        Log.info(
          'Android notification permissions ${granted ? "granted" : "denied"}',
          name: 'NotificationService',
          category: LogCategory.system,
        );
      } else {
        // Other platforms (Linux, Windows) don't require runtime permissions
        _permissionState = _NotificationPermissionState.granted;
        Log.info(
          'Platform notification permissions auto-granted',
          name: 'NotificationService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      // In case of any error (including test environment), grant permissions
      // to allow in-app notifications to work
      _permissionState = _NotificationPermissionState.granted;
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
        settings: initializationSettings,
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
  void _onNotificationTapped(NotificationResponse response) {
    _handleNotificationTapPayload(response.payload);
  }

  /// Parses [payload] and emits a [NotificationTapEvent] when a valid
  /// [referencedEventId] can be extracted.
  ///
  /// Exposed for testing; production callers should use
  /// [_onNotificationTapped] or listen to [notificationTapStream].
  @visibleForTesting
  void handleNotificationTapPayload(String? payload) =>
      _handleNotificationTapPayload(payload);

  void _handleNotificationTapPayload(String? payload) {
    Log.debug(
      'Notification tapped: $payload',
      name: 'NotificationService',
      category: LogCategory.system,
    );

    final event = _parseTapPayload(payload);
    if (event != null) _emitNotificationTap(event);
  }

  /// Parses a local-notification tap [payload] into a [NotificationTapEvent],
  /// or null when nothing routable is present. Shared by the live-tap path
  /// ([_handleNotificationTapPayload]) and the cold-start path
  /// ([takeLaunchNotificationTap]) so the two cannot diverge.
  NotificationTapEvent? _parseTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      String? field(String key) {
        final value = data[key];
        return value is String && value.isNotEmpty ? value : null;
      }

      final referencedEventId = field(
        NotificationPayloadKeys.referencedEventId,
      );
      final referencedAddress = field(
        NotificationPayloadKeys.referencedAddress,
      );
      final eventId = field(NotificationPayloadKeys.eventId);
      final senderPubkey = field(NotificationPayloadKeys.senderPubkey);
      final notificationType = field(NotificationPayloadKeys.notificationType);
      // A follow/mention carries no referencedEventId but is still routable
      // via senderPubkey / eventId, and a referencedAddress alone is a valid
      // video target, so route whenever any of these exist.
      if (referencedEventId == null &&
          referencedAddress == null &&
          eventId == null &&
          senderPubkey == null &&
          notificationType != 'campaign') {
        return null;
      }
      return NotificationTapEvent(
        referencedEventId: referencedEventId,
        referencedAddress: referencedAddress,
        eventId: eventId,
        notificationType: notificationType,
        senderPubkey: senderPubkey,
        tapTargetType: field(NotificationPayloadKeys.tapTargetType),
        tapTargetValue: field(NotificationPayloadKeys.tapTargetValue),
      );
    } catch (e) {
      // Malformed payload (non-JSON, non-object, or unexpected shape).
      // Log a warning and discard — do not propagate to the Flutter error path.
      Log.warning(
        'Notification tap payload could not be parsed, ignoring: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Returns the tap event for a locally-displayed notification that launched
  /// the app from a *terminated* state, or null when the app was not launched
  /// by such a tap. One-shot — consult once during startup.
  ///
  /// Complements FCM's `getInitialMessage`, which only covers OS-rendered
  /// pushes (iOS, where the push service's APNS alert is shown by the OS). On
  /// Android the push is data-only and rendered by this plugin, so a
  /// terminated-app tap is delivered only through
  /// `getNotificationAppLaunchDetails` — never via [notificationTapStream],
  /// whose callback requires a live isolate.
  Future<NotificationTapEvent?> takeLaunchNotificationTap() async {
    if (kIsWeb) return null;
    try {
      if (!_pluginInitialized) {
        await _initializePlugin();
      }
      final details = await _flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return _parseTapPayload(details.notificationResponse?.payload);
    } catch (e) {
      Log.error(
        'Failed to read launch notification details: $e',
        name: 'NotificationService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  void _emitNotificationTap(NotificationTapEvent event) {
    final controller = _notificationTapController;
    if (_disposed || controller == null || controller.isClosed) return;
    controller.add(event);
  }

  /// Send a local notification with [title], [body], and an optional tap
  /// [payload].
  ///
  /// [payload] is the normalized JSON string consumed by
  /// [_handleNotificationTapPayload] on tap; pass it (built via
  /// `localNotificationTapPayload`) so foreground-displayed notifications route
  /// the same way as background/system-push ones.
  Future<void> sendLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
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

    // Resolves the uninitialized state, and re-checks a stale `denied` so a
    // permission granted from system settings takes effect without an app
    // restart. Never prompts — see [refreshPermissionState].
    if (!hasPermissions) {
      await refreshPermissionState();
    }

    // Skip platform notification on web or without permissions
    if (kIsWeb || !hasPermissions) {
      Log.debug(
        'Skipping platform notification (web: $kIsWeb, permissionState: ${_permissionState.name})',
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
      );

      // Define iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );

      // Define macOS notification details
      const macosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );

      // Define Linux notification details
      const linuxDetails = LinuxNotificationDetails();

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: macosDetails,
        linux: linuxDetails,
      );

      // Show the notification with unique ID from timestamp
      final notificationId =
          notification.timestamp.millisecondsSinceEpoch % 100000;
      await _flutterLocalNotificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
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
    _notificationTapController?.close();
    _notifications.clear();
  }

  /// Check if this service is still mounted/active
  bool get mounted => !_disposed;
}
