// ABOUTME: Log level and category enums for structured logging.
// ABOUTME: Used by LogEntry model and logging infrastructure.

/// Log level enumeration with integer values for filtering
enum LogLevel {
  verbose(500),
  debug(700),
  info(800),
  warning(900),
  error(1000)
  ;

  const LogLevel(this.value);

  final int value;

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
  system('SYSTEM')
  ; // App lifecycle, initialization, configuration

  const LogCategory(this.name);

  final String name;

  static LogCategory? fromString(String category) {
    final lowerCategory = category.toLowerCase();
    for (final cat in LogCategory.values) {
      if (cat.name.toLowerCase() == lowerCategory) return cat;
    }
    return null;
  }
}
