// ABOUTME: Times one final export of the video editor and where its time goes.
// ABOUTME: Emits one video_generation trace per render with phase and output metrics.

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:openvine/extensions/complete_parameters_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoMetadata;
import 'package:unified_logger/unified_logger.dart';

/// A step of a final render that reports how long it took.
///
/// Each one reports a metric only when it ran, so an absent metric reads as
/// "did not happen" rather than as zero. A step that runs more than once in a
/// render, such as the assembly of several stop-motion clips, reports the sum.
/// A step that threw still reports the time it ran for.
enum VideoGenerationPhase {
  /// Keying the takes recorded with the recorder's color mask whose key has
  /// not been baked yet.
  chromaBake('chroma_bake_ms'),

  /// Assembling stop-motion stills into a video the render can use.
  assembly('assembly_ms'),

  /// The render of the output video: preparing it, such as fetching the
  /// sounds, and every native pass.
  render('render_ms'),

  /// Reading the duration and resolution of the output.
  metadata('metadata_ms'),

  /// Signing the app's own recordings left unsigned at capture, then the
  /// output, with C2PA and ProofMode.
  proof('proof_ms'),

  /// Taking the cover image from the output.
  cover('cover_ms');

  const VideoGenerationPhase(this.metric);

  /// The metric this step reports its milliseconds under.
  final String metric;
}

/// How a `video_generation` trace ended, its `outcome` attribute.
enum VideoGenerationOutcome {
  /// The render produced the video the editor now holds.
  success,

  /// The render produced a video, but the edit changed while it ran, so the
  /// video was thrown away and, while Post details still waits for it, the
  /// editor renders again. The user waited for this render and got nothing
  /// from it, so it must not count as a success.
  stale,

  /// A newer render replaced this one, or it was cancelled, for example
  /// because the user left Post details.
  incomplete,

  /// The render produced no video, for the `failure_reason` it names.
  failed,

  /// The render threw something it does not classify; `failure_reason` names
  /// the error type.
  error,
}

/// Receives the steps and the output of one final render.
///
/// The render service reports through this rather than holding the trace, so
/// it stays a plain static service that runs with or without one.
abstract interface class VideoGenerationRecorder {
  /// Runs [body] and records how long it took under [phase].
  Future<T> time<T>(VideoGenerationPhase phase, Future<T> Function() body);

  /// Records the rendered video: its [duration], its size in [bytes] when it
  /// could be read, and its resolution.
  void recordOutput({
    required Duration duration,
    required int width,
    required int height,
    int? bytes,
  });
}

/// Lets the render service time and report its steps whether or not it was
/// given a recorder.
extension OptionalVideoGenerationRecorder on VideoGenerationRecorder? {
  /// Runs [body], timed as [phase] when there is a recorder.
  Future<T> timed<T>(VideoGenerationPhase phase, Future<T> Function() body) {
    final recorder = this;
    return recorder == null ? body() : recorder.time(phase, body);
  }

  /// Records the video rendered to [path], which [metadata] describes.
  ///
  /// The size is read from the file rather than from [metadata], so a call
  /// after signing counts the manifest signing added.
  Future<void> recordOutputOf(String path, VideoMetadata metadata) async {
    final recorder = this;
    if (recorder == null) return;
    int? bytes;
    try {
      bytes = await File(path).length();
    } on FileSystemException {
      // The size is telemetry only; the rest of the output still counts.
      bytes = null;
    }
    recorder.recordOutput(
      duration: metadata.duration,
      width: metadata.resolution.width.round(),
      height: metadata.resolution.height.round(),
      bytes: bytes,
    );
  }
}

/// Which editor features a render used, each reported as a 0/1 metric, plus
/// the number of layers.
///
/// Metrics rather than attributes: a trace takes at most five attributes and
/// `video_generation` already carries four.
class VideoGenerationFeatures {
  const VideoGenerationFeatures({
    required this.layerCount,
    required this.text,
    required this.filter,
    required this.adjustment,
    required this.effect,
    required this.audioTrack,
    required this.speedChange,
    required this.reverse,
    required this.chromaKey,
    required this.stopMotion,
  });

  /// Reads the features of a render of [clips] with [parameters].
  factory VideoGenerationFeatures.of({
    required List<DivineVideoClip> clips,
    required CompleteParameters? parameters,
  }) {
    final layers = parameters?.layers ?? const <Layer>[];
    return VideoGenerationFeatures(
      layerCount: layers.length,
      text: layers.any((layer) => layer is TextLayer),
      filter: parameters?.filterStates.isNotEmpty ?? false,
      adjustment: parameters?.tuneAdjustments.isNotEmpty ?? false,
      effect:
          parameters != null &&
          (parameters.videoEffectEntriesFromCompleteMeta.isNotEmpty ||
              parameters.customVideoEffectsFromCompleteMeta.isNotEmpty),
      audioTrack: parameters?.audioTracks.isNotEmpty ?? false,
      speedChange: clips.any((clip) => clip.changesSpeed),
      reverse: clips.any((clip) => clip.reversed),
      chromaKey: clips.any(
        (clip) => clip.chromaKey != null || clip.captureChromaKey != null,
      ),
      stopMotion: clips.any((clip) => clip.isStopMotion),
    );
  }

  /// How many layers the editor placed on the video.
  final int layerCount;

  /// Whether a layer is text.
  final bool text;

  /// Whether a color filter from the Filter tool is applied.
  final bool filter;

  /// Whether an Adjust setting, such as brightness, is applied.
  final bool adjustment;

  /// Whether a video effect, such as a look, an intro or an outro, is
  /// applied.
  final bool effect;

  /// Whether a sound plays under the video.
  final bool audioTrack;

  /// Whether a clip plays faster or slower than recorded.
  final bool speedChange;

  /// Whether a clip plays in reverse.
  final bool reverse;

  /// Whether a clip is keyed, or still waits for its recorded key.
  final bool chromaKey;

  /// Whether a clip is made of stop-motion stills.
  final bool stopMotion;

  /// The features as trace metrics.
  Map<String, int> get metrics => {
    'layer_count': layerCount,
    'has_text': _flag(text),
    'has_filter': _flag(filter),
    'has_adjustment': _flag(adjustment),
    'has_effect': _flag(effect),
    'has_audio_track': _flag(audioTrack),
    'has_speed_change': _flag(speedChange),
    'has_reverse': _flag(reverse),
    'has_chroma_key': _flag(chromaKey),
    'has_stop_motion': _flag(stopMotion),
  };

  static int _flag(bool value) => value ? 1 : 0;
}

/// One `video_generation` trace: a final render of the editor's clips, from
/// the moment it starts until its outcome is known and the result is saved.
///
/// Besides the duration, the trace says where the time went
/// ([VideoGenerationPhase]), what came out (`output_*`), and which features
/// the render used ([VideoGenerationFeatures]), so a slow export can be
/// attributed to the encoder, the signing, or a feature.
///
/// Attributes are a fixed vocabulary: `outcome` ([VideoGenerationOutcome]),
/// `failure_reason`, `clip_count` and `aspect_ratio`. [finish] reports the
/// trace once; anything recorded after it is dropped.
class VideoGenerationTrace implements VideoGenerationRecorder {
  VideoGenerationTrace(
    PerformanceTraceMonitor monitor, {
    required int clipCount,
    required String? aspectRatio,
  }) : _clipCount = clipCount,
       _aspectRatio = aspectRatio,
       _operation = PerformanceOperation(monitor, traceName);

  static const traceName = 'video_generation';

  final int _clipCount;
  final String? _aspectRatio;
  final PerformanceOperation _operation;
  final Map<VideoGenerationPhase, int> _phaseMs = {};
  final Map<String, int> _outputMetrics = {};
  Map<String, int> _featureMetrics = const {};
  VideoGenerationOutcome? _outcome;
  String? _failureReason;
  bool _finished = false;

  @override
  Future<T> time<T>(
    VideoGenerationPhase phase,
    Future<T> Function() body,
  ) async {
    final stopwatch = clock.stopwatch()..start();
    try {
      return await body();
    } finally {
      stopwatch.stop();
      if (!_finished) {
        _phaseMs[phase] =
            (_phaseMs[phase] ?? 0) + stopwatch.elapsedMilliseconds;
      }
    }
  }

  @override
  void recordOutput({
    required Duration duration,
    required int width,
    required int height,
    int? bytes,
  }) {
    if (_finished) return;
    _outputMetrics
      ..clear()
      ..addAll({
        'output_duration_ms': duration.inMilliseconds,
        'output_width': width,
        'output_height': height,
        'output_bytes': ?bytes,
      });
  }

  /// Records which features the render uses, as [read] returns them.
  ///
  /// A [read] that throws leaves the features out: telemetry must not fail
  /// the render it measures.
  void recordFeatures(VideoGenerationFeatures Function() read) {
    if (_finished) return;
    try {
      _featureMetrics = read().metrics;
    } on Object catch (e) {
      Log.warning(
        'Could not read the features of the render: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// Sets the outcome [finish] reports, with the [failureReason] behind it
  /// when there is one. A later call replaces the outcome, and the reason
  /// only when it gives one.
  void tagOutcome(VideoGenerationOutcome outcome, {String? failureReason}) {
    if (_finished) return;
    _outcome = outcome;
    if (failureReason != null) _failureReason = failureReason;
  }

  /// Reports the trace. Only the first call counts.
  void finish() {
    if (_finished) return;
    _finished = true;
    final attributes = {
      'outcome': ?_outcome?.name,
      'failure_reason': ?_failureReason,
      'clip_count': '$_clipCount',
      'aspect_ratio': ?_aspectRatio,
    };
    final metrics = {
      for (final phase in VideoGenerationPhase.values)
        phase.metric: ?_phaseMs[phase],
      ..._outputMetrics,
      ..._featureMetrics,
    };
    // Builds that do not report to Firebase still show the sample here.
    Log.info(
      '$traceName $attributes $metrics',
      name: _logName,
      category: LogCategory.video,
    );
    _operation.finish(attributes: attributes, metrics: metrics);
  }

  static const _logName = 'VideoGenerationTrace';
}
