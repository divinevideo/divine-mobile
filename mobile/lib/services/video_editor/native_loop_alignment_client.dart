// ABOUTME: Bridges bounded upright native decode/render to pure loop policy.
// ABOUTME: Owns cancellable workers and only operation-owned temporary files.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/services/video_editor/native_render_task_registry.dart';
import 'package:openvine/services/video_editor/pve_loop_frame_matcher.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Injectable native boundary; tests exercise real client policy without plugins.
abstract interface class LoopNativeBackend {
  Stream<LumaFrame> decode(LumaFrameConfigs config);
  Future<VideoMetadata> metadata(String path);
  Future<void> render(String path, VideoRenderData data);
  Future<void> cancel(String id);
  Future<String> outputPath(String namespace, int index);
  Future<void> delete(String path);
}

final class PveLoopNativeBackend implements LoopNativeBackend {
  const PveLoopNativeBackend();
  @override
  Stream<LumaFrame> decode(LumaFrameConfigs config) =>
      ProVideoEditor.instance.getLumaFrameStream(config);
  @override
  Future<VideoMetadata> metadata(String path) =>
      ProVideoEditor.instance.getMetadata(EditorVideo.file(path));
  @override
  Future<void> render(String path, VideoRenderData data) async {
    await VideoEditorRenderService.renderNativeVideoToFile(
      path,
      data,
      reuseActiveCancellation: true,
    );
  }

  @override
  Future<void> cancel(String id) => VideoEditorRenderService.cancelTask(id);
  @override
  Future<String> outputPath(String namespace, int index) async =>
      p.join(await getDocumentsPath(), '${namespace}_$index.mp4');
  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}

final class NativeLoopAlignmentClient implements LoopAlignmentClient {
  NativeLoopAlignmentClient({
    LoopNativeBackend backend = const PveLoopNativeBackend(),
    Duration watchdogTimeout =
        VideoEditorConstants.previewRenderWatchdogTimeout,
  }) : _backend = backend,
       _watchdogTimeout = watchdogTimeout;
  final LoopNativeBackend _backend;
  final Duration _watchdogTimeout;
  final _operations = <String, _LoopOperation>{};
  final _ownedPaths = <String>{};
  static int _serial = 0;
  _LoopOperation _operation(String id) => _operations.putIfAbsent(
    id,
    () => _LoopOperation(
      'loop_${DateTime.now().microsecondsSinceEpoch}_${_serial++}',
    ),
  );
  void _check(_LoopOperation op) {
    if (op.cancelled) throw const LoopAlignmentCancelled();
  }

  Future<T> _bounded<T>(_LoopOperation op, Future<T> future) =>
      VideoRenderWatchdog.run(
        render: Future.any([
          future,
          op.cancelSignal.future.then<T>(
            (_) => throw const LoopAlignmentCancelled(),
          ),
        ]),
        taskId: op.namespace,
        cancelTask: (_) => _cancelOperation(op),
        timeout: _watchdogTimeout,
        reason: 'loop repair timed out',
      );

  Future<List<LoopFrame>> _decode(
    _LoopOperation op,
    LoopClipInput clip,
    String path,
    String phase, {
    Duration? end,
  }) async {
    _check(op);
    final id = '${op.namespace}_${phase}_${op.child++}';
    op.children.add(id);
    final frames = <LoopFrame>[];
    try {
      await NativeRenderTaskRegistry.track(id, () async {
        await for (final frame in _backend.decode(
          LumaFrameConfigs(
            video: EditorVideo.file(path),
            outputSize: const Size(320, 320),
            startTime: clip.sourceStart,
            endTime: end ?? clip.sourceEnd,
            maxParallelDecoders: 1,
            id: id,
          ),
        )) {
          _check(op);
          if (frame.width <= 0 ||
              frame.height <= 0 ||
              math.max(frame.width, frame.height) != 320 ||
              frame.bytes.length != frame.width * frame.height ||
              frame.time < clip.sourceStart ||
              frame.time >= (end ?? clip.sourceEnd) ||
              (frames.isNotEmpty &&
                  (frame.time <= frames.last.time ||
                      frame.width != frames.first.width ||
                      frame.height != frames.first.height)) ||
              frames.length >= 2000) {
            throw const LoopAlignmentFailure(
              'Malformed or unsupported decoded frames',
            );
          }
          // PVE guarantees upright pixels. Compare against display dimensions,
          // which metadata likewise reports after its rotation correction.
          if ((frame.width / frame.height - clip.width / clip.height).abs() >
              .015) {
            throw const LoopAlignmentFailure('Unsupported decoded orientation');
          }
          frames.add(
            LoopFrame(
              time: frame.time,
              width: frame.width,
              height: frame.height,
              luma: frame.bytes,
            ),
          );
        }
      });
      _check(op);
      if (frames.length < 4) {
        throw const LoopAlignmentFailure('Insufficient decoded frames');
      }
      return frames;
    } finally {
      op.children.remove(id);
    }
  }

  @override
  Future<LoopAnalysis> analyze(
    LoopRepairInput input,
    LoopAlignmentLimits limits,
    String taskId,
    void Function(double) onProgress,
  ) async {
    final op = _operation(taskId);
    return _bounded(op, _analyze(input, limits, op, onProgress));
  }

  Future<LoopAnalysis> _analyze(
    LoopRepairInput input,
    LoopAlignmentLimits limits,
    _LoopOperation op,
    void Function(double) progress,
  ) async {
    if (input.clips.map((c) => c.clipId).toSet().length != input.clips.length) {
      throw const LoopAlignmentFailure('Duplicate clip identity');
    }
    var duration = Duration.zero;
    for (final c in input.clips) {
      if (!c.speed.isFinite ||
          c.speed <= 0 ||
          c.width <= 0 ||
          c.height <= 0 ||
          c.sourceStart < Duration.zero ||
          c.sourceEnd <= c.sourceStart) {
        throw const LoopAlignmentFailure('Invalid displayed clip window');
      }
      duration += c.visibleDuration;
    }
    if (input.clips.isEmpty || duration > const Duration(milliseconds: 6300)) {
      throw const LoopAlignmentFailure(
        'Displayed composition exceeds analysis bound',
      );
    }
    for (var i = 0; i < input.clips.length; i++) {
      final c = input.clips[i];
      final meta = await _backend.metadata(c.path);
      _check(op);
      if (meta.rotation % 90 != 0 ||
          meta.resolution.width <= 0 ||
          meta.resolution.height <= 0 ||
          c.sourceEnd > meta.duration) {
        throw const LoopAlignmentFailure('Unsupported source metadata');
      }
      op.sourceMetadata[c.clipId] = meta;
      final decoded = await _decode(op, c, c.path, 'decode');
      op.frames[c.clipId] = decoded;
      final tailStart =
          c.sourceEnd -
          Duration(
            microseconds: (limits.maximumTrim.inMicroseconds * c.speed).ceil(),
          );
      op.proofFrames[c.clipId] = {
        ...decoded.take(3),
        ...decoded.where(
          (f) => f.time >= tailStart - const Duration(milliseconds: 150),
        ),
      }.toList();
      op.frameTimes[c.clipId] = decoded.map((f) => f.time).toList();
      op.dimensions[c.clipId] = (
        width: decoded.first.width,
        height: decoded.first.height,
      );
      progress((i + 1) / input.clips.length * .5);
    }
    final receive = ReceivePort();
    final errors = ReceivePort();
    op.workerPort = receive;
    final complete = Completer<LoopAnalysis>();
    complete.future.ignore();
    final listener = receive.listen((Object? value) {
      if (value is LoopAnalysis) {
        if (!complete.isCompleted) complete.complete(value);
      } else if (!complete.isCompleted) {
        complete.completeError(LoopAlignmentFailure('$value'));
      }
    });
    final errorListener = errors.listen((Object? error) {
      if (!complete.isCompleted) {
        complete.completeError(
          LoopAlignmentFailure('Analysis worker failed: $error'),
        );
      }
    });
    op.workerCompleter = complete;
    try {
      final payload = (
        input: input,
        limits: limits,
        frames: op.frames,
        reply: receive.sendPort,
      );
      op.worker = await Isolate.spawn(
        _analyzeWorker,
        payload,
        onError: errors.sendPort,
      );
      _check(op);
      final result = await complete.future;
      _check(op);
      final match = result.endpointRegistration;
      Log.info(
        'Loop analysis: candidates=${result.candidates.length}, '
        'endpointAccepted=${match != null && limits.acceptsMatch(match, result.endpointWidth, result.endpointHeight)}, '
        'matches=${match?.consistentCount}/${match?.retainedCount}, '
        'edges=L${match?.left.agreeing}/${match?.left.retained} '
        'R${match?.right.agreeing}/${match?.right.retained} '
        'T${match?.top.agreeing}/${match?.top.retained} '
        'B${match?.bottom.agreeing}/${match?.bottom.retained}, '
        'boundaryError=${match?.boundaryModelError}, '
        'difference=${result.baselineScores.difference}, '
        'motion=${result.baselineScores.motion}',
        name: 'LoopRepair',
        category: LogCategory.video,
      );
      progress(1);
      return result;
    } finally {
      op.worker?.kill(priority: Isolate.immediate);
      op.worker = null;
      await listener.cancel();
      await errorListener.cancel();
      receive.close();
      errors.close();
      op.workerPort = null;
      op.workerCompleter = null;
      op.frames.clear();
    }
  }

  /// Native scale contains the crop once; offsets include its outer zoom.
  static VideoStabilization stabilizationFor(
    LoopClipPlan plan,
    double zoom,
    int width,
    int height,
  ) => VideoStabilization(
    zoom: zoom,
    keyframes: [
      for (final key in plan.keyframes)
        StabilizationKeyframe(
          time: key.sourceTime,
          offset: Offset(
            key.correction.tx * zoom / width,
            key.correction.ty * zoom / height,
          ),
          rotation: key.correction.angle,
          scale: key.correction.scale * zoom,
        ),
    ],
  );

  @override
  Future<LoopRenderedOutput> render(
    LoopRepairInput input,
    LoopAlignmentPlan plan,
    String taskId,
    void Function(double) onProgress,
  ) async {
    final op = _operation(taskId);
    return _bounded(op, _render(input, plan, op, onProgress));
  }

  Future<LoopRenderedOutput> _render(
    LoopRepairInput input,
    LoopAlignmentPlan plan,
    _LoopOperation op,
    void Function(double) progress,
  ) async {
    final paths = <String, String>{};
    final metadata = <String, LoopMediaMetadata>{};
    try {
      for (var i = 0; i < input.clips.length; i++) {
        _check(op);
        final clip = input.clips[i];
        final cp = plan.clips[i];
        final times = op.frameTimes[clip.clipId];
        final dimensions = op.dimensions[clip.clipId];
        if (times == null || times.isEmpty || dimensions == null) {
          throw const LoopAlignmentFailure('Analysis state missing');
        }
        if (cp.sourceEnd < clip.sourceEnd && !times.contains(cp.sourceEnd)) {
          throw const LoopAlignmentFailure(
            'Trim is not a decoded frame boundary',
          );
        }
        final path = await _backend.outputPath(op.namespace, op.child++);
        _check(op);
        if (input.clips.any((c) => p.equals(c.path, path)) ||
            _ownedPaths.contains(path)) {
          throw const LoopAlignmentFailure('Unsafe output path');
        }
        _ownedPaths.add(path);
        op.paths.add(path);
        paths[clip.clipId] = path;
        final id = '${op.namespace}_render_${op.child++}';
        op.children.add(id);
        final token = RenderCancellationRegistry.start(id);
        try {
          await NativeRenderTaskRegistry.track(
            id,
            () => _backend.render(
              path,
              VideoRenderData(
                id: id,
                videoSegments: [
                  VideoSegment(
                    video: EditorVideo.file(clip.path),
                    startTime: cp.sourceStart,
                    endTime: cp.sourceEnd,
                    stabilization: stabilizationFor(
                      cp,
                      plan.zoom,
                      dimensions.width,
                      dimensions.height,
                    ),
                  ),
                ],
              ),
            ),
          );
          _check(op);
        } finally {
          op.children.remove(id);
          RenderCancellationRegistry.finish(id, token);
          if (op.cancelled) await _backend.delete(path);
        }
        final m = await _backend.metadata(path);
        _check(op);
        metadata[clip.clipId] = LoopMediaMetadata(
          videoDuration: m.duration,
          audioDuration: m.audioDuration,
          frameTimes: const [],
          width: m.resolution.width.round(),
          height: m.resolution.height.round(),
        );
        progress((i + 1) / input.clips.length);
      }
      return LoopRenderedOutput(paths: paths, metadata: metadata);
    } catch (_) {
      for (final path in paths.values) {
        await _deleteOwned(path);
      }
      rethrow;
    }
  }

  @override
  Future<LoopInspection> inspect(
    LoopRepairInput input,
    LoopAlignmentPlan plan,
    LoopRenderedOutput output,
    String taskId,
  ) async {
    final op = _operation(taskId);
    return _bounded(op, _inspect(input, plan, output, op));
  }

  Future<LoopInspection> _inspect(
    LoopRepairInput input,
    LoopAlignmentPlan plan,
    LoopRenderedOutput output,
    _LoopOperation op,
  ) async {
    final decoded = <String, List<LoopFrame>>{};
    final progression = <_ProgressionPair>[];
    var videoDuration = Duration.zero;
    var audioDuration = Duration.zero;
    var hasAudio = false;
    var timeline = Duration.zero;
    final frameTimes = <Duration>[];
    var covered = true;
    for (var i = 0; i < input.clips.length; i++) {
      final source = input.clips[i];
      final cp = plan.clips[i];
      final path = output.paths[source.clipId];
      if (path == null) {
        throw const LoopAlignmentFailure('Missing rendered replacement');
      }
      final m = await _backend.metadata(path);
      _check(op);
      final original = op.sourceMetadata[source.clipId];
      if (original == null) {
        throw const LoopAlignmentFailure('Missing source timing');
      }
      final rawDuration = cp.sourceEnd - cp.sourceStart;
      final replacement = LoopClipInput(
        clipId: source.clipId,
        path: path,
        sourceStart: Duration.zero,
        sourceEnd: m.duration,
        speed: source.speed,
        width: m.resolution.width.round(),
        height: m.resolution.height.round(),
      );
      final frames = await _decode(op, replacement, path, 'verify');
      final expected = op.frameTimes[source.clipId]!
          .where((time) => time >= cp.sourceStart && time < cp.sourceEnd)
          .toList();
      final tolerance = expected.length > 1
          ? expected.last - expected[expected.length - 2]
          : const Duration(milliseconds: 34);
      if (frames.length != expected.length ||
          (m.duration - rawDuration).abs() > tolerance ||
          frames.first.time > tolerance) {
        covered = false;
      }
      for (var j = 0; j < math.min(frames.length, expected.length); j++) {
        if ((frames[j].time - (expected[j] - cp.sourceStart)).abs() >
            const Duration(milliseconds: 2)) {
          covered = false;
        }
      }
      for (final raw in op.proofFrames[source.clipId]!) {
        if (raw.time < cp.sourceStart || raw.time >= cp.sourceEnd) continue;
        final index = expected.indexOf(raw.time);
        if (index < 0 || index >= frames.length) {
          covered = false;
          continue;
        }
        progression.add((
          expected: raw,
          actual: frames[index],
          correction: cp.correctionAt(raw.time),
          zoom: plan.zoom,
        ));
      }
      final expectedAudio = original.audioDuration;
      final wantedAudio =
          expectedAudio == null || expectedAudio <= cp.sourceStart
          ? null
          : (expectedAudio < cp.sourceEnd ? expectedAudio : cp.sourceEnd) -
                cp.sourceStart;
      if ((wantedAudio == null) != (m.audioDuration == null)) covered = false;
      if (wantedAudio != null && m.audioDuration != null) {
        if ((m.audioDuration! - wantedAudio).abs() >
            const Duration(milliseconds: 25)) {
          covered = false;
        }
        audioDuration += Duration(
          microseconds: (m.audioDuration!.inMicroseconds / source.speed)
              .round(),
        );
        hasAudio = true;
      }
      final dimensions = op.dimensions[source.clipId]!;
      final required = const LoopAlignmentPlanner().requiredZoom(
        cp,
        dimensions.width,
        dimensions.height,
        op.frameTimes[source.clipId]!,
      );
      if (required > plan.zoom + 1e-8) covered = false;
      decoded[source.clipId] = _playbackFrames(frames, source.speed);
      for (final f in frames) {
        frameTimes.add(
          timeline +
              Duration(
                microseconds: (f.time.inMicroseconds / source.speed).round(),
              ),
        );
      }
      final length = Duration(
        microseconds: (m.duration.inMicroseconds / source.speed).round(),
      );
      timeline += length;
      videoDuration += length;
      // Output metadata is immutable. Keep decoded proof in operation state for
      // the repository's independent duration/frame-count validation.
      op.inspectedMetadata[source.clipId] = LoopMediaMetadata(
        videoDuration: m.duration,
        audioDuration: m.audioDuration,
        frameTimes: frames.map((f) => f.time).toList(),
        width: replacement.width,
        height: replacement.height,
      );
    }
    final start = decoded[input.clips.first.clipId]!;
    final end = decoded[input.clips.last.clipId]!;
    final seamInterval = Duration(
      microseconds:
          ((op
                          .inspectedMetadata[input.clips.last.clipId]!
                          .videoDuration
                          .inMicroseconds /
                      input.clips.last.speed) -
                  end.last.time.inMicroseconds)
              .round(),
    );
    final proof = await _inspectInWorker(
      op,
      start,
      end,
      seamInterval,
      progression,
    );
    _check(op);
    Log.info(
      'Loop output inspection: timingAndCoverage=$covered, '
      'registrationAndProgression=${proof.confident}, '
      'difference=${proof.scores.difference}, motion=${proof.scores.motion}',
      name: 'LoopRepair',
      category: LogCategory.video,
    );
    return LoopInspection(
      scores: proof.scores,
      frameTimes: frameTimes,
      audioDuration: hasAudio ? audioDuration : null,
      videoDuration: videoDuration,
      covered: covered && proof.confident,
      metadata: op.inspectedMetadata,
    );
  }

  Future<({LoopSeamScores scores, bool confident})> _inspectInWorker(
    _LoopOperation op,
    List<LoopFrame> start,
    List<LoopFrame> end,
    Duration seamInterval,
    List<_ProgressionPair> progression,
  ) async {
    final port = ReceivePort();
    final errors = ReceivePort();
    final complete = Completer<dynamic>();
    complete.future.ignore();
    op.workerCompleter = complete;
    final subscription = port.listen((Object? value) {
      if (!complete.isCompleted) complete.complete(value);
    });
    final errorSubscription = errors.listen((Object? value) {
      if (!complete.isCompleted) {
        complete.completeError(
          LoopAlignmentFailure('Inspection worker failed: $value'),
        );
      }
    });
    try {
      op.worker = await Isolate.spawn(_inspectionWorker, (
        start: start,
        end: end,
        seamInterval: seamInterval,
        reply: port.sendPort,
        progression: progression,
      ), onError: errors.sendPort);
      _check(op);
      final result = await complete.future;
      if (result is! ({LoopSeamScores scores, bool confident})) {
        throw LoopAlignmentFailure('Invalid inspection worker result: $result');
      }
      return result;
    } finally {
      op.worker?.kill(priority: Isolate.immediate);
      op.worker = null;
      op.workerCompleter = null;
      await subscription.cancel();
      await errorSubscription.cancel();
      port.close();
      errors.close();
    }
  }

  Future<void> _deleteOwned(String path) async {
    if (_ownedPaths.contains(path)) {
      await _backend.delete(path);
      _ownedPaths.remove(path);
    }
  }

  @override
  Future<void> discard(LoopRenderedOutput output) async {
    for (final path in output.paths.values) {
      await _deleteOwned(path);
    }
  }

  Future<void> _cancelOperation(_LoopOperation op) async {
    op.cancelled = true;
    if (!op.cancelSignal.isCompleted) op.cancelSignal.complete();
    op.worker?.kill(priority: Isolate.immediate);
    final c = op.workerCompleter;
    if (c != null && !c.isCompleted) {
      c.completeError(const LoopAlignmentCancelled());
    }
    try {
      await Future.wait([
        for (final id in op.children.toList()) _backend.cancel(id),
      ]);
    } finally {
      for (final path in op.paths.toList()) {
        await _deleteOwned(path);
      }
    }
  }

  @override
  Future<void> cancel(String taskId) async {
    final op = _operations[taskId];
    if (op != null) await _cancelOperation(op);
  }

  @override
  Future<void> finish(String taskId) async {
    final op = _operations.remove(taskId);
    op?.worker?.kill(priority: Isolate.immediate);
  }
}

final class _LoopOperation {
  _LoopOperation(this.namespace);
  final String namespace;
  bool cancelled = false;
  int child = 0;
  final children = <String>{};
  final paths = <String>{};
  final frames = <String, List<LoopFrame>>{};
  final proofFrames = <String, List<LoopFrame>>{};
  final frameTimes = <String, List<Duration>>{};
  final dimensions = <String, ({int width, int height})>{};
  final sourceMetadata = <String, VideoMetadata>{};
  final inspectedMetadata = <String, LoopMediaMetadata>{};
  Isolate? worker;
  ReceivePort? workerPort;
  Completer<dynamic>? workerCompleter;
  final cancelSignal = Completer<void>();
}

List<LoopFrame> _playbackFrames(List<LoopFrame> frames, double speed) => [
  for (final f in frames)
    LoopFrame(
      time: Duration(microseconds: (f.time.inMicroseconds / speed).round()),
      width: f.width,
      height: f.height,
      luma: f.luma,
    ),
];
typedef _WorkerInput = ({
  LoopRepairInput input,
  LoopAlignmentLimits limits,
  Map<String, List<LoopFrame>> frames,
  SendPort reply,
});
void _analyzeWorker(_WorkerInput data) {
  try {
    final input = data.input;
    final limits = data.limits;
    final first = data.frames[input.clips.first.clipId]!;
    final last = data.frames[input.clips.last.clipId]!;
    const scorer = LoopSeamScorer();
    final matcher = PveLoopFrameMatcher();
    final start = _playbackFrames(
      first.take(4).toList(),
      input.clips.first.speed,
    );
    final end = _playbackFrames(
      last.skip(math.max(0, last.length - 4)).toList(),
      input.clips.last.speed,
    );
    final seamInterval = Duration(
      microseconds:
          ((input.clips.last.sourceEnd - last.last.time).inMicroseconds /
                  input.clips.last.speed)
              .round(),
    );
    final baseline = scorer.score(start, end, seamInterval: seamInterval);
    final ordinary = scorer.motionReference(start, end);
    final candidates = <LoopAlignmentPlan>[];
    void plan(
      LoopRepairInput candidate,
      List<LoopFrame> tail,
      Duration? trimmed,
    ) {
      final p = const LoopAlignmentPlanner().plan(
        input: candidate,
        firstFrames: input.clips.length == 1 ? tail : first,
        lastFrames: tail,
        matcher: matcher,
        limits: limits,
      );
      if (p != null) {
        candidates.add(
          LoopAlignmentPlan(
            clips: p.clips,
            zoom: p.zoom,
            confidence: p.confidence,
            predictedScores: p.predictedScores,
            baselineScores: p.baselineScores,
            kind: p.kind,
            trimmedSourceEnd: trimmed,
          ),
        );
      }
    }

    plan(input, last, null);
    final lastClip = input.clips.last;
    for (var i = last.length - 1; i >= 4; i--) {
      final cut = last[i].time;
      if ((lastClip.sourceEnd - cut).inMicroseconds / lastClip.speed >
          limits.maximumTrim.inMicroseconds) {
        break;
      }
      if (cut <= lastClip.sourceStart ||
          (cut - lastClip.sourceStart).inMicroseconds / lastClip.speed <
              lastClip.minimumDuration.inMicroseconds) {
        continue;
      }
      final clip = LoopClipInput(
        clipId: lastClip.clipId,
        path: lastClip.path,
        sourceStart: lastClip.sourceStart,
        sourceEnd: cut,
        speed: lastClip.speed,
        width: lastClip.width,
        height: lastClip.height,
        minimumDuration: lastClip.minimumDuration,
      );
      final candidate = LoopRepairInput(
        clips: [...input.clips.take(input.clips.length - 1), clip],
        revision: input.revision,
        minimumCompositionDuration: input.minimumCompositionDuration,
      );
      final tail = last.take(i).toList();
      plan(candidate, tail, cut);
      final match = matcher.match(first.first, tail.last);
      if (match == null ||
          !limits.acceptsMatch(match, first.first.width, first.first.height)) {
        continue;
      }
      final scores = scorer.score(
        start,
        _playbackFrames(
          tail.skip(math.max(0, tail.length - 3)).toList(),
          lastClip.speed,
        ),
        seamInterval: Duration(
          microseconds: ((cut - tail.last.time).inMicroseconds / lastClip.speed)
              .round(),
        ),
      );
      if (limits.acceptsScores(baseline, scores)) {
        candidates.add(
          LoopAlignmentPlan(
            clips: [
              for (final c in candidate.clips)
                LoopClipPlan(
                  clipId: c.clipId,
                  sourceStart: c.sourceStart,
                  sourceEnd: c.sourceEnd,
                  keyframes: [
                    LoopKeyframe(
                      sourceTime: c.sourceStart,
                      correction: LoopPose.identity,
                    ),
                    LoopKeyframe(
                      sourceTime: c.sourceEnd,
                      correction: LoopPose.identity,
                    ),
                  ],
                ),
            ],
            zoom: 1,
            kind: LoopAlignmentKind.trimOnly,
            confidence: match,
            predictedScores: scores,
            baselineScores: baseline,
            trimmedSourceEnd: cut,
          ),
        );
      }
    }
    data.reply.send(
      LoopAnalysis(
        baselineScores: baseline,
        candidates: candidates,
        endpointRegistration: matcher.match(first.first, last.last),
        endpointWidth: first.first.width,
        endpointHeight: first.first.height,
        ordinaryMotionP95: ordinary.p95,
        ordinaryMotionSamples: input.clips.length == 1
            ? math.min(ordinary.samples, math.max(0, first.length - 2))
            : ordinary.samples,
        eligibleTrimEnds: last.map((f) => f.time).toList(),
      ),
    );
  } catch (error) {
    data.reply.send('$error');
  }
}

void _inspectionWorker(
  ({
    List<LoopFrame> start,
    List<LoopFrame> end,
    Duration seamInterval,
    SendPort reply,
    List<_ProgressionPair> progression,
  })
  data,
) {
  try {
    final registration = PveLoopFrameMatcher().match(
      data.start.first,
      data.end.last,
    );
    var confident =
        registration != null &&
        const LoopAlignmentLimits().acceptsMatch(
          registration,
          data.start.first.width,
          data.start.first.height,
        );
    for (final pair in data.progression) {
      final predicted = const LoopFrameResampler().warp(
        pair.expected,
        pair.correction,
        pair.zoom,
      );
      final actual = const LoopFrameResampler().warp(
        pair.actual,
        LoopPose.identity,
        1,
      );
      if (predicted.width != actual.width ||
          predicted.height != actual.height) {
        confident = false;
        break;
      }
      var difference = 0.0;
      for (var i = 0; i < predicted.luma.length; i++) {
        difference += (predicted.luma[i] - actual.luma[i]).abs();
      }
      if (difference / predicted.luma.length / 255 > .025) {
        confident = false;
        break;
      }
    }
    data.reply.send((
      scores: const LoopSeamScorer().score(
        data.start.take(3).toList(),
        data.end.skip(math.max(0, data.end.length - 3)).toList(),
        seamInterval: data.seamInterval,
      ),
      confident: confident,
    ));
  } catch (error) {
    data.reply.send('$error');
  }
}

typedef _ProgressionPair = ({
  LoopFrame expected,
  LoopFrame actual,
  LoopPose correction,
  double zoom,
});
