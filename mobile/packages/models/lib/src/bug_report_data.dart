// ABOUTME: Complete diagnostic data model for bug reports
// ABOUTME: Aggregates logs, device info, errors
// and user description for NIP-17 transmission

import 'package:models/src/log_entry.dart';

/// Complete diagnostic data for a bug report
class BugReportData {
  const BugReportData({
    required this.reportId,
    required this.timestamp,
    required this.userDescription,
    required this.deviceInfo,
    required this.appVersion,
    required this.recentLogs,
    required this.errorCounts,
    this.relayStatus,
    this.currentScreen,
    this.userPubkey,
    this.additionalContext,
  });

  final String reportId; // UUID for tracking
  final DateTime timestamp;
  final String userDescription;
  final Map<String, dynamic> deviceInfo; // From ProofModeAttestationService
  final String appVersion; // From package_info_plus
  final List<LogEntry> recentLogs; // Last 1000 from buffer
  final Map<String, int> errorCounts; // From ErrorAnalyticsTracker
  final Map<String, dynamic>? relayStatus; // From NostrService
  final String? currentScreen; // Active route/screen
  final String? userPubkey; // Anonymous if not logged in
  final Map<String, dynamic>? additionalContext;

  /// Convert to JSON for NIP-17 message
  Map<String, dynamic> toJson() => {
    'reportId': reportId,
    'timestamp': timestamp.toIso8601String(),
    'userDescription': userDescription,
    'deviceInfo': deviceInfo,
    'appVersion': appVersion,
    'recentLogs': recentLogs.map((log) => log.toJson()).toList(),
    'errorCounts': errorCounts,
    if (relayStatus != null) 'relayStatus': relayStatus,
    if (currentScreen != null) 'currentScreen': currentScreen,
    if (userPubkey != null) 'userPubkey': userPubkey,
    if (additionalContext != null) 'additionalContext': additionalContext,
  };

  /// Create formatted report text for NIP-17 message content
  String toFormattedReport() {
    final buffer = StringBuffer()
      ..writeln('🐛 OpenVine Bug Report')
      ..writeln('═' * 50)
      ..writeln('Report ID: $reportId')
      ..writeln('Timestamp: ${timestamp.toIso8601String()}')
      ..writeln('Version: $appVersion')
      ..writeln()
      ..writeln('📝 User Description:')
      ..writeln(userDescription)
      ..writeln()
      ..writeln('📱 Device Info:');
    deviceInfo.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });
    buffer.writeln();

    if (relayStatus != null) {
      buffer.writeln('📡 Relay Status:');
      relayStatus!.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
      buffer.writeln();
    }

    if (errorCounts.isNotEmpty) {
      buffer.writeln('❌ Recent Errors:');
      errorCounts.forEach((error, count) {
        buffer.writeln('  $error: $count occurrences');
      });
      buffer.writeln();
    }

    buffer
      ..writeln('📋 Recent Logs: ${recentLogs.length} entries')
      ..writeln('═' * 50);

    if (recentLogs.isEmpty) {
      buffer.writeln('  (No logs captured)');
    } else {
      for (final log in recentLogs) {
        final timestamp = log.timestamp.toIso8601String();
        final level = log.level.toString().split('.').last.toUpperCase();
        final category = log.category?.toString().split('.').last ?? 'GENERAL';
        final name = log.name ?? '';

        final namePrefix = name.isNotEmpty ? '[$name] ' : '';
        buffer
          ..writeln()
          ..writeln('[$timestamp] [$level] $namePrefix$category')
          ..writeln('  ${log.message}');

        if (log.error != null) {
          buffer.writeln('  Error: ${log.error}');
        }

        if (log.stackTrace != null) {
          buffer.writeln('  Stack Trace:');
          final stackLines = log.stackTrace.toString().split('\n');
          for (final line in stackLines.take(10)) {
            // Limit to first 10 lines
            buffer.writeln('    $line');
          }
          if (stackLines.length > 10) {
            buffer.writeln('    ... (${stackLines.length - 10} more lines)');
          }
        }
      }
    }
    buffer
      ..writeln()
      ..writeln('═' * 50);

    if (currentScreen != null) {
      buffer
        ..writeln()
        ..writeln('📍 Current Screen: $currentScreen');
    }

    if (userPubkey != null) {
      buffer.writeln('👤 User Pubkey: $userPubkey');
    }

    return buffer.toString();
  }

  /// Copy with sanitized data
  BugReportData copyWith({
    String? reportId,
    DateTime? timestamp,
    String? userDescription,
    Map<String, dynamic>? deviceInfo,
    String? appVersion,
    List<LogEntry>? recentLogs,
    Map<String, int>? errorCounts,
    Map<String, dynamic>? relayStatus,
    String? currentScreen,
    String? userPubkey,
    Map<String, dynamic>? additionalContext,
  }) {
    return BugReportData(
      reportId: reportId ?? this.reportId,
      timestamp: timestamp ?? this.timestamp,
      userDescription: userDescription ?? this.userDescription,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      appVersion: appVersion ?? this.appVersion,
      recentLogs: recentLogs ?? this.recentLogs,
      errorCounts: errorCounts ?? this.errorCounts,
      relayStatus: relayStatus ?? this.relayStatus,
      currentScreen: currentScreen ?? this.currentScreen,
      userPubkey: userPubkey ?? this.userPubkey,
      additionalContext: additionalContext ?? this.additionalContext,
    );
  }
}
