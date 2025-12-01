// ABOUTME: Helper utilities for showing alerts with automatic analytics tracking
// ABOUTME: Use these instead of direct showDialog/ScaffoldMessenger calls to track user-facing issues

import 'package:flutter/material.dart';
import 'package:openvine/services/alert_analytics_tracker.dart';

/// Extension on BuildContext to show tracked dialogs and snackbars
extension TrackedAlerts on BuildContext {
  /// Show an error dialog with automatic tracking
  Future<void> showTrackedErrorDialog({
    required String title,
    required String message,
    required String location,
    String? technicalDetails,
    VoidCallback? onDismiss,
  }) async {
    final alertTracker = AlertAnalyticsTracker();

    alertTracker.trackDialog(
      dialogType: 'error',
      title: title,
      message: message,
      location: location,
      context: technicalDetails != null
          ? {'technical_details': technicalDetails}
          : null,
    );

    await showDialog(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show a confirmation dialog with automatic tracking
  Future<bool> showTrackedConfirmationDialog({
    required String title,
    required String message,
    required String confirmationType,
    required String location,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Map<String, dynamic>? context,
  }) async {
    final alertTracker = AlertAnalyticsTracker();

    final result = await showDialog<bool>(
      context: this,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    final userChoice = result == true
        ? 'confirmed'
        : (result == false ? 'cancelled' : 'dismissed');

    alertTracker.trackConfirmationDialog(
      confirmationType: confirmationType,
      location: location,
      userChoice: userChoice,
      context: context,
    );

    return result ?? false;
  }

  /// Show a tracked snackbar
  void showTrackedSnackbar({
    required String message,
    required String messageType, // 'error', 'success', 'warning', 'info'
    required String location,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration duration = const Duration(seconds: 3),
  }) {
    final alertTracker = AlertAnalyticsTracker();

    alertTracker.trackSnackbar(
      messageType: messageType,
      message: message,
      location: location,
      actionLabel: actionLabel,
    );

    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onActionPressed ?? () {},
              )
            : null,
        backgroundColor: _getSnackbarColor(messageType),
      ),
    );
  }

  /// Show a tracked camera error dialog
  Future<void> showTrackedCameraError({
    required String errorType,
    required String userMessage,
    required String technicalError,
    String? suggestedAction,
    VoidCallback? onRetry,
  }) async {
    final alertTracker = AlertAnalyticsTracker();

    alertTracker.trackCameraAlert(
      alertType: errorType,
      userMessage: userMessage,
      technicalError: technicalError,
      suggestedAction: suggestedAction,
    );

    await showDialog(
      context: this,
      builder: (context) => AlertDialog(
        title: const Text('Camera Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userMessage),
            if (suggestedAction != null) ...[
              const SizedBox(height: 12),
              Text(
                suggestedAction,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show a tracked network error snackbar
  void showTrackedNetworkError({
    required String alertType,
    required String message,
    required String location,
    VoidCallback? onRetry,
  }) {
    final alertTracker = AlertAnalyticsTracker();

    alertTracker.trackNetworkAlert(
      alertType: alertType,
      userMessage: message,
      location: location,
    );

    showTrackedSnackbar(
      message: message,
      messageType: 'error',
      location: location,
      actionLabel: onRetry != null ? 'Retry' : null,
      onActionPressed: onRetry,
    );
  }

  Color _getSnackbarColor(String messageType) {
    switch (messageType) {
      case 'error':
        return Colors.red.shade700;
      case 'success':
        return Colors.green.shade700;
      case 'warning':
        return Colors.orange.shade700;
      case 'info':
      default:
        return Colors.blue.shade700;
    }
  }
}

/// Tracked alert helpers that can be used without BuildContext
class TrackedAlertHelpers {
  static final _alertTracker = AlertAnalyticsTracker();

  /// Track a permission request (call this when requesting permissions)
  static void trackPermission({
    required String permissionType,
    required String location,
    bool? granted,
    bool? permanentlyDenied,
  }) {
    _alertTracker.trackPermissionRequest(
      permissionType: permissionType,
      location: location,
      userResponse: granted == true
          ? 'granted'
          : (permanentlyDenied == true ? 'permanently_denied' : 'denied'),
    );
  }

  /// Track a video playback error
  static void trackVideoError({
    required String videoId,
    required String errorType,
    required String userMessage,
    String? technicalError,
    int? segmentCount,
  }) {
    _alertTracker.trackVideoPlaybackAlert(
      videoId: videoId,
      alertType: errorType,
      userMessage: userMessage,
      technicalError: technicalError,
      segmentCount: segmentCount,
    );
  }

  /// Track an upload error
  static void trackUploadError({
    required String errorType,
    required String userMessage,
    required String uploadType,
    int? fileSizeBytes,
    String? technicalError,
  }) {
    _alertTracker.trackUploadAlert(
      alertType: errorType,
      userMessage: userMessage,
      uploadType: uploadType,
      fileSizeBytes: fileSizeBytes,
      technicalError: technicalError,
    );
  }
}
