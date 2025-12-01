// ABOUTME: Service for capturing log entries in memory for bug reports
// ABOUTME: Maintains a ring buffer of recent logs without file I/O overhead

import 'dart:collection';
import 'package:openvine/models/log_entry.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for capturing and storing log entries in memory for bug reports
class LogCaptureService {
  static LogCaptureService? _instance;

  /// Singleton instance
  static LogCaptureService get instance => _instance ??= LogCaptureService._();

  LogCaptureService._();

  /// In-memory ring buffer for logs
  final Queue<LogEntry> _memoryBuffer = Queue<LogEntry>();

  /// Maximum memory buffer size (50k entries = ~5-10MB, totally fine for mobile)
  static const int _memoryBufferSize = 50000;

  /// Total entries captured in current session
  int _totalEntriesWritten = 0;

  /// Format a log entry as a text line
  String _formatLogEntry(LogEntry entry) {
    final timestamp = entry.timestamp.toIso8601String();
    final level = entry.level.toString().split('.').last.toUpperCase();
    final category = entry.category?.toString().split('.').last ?? 'GENERAL';
    final name = entry.name ?? '';

    final buffer = StringBuffer();
    buffer.write('[$timestamp] [$level] ');
    if (name.isNotEmpty) {
      buffer.write('[$name] ');
    }
    buffer.write('$category: ${entry.message}');

    if (entry.error != null) {
      buffer.write(' | Error: ${entry.error}');
    }

    if (entry.stackTrace != null) {
      buffer.write(
        ' | Stack: ${entry.stackTrace.toString().split('\n').first}',
      );
    }

    return buffer.toString();
  }

  /// Capture a log entry to memory buffer (ring buffer)
  void captureLog(LogEntry entry) {
    // Add to memory buffer (maintain max size as ring buffer)
    if (_memoryBuffer.length >= _memoryBufferSize) {
      _memoryBuffer.removeFirst();
    }
    _memoryBuffer.add(entry);
    _totalEntriesWritten++;
  }

  /// Get recent logs from memory buffer (fast access)
  ///
  /// [limit] - Optional limit on number of entries to return (returns most recent)
  /// [minLevel] - Optional minimum log level filter
  List<LogEntry> getRecentLogs({int? limit, LogLevel? minLevel}) {
    // Convert buffer to list and sort by timestamp
    var logs = _memoryBuffer.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Apply level filter if specified
    if (minLevel != null) {
      logs = logs.where((log) => log.level.value >= minLevel.value).toList();
    }

    // Apply limit if specified (return most recent)
    if (limit != null && logs.length > limit) {
      return logs.sublist(logs.length - limit);
    }

    return logs;
  }

  /// Get ALL logs as formatted text lines (for export/bug reports)
  ///
  /// This returns all logs from the memory buffer
  Future<List<String>> getAllLogsAsText() async {
    if (_memoryBuffer.isEmpty) {
      return [];
    }

    return _memoryBuffer.map((entry) => _formatLogEntry(entry)).toList();
  }

  /// Get statistics about log storage
  Future<Map<String, dynamic>> getLogStatistics() async {
    final allLogLines = await getAllLogsAsText();
    final totalSize = allLogLines.fold<int>(
      0,
      (sum, line) => sum + line.length,
    );

    return {
      'fileCount': 0, // No file storage
      'totalSizeBytes': totalSize,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      'totalLogLines': allLogLines.length,
      'memoryBufferSize': _memoryBuffer.length,
      'totalEntriesWritten': _totalEntriesWritten,
    };
  }

  /// Clear all logs
  Future<void> clearAllLogs() async {
    _memoryBuffer.clear();
    _totalEntriesWritten = 0;
  }

  /// Get current buffer size
  int get bufferSize => _memoryBuffer.length;

  /// Get maximum buffer capacity
  int get maxCapacity => _memoryBufferSize;

  /// Check if buffer is empty
  bool get isEmpty => _memoryBuffer.isEmpty;

  /// Check if buffer is at capacity
  bool get isFull => _memoryBuffer.length >= _memoryBufferSize;
}
