// ABOUTME: Service for managing logging configuration and runtime log level control
// ABOUTME: Allows dynamic adjustment of log verbosity for debugging production issues

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing logging configuration
class LoggingConfigService {
  LoggingConfigService._();
  static const String _logLevelKey = 'log_level_preference';
  static LoggingConfigService? _instance;

  static LoggingConfigService get instance {
    _instance ??= LoggingConfigService._();
    return _instance!;
  }

  /// Initialize logging configuration from stored preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedLevel = prefs.getString(_logLevelKey);

      if (storedLevel != null) {
        final level = LogLevel.fromString(storedLevel);
        UnifiedLogger.setLogLevel(level);
        Log.info(
          'Logging initialized with stored level: ${level.name}',
          name: 'LogConfig',
        );
      } else {
        // Log initial level
        Log.info(
          'Logging initialized with default level: ${UnifiedLogger.currentLevel.name}',
          name: 'LogConfig',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        Log.error(
          'Failed to load logging preferences: $e',
          name: 'LoggingConfigService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Set and persist log level
  Future<void> setLogLevel(LogLevel level) async {
    UnifiedLogger.setLogLevel(level);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_logLevelKey, level.name);
      Log.info('Log level changed to: ${level.name}', name: 'LogConfig');
    } catch (e) {
      Log.error('Failed to persist log level: $e', name: 'LogConfig');
    }
  }

  /// Get current log level
  LogLevel get currentLevel => UnifiedLogger.currentLevel;

  /// Check if verbose logging is enabled
  bool get isVerboseEnabled => UnifiedLogger.isLevelEnabled(LogLevel.verbose);

  /// Check if debug logging is enabled
  bool get isDebugEnabled => UnifiedLogger.isLevelEnabled(LogLevel.debug);

  /// Enable verbose logging temporarily (useful for debugging)
  void enableVerboseLogging() {
    UnifiedLogger.setLogLevel(LogLevel.verbose);
    Log.warning(
      'Verbose logging enabled - remember to disable for production!',
      name: 'LogConfig',
    );
  }

  /// Reset to default log level
  Future<void> resetToDefault() async {
    const defaultLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
    await setLogLevel(defaultLevel);
  }
}
