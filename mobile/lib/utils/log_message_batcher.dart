// ABOUTME: Utility for batching and deduplicating repetitive log messages to reduce console noise
// ABOUTME: Groups similar messages and periodically outputs summaries instead of individual logs

import 'dart:async';
import 'dart:collection';
import 'unified_logger.dart';

/// Batches similar log messages and outputs summaries instead of individual messages
class LogMessageBatcher {
  static final LogMessageBatcher _instance = LogMessageBatcher._internal();
  factory LogMessageBatcher() => _instance;
  LogMessageBatcher._internal();

  static LogMessageBatcher get instance => _instance;

  /// Map of message patterns to their batch info
  final Map<String, _BatchInfo> _batchedMessages = {};

  /// Timer for periodic batch flushing
  Timer? _flushTimer;

  /// Duration to wait before flushing batched messages
  static const Duration _flushInterval = Duration(seconds: 10);

  /// Maximum number of similar messages to batch before forcing a flush
  static const int _maxBatchSize = 50;

  /// Initialize the batcher with periodic flushing
  void initialize() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flushBatches());
  }

  /// Dispose the batcher and clean up resources
  void dispose() {
    _flushTimer?.cancel();
    _flushBatches(); // Flush any remaining messages
    _batchedMessages.clear();
  }

  /// Add a message to the batch if it matches a known pattern
  /// Returns true if the message was batched, false if it should be logged immediately
  bool tryBatchMessage(
    String message, {
    LogLevel level = LogLevel.info,
    LogCategory? category,
  }) {
    // Check for patterns that should be batched
    final pattern = _extractPattern(message);
    if (pattern == null) {
      return false; // Not a batchable message
    }

    final batchInfo = _batchedMessages.putIfAbsent(
      pattern,
      () => _BatchInfo(pattern: pattern, level: level, category: category),
    );

    batchInfo.count++;
    batchInfo.lastSeen = DateTime.now();
    batchInfo.examples.add(message);

    // Keep only a few examples to avoid memory bloat
    if (batchInfo.examples.length > 3) {
      batchInfo.examples.removeFirst();
    }

    // Force flush if batch gets too large
    if (batchInfo.count >= _maxBatchSize) {
      _flushSingleBatch(pattern, batchInfo);
      _batchedMessages.remove(pattern);
    }

    return true; // Message was batched
  }

  /// Extract a pattern from a log message if it's batchable
  String? _extractPattern(String message) {
    // Pattern for "Event ... already exists in database or was rejected"
    if (message.contains('already exists in database or was rejected')) {
      return 'events_already_exist';
    }

    // Pattern for "Event ... matches subscription"
    if (message.contains('matches subscription')) {
      return 'events_match_subscription';
    }

    // Pattern for "Received event ... from ... - kind:"
    if (message.contains('Received event') &&
        message.contains('from') &&
        message.contains('kind:')) {
      return 'events_received';
    }

    // Add more patterns as needed
    return null;
  }

  /// Flush all batched messages
  void _flushBatches() {
    if (_batchedMessages.isEmpty) return;

    final batches = Map<String, _BatchInfo>.from(_batchedMessages);
    _batchedMessages.clear();

    for (final entry in batches.entries) {
      _flushSingleBatch(entry.key, entry.value);
    }
  }

  /// Flush a single batch
  void _flushSingleBatch(String pattern, _BatchInfo batchInfo) {
    final message = _createBatchSummary(pattern, batchInfo);

    // Log the batch summary using UnifiedLogger
    switch (batchInfo.level) {
      case LogLevel.verbose:
        Log.verbose(message, category: batchInfo.category);
        break;
      case LogLevel.debug:
        Log.debug(message, category: batchInfo.category);
        break;
      case LogLevel.info:
        Log.info(message, category: batchInfo.category);
        break;
      case LogLevel.warning:
        Log.warning(message, category: batchInfo.category);
        break;
      case LogLevel.error:
        Log.error(message, category: batchInfo.category);
        break;
    }
  }

  /// Create a summary message for a batch
  String _createBatchSummary(String pattern, _BatchInfo batchInfo) {
    switch (pattern) {
      case 'events_already_exist':
        return '📦 BATCHED: ${batchInfo.count} events already existed in database and were not saved';

      case 'events_match_subscription':
        return '📦 BATCHED: ${batchInfo.count} events matched subscriptions';

      case 'events_received':
        return '📦 BATCHED: ${batchInfo.count} events received from external relays';

      default:
        return '📦 BATCHED: ${batchInfo.count} similar messages (pattern: $pattern)';
    }
  }

  /// Force flush all batches immediately
  void flushNow() {
    _flushBatches();
  }

  /// Get current batch statistics for debugging
  Map<String, int> getBatchStats() {
    return _batchedMessages.map(
      (pattern, info) => MapEntry(pattern, info.count),
    );
  }
}

/// Internal class to track batch information
class _BatchInfo {
  final String pattern;
  final LogLevel level;
  final LogCategory? category;
  int count = 0;
  DateTime lastSeen = DateTime.now();
  final Queue<String> examples = Queue<String>();

  _BatchInfo({required this.pattern, required this.level, this.category});
}

/// Extension to add batching capabilities to Log class
extension LogBatcher on Log {
  /// Log a message with automatic batching for repetitive patterns
  static void batchableInfo(
    String message, {
    String? name,
    LogCategory? category,
  }) {
    if (LogMessageBatcher.instance.tryBatchMessage(
      message,
      level: LogLevel.info,
      category: category,
    )) {
      return; // Message was batched
    }
    // Log normally if not batchable
    Log.info(message, name: name, category: category);
  }

  /// Log a debug message with automatic batching
  static void batchableDebug(
    String message, {
    String? name,
    LogCategory? category,
  }) {
    if (LogMessageBatcher.instance.tryBatchMessage(
      message,
      level: LogLevel.debug,
      category: category,
    )) {
      return; // Message was batched
    }
    Log.debug(message, name: name, category: category);
  }

  /// Log a warning message with automatic batching
  static void batchableWarning(
    String message, {
    String? name,
    LogCategory? category,
  }) {
    if (LogMessageBatcher.instance.tryBatchMessage(
      message,
      level: LogLevel.warning,
      category: category,
    )) {
      return; // Message was batched
    }
    Log.warning(message, name: name, category: category);
  }
}
