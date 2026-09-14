// ABOUTME: Correlates native playback resources with memory and app lifecycle.
// ABOUTME: Bounds channel work and reports persistent disposal invariants once.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:divine_video_player/divine_video_player.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/memory_telemetry_service.dart';

/// A disposed native player still owns playback resources after the grace time.
/// Contains no player IDs, media URLs, or user information.
class PlaybackResourceInvariantException implements Exception {
  @override
  String toString() =>
      'PlaybackResourceInvariantException: '
      'disposed native players still own playback resources';
}

/// Adds Apple-native observations to the existing memory sampling cadence.
///
/// Owns no periodic timer. The caller samples at startup, lifecycle changes,
/// memory pressure, and on the existing memory tick. A hung native read cannot
/// accumulate more requests. A lifecycle transition invalidates an older read.
/// High footprint alone is NOT evidence of a leak and never raises an error.
class PlaybackMemoryTelemetryService {
  PlaybackMemoryTelemetryService({
    required Future<NativePlaybackDiagnostics?> Function() readNative,
    required CrashReporter reporter,
    required void Function(String) log,
    required bool Function() isForeground,
    required Duration Function() elapsed,
    String initialLifecycle = 'unknown',
  }) : _readNative = readNative,
       _reporter = reporter,
       _log = log,
       _isForeground = isForeground,
       _elapsed = elapsed,
       _lifecycle = initialLifecycle,
       _lifecycleSince = elapsed();

  final Future<NativePlaybackDiagnostics?> Function() _readNative;
  final CrashReporter _reporter;
  final void Function(String) _log;
  final bool Function() _isForeground;
  final Duration Function() _elapsed;
  String _lifecycle;
  Duration _lifecycleSince;
  int _generation = 0;
  int _peakFootprint = MemorySnapshot.unavailableGauge;
  int? _lastFrames;
  Duration? _lastSampleTime;
  Duration? _disposedPlayersSince;
  bool _reportedDisposedPlayers = false;
  bool _disposed = false;
  bool _sampling = false;
  bool _nativeReadPending = false;

  /// Records a transition immediately; no native round trip is needed.
  void onLifecycleChanged(String state) {
    if (_disposed || state == _lifecycle) return;
    _lifecycle = state;
    _lifecycleSince = _elapsed();
    _generation++;
    _lastFrames = null;
    _lastSampleTime = null;
    final message =
        'Memory lifecycle: $state, '
        'observer_age_s=${_elapsed().inSeconds}';
    _log(message);
    try {
      _reporter.log(message);
    } on Object catch (_) {
      // Breadcrumb failure must not interfere with lifecycle cleanup.
    }
  }

  /// Samples at most one native request at a time. Failure stays local.
  Future<void> sample(
    MemorySnapshot memory, {
    int pressureEvents = 0,
    String trigger = 'periodic',
  }) async {
    if (_disposed || _sampling || _nativeReadPending) return;
    _sampling = true;
    final generation = _generation;
    try {
      NativePlaybackDiagnostics? native;
      var status = 'ok';
      _nativeReadPending = true;
      final read = Future<NativePlaybackDiagnostics?>.sync(_readNative);
      // A timeout only stops waiting, not the native call. Hold the gate until
      // that original call settles, even after emitting its unavailable sample.
      unawaited(
        read.then<void>(
          (_) => _nativeReadPending = false,
          onError: (Object _, StackTrace _) => _nativeReadPending = false,
        ),
      );
      try {
        native = await read.timeout(const Duration(seconds: 2));
        if (native == null) status = 'unavailable';
      } on TimeoutException {
        status = 'timeout';
      } on Object catch (_) {
        status = 'failed';
      }
      if (_disposed || generation != _generation) return;

      final now = _elapsed();
      final footprint =
          native?.footprintBytes ?? MemorySnapshot.unavailableGauge;
      _peakFootprint = math.max(_peakFootprint, footprint);
      final nativeValues = <String, Object>{
        'status': status,
        ...?native?.toMap(),
      };
      final lifecycleValues = <String, Object>{
        'flutter': _lifecycle,
        'foregroundGate': _isForeground(),
        'stateAgeS': (now - _lifecycleSince).inSeconds,
        'observerAgeS': now.inSeconds,
        'trigger': trigger,
        'pressureEvents': pressureEvents,
        if (native != null &&
            _lastFrames != null &&
            _lastSampleTime != null) ...{
          'framesSinceSample': math.max(
            0,
            native.framesDelivered - _lastFrames!,
          ),
          'sampleIntervalMs': (now - _lastSampleTime!).inMilliseconds,
        },
      };
      _lastFrames = native?.framesDelivered;
      _lastSampleTime = native == null ? null : now;
      final nativeJson = jsonEncode(nativeValues);
      final lifecycleJson = jsonEncode(lifecycleValues);
      _log(
        'Memory native: $nativeJson, lifecycle: $lifecycleJson, '
        'dart: ${jsonEncode({'rssBytes': memory.rssBytes, 'peakRssBytes': memory.peakRssBytes, 'controllers': memory.nativeControllers, 'imageCacheBytes': memory.imageCacheBytes, 'ingestQueue': memory.queueDepth})}',
      );

      // The disposed-player grace period tracks native diagnostics only; a
      // reporter failure below must never reset it.
      if (native == null ||
          native.disposedPlayers == 0 ||
          native.pendingLoads > 0) {
        _disposedPlayersSince = null;
      } else {
        _disposedPlayersSince ??= now;
      }

      try {
        // Four fixed keys, not a key per gauge: Crashlytics has a 64-key
        // budget. Both JSON values stay below 1 KB and contain only
        // allow-listed scalars.
        await _reporter.setCustomKey('mem_native', nativeJson);
        if (_disposed || generation != _generation) return;
        await _reporter.setCustomKey('mem_lifecycle', lifecycleJson);
        if (_disposed || generation != _generation) return;
        await _reporter.setCustomKey('mem_footprint_mb', _mb(footprint));
        if (_disposed || generation != _generation) return;
        await _reporter.setCustomKey(
          'mem_footprint_sampled_peak_mb',
          _mb(_peakFootprint),
        );
        if (_disposed || generation != _generation) return;
        if (trigger != 'periodic') {
          _reporter.log('Memory $trigger: $nativeJson $lifecycleJson');
        }

        if (_disposedPlayersSince != null &&
            !_reportedDisposedPlayers &&
            now - _disposedPlayersSince! >= const Duration(seconds: 30)) {
          // One non-fatal per observer lifetime. Never per player or tick.
          await _reporter.recordError(
            PlaybackResourceInvariantException(),
            StackTrace.current,
            reason: 'native_player_resources_after_dispose',
          );
          _reportedDisposedPlayers = true;
        }
      } on Object catch (_) {
        // Reporter transport failures stay local and must not mask the
        // native-diagnostics-derived leak signal above.
        _log('Memory native: reporting unavailable');
      }
    } on Object catch (_) {
      // Reached only if native diagnostics could not even be processed.
      _disposedPlayersSince = null;
      _log('Memory native: reporting unavailable');
    } finally {
      _sampling = false;
    }
  }

  static String _mb(int bytes) => bytes == MemorySnapshot.unavailableGauge
      ? 'unavailable'
      : (bytes / (1024 * 1024)).toStringAsFixed(1);

  /// Prevents late asynchronous completions from touching the disposed caller.
  void dispose() => _disposed = true;
}
