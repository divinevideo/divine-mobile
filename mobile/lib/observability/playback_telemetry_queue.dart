// ABOUTME: Bounded memory-only delivery for opt-in playback diagnostics.
// ABOUTME: Privacy changes discard queued work and invalidate correlation.

import 'dart:async';
import 'dart:convert';

import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:openvine/services/analytics_ingest_client.dart';

class PlaybackTelemetryQueue {
  PlaybackTelemetryQueue({
    required AnalyticsIngestClient client,
    required String platform,
  }) : _client = client,
       _platform = platform {
    _events = FeedPlaybackTelemetry.events.listen(_enqueue);
    _resets = FeedPlaybackTelemetry.resets.listen((_) {
      _generation++;
      _pending.clear();
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(flush());
    });
  }

  final AnalyticsIngestClient _client;
  final String _platform;
  final _pending = <_PendingPlayback>[];
  late final StreamSubscription<Map<String, Object?>> _events;
  late final StreamSubscription<void> _resets;
  late final Timer _timer;
  bool _enabled = false;
  bool _sending = false;
  bool _disposed = false;
  int _generation = 0;

  void configure({
    required bool initializedConsent,
    required bool b2OptIn,
    bool reset = false,
  }) {
    _enabled = !_disposed && initializedConsent && b2OptIn;
    FeedPlaybackTelemetry.configure(enabled: _enabled, reset: reset);
  }

  void _enqueue(Map<String, Object?> event) {
    if (!_enabled || _disposed) return;
    if (_pending.length == 200) _pending.removeAt(0);
    _pending.add(
      _PendingPlayback(
        Map.unmodifiable({
          ...event,
          'platform': _platform,
        }),
      ),
    );
  }

  Future<void> flush() async {
    if (!_enabled || _disposed || _sending || _pending.isEmpty) return;
    final generation = _generation;
    final selected = <_PendingPlayback>[];
    for (final row in _pending) {
      final candidate = [...selected.map((r) => r.event), row.event];
      final size = utf8
          .encode(
            jsonEncode({
              'schema': 'divine.playback.batch.v1',
              'events': candidate,
            }),
          )
          .length;
      if (size > 65536 || selected.length == 50) break;
      selected.add(row);
    }
    if (selected.isEmpty) {
      _pending.removeAt(0);
      return;
    }
    _sending = true;
    try {
      for (final row in selected) {
        row.attempts++;
      }
      final result = await _client.publishPlaybackBatch(
        selected.map((row) => row.event).toList(growable: false),
      );
      if (generation != _generation) return;
      for (final row in selected) {
        if (result is! AnalyticsIngestTransientFailure || row.attempts >= 3) {
          _pending.remove(row);
        }
      }
    } catch (_) {
      // Telemetry must never affect playback, including unexpected adapters.
      if (generation == _generation) {
        _pending.removeWhere((row) => row.attempts >= 3);
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    configure(initializedConsent: false, b2OptIn: false, reset: true);
    _timer.cancel();
    await _events.cancel();
    await _resets.cancel();
  }
}

class _PendingPlayback {
  _PendingPlayback(this.event);
  final Map<String, Object?> event;
  int attempts = 0;
}
