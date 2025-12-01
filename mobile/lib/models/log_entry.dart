// ABOUTME: Data model representing a single log entry in the circular buffer
// ABOUTME: Includes timestamp, level, message, category, and optional error/stack trace

import 'package:openvine/utils/unified_logger.dart';

/// Represents a single log entry in the circular buffer
class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.category,
    this.name,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final LogCategory? category;
  final String? name;
  final String? error;
  final String? stackTrace;

  /// Convert to JSON for bug report
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    if (category != null) 'category': category!.name,
    if (name != null) 'name': name,
    if (error != null) 'error': error,
    if (stackTrace != null) 'stackTrace': stackTrace,
  };

  /// Create from JSON
  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    timestamp: DateTime.parse(json['timestamp'] as String),
    level: LogLevel.fromString(json['level'] as String),
    message: json['message'] as String,
    category: json['category'] != null
        ? LogCategory.fromString(json['category'] as String)
        : null,
    name: json['name'] as String?,
    error: json['error'] as String?,
    stackTrace: json['stackTrace'] as String?,
  );

  /// Create formatted string for display
  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.name.toUpperCase()}] ');
    if (category != null) {
      buffer.write('[${category!.name}] ');
    }
    if (name != null) {
      buffer.write('($name) ');
    }
    buffer.write(message);
    if (error != null) {
      buffer.write(' | Error: $error');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntry &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          level == other.level &&
          message == other.message &&
          category == other.category &&
          name == other.name &&
          error == other.error &&
          stackTrace == other.stackTrace;

  @override
  int get hashCode =>
      timestamp.hashCode ^
      level.hashCode ^
      message.hashCode ^
      category.hashCode ^
      name.hashCode ^
      error.hashCode ^
      stackTrace.hashCode;
}
