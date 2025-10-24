// ABOUTME: Service for capturing log entries with persistent file-based storage
// ABOUTME: Writes logs continuously to rotating files, supporting hundreds of thousands of entries

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:openvine/models/log_entry.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Service for capturing and persisting log entries for bug reports
class LogCaptureService {
  static LogCaptureService? _instance;

  /// Singleton instance
  static LogCaptureService get instance => _instance ??= LogCaptureService._();

  LogCaptureService._() {
    _initializeLogFiles();
  }

  /// Small in-memory buffer for immediate access (most recent logs)
  final Queue<LogEntry> _memoryBuffer = Queue<LogEntry>();

  /// Maximum memory buffer size (keep last 1000 for quick access)
  static const int _memoryBufferSize = 1000;

  /// Maximum size per log file (1MB)
  static const int _maxFileSize = 1024 * 1024;

  /// Maximum number of log files to keep (10 files = 10MB total)
  static const int _maxLogFiles = 10;

  /// Directory for log files
  Directory? _logDirectory;

  /// Current log file
  File? _currentLogFile;

  /// Current log file number
  int _currentFileNumber = 0;

  /// Total entries written in current session
  int _totalEntriesWritten = 0;

  /// Initialize log file storage
  Future<void> _initializeLogFiles() async {
    try {
      // Use Application Support directory (hidden app data, not user's Documents)
      // - iOS: NSApplicationSupportDirectory
      // - macOS: ~/Library/Application Support/openvine (hidden from user)
      // - Android: App-specific internal storage
      // - Linux: ~/.local/share/openvine
      // - Windows: %APPDATA%\openvine
      final appDir = await getApplicationSupportDirectory();
      _logDirectory = Directory('${appDir.path}/logs');

      // Create logs directory if it doesn't exist
      if (!await _logDirectory!.exists()) {
        await _logDirectory!.create(recursive: true);
      }

      // Find existing log files and determine next file number
      final existingFiles = await _getLogFiles();
      if (existingFiles.isNotEmpty) {
        // Get highest file number
        final numbers = existingFiles
            .map((f) => _extractFileNumber(f.path))
            .where((n) => n != null)
            .cast<int>()
            .toList()
          ..sort();
        if (numbers.isNotEmpty) {
          _currentFileNumber = numbers.last;
        }
      }

      // Clean up old files if we have too many
      await _cleanupOldFiles();

      // Create or open current log file
      _currentLogFile = File('${_logDirectory!.path}/openvine_log_$_currentFileNumber.txt');
    } catch (e) {
      // If file system initialization fails, we'll fall back to memory-only logging
      print('Failed to initialize log files: $e');
    }
  }

  /// Extract file number from log file path
  int? _extractFileNumber(String path) {
    final match = RegExp(r'openvine_log_(\d+)\.txt$').firstMatch(path);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Get all log files sorted by file number
  Future<List<File>> _getLogFiles() async {
    if (_logDirectory == null || !await _logDirectory!.exists()) {
      return [];
    }

    final files = await _logDirectory!
        .list()
        .where((entity) => entity is File && entity.path.contains('openvine_log_'))
        .cast<File>()
        .toList();

    // Sort by file number
    files.sort((a, b) {
      final numA = _extractFileNumber(a.path) ?? 0;
      final numB = _extractFileNumber(b.path) ?? 0;
      return numA.compareTo(numB);
    });

    return files;
  }

  /// Clean up old log files if we exceed the limit
  Future<void> _cleanupOldFiles() async {
    final files = await _getLogFiles();
    if (files.length > _maxLogFiles) {
      // Delete oldest files
      final filesToDelete = files.take(files.length - _maxLogFiles);
      for (final file in filesToDelete) {
        try {
          await file.delete();
        } catch (e) {
          print('Failed to delete old log file: $e');
        }
      }
    }
  }

  /// Rotate to a new log file
  Future<void> _rotateLogFile() async {
    _currentFileNumber++;
    _currentLogFile = File('${_logDirectory!.path}/openvine_log_$_currentFileNumber.txt');
    await _cleanupOldFiles();
  }

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
      buffer.write(' | Stack: ${entry.stackTrace.toString().split('\n').first}');
    }

    return buffer.toString();
  }

  /// Capture a log entry and persist to file
  ///
  /// Writes to persistent log file and keeps in memory buffer for quick access
  Future<void> captureLog(LogEntry entry) async {
    // Add to memory buffer
    if (_memoryBuffer.length >= _memoryBufferSize) {
      _memoryBuffer.removeFirst();
    }
    _memoryBuffer.add(entry);

    // Write to persistent file
    if (_currentLogFile != null && _logDirectory != null) {
      try {
        // Check if we need to rotate
        if (await _currentLogFile!.exists()) {
          final size = await _currentLogFile!.length();
          if (size > _maxFileSize) {
            await _rotateLogFile();
          }
        }

        // Write log entry to file
        final logLine = '${_formatLogEntry(entry)}\n';
        await _currentLogFile!.writeAsString(
          logLine,
          mode: FileMode.append,
          flush: false, // Don't flush on every write for performance
        );

        _totalEntriesWritten++;

        // Flush every 100 entries to ensure we don't lose too much data on crash
        if (_totalEntriesWritten % 100 == 0) {
          // Note: flush() is not available on File, but writeAsString with flush: true would work
          // However, we're trading off crash-safety for performance here
        }
      } catch (e) {
        // If file write fails, we still have the memory buffer
        print('Failed to write log to file: $e');
      }
    }
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

  /// Get ALL logs from persistent storage (comprehensive export)
  ///
  /// This reads all log files and returns the complete log history
  /// Use this for bug reports to get hundreds of thousands of entries
  Future<List<String>> getAllLogsAsText() async {
    final allLogs = <String>[];

    try {
      final files = await _getLogFiles();

      for (final file in files) {
        if (await file.exists()) {
          // Read with error-tolerant UTF-8 decoding to handle malformed bytes
          final bytes = await file.readAsBytes();
          final contents = utf8.decode(bytes, allowMalformed: true);
          final lines = contents.split('\n').where((line) => line.isNotEmpty);
          allLogs.addAll(lines);
        }
      }
    } catch (e) {
      print('Failed to read log files: $e');
    }

    // If no file logs available (e.g., on web), include memory buffer
    if (allLogs.isEmpty && _memoryBuffer.isNotEmpty) {
      print('No file logs found, using memory buffer (${_memoryBuffer.length} entries)');
      allLogs.addAll(_memoryBuffer.map((entry) => _formatLogEntry(entry)));
    }

    return allLogs;
  }

  /// Get comprehensive statistics about log storage
  Future<Map<String, dynamic>> getLogStatistics() async {
    final files = await _getLogFiles();
    int totalSize = 0;
    int totalLines = 0;

    for (final file in files) {
      if (await file.exists()) {
        totalSize += await file.length();
        // Read with error-tolerant UTF-8 decoding to handle malformed bytes
        final bytes = await file.readAsBytes();
        final contents = utf8.decode(bytes, allowMalformed: true);
        totalLines += contents.split('\n').where((line) => line.isNotEmpty).length;
      }
    }

    return {
      'fileCount': files.length,
      'totalSizeBytes': totalSize,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      'totalLogLines': totalLines,
      'memoryBufferSize': _memoryBuffer.length,
      'currentFileNumber': _currentFileNumber,
    };
  }

  /// Clear all logs (both memory and files)
  Future<void> clearAllLogs() async {
    _memoryBuffer.clear();

    try {
      final files = await _getLogFiles();
      for (final file in files) {
        await file.delete();
      }
      _currentFileNumber = 0;
      _totalEntriesWritten = 0;
      _currentLogFile = File('${_logDirectory!.path}/openvine_log_0.txt');
    } catch (e) {
      print('Failed to clear log files: $e');
    }
  }

  /// Get current buffer size (memory buffer only)
  int get bufferSize => _memoryBuffer.length;

  /// Get maximum buffer capacity (memory buffer only)
  int get maxCapacity => _memoryBufferSize;

  /// Check if buffer is empty
  bool get isEmpty => _memoryBuffer.isEmpty;

  /// Check if buffer is at capacity
  bool get isFull => _memoryBuffer.length >= _memoryBufferSize;
}
