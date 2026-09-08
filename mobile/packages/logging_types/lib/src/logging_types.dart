// ABOUTME: Log level and category enums for structured logging.
// ABOUTME: Used by LogEntry and logging infrastructure.

/// Log level enumeration with integer values for filtering.
enum LogLevel {
  /// Highly detailed diagnostic output.
  verbose(500),

  /// Development diagnostics.
  debug(700),

  /// Normal operational information.
  info(800),

  /// A recoverable or potentially problematic condition.
  warning(900),

  /// A failed operation.
  error(1000);

  const LogLevel(this.value);

  /// Numeric severity used for threshold filtering.
  final int value;

  /// Parses a serialized level, defaulting unknown values to [info].
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

/// Log categories for filtering by functional area.
enum LogCategory {
  /// Nostr relay connections, subscriptions, and events.
  relay('RELAY'),

  /// Video playback, upload, and processing.
  video('VIDEO'),

  /// User-interface interactions and navigation.
  ui('UI'),

  /// Authentication, key management, and identity.
  auth('AUTH'),

  /// Local storage, caching, and persistence.
  storage('STORAGE'),

  /// External API calls and network requests.
  api('API'),

  /// App lifecycle, initialization, and configuration.
  system('SYSTEM');

  const LogCategory(this.name);

  /// Stable serialized category name.
  final String name;

  /// Parses a serialized category, or returns `null` when it is unknown.
  static LogCategory? fromString(String category) {
    final lowerCategory = category.toLowerCase();
    for (final cat in LogCategory.values) {
      if (cat.name.toLowerCase() == lowerCategory) return cat;
    }
    return null;
  }
}
