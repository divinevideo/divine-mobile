// ABOUTME: Service that auto-sweeps the durable pending_reports outbox.
// ABOUTME: Drives the kind-1984 and Zendesk channels until each is delivered.

import 'dart:async';
import 'dart:math' as math;

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:unified_logger/unified_logger.dart';

/// Delivers one channel of one queued report. Implemented by
/// `ContentReportingService`, which owns the actual relay publish and Zendesk
/// POST; the retry service only decides *when* to call it and what to do with
/// the result.
abstract interface class ReportChannelDriver {
  /// Attempts delivery of [channel] for [report]. Returns whether it landed.
  /// Must not throw; a thrown error is treated as a failed attempt.
  Future<bool> deliverReportChannel(
    PendingReport report,
    ReportChannel channel,
  );
}

/// Backoff and cap configuration for [ReportRetryService].
class ReportRetryConfig {
  const ReportRetryConfig({
    this.maxReportsPerSweep = 25,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.maxAttemptsPerChannel = 10,
  });

  final int maxReportsPerSweep;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  /// After this many failed attempts a channel is dead-lettered instead of
  /// retried. Because sweeps fire on app-foreground, this spans many sessions.
  final int maxAttemptsPerChannel;

  Duration backoffFor(int attempts) {
    if (attempts <= 0) return Duration.zero;
    var ms = initialDelay.inMilliseconds.toDouble();
    for (var i = 0; i < attempts; i++) {
      ms *= backoffMultiplier;
      if (ms >= maxDelay.inMilliseconds) return maxDelay;
    }
    return Duration(milliseconds: ms.round());
  }
}

/// Sweeps the durable `pending_reports` queue, driving each report's undelivered
/// channels with per-channel backoff and a dead-letter cap.
class ReportRetryService {
  ReportRetryService({
    required ReportChannelDriver driver,
    required PendingReportsDao pendingReportsDao,
    required String userPubkey,
    required Stream<bool> appForegroundStream,
    ReportRetryConfig retryConfig = const ReportRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _driver = driver,
       _dao = pendingReportsDao,
       _userPubkey = userPubkey,
       _appForegroundStream = appForegroundStream,
       _config = retryConfig,
       _now = now;

  final ReportChannelDriver _driver;
  final PendingReportsDao _dao;
  final String _userPubkey;
  final Stream<bool> _appForegroundStream;
  final ReportRetryConfig _config;
  final DateTime Function() _now;

  StreamSubscription<bool>? _foregroundSubscription;
  bool _isInitialized = false;
  bool _isSweeping = false;

  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool get isSweeping => _isSweeping;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // No in-flight status to reset: a crash mid-drive leaves each channel
    // `pending`, and both the relay republish (stable event id) and the Zendesk
    // POST (external_id) are idempotent, so a re-drive is safe.
    _foregroundSubscription = _appForegroundStream.listen((foreground) {
      if (foreground) {
        unawaited(sweep());
      }
    });
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    _isInitialized = false;
  }

  Future<void> sweep() async {
    if (_isSweeping) return;
    _isSweeping = true;
    try {
      final rows = await _dao.getRetryableForUser(
        userPubkey: _userPubkey,
        limit: _config.maxReportsPerSweep,
      );
      for (final row in rows) {
        await _driveRow(row);
      }
    } finally {
      _isSweeping = false;
    }
  }

  Future<void> _driveRow(PendingReport row) async {
    final pendingChannels = ReportChannel.values
        .where((c) => row.statusOf(c) == PendingReportChannelStatus.pending)
        .toList();
    if (pendingChannels.isEmpty) return;

    // Gate the row on the least-attempted pending channel, so a channel still
    // in deep backoff never holds back one that is ready to retry.
    final lastAttempt = row.lastAttemptAt;
    if (lastAttempt != null) {
      final minAttempts = pendingChannels.map(row.attemptsOf).reduce(math.min);
      if (_now().difference(lastAttempt) < _config.backoffFor(minAttempts)) {
        return;
      }
    }

    for (final channel in pendingChannels) {
      bool delivered;
      try {
        delivered = await _driver.deliverReportChannel(row, channel);
      } catch (e) {
        delivered = false;
      }

      if (delivered) {
        await _dao.markChannelDone(reportId: row.reportId, channel: channel);
        continue;
      }

      final nextAttempts = row.attemptsOf(channel) + 1;
      if (nextAttempts >= _config.maxAttemptsPerChannel) {
        await _dao.markChannelDeadLetter(
          reportId: row.reportId,
          channel: channel,
          error: 'exhausted after $nextAttempts attempts',
        );
        Log.warning(
          'Report ${row.reportId} channel ${channel.name} dead-lettered after '
          '$nextAttempts attempts; it will not be retried',
          name: 'ReportRetryService',
          category: LogCategory.system,
        );
      } else {
        await _dao.recordChannelFailure(
          reportId: row.reportId,
          channel: channel,
          error: '${channel.name} delivery failed (attempt $nextAttempts)',
        );
      }
    }

    // Delete once every channel has landed; a dead-lettered channel keeps the
    // row for inspection.
    final updated = await _dao.getById(row.reportId);
    if (updated != null &&
        updated.relayStatus == PendingReportChannelStatus.done &&
        updated.zendeskStatus == PendingReportChannelStatus.done) {
      await _dao.deleteById(row.reportId);
    }
  }
}
