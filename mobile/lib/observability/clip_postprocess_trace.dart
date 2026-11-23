// ABOUTME: Times the background work after each recorded take, phase by phase,
// ABOUTME: as one clip_postprocess trace that never holds up the stop.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// A step of a take's post-processing, named by the metric that holds its
/// duration.
enum ClipPostprocessPhase {
  /// Resolving the recording and copying it to a work file the native
  /// readers can open.
  copy('copy_ms'),

  /// Reading the real duration from the file.
  duration('duration_ms'),

  /// Extracting the take's thumbnail.
  thumbnail('thumbnail_ms'),

  /// Extracting the last frame the recorder overlays for the next take.
  ghostFrame('ghost_frame_ms'),

  /// Saving the enriched take to the clip library.
  librarySave('library_save_ms');

  const ClipPostprocessPhase(this.metric);

  final String metric;
}

/// One `clip_postprocess` trace per recorded take, from the stop handing the
/// take over until its background work has finished.
///
/// The phases of [ClipPostprocessPhase] run one after another while the take
/// is enriched. A take recorded with a color mask is then baked, which
/// `chroma_key_bake_ms` measures from the end of the enrichment; it includes
/// any time the bake waits while the next take records.
///
/// The trace only observes futures the stop already leaves running, so it
/// never adds a wait to the stop. It ends once: `success` (the enriched take
/// was saved), `save_failed` (the library refused it), `superseded` (the
/// session moved on or the take was removed first) or `error` (a step threw).
class ClipPostprocessTrace {
  ClipPostprocessTrace(
    PerformanceTraceMonitor monitor, {
    required this.chromaKey,
  }) : _operation = PerformanceOperation(monitor, traceName);

  static const traceName = 'clip_postprocess';

  /// Whether the take waits for a chroma-key bake after its enrichment.
  final bool chromaKey;

  final PerformanceOperation _operation;
  final Stopwatch _stopwatch = clock.stopwatch()..start();
  final Map<String, int> _phaseMetrics = {};

  ClipPostprocessPhase? _phase;
  int _phaseStartMs = 0;
  String _outcome = 'superseded';
  int? _enrichmentEndMs;
  int? _bakeEndMs;
  bool _finished = false;

  /// Ends the running phase and starts [phase].
  void startPhase(ClipPostprocessPhase phase) {
    if (_finished) return;
    _endPhase();
    _phase = phase;
    _phaseStartMs = _elapsedMs;
  }

  /// Ends the library save, recording whether the library took the enriched
  /// take.
  void librarySaved({required bool saved}) {
    if (_finished) return;
    _endPhase();
    if (_outcome == 'error') return;
    _outcome = saved ? 'success' : 'save_failed';
  }

  /// Times [enrichment], the take's metadata, thumbnail, ghost frame and
  /// library save. Completes as [enrichment] does, error included.
  Future<void> timeEnrichment(Future<void> Function() enrichment) async {
    try {
      await enrichment();
    } on Object {
      _outcome = 'error';
      rethrow;
    } finally {
      _endPhase();
      _enrichmentEndMs = _elapsedMs;
      _finishIfDone();
    }
  }

  /// Times [bake], the chroma-key bake that follows the enrichment of a take
  /// recorded with a color mask. Completes as [bake] does, error included.
  Future<void> timeChromaKeyBake(Future<void> bake) async {
    try {
      await bake;
    } on Object {
      _outcome = 'error';
      rethrow;
    } finally {
      _bakeEndMs = _elapsedMs;
      _finishIfDone();
    }
  }

  int get _elapsedMs => _stopwatch.elapsedMilliseconds;

  void _endPhase() {
    final phase = _phase;
    if (phase == null) return;
    _phase = null;
    _phaseMetrics[phase.metric] = _elapsedMs - _phaseStartMs;
  }

  void _finishIfDone() {
    final enrichmentEndMs = _enrichmentEndMs;
    final bakeEndMs = _bakeEndMs;
    if (_finished || enrichmentEndMs == null) return;
    if (chromaKey && bakeEndMs == null) return;
    _finished = true;
    _stopwatch.stop();
    final attributes = {
      'outcome': _outcome,
      'chroma_key': chromaKey ? 'yes' : 'no',
    };
    final metrics = {
      'total_ms': _elapsedMs,
      ..._phaseMetrics,
      if (bakeEndMs != null)
        'chroma_key_bake_ms': bakeEndMs > enrichmentEndMs
            ? bakeEndMs - enrichmentEndMs
            : 0,
    };
    // Builds that do not report to Firebase still show the sample here.
    Log.info(
      '$traceName $attributes $metrics',
      name: 'ClipPostprocessTrace',
      category: LogCategory.video,
    );
    _operation.finish(attributes: attributes, metrics: metrics);
  }
}
