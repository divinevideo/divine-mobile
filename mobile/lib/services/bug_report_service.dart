// ABOUTME: Service for collecting comprehensive bug report diagnostics
// ABOUTME: Gathers device info, logs, errors and sanitizes sensitive data before transmission

import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/models/bug_report_data.dart';
import 'package:openvine/models/bug_report_result.dart';
import 'package:openvine/models/log_entry.dart';
import 'package:openvine/services/log_capture_service.dart';
import 'package:openvine/services/error_analytics_tracker.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import 'package:openvine/services/nip17_message_service.dart';
import 'package:openvine/utils/unified_logger.dart';
// Conditional import: dart:html on web, stub on native
import 'dart:html' if (dart.library.io) 'package:openvine/services/bug_report_service_stub.dart' as html;

/// Service for creating and managing bug reports
class BugReportService {
  BugReportService({NIP17MessageService? nip17MessageService})
      : _nip17MessageService = nip17MessageService;

  static const _uuid = Uuid();
  final ProofModeAttestationService _proofModeService =
      ProofModeAttestationService();
  final NIP17MessageService? _nip17MessageService;

  /// Collect comprehensive diagnostics for bug report
  Future<BugReportData> collectDiagnostics({
    required String userDescription,
    String? currentScreen,
    String? userPubkey,
    Map<String, dynamic>? additionalContext,
  }) async {
    Log.info('Collecting bug report diagnostics', category: LogCategory.system);

    try {
      // Generate unique report ID
      final reportId = _uuid.v4();

      // Get app version from package_info_plus
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion =
          '${packageInfo.version}+${packageInfo.buildNumber}';

      // Get device info from ProofModeAttestationService
      final deviceInfo = await _proofModeService.getDeviceInfo();

      // Get recent logs from LogCaptureService
      final recentLogs = LogCaptureService.instance.getRecentLogs(
        limit: BugReportConfig.maxLogEntries,
      );

      // Get error counts from ErrorAnalyticsTracker
      final errorCounts = ErrorAnalyticsTracker().getAllErrorCounts();

      // Create bug report data
      final reportData = BugReportData(
        reportId: reportId,
        timestamp: DateTime.now(),
        userDescription: userDescription,
        deviceInfo: deviceInfo.toJson(),
        appVersion: appVersion,
        recentLogs: recentLogs,
        errorCounts: errorCounts,
        currentScreen: currentScreen,
        userPubkey: userPubkey,
        additionalContext: additionalContext,
      );

      Log.info(
        'Diagnostics collected: ${recentLogs.length} logs, ${errorCounts.length} error types',
        category: LogCategory.system,
      );

      return reportData;
    } catch (e) {
      Log.error('Failed to collect diagnostics: $e',
          category: LogCategory.system);
      rethrow;
    }
  }

  /// Sanitize sensitive data from bug report
  BugReportData sanitizeSensitiveData(BugReportData data) {
    Log.debug('Sanitizing sensitive data from bug report',
        category: LogCategory.system);

    // Sanitize user description
    final sanitizedDescription = _sanitizeString(data.userDescription);

    // Sanitize logs
    final sanitizedLogs = data.recentLogs.map((log) {
      return LogEntry(
        timestamp: log.timestamp,
        level: log.level,
        message: _sanitizeString(log.message),
        category: log.category,
        name: log.name,
        error: log.error != null ? _sanitizeString(log.error!) : null,
        stackTrace: log.stackTrace, // Stack traces are safe
      );
    }).toList();

    // Sanitize additional context if present
    Map<String, dynamic>? sanitizedContext;
    if (data.additionalContext != null) {
      sanitizedContext = _sanitizeMap(data.additionalContext!);
    }

    return data.copyWith(
      userDescription: sanitizedDescription,
      recentLogs: sanitizedLogs,
      additionalContext: sanitizedContext,
    );
  }

  /// Estimate report size in bytes
  int estimateReportSize(BugReportData data) {
    final jsonString = jsonEncode(data.toJson());
    return jsonString.length;
  }

  /// Send bug report via encrypted NIP-17 message to support
  Future<BugReportResult> sendBugReport(BugReportData data) async {
    return sendBugReportToRecipient(data, BugReportConfig.supportPubkey);
  }

  /// Send bug report to a specific recipient (for testing)
  Future<BugReportResult> sendBugReportToRecipient(
    BugReportData data,
    String recipientPubkey,
  ) async {
    if (_nip17MessageService == null) {
      return BugReportResult.failure(
        'NIP17MessageService not available',
        reportId: data.reportId,
      );
    }

    try {
      Log.info('Sending bug report ${data.reportId} to $recipientPubkey',
          category: LogCategory.system);

      // Sanitize sensitive data before sending
      final sanitizedData = sanitizeSensitiveData(data);

      // Check report size
      final sizeBytes = estimateReportSize(sanitizedData);
      if (sizeBytes > BugReportConfig.maxReportSizeBytes) {
        Log.warning(
          'Bug report exceeds size limit: ${sizeBytes} bytes (max: ${BugReportConfig.maxReportSizeBytes})',
          category: LogCategory.system,
        );
        // TODO: Implement log truncation if needed
      }

      // Convert to formatted report
      final reportContent = sanitizedData.toFormattedReport();

      // Ensure backup relay is connected for bug reports
      try {
        await _nip17MessageService.nostrService.addRelay('wss://relay.nos.social');
        Log.info('Added relay.nos.social as backup for bug report',
            category: LogCategory.system);
      } catch (e) {
        Log.warning('Failed to add backup relay, continuing anyway: $e',
            category: LogCategory.system);
      }

      // Send via NIP-17 encrypted message
      final result = await _nip17MessageService.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: reportContent,
        additionalTags: [
          ['client', 'openvine_bug_report'],
          ['report_id', data.reportId],
          ['app_version', data.appVersion],
        ],
      );

      if (result.success && result.messageEventId != null) {
        Log.info('Bug report sent successfully: ${result.messageEventId}',
            category: LogCategory.system);
        return BugReportResult.createSuccess(
          reportId: data.reportId,
          messageEventId: result.messageEventId!,
        );
      } else {
        Log.error('Failed to send bug report: ${result.error}',
            category: LogCategory.system);
        return BugReportResult.failure(
          result.error ?? 'Unknown error',
          reportId: data.reportId,
        );
      }
    } catch (e, stackTrace) {
      Log.error('Exception while sending bug report: $e',
          category: LogCategory.system, error: e, stackTrace: stackTrace);
      return BugReportResult.failure(
        'Failed to send: $e',
        reportId: data.reportId,
      );
    }
  }

  /// Send bug report via email by creating a file attachment
  Future<BugReportResult> sendBugReportViaEmail(BugReportData data) async {
    try {
      Log.info('Creating bug report file for email ${data.reportId}',
          category: LogCategory.system);

      // Sanitize sensitive data before sending
      final sanitizedData = sanitizeSensitiveData(data);

      // Get package info for metadata
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      // Build bug report file content with header
      final buffer = StringBuffer();
      buffer.writeln('OpenVine Bug Report');
      buffer.writeln('═' * 80);
      buffer.writeln('Report ID: ${sanitizedData.reportId}');
      buffer.writeln('Timestamp: ${sanitizedData.timestamp.toIso8601String()}');
      buffer.writeln('App Version: $appVersion');
      if (sanitizedData.currentScreen != null) {
        buffer.writeln('Current Screen: ${sanitizedData.currentScreen}');
      }
      if (sanitizedData.userPubkey != null) {
        buffer.writeln('User Pubkey: ${sanitizedData.userPubkey}');
      }
      buffer.writeln('═' * 80);
      buffer.writeln();
      buffer.writeln('User Description:');
      buffer.writeln(sanitizedData.userDescription);
      buffer.writeln();
      buffer.writeln('═' * 80);
      buffer.writeln('Device Information:');
      buffer.writeln(const JsonEncoder.withIndent('  ').convert(sanitizedData.deviceInfo));
      buffer.writeln();
      buffer.writeln('═' * 80);
      buffer.writeln('Recent Logs (${sanitizedData.recentLogs.length} entries):');
      for (final log in sanitizedData.recentLogs) {
        buffer.writeln('[${log.timestamp.toIso8601String()}] ${log.level.name.toUpperCase()} - ${log.message}');
        if (log.error != null) {
          buffer.writeln('  Error: ${log.error}');
        }
        if (log.stackTrace != null) {
          buffer.writeln('  Stack: ${log.stackTrace}');
        }
      }
      if (sanitizedData.errorCounts.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('═' * 80);
        buffer.writeln('Error Counts:');
        sanitizedData.errorCounts.forEach((key, value) {
          buffer.writeln('  $key: $value');
        });
      }

      final content = buffer.toString();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'openvine_bug_report_${sanitizedData.reportId}_$timestamp.txt';

      // Platform-specific sharing
      if (kIsWeb) {
        // Web: Download the file
        return _sendBugReportWeb(content, fileName, data.reportId);
      } else {
        // Native: Share via system dialog (user can choose email)
        return _sendBugReportNative(content, fileName, data.reportId);
      }
    } catch (e, stackTrace) {
      Log.error('Exception while creating bug report file: $e',
          category: LogCategory.system, error: e, stackTrace: stackTrace);
      return BugReportResult.failure(
        'Failed to create bug report: $e',
        reportId: data.reportId,
      );
    }
  }

  /// Send bug report on web platform by downloading the file
  BugReportResult _sendBugReportWeb(String content, String fileName, String reportId) {
    try {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], 'text/plain');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();

      html.Url.revokeObjectUrl(url);

      final sizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
      Log.info('Bug report downloaded: $fileName ($sizeMB MB)',
          category: LogCategory.system);

      // Open mailto: link to make it easier for user
      _openEmailClient(reportId, fileName);

      return BugReportResult(
        success: true,
        reportId: reportId,
        timestamp: DateTime.now(),
      );
    } catch (e, stackTrace) {
      Log.error('Failed to download bug report on web: $e',
          category: LogCategory.system, error: e, stackTrace: stackTrace);
      return BugReportResult.failure(
        'Failed to download bug report: $e',
        reportId: reportId,
      );
    }
  }

  /// Open email client with pre-filled bug report details
  Future<void> _openEmailClient(String reportId, String fileName) async {
    try {
      final subject = Uri.encodeComponent('OpenVine Bug Report $reportId');
      final body = Uri.encodeComponent(
        'Please attach the downloaded file: $fileName\n\n'
        'Report ID: $reportId\n\n'
        'Describe what happened:\n\n',
      );
      final mailtoUrl = 'mailto:${BugReportConfig.supportEmail}?subject=$subject&body=$body';
      final uri = Uri.parse(mailtoUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        Log.info('Opened email client', category: LogCategory.system);
      }
    } catch (e) {
      Log.warning('Could not open email client: $e', category: LogCategory.system);
    }
  }

  /// Send bug report on native platforms by sharing the file
  Future<BugReportResult> _sendBugReportNative(String content, String fileName, String reportId) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(content);

      final fileSizeMB = (await file.length() / (1024 * 1024)).toStringAsFixed(2);
      Log.info('Bug report file created: $filePath ($fileSizeMB MB)',
          category: LogCategory.system);

      // Share the file with instructions
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'OpenVine Bug Report',
          text: 'Please email this bug report to ${BugReportConfig.supportEmail}\n\nReport ID: $reportId',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        Log.info('Bug report shared successfully', category: LogCategory.system);
        return BugReportResult(
          success: true,
          reportId: reportId,
          timestamp: DateTime.now(),
        );
      } else if (result.status == ShareResultStatus.dismissed) {
        Log.info('Bug report sharing was dismissed', category: LogCategory.system);
        return BugReportResult.failure(
          'Sharing was cancelled',
          reportId: reportId,
        );
      } else {
        Log.warning('Bug report sharing failed: ${result.status}',
            category: LogCategory.system);
        return BugReportResult.failure(
          'Failed to share bug report',
          reportId: reportId,
        );
      }
    } catch (e, stackTrace) {
      Log.error('Failed to share bug report on native platform: $e',
          category: LogCategory.system, error: e, stackTrace: stackTrace);
      return BugReportResult.failure(
        'Failed to share bug report: $e',
        reportId: reportId,
      );
    }
  }

  /// Export logs to a file and share via system share dialog
  /// Returns true if successful, false otherwise
  Future<bool> exportLogsToFile({
    String? currentScreen,
    String? userPubkey,
  }) async {
    try {
      Log.info('Exporting comprehensive logs to file', category: LogCategory.system);

      // Get comprehensive statistics about logs
      final stats = await LogCaptureService.instance.getLogStatistics();
      Log.info('Log stats: ${stats['totalLogLines']} lines, ${stats['totalSizeMB']} MB across ${stats['fileCount']} files',
          category: LogCategory.system);

      // Get ALL logs from persistent storage (hundreds of thousands of entries)
      final allLogLines = await LogCaptureService.instance.getAllLogsAsText();

      if (allLogLines.isEmpty) {
        Log.warning('No logs available for export', category: LogCategory.system);
        return false;
      }

      // Get package info for metadata
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      // Build comprehensive log file with header
      final buffer = StringBuffer();
      buffer.writeln('OpenVine Comprehensive Log Export');
      buffer.writeln('═' * 80);
      buffer.writeln('Export Time: ${DateTime.now().toIso8601String()}');
      buffer.writeln('App Version: $appVersion');
      buffer.writeln('Total Log Lines: ${allLogLines.length}');
      buffer.writeln('Log Files: ${stats['fileCount']}');
      buffer.writeln('Total Size: ${stats['totalSizeMB']} MB');
      if (currentScreen != null) {
        buffer.writeln('Current Screen: $currentScreen');
      }
      if (userPubkey != null) {
        buffer.writeln('User Pubkey: $userPubkey');
      }
      buffer.writeln('═' * 80);
      buffer.writeln();

      // Add all log lines (already formatted by LogCaptureService)
      for (final line in allLogLines) {
        // Sanitize each line for sensitive data
        buffer.writeln(_sanitizeString(line));
      }

      final content = buffer.toString();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'openvine_full_logs_$timestamp.txt';

      // Platform-specific export
      if (kIsWeb) {
        // Web: Use browser download API
        return _exportLogsWeb(content, fileName, allLogLines.length);
      } else {
        // Native: Use file sharing
        return _exportLogsNative(content, fileName, allLogLines.length);
      }
    } catch (e, stackTrace) {
      Log.error('Failed to export logs: $e',
          category: LogCategory.system, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Export logs on web platform using browser download
  bool _exportLogsWeb(String content, String fileName, int lineCount) {
    try {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], 'text/plain');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();

      html.Url.revokeObjectUrl(url);

      final sizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
      Log.info('Logs downloaded via browser: $fileName ($sizeMB MB, $lineCount lines)',
          category: LogCategory.system);
      return true;
    } catch (e, stackTrace) {
      Log.error('Failed to download logs on web: $e',
          category: LogCategory.system, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Export logs on native platforms using file sharing
  Future<bool> _exportLogsNative(String content, String fileName, int lineCount) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(content);

      final fileSizeMB = (await file.length() / (1024 * 1024)).toStringAsFixed(2);
      Log.info('Comprehensive logs written to file: $filePath ($fileSizeMB MB, $lineCount lines)',
          category: LogCategory.system);

      // Share the file
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'OpenVine Full Logs',
          text: 'OpenVine comprehensive diagnostic logs ($lineCount entries, $fileSizeMB MB)',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        Log.info('Logs shared successfully', category: LogCategory.system);
        return true;
      } else {
        Log.warning('Log sharing was dismissed or failed: ${result.status}',
            category: LogCategory.system);
        return false;
      }
    } catch (e, stackTrace) {
      Log.error('Failed to export logs on native platform: $e',
          category: LogCategory.system, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Private helper methods

  /// Sanitize a string by removing sensitive patterns
  String _sanitizeString(String input) {
    String sanitized = input;

    for (final pattern in BugReportConfig.sensitivePatterns) {
      sanitized = sanitized.replaceAll(pattern, '[REDACTED]');
    }

    return sanitized;
  }

  /// Sanitize a map by removing sensitive values
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final Map<String, dynamic> sanitized = {};

    input.forEach((key, value) {
      if (value is String) {
        sanitized[key] = _sanitizeString(value);
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeMap(value);
      } else if (value is List) {
        sanitized[key] = _sanitizeList(value);
      } else {
        sanitized[key] = value;
      }
    });

    return sanitized;
  }

  /// Sanitize a list by removing sensitive values
  List<dynamic> _sanitizeList(List<dynamic> input) {
    return input.map((item) {
      if (item is String) {
        return _sanitizeString(item);
      } else if (item is Map<String, dynamic>) {
        return _sanitizeMap(item);
      } else if (item is List) {
        return _sanitizeList(item);
      } else {
        return item;
      }
    }).toList();
  }
}
