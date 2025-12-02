// ABOUTME: Service for collecting comprehensive bug report diagnostics
// ABOUTME: Gathers device info, logs, errors and sanitizes sensitive data before transmission

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
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
import 'package:device_info_plus/device_info_plus.dart';
import 'package:openvine/services/nip17_message_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/unified_logger.dart';
// Conditional import: dart:html on web, stub on native
import 'dart:html'
    if (dart.library.io) 'package:openvine/services/bug_report_service_stub.dart'
    as html;

/// Service for creating and managing bug reports
class BugReportService {
  BugReportService({
    NIP17MessageService? nip17MessageService,
    BlossomUploadService? blossomUploadService,
  }) : _nip17MessageService = nip17MessageService,
       _blossomUploadService = blossomUploadService;

  static const _uuid = Uuid();
  final NIP17MessageService? _nip17MessageService;
  final BlossomUploadService? _blossomUploadService;

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
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      // Get device info using device_info_plus
      final deviceInfoPlugin = DeviceInfoPlugin();
      Map<String, dynamic> deviceInfo = {};
      try {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          deviceInfo = {
            'model': androidInfo.model,
            'manufacturer': androidInfo.manufacturer,
            'version': androidInfo.version.release,
            'sdkInt': androidInfo.version.sdkInt,
            'brand': androidInfo.brand,
          };
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          deviceInfo = {
            'model': iosInfo.model,
            'systemName': iosInfo.systemName,
            'systemVersion': iosInfo.systemVersion,
            'name': iosInfo.name,
          };
        }
      } catch (e) {
        Log.warning(
          'Failed to get device info: $e',
          category: LogCategory.system,
        );
        deviceInfo = {'error': 'Failed to get device info'};
      }

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
        deviceInfo: deviceInfo,
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
      Log.error(
        'Failed to collect diagnostics: $e',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Sanitize sensitive data from bug report
  BugReportData sanitizeSensitiveData(BugReportData data) {
    Log.debug(
      'Sanitizing sensitive data from bug report',
      category: LogCategory.system,
    );

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

  /// Send bug report to Cloudflare Worker backend
  /// This is the primary method for submitting bug reports
  ///
  /// Fallback order:
  /// 1. Cloudflare Worker API
  /// 2. Zendesk REST API (works on all platforms including macOS)
  /// 3. Log error (no blocking dialogs)
  Future<BugReportResult> sendBugReport(BugReportData data) async {
    try {
      Log.info(
        'Sending bug report ${data.reportId} to Worker API',
        category: LogCategory.system,
      );

      // Sanitize sensitive data before sending
      final sanitizedData = sanitizeSensitiveData(data);

      // POST to Cloudflare Worker
      final response = await http.post(
        Uri.parse(BugReportConfig.bugReportApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(sanitizedData.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        Log.info(
          '✅ Bug report sent successfully: ${data.reportId}',
          category: LogCategory.system,
        );
        return BugReportResult.createSuccess(
          reportId: data.reportId,
          messageEventId: result['reportId'] as String,
        );
      } else {
        Log.error(
          'Bug report API error: ${response.statusCode} ${response.body}',
          category: LogCategory.system,
        );

        // Fall back to Zendesk REST API
        return _fallbackToZendeskApi(sanitizedData);
      }
    } catch (e, stackTrace) {
      Log.error(
        'Exception while sending bug report to Worker: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );

      // Sanitize and fall back to Zendesk REST API
      final sanitizedData = sanitizeSensitiveData(data);
      return _fallbackToZendeskApi(sanitizedData);
    }
  }

  /// Fallback to Zendesk REST API when Worker API fails
  Future<BugReportResult> _fallbackToZendeskApi(BugReportData data) async {
    Log.info('Falling back to Zendesk REST API', category: LogCategory.system);

    // Create a logs summary (last 50 log messages)
    String? logsSummary;
    if (data.recentLogs.isNotEmpty) {
      final recentLines = data.recentLogs.take(50).map((log) =>
          '[${log.timestamp.toIso8601String()}] ${log.level.name}: ${log.message}');
      logsSummary = recentLines.join('\n');
    }

    final success = await ZendeskSupportService.createBugReportTicketViaApi(
      reportId: data.reportId,
      userDescription: data.userDescription,
      appVersion: data.appVersion,
      deviceInfo: data.deviceInfo,
      currentScreen: data.currentScreen,
      userPubkey: data.userPubkey,
      errorCounts: data.errorCounts,
      logsSummary: logsSummary,
    );

    if (success) {
      Log.info('✅ Bug report sent via Zendesk REST API: ${data.reportId}',
          category: LogCategory.system);
      return BugReportResult.createSuccess(
        reportId: data.reportId,
        messageEventId: 'zendesk-${data.reportId}',
      );
    } else {
      // Don't fall back to file share - just log the error
      Log.error(
          'Failed to send bug report via all methods: ${data.reportId}',
          category: LogCategory.system);
      return BugReportResult.failure(
        'Failed to submit bug report. Please try again later.',
        reportId: data.reportId,
      );
    }
  }

  /// Send bug report to a specific recipient (for testing)
  ///
  /// This method uploads the full bug report file to Blossom server,
  /// then sends a lightweight NIP-17 message with the URL
  Future<BugReportResult> sendBugReportToRecipient(
    BugReportData data,
    String recipientPubkey,
  ) async {
    if (_nip17MessageService == null) {
      Log.error(
        'NIP17MessageService not available, falling back to email',
        category: LogCategory.system,
      );
      return sendBugReportViaEmail(data);
    }

    try {
      Log.info(
        'Sending bug report ${data.reportId} to $recipientPubkey',
        category: LogCategory.system,
      );

      // Sanitize sensitive data before uploading
      final sanitizedData = sanitizeSensitiveData(data);

      // Create bug report file
      final bugReportFile = await _createBugReportFile(sanitizedData);

      String? bugReportUrl;

      // Try Blossom upload first (if available)
      if (_blossomUploadService != null) {
        Log.info(
          'Uploading bug report to Blossom server',
          category: LogCategory.system,
        );

        bugReportUrl = await _blossomUploadService.uploadBugReport(
          bugReportFile: bugReportFile,
        );

        Log.info(
          '✅ Bug report uploaded to Blossom: $bugReportUrl',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'BlossomUploadService not available, will send summary only',
          category: LogCategory.system,
        );
      }

      // Prepare NIP-17 message content
      final messageContent = _formatBugReportMessage(
        sanitizedData,
        bugReportUrl,
      );

      // Ensure backup relay is connected for bug reports
      try {
        await _nip17MessageService.nostrService.addRelay(
          'wss://relay.nos.social',
        );
        Log.info(
          'Added relay.nos.social as backup for bug report',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.warning(
          'Failed to add backup relay, continuing anyway: $e',
          category: LogCategory.system,
        );
      }

      // Send via NIP-17 encrypted message
      final result = await _nip17MessageService.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: messageContent,
        additionalTags: [
          ['client', 'diVine_bug_report'],
          ['report_id', data.reportId],
          ['app_version', data.appVersion],
          if (bugReportUrl != null) ['bug_report_url', bugReportUrl],
        ],
      );

      if (result.success && result.messageEventId != null) {
        Log.info(
          'Bug report sent successfully: ${result.messageEventId}',
          category: LogCategory.system,
        );
        return BugReportResult.createSuccess(
          reportId: data.reportId,
          messageEventId: result.messageEventId!,
        );
      } else {
        Log.error(
          'Failed to send bug report DM: ${result.error}',
          category: LogCategory.system,
        );

        // If DM failed but we have a Blossom URL, that's still useful
        if (bugReportUrl != null) {
          return BugReportResult(
            success: true,
            reportId: data.reportId,
            messageEventId: null,
            timestamp: DateTime.now(),
            error:
                'Uploaded to Blossom but DM failed: ${result.error}. URL: $bugReportUrl',
          );
        }

        // Fall back to email if both Blossom and DM failed
        Log.info(
          'Falling back to email attachment method',
          category: LogCategory.system,
        );
        return sendBugReportViaEmail(data);
      }
    } catch (e, stackTrace) {
      Log.error(
        'Exception while sending bug report: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );

      // Fall back to email on any exception
      Log.info(
        'Falling back to email attachment method',
        category: LogCategory.system,
      );
      return sendBugReportViaEmail(data);
    }
  }

  /// Format bug report message for NIP-17 (with or without Blossom URL)
  String _formatBugReportMessage(BugReportData data, String? bugReportUrl) {
    final buffer = StringBuffer();

    buffer.writeln('🐛 OpenVine Bug Report');
    buffer.writeln('═' * 50);
    buffer.writeln('Report ID: ${data.reportId}');
    buffer.writeln('Timestamp: ${data.timestamp.toIso8601String()}');
    buffer.writeln('App Version: ${data.appVersion}');
    buffer.writeln();

    buffer.writeln('📝 User Description:');
    buffer.writeln(data.userDescription);
    buffer.writeln();

    if (bugReportUrl != null) {
      buffer.writeln('📄 Full Diagnostic Logs:');
      buffer.writeln(bugReportUrl);
      buffer.writeln();
    }

    buffer.writeln('📱 Device Info:');
    buffer.writeln('  Platform: ${data.deviceInfo['platform']}');
    buffer.writeln('  Version: ${data.deviceInfo['version']}');
    if (data.deviceInfo['model'] != null) {
      buffer.writeln('  Model: ${data.deviceInfo['model']}');
    }
    buffer.writeln();

    if (data.currentScreen != null) {
      buffer.writeln('📍 Current Screen: ${data.currentScreen}');
      buffer.writeln();
    }

    if (data.errorCounts.isNotEmpty) {
      buffer.writeln('❌ Recent Error Summary:');
      final sortedErrors = data.errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedErrors.take(5)) {
        buffer.writeln('  ${entry.key}: ${entry.value} occurrences');
      }
      buffer.writeln();
    }

    if (bugReportUrl == null) {
      buffer.writeln('⚠️ Note: Full logs not uploaded (Blossom unavailable)');
      buffer.writeln('Recent log entries: ${data.recentLogs.length}');
    }

    return buffer.toString();
  }

  /// Create a bug report file from sanitized data
  Future<File> _createBugReportFile(BugReportData data) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'openvine_bug_report_${data.reportId}_$timestamp.txt';
    final filePath = '${tempDir.path}/$fileName';

    // Build comprehensive bug report file content
    final buffer = StringBuffer();
    buffer.writeln('OpenVine Bug Report');
    buffer.writeln('═' * 80);
    buffer.writeln('Report ID: ${data.reportId}');
    buffer.writeln('Timestamp: ${data.timestamp.toIso8601String()}');
    buffer.writeln('App Version: ${data.appVersion}');
    if (data.currentScreen != null) {
      buffer.writeln('Current Screen: ${data.currentScreen}');
    }
    if (data.userPubkey != null) {
      buffer.writeln('User Pubkey: ${data.userPubkey}');
    }
    buffer.writeln('═' * 80);
    buffer.writeln();
    buffer.writeln('User Description:');
    buffer.writeln(data.userDescription);
    buffer.writeln();
    buffer.writeln('═' * 80);
    buffer.writeln('Device Information:');
    buffer.writeln(const JsonEncoder.withIndent('  ').convert(data.deviceInfo));
    buffer.writeln();
    buffer.writeln('═' * 80);
    buffer.writeln('Recent Logs (${data.recentLogs.length} entries):');
    for (final log in data.recentLogs) {
      buffer.writeln(
        '[${log.timestamp.toIso8601String()}] ${log.level.name.toUpperCase()} - ${log.message}',
      );
      if (log.error != null) {
        buffer.writeln('  Error: ${log.error}');
      }
      if (log.stackTrace != null) {
        buffer.writeln('  Stack: ${log.stackTrace}');
      }
    }
    if (data.errorCounts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('═' * 80);
      buffer.writeln('Error Counts:');
      data.errorCounts.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }

    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    final fileSizeMB = (await file.length() / (1024 * 1024)).toStringAsFixed(2);
    Log.info(
      'Bug report file created: $filePath ($fileSizeMB MB)',
      category: LogCategory.system,
    );

    return file;
  }

  /// Send bug report via email by creating a file attachment
  Future<BugReportResult> sendBugReportViaEmail(BugReportData data) async {
    try {
      Log.info(
        'Creating bug report file for email ${data.reportId}',
        category: LogCategory.system,
      );

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
      buffer.writeln(
        const JsonEncoder.withIndent('  ').convert(sanitizedData.deviceInfo),
      );
      buffer.writeln();
      buffer.writeln('═' * 80);
      buffer.writeln(
        'Recent Logs (${sanitizedData.recentLogs.length} entries):',
      );
      for (final log in sanitizedData.recentLogs) {
        buffer.writeln(
          '[${log.timestamp.toIso8601String()}] ${log.level.name.toUpperCase()} - ${log.message}',
        );
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
      final fileName =
          'openvine_bug_report_${sanitizedData.reportId}_$timestamp.txt';

      // Platform-specific sharing
      if (kIsWeb) {
        // Web: Download the file
        return _sendBugReportWeb(content, fileName, data.reportId);
      } else {
        // Native: Share via system dialog (user can choose email)
        return _sendBugReportNative(content, fileName, data.reportId);
      }
    } catch (e, stackTrace) {
      Log.error(
        'Exception while creating bug report file: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return BugReportResult.failure(
        'Failed to create bug report: $e',
        reportId: data.reportId,
      );
    }
  }

  /// Send bug report on web platform by downloading the file
  BugReportResult _sendBugReportWeb(
    String content,
    String fileName,
    String reportId,
  ) {
    try {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], 'text/plain');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();

      html.Url.revokeObjectUrl(url);

      final sizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
      Log.info(
        'Bug report downloaded: $fileName ($sizeMB MB)',
        category: LogCategory.system,
      );

      // Open mailto: link to make it easier for user
      _openEmailClient(reportId, fileName);

      return BugReportResult(
        success: true,
        reportId: reportId,
        timestamp: DateTime.now(),
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to download bug report on web: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
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
      final mailtoUrl =
          'mailto:${BugReportConfig.supportEmail}?subject=$subject&body=$body';
      final uri = Uri.parse(mailtoUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        Log.info('Opened email client', category: LogCategory.system);
      }
    } catch (e) {
      Log.warning(
        'Could not open email client: $e',
        category: LogCategory.system,
      );
    }
  }

  /// Send bug report on native platforms by sharing the file
  Future<BugReportResult> _sendBugReportNative(
    String content,
    String fileName,
    String reportId,
  ) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(content);

      final fileSizeMB = (await file.length() / (1024 * 1024)).toStringAsFixed(
        2,
      );
      Log.info(
        'Bug report file created: $filePath ($fileSizeMB MB)',
        category: LogCategory.system,
      );

      // Share the file with instructions
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'OpenVine Bug Report',
          text:
              'Please email this bug report to ${BugReportConfig.supportEmail}\n\nReport ID: $reportId',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        Log.info(
          'Bug report shared successfully',
          category: LogCategory.system,
        );
        return BugReportResult(
          success: true,
          reportId: reportId,
          timestamp: DateTime.now(),
        );
      } else if (result.status == ShareResultStatus.dismissed) {
        Log.info(
          'Bug report sharing was dismissed',
          category: LogCategory.system,
        );
        return BugReportResult.failure(
          'Sharing was cancelled',
          reportId: reportId,
        );
      } else {
        Log.warning(
          'Bug report sharing failed: ${result.status}',
          category: LogCategory.system,
        );
        return BugReportResult.failure(
          'Failed to share bug report',
          reportId: reportId,
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to share bug report on native platform: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
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
      Log.info(
        'Exporting comprehensive logs to file',
        category: LogCategory.system,
      );

      // Get comprehensive statistics about logs
      final stats = await LogCaptureService.instance.getLogStatistics();
      Log.info(
        'Log stats: ${stats['totalLogLines']} lines, ${stats['totalSizeMB']} MB across ${stats['fileCount']} files',
        category: LogCategory.system,
      );

      // Get ALL logs from persistent storage (hundreds of thousands of entries)
      final allLogLines = await LogCaptureService.instance.getAllLogsAsText();

      if (allLogLines.isEmpty) {
        Log.warning(
          'No logs available for export',
          category: LogCategory.system,
        );
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
      Log.error(
        'Failed to export logs: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
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
      Log.info(
        'Logs downloaded via browser: $fileName ($sizeMB MB, $lineCount lines)',
        category: LogCategory.system,
      );
      return true;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to download logs on web: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Export logs on native platforms using file sharing
  Future<bool> _exportLogsNative(
    String content,
    String fileName,
    int lineCount,
  ) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(content);

      final fileSizeMB = (await file.length() / (1024 * 1024)).toStringAsFixed(
        2,
      );
      Log.info(
        'Comprehensive logs written to file: $filePath ($fileSizeMB MB, $lineCount lines)',
        category: LogCategory.system,
      );

      // Share the file
      // Note: text field is intentionally minimal to ensure the file is the primary content
      // When users select "Copy" in the share dialog, they should get the file, not metadata
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'OpenVine Full Logs',
          text: 'OpenVine Full Logs',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        Log.info('Logs shared successfully', category: LogCategory.system);
        return true;
      } else {
        Log.warning(
          'Log sharing was dismissed or failed: ${result.status}',
          category: LogCategory.system,
        );
        return false;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to export logs on native platform: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
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
