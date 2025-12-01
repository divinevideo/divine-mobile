// ABOUTME: ProofMode configuration service managing settings
// ABOUTME: ProofMode is always enabled - provides configuration for attestation and verification

import 'package:openvine/utils/unified_logger.dart';

/// ProofMode configuration management
/// ProofMode is always enabled by default for all video recordings
class ProofModeConfig {
  /// Check if ProofMode is enabled for development/testing
  /// Always returns true - ProofMode is always enabled
  static Future<bool> get isDevelopmentEnabled async {
    return true;
  }

  /// Check if crypto key generation is enabled
  /// Always returns true - PGP key generation is enabled
  static Future<bool> get isCryptoEnabled async {
    return true;
  }

  /// Check if proof generation during capture is enabled
  /// Always returns true - ProofMode captures proofs during recording
  static Future<bool> get isCaptureEnabled async {
    return true;
  }

  /// Check if proof data publishing to Nostr is enabled
  /// Always returns true - ProofMode data is published to Nostr events
  static Future<bool> get isPublishEnabled async {
    return true;
  }

  /// Check if verification services are enabled
  /// Returns false by default - verification is not yet implemented
  static Future<bool> get isVerifyEnabled async {
    return false;
  }

  /// Check if UI verification badges are enabled
  /// Returns false by default - UI badges are not yet implemented
  static Future<bool> get isUIEnabled async {
    return false;
  }

  /// Check if full production ProofMode is enabled
  /// Always returns true - ProofMode is production-ready
  static Future<bool> get isProductionEnabled async {
    return true;
  }

  /// Check if any ProofMode functionality is enabled
  /// Always returns true - ProofMode is always enabled
  static Future<bool> get isAnyEnabled async {
    return true;
  }

  /// Get current ProofMode capabilities as a map
  static Future<Map<String, bool>> getCapabilities() async {
    final capabilities = {
      'development': await isDevelopmentEnabled,
      'crypto': await isCryptoEnabled,
      'capture': await isCaptureEnabled,
      'publish': await isPublishEnabled,
      'verify': await isVerifyEnabled,
      'ui': await isUIEnabled,
      'production': await isProductionEnabled,
    };

    Log.debug(
      'ProofMode capabilities: $capabilities',
      name: 'ProofModeConfig',
      category: LogCategory.system,
    );

    return capabilities;
  }

  /// Log current ProofMode status
  static Future<void> logStatus() async {
    final capabilities = await getCapabilities();
    final enabledFeatures = capabilities.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    Log.info(
      'ProofMode: Always enabled. Active features: ${enabledFeatures.join(", ")}',
      name: 'ProofModeConfig',
      category: LogCategory.system,
    );
  }

  /// Get GCP Project ID for Android Play Integrity attestation
  ///
  /// Returns the configured GCP Project ID or 0 if not configured.
  /// This is used by ProofModeAttestationService for Android Play Integrity API.
  ///
  /// The GCP Project ID can be configured via:
  /// 1. GCP_PROJECT_ID environment variable (preferred)
  /// 2. Defaults to 0 (not configured)
  static Future<int> get gcpProjectId async {
    try {
      // Try to load from environment variable
      final envValue = const String.fromEnvironment(
        'GCP_PROJECT_ID',
        defaultValue: '0',
      );
      final projectId = int.tryParse(envValue) ?? 0;

      if (projectId > 0) {
        Log.debug(
          'Loaded GCP Project ID from environment: $projectId',
          name: 'ProofModeConfig',
          category: LogCategory.system,
        );
      } else {
        Log.debug(
          'GCP Project ID not configured (using default: 0)',
          name: 'ProofModeConfig',
          category: LogCategory.system,
        );
      }

      return projectId;
    } catch (e) {
      Log.warning(
        'Failed to load GCP Project ID: $e',
        name: 'ProofModeConfig',
        category: LogCategory.system,
      );
      return 0;
    }
  }
}
