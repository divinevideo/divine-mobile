// ABOUTME: Configuration for bug report system including support pubkey and limits
// ABOUTME: Defines sensitive data patterns for sanitization and report size constraints

import 'package:openvine/utils/unified_logger.dart';

/// Configuration for bug report system
class BugReportConfig {
  /// API endpoint for submitting bug reports
  /// Worker deployed at: https://bug-reports.protestnet.workers.dev
  /// Will move to reports.divine.video once custom domain is configured
  static const String bugReportApiUrl =
      'https://bug-reports.protestnet.workers.dev/api/bug-reports';

  /// Pubkey for receiving bug reports (hex format)
  /// Currently set to Rabble's personal Nostr key
  static const String supportPubkey =
      '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';

  /// Email address for receiving bug reports (fallback only)
  static const String supportEmail = 'contact@divine.video';

  /// Maximum log entries to include in bug report
  static const int maxLogEntries = 5000;

  /// Maximum bug report size in bytes (~1MB)
  static const int maxReportSizeBytes = 1024 * 1024;

  /// Sensitive data patterns to sanitize
  static final List<RegExp> sensitivePatterns = [
    RegExp(
      r'nsec1[a-z0-9]{58}',
      caseSensitive: false,
    ), // nsec private keys (bech32)
    // Note: We do NOT redact 64-char hex strings because that would redact public event IDs and pubkeys
    // Private keys should always be in nsec format anyway
    RegExp(r'password[:\s=]+\S+', caseSensitive: false),
    RegExp(r'token[:\s=]+\S+', caseSensitive: false),
    RegExp(r'secret[:\s=]+\S+', caseSensitive: false),
    RegExp(r'Authorization:\s*Bearer\s+\S+', caseSensitive: false),
  ];

  /// Log levels to include in bug reports (all by default)
  static const Set<LogLevel> includedLogLevels = {
    LogLevel.verbose,
    LogLevel.debug,
    LogLevel.info,
    LogLevel.warning,
    LogLevel.error,
  };
}
