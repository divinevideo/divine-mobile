// ABOUTME: Data model representing a single log entry in the circular buffer.
// ABOUTME: Includes timestamp, level, message, category, optional error/stack.

import 'package:logging_types/src/logging_types.dart';
import 'package:meta/meta.dart';

/// Represents a single log entry in the circular buffer.
@immutable
class LogEntry {
  /// Creates a log entry.
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.category,
    this.name,
    this.error,
    this.stackTrace,
  });

  /// Creates a log entry from its serialized representation.
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

  /// When this entry was recorded.
  final DateTime timestamp;

  /// Severity used for filtering and display.
  final LogLevel level;

  /// Human-readable log message.
  final String message;

  /// Optional functional area associated with the entry.
  final LogCategory? category;

  /// Optional logger or operation name.
  final String? name;

  /// Optional error description.
  final String? error;

  /// Optional serialized stack trace.
  final String? stackTrace;

  /// Converts this entry to its serialized representation.
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    if (category != null) 'category': category!.name,
    if (name != null) 'name': name,
    if (error != null) 'error': error,
    if (stackTrace != null) 'stackTrace': stackTrace,
  };

  /// Formats this entry for display.
  String toFormattedString() {
    final buffer = StringBuffer()
      ..write('[${timestamp.toIso8601String()}] ')
      ..write('[${level.name.toUpperCase()}] ');
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
  int get hashCode => Object.hash(
    timestamp,
    level,
    message,
    category,
    name,
    error,
    stackTrace,
  );
}
