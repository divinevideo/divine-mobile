// ABOUTME: Durable retry queue for version-two product analytics events.
// ABOUTME: Separates anonymous acquisition from account-signed activity.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/services/analytics_ingest_client.dart';

class ProductEventRetryConfig {
  const ProductEventRetryConfig({
    this.batchSize = 25,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.maxRecords = 500,
    this.maxAge = const Duration(days: 7),
  });

  final int batchSize;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final int maxRecords;
  final Duration maxAge;

  Duration backoffFor(int attemptCount) {
    if (attemptCount <= 0) return initialDelay;
    var ms = initialDelay.inMilliseconds.toDouble();
    for (var i = 1; i < attemptCount; i++) {
      ms *= backoffMultiplier;
      if (ms >= maxDelay.inMilliseconds) return maxDelay;
    }
    return Duration(milliseconds: ms.round());
  }
}

class ProductEventQueue {
  ProductEventQueue({
    required PendingProductEventsDao dao,
    required AnalyticsIngestClient ingestClient,
    ProductEventRetryConfig retryConfig = const ProductEventRetryConfig(),
    DateTime Function() now = DateTime.now,
    String? Function()? currentOwnerPubkey,
    // Fail closed: a transmit gate must default to off so a construction
    // site that forgets the argument cannot send.
    bool sendingEnabled = false,
  }) : _dao = dao,
       _ingestClient = ingestClient,
       _retryConfig = retryConfig,
       _now = now,
       _currentOwnerPubkey = currentOwnerPubkey,
       _sendingEnabled = sendingEnabled;

  final PendingProductEventsDao _dao;
  final AnalyticsIngestClient _ingestClient;
  final String? Function()? _currentOwnerPubkey;
  final ProductEventRetryConfig _retryConfig;
  final DateTime Function() _now;

  bool _isFlushing = false;
  bool _sendingEnabled;

  void setSendingEnabled(bool enabled) => _sendingEnabled = enabled;

  Future<void> enqueue(
    ProductAnalyticsV2Event event, {
    String? ownerPubkey,
  }) async {
    final normalizedOwner = ownerPubkey?.trim();
    await _dao.enqueue(
      PendingProductEvent(
        id: event.envelope.eventId,
        eventName: event.eventName,
        payloadJson: jsonEncode(event.toJson()),
        status: PendingProductEventStatus.pending,
        createdAt: event.envelope.occurredAt,
        ownerPubkey: normalizedOwner == null || normalizedOwner.isEmpty
            ? null
            : normalizedOwner,
      ),
    );
    await _prune();
  }

  Future<void> clear() => _dao.deleteAll();

  Future<void> flush() async {
    if (!_sendingEnabled || _isFlushing) return;
    _isFlushing = true;
    try {
      await _flushUnlocked();
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> recoverPublishingAndFlush() async {
    if (!_sendingEnabled || _isFlushing) return;
    _isFlushing = true;
    try {
      await _dao.resetPublishingToPending();
      await _flushUnlocked();
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _flushUnlocked() async {
    await _prune();
    await _flushOwner(null);
    final currentOwner = _currentOwnerPubkey?.call();
    if (currentOwner != null && currentOwner.isNotEmpty) {
      await _flushOwner(currentOwner);
    }
  }

  Future<void> _prune() => _dao.prune(
    cutoff: _now().subtract(_retryConfig.maxAge),
    maxRecords: _retryConfig.maxRecords,
  );

  Future<void> _flushOwner(String? ownerPubkey) async {
    final rows = await _dao.getRetryable(
      now: _now(),
      limit: _retryConfig.batchSize,
      ownerPubkey: ownerPubkey,
    );
    if (rows.isEmpty) return;

    final claimed = <PendingProductEvent>[];
    for (final row in rows) {
      if (await _dao.markPublishing(row.id)) claimed.add(row);
    }
    if (claimed.isEmpty) return;

    final events = <Map<String, Object?>>[];
    final publishable = <PendingProductEvent>[];
    final oldShareIntents = <PendingProductEvent>[];
    try {
      for (final row in claimed) {
        final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
        // Before this version a share tap could be waiting offline with a
        // content ID and the signing account. Never transmit it on upgrade.
        if (payload case {
          'event_name': 'engagement_recorded',
          'properties': {'action': 'share_tapped'},
        }) {
          oldShareIntents.add(row);
        } else {
          publishable.add(row);
          events.add(payload);
        }
      }
    } catch (_) {
      for (final row in claimed) {
        await _dao.markDeadLetter(row.id, 'invalid_queued_payload');
      }
      return;
    }
    for (final row in oldShareIntents) {
      await _dao.deleteById(row.id);
    }
    if (publishable.isEmpty) return;

    final result = ownerPubkey == null
        ? await _ingestClient.publishAnonymousBatch(events)
        : await _ingestClient.publishBatch(
            events,
            subjectPubkey: ownerPubkey,
          );
    await _applyResult(publishable, result);
  }

  Future<void> _applyResult(
    List<PendingProductEvent> rows,
    AnalyticsIngestResult result,
  ) async {
    switch (result) {
      case AnalyticsIngestAccepted():
        for (final row in rows) {
          await _dao.deleteById(row.id);
        }
      case AnalyticsIngestRejected(:final reason):
        for (final row in rows) {
          await _dao.markDeadLetter(row.id, reason);
        }
      case AnalyticsIngestTransientFailure(:final reason):
        for (final row in rows) {
          await _dao.markFailed(
            row.id,
            reason,
            nextAttemptAt: _now().add(
              _retryConfig.backoffFor(row.attemptCount + 1),
            ),
          );
        }
    }
  }
}
