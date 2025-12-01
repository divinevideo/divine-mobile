// ABOUTME: Tracks all user-facing alerts, dialogs, snackbars, and error messages
// ABOUTME: Helps identify what issues users are actually seeing in the UI

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for tracking all user-facing alerts and messages
class AlertAnalyticsTracker {
  static final AlertAnalyticsTracker _instance =
      AlertAnalyticsTracker._internal();
  factory AlertAnalyticsTracker() => _instance;
  AlertAnalyticsTracker._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Track alert frequency
  final Map<String, int> _alertCounts = {};

  /// Track a dialog shown to user
  void trackDialog({
    required String dialogType, // 'error', 'warning', 'info', 'confirmation'
    required String title,
    required String message,
    required String location, // Screen/feature where shown
    String? primaryAction, // Button text user clicked
    String? secondaryAction,
    Map<String, dynamic>? context,
  }) {
    final alertKey = '$location:$dialogType:$title';
    _alertCounts[alertKey] = (_alertCounts[alertKey] ?? 0) + 1;

    _analytics.logEvent(
      name: 'user_dialog_shown',
      parameters: {
        'dialog_type': dialogType,
        'title': title.substring(0, title.length > 50 ? 50 : title.length),
        'message': message.substring(
          0,
          message.length > 100 ? 100 : message.length,
        ),
        'location': location,
        'occurrence_count': _alertCounts[alertKey]!,
        if (primaryAction != null) 'primary_action': primaryAction,
        if (secondaryAction != null) 'secondary_action': secondaryAction,
        if (context != null) ...context,
      },
    );

    UnifiedLogger.info(
      '📢 Dialog shown: $dialogType "$title" at $location (count: ${_alertCounts[alertKey]})',
      name: 'AlertAnalytics',
    );
  }

  /// Track a snackbar/toast message shown to user
  void trackSnackbar({
    required String messageType, // 'error', 'success', 'warning', 'info'
    required String message,
    required String location,
    String? actionLabel, // If snackbar has an action button
    Map<String, dynamic>? context,
  }) {
    final alertKey = '$location:snackbar:$messageType';
    _alertCounts[alertKey] = (_alertCounts[alertKey] ?? 0) + 1;

    _analytics.logEvent(
      name: 'user_snackbar_shown',
      parameters: {
        'message_type': messageType,
        'message': message.substring(
          0,
          message.length > 100 ? 100 : message.length,
        ),
        'location': location,
        'occurrence_count': _alertCounts[alertKey]!,
        if (actionLabel != null) 'action_label': actionLabel,
        if (context != null) ...context,
      },
    );

    UnifiedLogger.debug(
      '📌 Snackbar: $messageType - "$message" at $location',
      name: 'AlertAnalytics',
    );
  }

  /// Track a permission request dialog
  void trackPermissionRequest({
    required String
    permissionType, // 'camera', 'microphone', 'storage', 'notifications'
    required String location,
    String? userResponse, // 'granted', 'denied', 'dismissed'
  }) {
    _analytics.logEvent(
      name: 'permission_request',
      parameters: {
        'permission_type': permissionType,
        'location': location,
        if (userResponse != null) 'user_response': userResponse,
      },
    );

    UnifiedLogger.info(
      '🔐 Permission request: $permissionType at $location ${userResponse != null ? "- $userResponse" : ""}',
      name: 'AlertAnalytics',
    );
  }

  /// Track camera-specific error alerts
  void trackCameraAlert({
    required String
    alertType, // 'init_failed', 'permission_denied', 'device_busy', 'unsupported_format'
    required String userMessage,
    required String technicalError,
    String? suggestedAction,
  }) {
    _analytics.logEvent(
      name: 'camera_alert',
      parameters: {
        'alert_type': alertType,
        'user_message': userMessage.substring(
          0,
          userMessage.length > 100 ? 100 : userMessage.length,
        ),
        'technical_error': technicalError.substring(
          0,
          technicalError.length > 150 ? 150 : technicalError.length,
        ),
        if (suggestedAction != null) 'suggested_action': suggestedAction,
      },
    );

    UnifiedLogger.warning(
      '📷 Camera alert: $alertType - "$userMessage"',
      name: 'AlertAnalytics',
    );
  }

  /// Track video playback error alerts
  void trackVideoPlaybackAlert({
    required String videoId,
    required String
    alertType, // 'load_failed', 'playback_error', 'buffering_timeout', 'format_error'
    required String userMessage,
    String? technicalError,
    int? segmentCount,
  }) {
    _analytics.logEvent(
      name: 'video_playback_alert',
      parameters: {
        'video_id': videoId,
        'alert_type': alertType,
        'user_message': userMessage.substring(
          0,
          userMessage.length > 100 ? 100 : userMessage.length,
        ),
        if (technicalError != null)
          'technical_error': technicalError.substring(
            0,
            technicalError.length > 150 ? 150 : technicalError.length,
          ),
        if (segmentCount != null) 'segment_count': segmentCount,
      },
    );

    UnifiedLogger.warning(
      '📹 Video playback alert: $alertType for video ${videoId}',
      name: 'AlertAnalytics',
    );
  }

  /// Track network error alerts
  void trackNetworkAlert({
    required String
    alertType, // 'offline', 'timeout', 'connection_failed', 'slow_connection'
    required String userMessage,
    required String location,
    String? technicalDetails,
  }) {
    _analytics.logEvent(
      name: 'network_alert',
      parameters: {
        'alert_type': alertType,
        'user_message': userMessage.substring(
          0,
          userMessage.length > 100 ? 100 : userMessage.length,
        ),
        'location': location,
        if (technicalDetails != null)
          'technical_details': technicalDetails.substring(
            0,
            technicalDetails.length > 150 ? 150 : technicalDetails.length,
          ),
      },
    );

    UnifiedLogger.warning(
      '🌐 Network alert: $alertType - "$userMessage" at $location',
      name: 'AlertAnalytics',
    );
  }

  /// Track upload error alerts
  void trackUploadAlert({
    required String
    alertType, // 'upload_failed', 'file_too_large', 'server_error', 'network_error'
    required String userMessage,
    required String uploadType, // 'video', 'thumbnail', 'profile_image'
    int? fileSizeBytes,
    String? technicalError,
  }) {
    _analytics.logEvent(
      name: 'upload_alert',
      parameters: {
        'alert_type': alertType,
        'user_message': userMessage.substring(
          0,
          userMessage.length > 100 ? 100 : userMessage.length,
        ),
        'upload_type': uploadType,
        if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
        if (fileSizeBytes != null)
          'file_size_mb': (fileSizeBytes / 1024 / 1024).toStringAsFixed(2),
        if (technicalError != null)
          'technical_error': technicalError.substring(
            0,
            technicalError.length > 150 ? 150 : technicalError.length,
          ),
      },
    );

    UnifiedLogger.warning(
      '📤 Upload alert: $alertType for $uploadType - "$userMessage"',
      name: 'AlertAnalytics',
    );
  }

  /// Track confirmation dialogs and user choice
  void trackConfirmationDialog({
    required String
    confirmationType, // 'delete', 'discard', 'logout', 'report', 'block'
    required String location,
    required String userChoice, // 'confirmed', 'cancelled', 'dismissed'
    Map<String, dynamic>? context,
  }) {
    _analytics.logEvent(
      name: 'confirmation_dialog',
      parameters: {
        'confirmation_type': confirmationType,
        'location': location,
        'user_choice': userChoice,
        if (context != null) ...context,
      },
    );

    UnifiedLogger.info(
      '❓ Confirmation: $confirmationType at $location - user chose: $userChoice',
      name: 'AlertAnalytics',
    );
  }

  /// Track bottom sheet shown
  void trackBottomSheet({
    required String sheetType, // 'options', 'share', 'settings', 'info'
    required String location,
    String? primaryAction,
    Map<String, dynamic>? context,
  }) {
    _analytics.logEvent(
      name: 'bottom_sheet_shown',
      parameters: {
        'sheet_type': sheetType,
        'location': location,
        if (primaryAction != null) 'primary_action': primaryAction,
        if (context != null) ...context,
      },
    );

    UnifiedLogger.debug(
      '📋 Bottom sheet: $sheetType at $location',
      name: 'AlertAnalytics',
    );
  }

  /// Track in-app notifications/banners
  void trackBanner({
    required String
    bannerType, // 'info', 'warning', 'update_available', 'maintenance'
    required String message,
    required String location,
    String? actionTaken, // 'dismissed', 'action_clicked', 'ignored'
  }) {
    _analytics.logEvent(
      name: 'banner_shown',
      parameters: {
        'banner_type': bannerType,
        'message': message.substring(
          0,
          message.length > 100 ? 100 : message.length,
        ),
        'location': location,
        if (actionTaken != null) 'action_taken': actionTaken,
      },
    );

    UnifiedLogger.debug(
      '🎌 Banner: $bannerType - "$message" at $location',
      name: 'AlertAnalytics',
    );
  }

  /// Track validation error messages shown in forms
  void trackValidationError({
    required String fieldName,
    required String errorMessage,
    required String formName,
  }) {
    _analytics.logEvent(
      name: 'validation_error',
      parameters: {
        'field_name': fieldName,
        'error_message': errorMessage.substring(
          0,
          errorMessage.length > 100 ? 100 : errorMessage.length,
        ),
        'form_name': formName,
      },
    );

    UnifiedLogger.debug(
      '✏️ Validation error: $fieldName in $formName - "$errorMessage"',
      name: 'AlertAnalytics',
    );
  }

  /// Get count of how many times a specific alert has been shown
  int getAlertCount(String location, String alertType, String identifier) {
    return _alertCounts['$location:$alertType:$identifier'] ?? 0;
  }

  /// Reset alert counts (useful for testing)
  void resetCounts() {
    _alertCounts.clear();
  }
}
