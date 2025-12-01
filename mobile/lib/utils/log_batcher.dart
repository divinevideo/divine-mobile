// ABOUTME: Utility for batching repetitive log messages to reduce console noise
// ABOUTME: Groups similar messages and outputs summaries instead of individual lines

import 'dart:async';
import 'package:openvine/utils/unified_logger.dart';

/// Batches repetitive log messages and outputs summaries
class LogBatcher {
  static final Map<String, _BatchedMessage> _batches = {};
  static Timer? _flushTimer;
  static const Duration _flushInterval = Duration(seconds: 5);

  /// Batch a repetitive log message
  static void batch({
    required String pattern,
    required LogCategory? category,
    String? name,
    Map<String, dynamic>? data,
  }) {
    final key = '$pattern-$category-${name ?? ""}';

    if (!_batches.containsKey(key)) {
      _batches[key] = _BatchedMessage(
        pattern: pattern,
        category: category,
        name: name,
      );
    }

    _batches[key]!.add(data);

    // Start flush timer if not running
    _flushTimer ??= Timer.periodic(_flushInterval, (_) => flush());
  }

  /// Flush all batched messages
  static void flush() {
    if (_batches.isEmpty) return;

    for (var batch in _batches.values) {
      batch.flush();
    }

    _batches.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Force immediate flush of specific pattern
  static void flushPattern(String pattern) {
    _batches.entries.where((e) => e.value.pattern == pattern).forEach((e) {
      e.value.flush();
      _batches.remove(e.key);
    });
  }
}

/// Represents a batch of similar log messages
class _BatchedMessage {
  final String pattern;
  final LogCategory? category;
  final String? name;
  final List<Map<String, dynamic>> instances = [];
  int count = 0;

  _BatchedMessage({required this.pattern, required this.category, this.name});

  void add(Map<String, dynamic>? data) {
    count++;
    if (data != null && instances.length < 5) {
      // Keep first 5 instances for context
      instances.add(data);
    }
  }

  void flush() {
    if (count == 0) return;

    if (count == 1 && instances.isNotEmpty) {
      // Single message, log normally
      final instance = instances.first;
      Log.debug(
        _formatMessage(pattern, instance),
        name: name ?? 'LogBatcher',
        category: category,
      );
    } else {
      // Multiple messages, log summary
      final summaryMessage = _buildSummaryMessage();
      Log.debug(summaryMessage, name: name ?? 'LogBatcher', category: category);
    }
  }

  String _buildSummaryMessage() {
    final buffer = StringBuffer();
    buffer.write('📦 Batched $count similar messages: "$pattern"');

    if (instances.isNotEmpty) {
      buffer.write('\n  First few instances:');
      for (var i = 0; i < instances.length && i < 3; i++) {
        final instance = instances[i];
        buffer.write('\n    - ${_formatCompactInstance(instance)}');
      }

      if (count > instances.length) {
        buffer.write('\n    ... and ${count - instances.length} more');
      }
    }

    return buffer.toString();
  }

  String _formatMessage(String pattern, Map<String, dynamic> data) {
    var message = pattern;
    data.forEach((key, value) {
      message = message.replaceAll('{$key}', value.toString());
    });
    return message;
  }

  String _formatCompactInstance(Map<String, dynamic> data) {
    if (data.isEmpty) return '(no data)';

    // Create compact representation of key data points
    final parts = <String>[];

    // Prioritize certain fields for compact display
    final priorityFields = ['id', 'kind', 'author', 'subscription', 'type'];

    for (final field in priorityFields) {
      if (data.containsKey(field)) {
        final value = data[field].toString();
        parts.add('$field:$value');
      }
    }

    // Add any remaining fields not in priority list
    data.forEach((key, value) {
      if (!priorityFields.contains(key) && parts.length < 4) {
        parts.add('$key:${value.toString()}');
      }
    });

    return parts.join(', ');
  }
}

/// Extension for batching video event logs specifically
extension VideoEventLogBatcher on LogBatcher {
  static void batchVideoEvent({
    required String eventId,
    required String authorPubkey,
    required String subscriptionType,
    int? kind,
  }) {
    LogBatcher.batch(
      pattern: 'Received video event',
      category: LogCategory.video,
      name: 'VideoEventService',
      data: {
        'id': eventId,
        'author': authorPubkey,
        'subscription': subscriptionType,
        if (kind != null) 'kind': kind,
      },
    );
  }

  static void batchNip71Event({
    required String eventId,
    required String subscriptionType,
  }) {
    LogBatcher.batch(
      pattern: 'Received NIP-71 video event',
      category: LogCategory.video,
      name: 'VideoEventService',
      data: {'id': eventId, 'subscription': subscriptionType},
    );
  }
}

/// Extension for batching relay event logs
extension RelayEventLogBatcher on LogBatcher {
  static void batchRelayEvent({required String subscriptionId}) {
    LogBatcher.batch(
      pattern: 'Embedded relay returned event',
      category: LogCategory.relay,
      name: 'NostrService',
      data: {'subscription': subscriptionId},
    );
  }

  static void batchDuplicateEvent({
    required String eventId,
    required String subscriptionId,
  }) {
    LogBatcher.batch(
      pattern: 'Dropping duplicate event',
      category: LogCategory.relay,
      name: 'NostrService',
      data: {'id': eventId, 'subscription': subscriptionId},
    );
  }
}
