import 'dart:async';
import 'dart:math';

import 'package:divine_video_player/divine_video_player.dart';

/// Terminal activation outcomes, independent of success-only Firebase traces.
enum FeedPlaybackOutcome {
  /// A native frame was actually rendered.
  firstFrame,

  /// Initialization, source or playback failed.
  error,

  /// The activation left the screen before a frame rendered.
  cancelled,

  /// No frame was observed within the bounded diagnostic window.
  noFrame,
}

/// Finite categories only; never export native exception text.
enum FeedPlaybackError {
  /// No error occurred.
  none,

  /// The controller or initial source could not initialize.
  initialization,

  /// Source preparation failed.
  source,

  /// An active player failed.
  playback,

  /// The diagnostic frame deadline elapsed.
  timeout,

  /// No finite category was available.
  unknown,
}

/// Ephemeral correlation for one source load, including preloaded sources.
final class FeedPlaybackLoad {
  FeedPlaybackLoad._(this.id, this._context, this._networkSupported);

  /// Random technical identifier, never derived from content or account data.
  final String id;
  final Object _context;
  final bool _networkSupported;
  String? _request;
  Map<String, Object?>? _network;

  /// Uses the first actual request only; later ranges are not an aggregate.
  void observeNetwork(Map<String, Object?> sample) {
    if (!isCurrent || sample['load_id'] != id) return;
    final outcome = sample['network_outcome'];
    if (!{'complete', 'error', 'cancelled', 'unavailable'}.contains(outcome)) {
      return;
    }
    for (final key in [
      'network_headers_ms',
      'network_duration_ms',
      'network_bytes',
    ]) {
      final value = sample[key];
      if (value != null &&
          (value is! int ||
              value < 0 ||
              value > (key == 'network_bytes' ? 1073741824 : 600000))) {
        return;
      }
    }
    if (outcome == 'complete' && sample['network_duration_ms'] == null) return;
    final request = sample['request_id'];
    if (request is! String) return;
    _request ??= request;
    if (request != _request) return;
    _network = {
      for (final key in [
        'network_headers_ms',
        'network_duration_ms',
        'network_bytes',
        'network_outcome',
      ])
        if (sample.containsKey(key)) key: sample[key],
    };
  }

  /// False after consent/cohort withdrawal or an account boundary.
  bool get isCurrent => identical(_context, FeedPlaybackTelemetry._context);
}

/// Memory-only cohort context. Disabled until the app resolves both gates.
abstract final class FeedPlaybackTelemetry {
  static Object? _context;
  static final _events = StreamController<Map<String, Object?>>.broadcast(
    sync: true,
  );
  static final _resets = StreamController<void>.broadcast(sync: true);
  static final _random = Random.secure();

  /// Operational samples contain no content, account, device or session ID.
  static Stream<Map<String, Object?>> get events => _events.stream;

  /// Clears collectors synchronously at privacy boundaries.
  static Stream<void> get resets => _resets.stream;

  /// Only initialized analytics consent plus the existing B2 opt-in enables it.
  static void configure({required bool enabled, bool reset = false}) {
    if (reset || enabled != (_context != null)) {
      _context = enabled ? Object() : null;
      _resets.add(null);
      unawaited(DivineVideoPlayerController.clearPlaybackTelemetryContext());
    }
  }

  /// Starts correlation only inside the current opt-in privacy context.
  static FeedPlaybackLoad? startLoad({bool networkSupported = false}) {
    final context = _context;
    return context == null
        ? null
        : FeedPlaybackLoad._(_uuid(), context, networkSupported);
  }

  static String _uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20),
    ].join('-');
  }

  /// Captures authorization at activation, never retroactively at completion.
  static FeedPlaybackAttempt? startAttempt() {
    final context = _context;
    return context == null ? null : FeedPlaybackAttempt._(_uuid(), context);
  }
}

/// One-shot operational half of the feed's monotonic first-frame timer.
final class FeedPlaybackAttempt {
  FeedPlaybackAttempt._(this._id, this._context);
  final String _id;
  final Object _context;
  FeedPlaybackLoad? _load;
  bool _finished = false;

  /// Associates a real source load; stale/prewarmed sources remain unmatched.
  void attachLoad(FeedPlaybackLoad? load) {
    if (_finished) return;
    _load = load != null && identical(load._context, _context) && load.isCurrent
        ? load
        : null;
  }

  /// Publishes only allowlisted, measured fields in the original context.
  void finish({
    required FeedPlaybackOutcome outcome,
    required Duration elapsed,
    required String localCache,
    required FeedPlaybackError error,
    Duration? controllerInitialized,
    Duration? sourceReady,
    Duration? playbackRequested,
  }) {
    if (_finished) return;
    _finished = true;
    if (!identical(_context, FeedPlaybackTelemetry._context)) return;
    final ms = elapsed.inMilliseconds;
    if (ms > 600000) return;
    final load = _load;
    final network = localCache == 'hit' ? null : load?._network;
    FeedPlaybackTelemetry._events.add(
      Map.unmodifiable({
        'event_id': FeedPlaybackTelemetry._uuid(),
        'attempt_id': _id,
        if (load != null && load.isCurrent) 'load_id': load.id,
        'occurred_at_ms': DateTime.now().millisecondsSinceEpoch,
        'cohort': 'b2_canary',
        'outcome': switch (outcome) {
          FeedPlaybackOutcome.firstFrame => 'first_frame',
          FeedPlaybackOutcome.noFrame => 'no_frame',
          _ => outcome.name,
        },
        'local_cache': localCache,
        'network_coverage': localCache == 'hit'
            ? 'cache'
            : network != null
            ? 'observed'
            : load == null || load._networkSupported
            ? 'unknown'
            : 'unsupported',
        'elapsed_ms': ms,
        if (outcome == FeedPlaybackOutcome.firstFrame) 'ttff_ms': ms,
        if (controllerInitialized != null)
          'controller_initialized_ms': controllerInitialized.inMilliseconds,
        if (sourceReady != null) 'source_ready_ms': sourceReady.inMilliseconds,
        if (playbackRequested != null)
          'playback_requested_ms': playbackRequested.inMilliseconds,
        'network_outcome': 'unavailable',
        ...?network,
        'error_category': error.name,
      }),
    );
  }
}
