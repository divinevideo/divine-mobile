// ABOUTME: Service that auto-sweeps durable pending view events.
// ABOUTME: Publishes queued kind 22236 views until relay delivery succeeds.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/services/view_event_publisher.dart';

/// Backoff configuration for [ViewEventRetryService].
class ViewEventRetryConfig {
  const ViewEventRetryConfig({
    this.maxEventsPerSweep = 25,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
  });

  final int maxEventsPerSweep;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  Duration backoffFor(int retryCount) {
    if (retryCount <= 0) return Duration.zero;
    var ms = initialDelay.inMilliseconds.toDouble();
    for (var i = 0; i < retryCount; i++) {
      ms *= backoffMultiplier;
      if (ms >= maxDelay.inMilliseconds) return maxDelay;
    }
    return Duration(milliseconds: ms.round());
  }
}

/// Sweeps the durable `pending_view_events` queue for relay publish retries.
class ViewEventRetryService {
  ViewEventRetryService({
    required ViewEventPublisher viewEventPublisher,
    required PendingViewEventsDao pendingViewEventsDao,
    required String userPubkey,
    required Stream<bool> appForegroundStream,
    bool Function()? isAnalyticsEnabled,
    ViewEventRetryConfig retryConfig = const ViewEventRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _viewEventPublisher = viewEventPublisher,
       _dao = pendingViewEventsDao,
       _userPubkey = userPubkey,
       _appForegroundStream = appForegroundStream,
       _isAnalyticsEnabled = isAnalyticsEnabled,
       _retryConfig = retryConfig,
       _now = now;

  final ViewEventPublisher _viewEventPublisher;
  final PendingViewEventsDao _dao;
  final String _userPubkey;
  final Stream<bool> _appForegroundStream;

  /// Reads the current analytics consent decision, owned by `AnalyticsService`.
  ///
  /// Sampled at sweep time rather than injected as a value: consent can be
  /// withdrawn while this service is alive, and the queue outlives the switch.
  /// Null means no consent owner is wired, which only happens in tests that
  /// exercise the sweep mechanics themselves.
  final bool Function()? _isAnalyticsEnabled;

  final ViewEventRetryConfig _retryConfig;
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

    await _dao.resetPublishingToPending(_userPubkey);
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
    // These rows are identity-bearing Kind 22236 events. Consent can be
    // withdrawn after they were queued, and withdrawal deletes them — but a
    // foreground sweep can race that deletion, and rows written by a build
    // that predates the switch have never been offered a consent decision at
    // all. Publishing is the irreversible half, so it is what gets gated.
    if (_isAnalyticsEnabled?.call() == false) return;

    if (_isSweeping) return;
    _isSweeping = true;

    try {
      final retryable = await _dao.getRetryableForUser(
        userPubkey: _userPubkey,
        limit: _retryConfig.maxEventsPerSweep,
      );

      for (final row in retryable) {
        // View = playback start per spec: any watch is valid, no ≥1s gate.
        final lastAttempt = row.lastAttemptAt;
        if (lastAttempt != null) {
          final gap = _now().difference(lastAttempt);
          if (gap < _retryConfig.backoffFor(row.retryCount)) continue;
        }

        final marked = await _dao.markPublishing(row.id);
        if (!marked) continue;

        // Consent may be withdrawn while the database awaits above are in
        // flight. Check again after the final await before publication; the
        // publisher call begins synchronously, so no other event-loop turn can
        // change consent between this check and that irreversible operation.
        if (_isAnalyticsEnabled?.call() == false) return;

        try {
          final video = _toVideoEvent(row);
          // Pre-phase rows (phase IS NULL) are legacy end-of-session events
          // and replay WITHOUT a phase tag: the relay counts views on start
          // events only, so marking them 'end' would erase their view.
          final phase = switch (row.phase) {
            'start' => ViewEventPhase.start,
            'end' => ViewEventPhase.end,
            _ => null,
          };

          double? fractionalLoops;
          if (phase != ViewEventPhase.start) {
            // Derive fractional loops from watch/total already on the row
            // instead of the rounded IntColumn, so 0.75 does not become 1.0
            // and the queue vs direct paths agree.
            if (row.totalDurationMs != null && row.totalDurationMs! > 0) {
              fractionalLoops =
                  row.watchDurationMs / row.totalDurationMs!.toDouble();
            } else {
              fractionalLoops = row.loopCount?.toDouble();
            }
          }
          final success = await _viewEventPublisher.publishViewEvent(
            video: video,
            startSeconds: 0,
            endSeconds: row.watchDurationMs ~/ 1000,
            source: viewTrafficSourceFromTag(row.trafficSource),
            sourceDetail: row.sourceDetail,
            loopCount: fractionalLoops,
            phase: phase,
          );
          if (success) {
            await _dao.deleteById(row.id);
          } else if (video.addressableId == null) {
            // The publisher has now reported the missing d tag, and a queued
            // snapshot can never grow one, so a retry would only re-report.
            await _dao.deleteById(row.id);
          } else {
            await _dao.markFailed(row.id, 'publish returned false');
          }
        } on Object catch (e) {
          await _dao.markFailed(row.id, e.toString());
        }
      }
    } finally {
      _isSweeping = false;
    }
  }

  VideoEvent _toVideoEvent(PendingViewEvent row) {
    return VideoEvent(
      id: row.videoId,
      pubkey: row.videoPubkey,
      createdAt: row.createdAt.millisecondsSinceEpoch ~/ 1000,
      content: '',
      timestamp: row.createdAt,
      vineId: row.videoVineId,
      addressableDTag: row.videoAddressableDTag,
      eventKind: row.videoEventKind,
    );
  }
}
