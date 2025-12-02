// ABOUTME: iOS-specific debug helper for capturing and displaying upload errors
// ABOUTME: Shows detailed error information in a dialog for user reporting

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/theme/vine_theme.dart';

class IOSUploadDebugHelper {
  /// Show detailed error information in a dialog
  static void showDetailedError(
    BuildContext context, {
    required String errorMessage,
    PendingUpload? upload,
    dynamic exception,
  }) {
    // Only show on iOS
    if (!Platform.isIOS) return;

    final details = StringBuffer();

    // Basic error info
    details.writeln('🚨 UPLOAD ERROR DETAILS');
    details.writeln('========================');
    details.writeln();
    details.writeln('Platform: ${Platform.operatingSystem}');
    details.writeln('Version: ${Platform.operatingSystemVersion}');
    details.writeln('Time: ${DateTime.now().toIso8601String()}');
    details.writeln();

    // Error message
    details.writeln('ERROR MESSAGE:');
    details.writeln(errorMessage);
    details.writeln();

    // Upload details if available
    if (upload != null) {
      details.writeln('UPLOAD INFO:');
      details.writeln('ID: ${upload.id}');
      details.writeln('Status: ${upload.status}');
      details.writeln('Title: ${upload.title ?? "Untitled"}');
      details.writeln('File: ${upload.localVideoPath}');

      // Check if file exists
      final file = File(upload.localVideoPath);
      if (file.existsSync()) {
        final sizeInMB = file.lengthSync() / (1024 * 1024);
        details.writeln('File Size: ${sizeInMB.toStringAsFixed(2)} MB');
        details.writeln('File Exists: YES');
      } else {
        details.writeln('File Exists: NO ❌');
      }
      details.writeln();
    }

    // Exception details
    if (exception != null) {
      details.writeln('EXCEPTION TYPE:');
      details.writeln(exception.runtimeType.toString());
      details.writeln();

      if (exception is SocketException) {
        details.writeln('NETWORK ERROR:');
        details.writeln('Message: ${exception.message}');
        if (exception.osError != null) {
          details.writeln('OS Error: ${exception.osError}');
        }
        if (exception.address != null) {
          details.writeln('Address: ${exception.address}');
        }
        if (exception.port != null) {
          details.writeln('Port: ${exception.port}');
        }
      }
    }

    final errorDetails = details.toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'iOS Upload Error',
                style: TextStyle(color: VineTheme.primaryText),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please take a screenshot of this error and report it:',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: SelectableText(
                  errorDetails,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copy error to clipboard
              Clipboard.setData(ClipboardData(text: errorDetails));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error details copied to clipboard'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Copy',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if we should show debug info
  static bool shouldShowDebugInfo() {
    // Always show on iOS in debug/profile builds
    return Platform.isIOS &&
        (const bool.fromEnvironment('dart.vm.product') == false);
  }
}
