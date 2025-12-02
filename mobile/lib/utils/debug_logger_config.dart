// ABOUTME: Quick debug configuration helpers for switching between logging modes
// ABOUTME: Import this to quickly enable specific logging categories during debugging

import 'package:openvine/utils/unified_logger.dart';

/// Quick debugging configurations for common scenarios
class DebugLoggerConfig {
  /// Call this at app startup to reduce log noise to minimum
  static void setupProductionLogging() {
    LogConfig.minimal();
  }

  /// Call this when debugging video playback issues
  static void setupVideoDebugging() {
    LogConfig.videoDebug();
    Log.info(
      '🎥 Video debugging enabled - logs filtered to VIDEO + SYSTEM only',
    );
  }

  /// Call this when debugging Nostr relay connection issues
  static void setupRelayDebugging() {
    LogConfig.relayDebug();
    Log.info(
      '📡 Relay debugging enabled - logs filtered to RELAY + SYSTEM only',
    );
  }

  /// Call this when debugging UI interactions
  static void setupUIDebugging() {
    LogConfig.uiDebug();
    Log.info('🖱️ UI debugging enabled - logs filtered to UI + SYSTEM only');
  }

  /// Call this when debugging authentication or key issues
  static void setupAuthDebugging() {
    Log.setLogLevel(LogLevel.debug);
    Log.enableCategories({
      LogCategory.auth,
      LogCategory.system,
      LogCategory.storage,
    });
    Log.info(
      '🔐 Auth debugging enabled - logs filtered to AUTH + SYSTEM + STORAGE',
    );
  }

  /// Call this for full verbose logging (warning: may be overwhelming)
  static void setupFullDebugging() {
    LogConfig.verbose();
    Log.warning(
      '⚠️ Full debugging enabled - this will generate A LOT of logs!',
    );
  }
}
