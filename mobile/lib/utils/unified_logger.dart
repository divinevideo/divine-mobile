// ABOUTME: Unified logging utility that outputs to both Flutter console and browser DevTools
// ABOUTME: Provides structured logging with levels while maintaining single command simplicity

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:openvine/models/log_entry.dart';
import 'package:openvine/services/log_capture_service.dart';

/// Log levels for filtering and categorization
enum LogLevel {
  verbose(500),
  debug(700),
  info(800),
  warning(900),
  error(1000);

  final int value;
  const LogLevel(this.value);

  static LogLevel fromString(String level) {
    switch (level.toLowerCase()) {
      case 'verbose':
        return LogLevel.verbose;
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warning':
      case 'warn':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}

/// Log categories for filtering by functional area
enum LogCategory {
  relay('RELAY'), // Nostr relay connections, subscriptions, events
  video('VIDEO'), // Video playback, upload, processing
  ui('UI'), // User interface interactions, navigation
  auth('AUTH'), // Authentication, key management, identity
  storage('STORAGE'), // Local storage, caching, persistence
  api('API'), // External API calls, network requests
  system('SYSTEM'); // App lifecycle, initialization, configuration

  final String name;
  const LogCategory(this.name);

  static LogCategory? fromString(String category) {
    try {
      return LogCategory.values.firstWhere(
        (cat) => cat.name.toLowerCase() == category.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Unified logger that outputs to both Flutter tool console and browser DevTools
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
/// - Code: UnifiedLogger.enableCategories({LogCategory.relay, LogCategory.video})
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
    // Check if this message should be printed to console
    // Category/level filtering applies ONLY to console output (noise reduction)
    final shouldPrintToConsole =
        isLevelEnabled(level) &&
        (category == null || isCategoryEnabled(category));

    // Create timestamp
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';

    // Format category prefix
    final categoryPrefix = category != null ? '[${category.name}] ' : '';

    // Format message with timestamp and category
    final timestampedMessage = '[$timestamp] $categoryPrefix$message';

    // Output to console ONLY if category/level filters allow it
    if (shouldPrintToConsole) {
      // Always output to Flutter tool console via debugPrint
      debugPrint(timestampedMessage);

      // Also output to browser DevTools via developer.log (web only)
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

    // CRITICAL: ALWAYS capture to file regardless of category/level filtering
    // Console filtering is for noise reduction during development
    // File capture must be comprehensive for debugging remote user issues
    try {
      final logEntry = LogEntry(
        timestamp: now,
        level: level,
        message: message,
        category: category,
        name: name,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      );
      // Logging is now synchronous and non-blocking (in-memory only)
      LogCaptureService.instance.captureLog(logEntry);
    } catch (e) {
      // Don't let log capture failures break logging
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

  /// Warning logging - potential issues
  static void warning(String message, {String? name, LogCategory? category}) {
    _log(message, name: name, category: category, level: LogLevel.warning);
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
