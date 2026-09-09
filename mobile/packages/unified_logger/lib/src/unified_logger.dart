// ABOUTME: Unified logging utility that outputs to both
// ABOUTME: Flutter console and browser DevTools.
// ABOUTME: Provides structured logging with levels while
// ABOUTME: maintaining single command simplicity.

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:logging_types/logging_types.dart'
    show LogCategory, LogEntry, LogLevel;
import 'package:unified_logger/src/log_capture_service.dart';

// Re-export logging values so existing unified_logger consumers keep their
// public imports while the types remain owned by the pure-Dart leaf package.
export 'package:logging_types/logging_types.dart'
    show LogCategory, LogEntry, LogLevel;

/// Unified logger that outputs to both Flutter tool console
/// and browser DevTools.
///
/// This logger combines the best of both worlds:
/// - debugPrint: Shows in Flutter tool console (terminal)
/// - developer.log: Shows in browser DevTools with structured logging
///
/// Features both traditional log levels AND category-based filtering:
///
/// Configure log level via:
/// - Code: UnifiedLogger.setLogLevel(LogLevel.info)
/// - Environment: LOG_LEVEL=info (or verbose, debug, warning, error)
/// - Default: debug in debug mode, info in release mode
///
/// Configure log categories via:
/// - Code: `UnifiedLogger.enableCategories({...})`
/// - Environment: LOG_CATEGORIES=RELAY,VIDEO,AUTH
/// - Default: all categories in debug mode, only SYSTEM+AUTH in release mode
///
/// Usage examples:
/// - Log.info('Connection established', category: LogCategory.relay)
/// - Log.error('Video failed to load', category: LogCategory.video, error: e)
/// - Log.debug('User tapped button', category: LogCategory.ui)
class UnifiedLogger {
  /// Current log level - only messages at or above this level will be logged
  static LogLevel _currentLevel = _getDefaultLogLevel();

  /// Enabled categories - only messages in these categories will be logged
  static Set<LogCategory> _enabledCategories = _getDefaultCategories();

  /// Get default log level from environment or mode
  static LogLevel _getDefaultLogLevel() {
    // Check environment variable first
    const envLevel = String.fromEnvironment('LOG_LEVEL');
    if (envLevel.isNotEmpty) {
      return LogLevel.fromString(envLevel);
    }
    // Default based on build mode
    return kDebugMode ? LogLevel.debug : LogLevel.info;
  }

  /// Get default categories from environment or enable all
  static Set<LogCategory> _getDefaultCategories() {
    // Check environment variable first (comma-separated list)
    const envCategories = String.fromEnvironment('LOG_CATEGORIES');
    if (envCategories.isNotEmpty) {
      final categories = envCategories
          .split(',')
          .map((cat) => LogCategory.fromString(cat.trim()))
          .whereType<LogCategory>()
          .toSet();
      if (categories.isNotEmpty) return categories;
    }
    // Default: minimal logging to reduce noise
    // Users can enable specific categories when debugging
    return {LogCategory.system, LogCategory.auth};
  }

  /// Set the minimum log level
  static void setLogLevel(LogLevel level) {
    _currentLevel = level;
    if (kDebugMode) {
      Log.debug(
        'Log level set to: ${level.name}',
        name: 'UnifiedLogger',
        category: LogCategory.system,
      );
    }
  }

  /// Enable specific categories
  static void enableCategories(Set<LogCategory> categories) {
    _enabledCategories = categories;
    if (kDebugMode) {
      debugPrint(
        'Enabled categories: ${categories.map((c) => c.name).join(', ')}',
      );
    }
  }

  /// Enable a single category
  static void enableCategory(LogCategory category) {
    _enabledCategories.add(category);
    if (kDebugMode) {
      Log.debug(
        'Enabled category: ${category.name}',
        name: 'UnifiedLogger',
        category: LogCategory.system,
      );
    }
  }

  /// Disable a single category
  static void disableCategory(LogCategory category) {
    _enabledCategories.remove(category);
    if (kDebugMode) {
      Log.debug(
        'Disabled category: ${category.name}',
        name: 'UnifiedLogger',
        category: LogCategory.system,
      );
    }
  }

  /// Get the current log level
  static LogLevel get currentLevel => _currentLevel;

  /// Get enabled categories
  static Set<LogCategory> get enabledCategories => _enabledCategories;

  /// Check if a specific level is enabled
  static bool isLevelEnabled(LogLevel level) =>
      level.value >= _currentLevel.value;

  /// Check if a specific category is enabled
  static bool isCategoryEnabled(LogCategory category) =>
      _enabledCategories.contains(category);

  /// Internal logging method that outputs to both destinations
  static void _log(
    String message, {
    required LogLevel level,
    String? name,
    LogCategory? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Console output — entirely tree-shaken from release builds.
    // Timestamp formatting, debugPrint, and developer.log only serve the
    // developer console; nobody reads them in production.
    if (kDebugMode) {
      final shouldPrintToConsole =
          isLevelEnabled(level) &&
          (category == null || isCategoryEnabled(category));

      if (shouldPrintToConsole) {
        final now = DateTime.now();
        final h = now.hour.toString().padLeft(2, '0');
        final m = now.minute.toString().padLeft(2, '0');
        final s = now.second.toString().padLeft(2, '0');
        final ms = now.millisecond.toString().padLeft(3, '0');
        final timestamp = '$h:$m:$s.$ms';
        final categoryPrefix = category != null ? '[${category.name}] ' : '';
        final timestampedMessage = '[$timestamp] $categoryPrefix$message';

        debugPrint(timestampedMessage);

        if (kIsWeb) {
          developer.log(
            timestampedMessage,
            name: name ?? 'divine',
            level: level.value,
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }

    // CRITICAL: ALWAYS capture to memory regardless of category/level filtering
    // Console filtering is for noise reduction during development
    // Memory capture must be comprehensive for debugging remote user issues
    try {
      final logEntry = LogEntry(
        // UTC so exported logs correlate with relay, funnelcake and
        // ClickHouse rows without guessing the reporter's timezone.
        timestamp: DateTime.now().toUtc(),
        level: level,
        message: message,
        category: category,
        name: name,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      );
      LogCaptureService().captureLog(logEntry);
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to capture log: $e');
      }
    }
  }

  /// Verbose logging - detailed debug information
  static void verbose(String message, {String? name, LogCategory? category}) {
    _log(message, name: name, category: category, level: LogLevel.verbose);
  }

  /// Debug logging - development debugging
  static void debug(String message, {String? name, LogCategory? category}) {
    _log(message, name: name, category: category, level: LogLevel.debug);
  }

  /// Info logging - general information
  static void info(String message, {String? name, LogCategory? category}) {
    _log(message, name: name, category: category, level: LogLevel.info);
  }

  /// Warning logging - potential issues with optional error object
  static void warning(
    String message, {
    String? name,
    LogCategory? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      name: name,
      category: category,
      level: LogLevel.warning,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Error logging - actual errors with optional error object
  static void error(
    String message, {
    String? name,
    LogCategory? category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      name: name,
      category: category,
      level: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Convenience method that matches developer.log signature
  static void log(
    String message, {
    String? name,
    LogCategory? category,
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      name: name,
      category: category,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Migration helper - replaces debugPrint calls
  /// In debug mode: logs at debug level
  /// In release mode: logs at info level
  static void print(String message, {String? name, LogCategory? category}) {
    _log(
      message,
      name: name,
      category: category,
      level: kDebugMode ? LogLevel.debug : LogLevel.info,
    );
  }
}

/// Convenience alias for shorter syntax
typedef Log = UnifiedLogger;

/// Helper class for common logging configurations
class LogConfig {
  /// Enable only essential logs (errors and critical system events)
  static void minimal() {
    UnifiedLogger.setLogLevel(LogLevel.error);
    UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth});
  }

  /// Enable only relay-related logs for debugging connection issues
  static void relayDebug() {
    UnifiedLogger.setLogLevel(LogLevel.debug);
    UnifiedLogger.enableCategories({LogCategory.relay, LogCategory.system});
  }

  /// Enable only video-related logs for debugging playback issues
  static void videoDebug() {
    UnifiedLogger.setLogLevel(LogLevel.debug);
    UnifiedLogger.enableCategories({LogCategory.video, LogCategory.system});
  }

  /// Enable UI and interaction logs for debugging user experience
  static void uiDebug() {
    UnifiedLogger.setLogLevel(LogLevel.debug);
    UnifiedLogger.enableCategories({LogCategory.ui, LogCategory.system});
  }

  /// Enable all logs (development mode)
  static void verbose() {
    UnifiedLogger.setLogLevel(LogLevel.verbose);
    UnifiedLogger.enableCategories(Set.from(LogCategory.values));
  }

  /// Completely disable logging
  static void disable() {
    UnifiedLogger.enableCategories(<LogCategory>{});
  }
}
