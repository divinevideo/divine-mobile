// ABOUTME: Delivers durable reports independently of the reporting screen.
// ABOUTME: Retries on reconnect, foreground, and bounded backoff without expiry.

import 'dart:async';
import 'dart:math' as math;

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:unified_logger/unified_logger.dart';

abstract interface class ReportChannelDriver {
  Future<bool> deliverReportChannel(
    PendingReport report,
    ReportChannel channel,
  );
}

class ReportRetryConfig {
  const ReportRetryConfig({
    this.maxReportsPerSweep = 25,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.attemptTimeout = const Duration(seconds: 30),
  });

  final int maxReportsPerSweep;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  /// Bound an attempt so a silent native SDK cannot stop the whole outbox.
  final Duration attemptTimeout;

  Duration backoffFor(int attempts) {
    if (attempts <= 0) return Duration.zero;
    var ms = initialDelay.inMilliseconds.toDouble();
    for (var i = 1; i < attempts; i++) {
      ms *= backoffMultiplier;
      if (ms >= maxDelay.inMilliseconds) return maxDelay;
    }
    return Duration(milliseconds: ms.round());
  }
}

/// Each channel retains its pending intent until delivery. Connectivity is a
/// wake-up signal, not proof that the relay or support server is reachable.
class ReportRetryService {
  ReportRetryService({
    required ReportChannelDriver driver,
    required PendingReportsDao pendingReportsDao,
    required String userPubkey,
    required Stream<bool> appForegroundStream,
    Stream<void>? retryTriggerStream,
    Stream<void>? reportQueuedStream,
    ReportRetryConfig retryConfig = const ReportRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _driver = driver,
       _dao = pendingReportsDao,
       _userPubkey = userPubkey,
       _appForegroundStream = appForegroundStream,
       _retryTriggerStream = retryTriggerStream,
       _reportQueuedStream = reportQueuedStream,
       _config = retryConfig,
       _now = now;

  final ReportChannelDriver _driver;
  final PendingReportsDao _dao;
  final String _userPubkey;
  final Stream<bool> _appForegroundStream;
  final Stream<void>? _retryTriggerStream;

  /// Fires when the driver has just saved a report, so its first attempt
  /// happens now rather than on the next reconnect or foreground transition.
  final Stream<void>? _reportQueuedStream;
  final ReportRetryConfig _config;
  final DateTime Function() _now;
  StreamSubscription<bool>? _foregroundSubscription;
  StreamSubscription<void>? _retrySubscription;
  StreamSubscription<void>? _queuedSubscription;
  Timer? _timer;
  bool _isInitialized = false;
  bool _isSweeping = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _sweepAgain = false;
  bool _forceNext = false;

  bool get isInitialized => _isInitialized;
  @visibleForTesting
  bool get isSweeping => _isSweeping;

  Future<void> initialize() async {
    if (_isInitialized || _disposed) return;
    _isInitialized = true;
    _foregroundSubscription = _appForegroundStream.listen((foreground) {
      _foreground = foreground;
      if (foreground) {
        unawaited(sweep());
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
    _retrySubscription = _retryTriggerStream?.listen((_) {
      if (_foreground) unawaited(sweep(force: true));
    });
    // A new row is due immediately; rows already in backoff keep their delay.
    _queuedSubscription = _reportQueuedStream?.listen(
      (_) => unawaited(sweep()),
    );
    unawaited(sweep());
  }

  Future<void> dispose() async {
    _disposed = true;
    _isInitialized = false;
    _timer?.cancel();
    _timer = null;
    await _foregroundSubscription?.cancel();
    await _retrySubscription?.cancel();
    await _queuedSubscription?.cancel();
  }

  Future<void> sweep({bool force = false}) async {
    if (_disposed || !_foreground) return;
    if (_isSweeping) {
      _sweepAgain = true;
      _forceNext |= force;
      return;
    }
    _isSweeping = true;
    _timer?.cancel();
    _timer = null;
    try {
      final rows = await _dao.getRetryableForUser(userPubkey: _userPubkey);
      // Filter before limiting: an old report in backoff must not starve a
      // newly queued report behind it.
      final due = rows
          .where((row) => force || _delayFor(row) <= Duration.zero)
          .take(_config.maxReportsPerSweep);
      for (final candidate in due) {
        if (_disposed || !_foreground) break;
        // A late acknowledgement may retire a later row during this sweep.
        final row = await _dao.getById(candidate.reportId);
        if (row == null) continue;
        // A hung relay does not hold the support ticket or moderation DM.
        await Future.wait(
          ReportChannel.values
              .where(
                (c) => row.statusOf(c) == PendingReportChannelStatus.pending,
              )
              .map((c) => _driveChannel(row, c)),
        );
        if (_disposed) break;
      }
    } catch (e) {
      Log.warning(
        'Report retry pass failed; pending reports are retained: $e',
        name: 'ReportRetryService',
        category: LogCategory.system,
      );
    } finally {
      _isSweeping = false;
      if (_sweepAgain && !_disposed && _foreground) {
        final forceNext = _forceNext;
        _sweepAgain = false;
        _forceNext = false;
        unawaited(sweep(force: forceNext));
      } else {
        await _scheduleNext();
      }
    }
  }

  Duration _delayFor(PendingReport row) {
    final last = row.lastAttemptAt;
    if (last == null) return Duration.zero;
    final attempts = ReportChannel.values
        .where((c) => row.statusOf(c) == PendingReportChannelStatus.pending)
        .map(row.attemptsOf)
        .reduce(math.min);
    return _config.backoffFor(attempts) - _now().difference(last);
  }

  Future<void> _scheduleNext() async {
    if (!_isInitialized || _disposed || !_foreground || _isSweeping) return;
    var delay = _config.maxDelay;
    try {
      final rows = await _dao.getRetryableForUser(userPubkey: _userPubkey);
      if (rows.isEmpty) return;
      for (final row in rows) {
        final remaining = _delayFor(row);
        if (remaining < delay) delay = remaining;
      }
    } catch (e) {
      Log.warning(
        'Could not schedule pending reports: $e',
        name: 'ReportRetryService',
        category: LogCategory.system,
      );
    }
    if (!_isInitialized || _disposed || !_foreground || _isSweeping) return;
    if (delay < _config.initialDelay) delay = _config.initialDelay;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(sweep()));
  }

  Future<void> _driveChannel(PendingReport row, ReportChannel channel) async {
    if (_disposed) return;
    bool delivered;
    try {
      delivered = await _driver
          .deliverReportChannel(row, channel)
          .then((delivered) async {
            // Persist late acknowledgements even after this sweep stops waiting.
            if (delivered) {
              await _dao.markChannelDone(
                reportId: row.reportId,
                channel: channel,
              );
              await _dao.deleteIfDelivered(row.reportId);
            }
            return delivered;
          })
          .timeout(_config.attemptTimeout);
    } catch (e) {
      delivered = false;
    }
    if (_disposed) return;
    if (!delivered) {
      await _dao.recordChannelFailure(
        reportId: row.reportId,
        channel: channel,
        error: '${channel.name} delivery failed',
      );
    }
  }
}
