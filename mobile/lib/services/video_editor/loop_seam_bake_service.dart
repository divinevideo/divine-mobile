// ABOUTME: Bakes a loop-seam alignment into a video's first and last clip so
// ABOUTME: the loop restart does not jump when the camera drifted.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/loop_seam_alignment.dart';
import 'package:openvine/services/video_editor/loop_seam_ramp.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// What the bake needs to know about a clip's file.
@immutable
class LoopSeamSourceInfo {
  const LoopSeamSourceInfo({
    required this.resolution,
    required this.duration,
    required this.frameRate,
    required this.hasAudio,
  });

  final Size resolution;
  final Duration duration;
  final double frameRate;
  final bool hasAudio;
}

/// Reads [LoopSeamSourceInfo] for the file at a path.
typedef LoopSeamInfoReader = Future<LoopSeamSourceInfo> Function(String path);

/// Grabs the frame at [at] from the file at [path], [size] pixels, as RGBA.
typedef LoopSeamFrameGrabber = Future<GrayFrame?> Function(
  String path,
  Duration at,
  Size size,
);

/// Renders [task] to [outputPath].
typedef LoopSeamRenderer = Future<void> Function(
  String outputPath,
  VideoRenderData task,
);

/// Result of [LoopSeamBakeService.alignClips].
@immutable
class LoopSeamBakeResult {
  const LoopSeamBakeResult({required this.clips, this.bakedPaths = const []});

  /// The clips to render: the input list with baked clips swapped in.
  final List<DivineVideoClip> clips;

  /// Files this bake wrote, for the caller to delete after the export.
  final List<String> bakedPaths;
}

/// Eases the end of a video onto its start so a loop restart does not jump.
///
/// Prototype behind `FeatureFlag.smoothLoopSeam`. It measures how the camera
/// moved between the last and first visible frame, then re-renders the first
/// and last clip with a per-frame placement that meets in the middle (see
/// [planLoopSeamPieces]). The per-frame placement needs a composition render,
/// because `SegmentTransform` is only honoured there, so the result is baked
/// into new clip files and the normal export — loop dissolve included — runs
/// on them unchanged.
///
/// Any failure leaves the clips untouched: a smoother loop is not worth a
/// failed export.
class LoopSeamBakeService {
  LoopSeamBakeService({
    LoopSeamInfoReader? readInfo,
    LoopSeamFrameGrabber? grabFrame,
    LoopSeamRenderer? render,
    Future<String> Function()? outputDirectory,
    LoopSeamLimits limits = const LoopSeamLimits(),
  }) : _readInfo = readInfo ?? _defaultReadInfo,
       _grabFrame = grabFrame ?? _defaultGrabFrame,
       _render = render ?? _defaultRender,
       _outputDirectory = outputDirectory ?? _defaultOutputDirectory,
       _limits = limits;

  static const _logName = 'LoopSeamBakeService';

  /// Long side of the frames the alignment is measured on.
  @visibleForTesting
  static const analysisLongSide = 192.0;

  static const _fallbackFrameRate = 30.0;

  final LoopSeamInfoReader _readInfo;
  final LoopSeamFrameGrabber _grabFrame;
  final LoopSeamRenderer _render;
  final Future<String> Function() _outputDirectory;
  final LoopSeamLimits _limits;

  /// Whether [clip] can take part in the bake.
  ///
  /// Reversed, re-timed and frames-based clips map source time to output time
  /// differently, and the prototype does not model that.
  @visibleForTesting
  static bool isEligible(DivineVideoClip clip) =>
      clip.video != null &&
      !clip.isStopMotion &&
      !clip.isPlaceholder &&
      !clip.reversed &&
      (clip.playbackSpeed ?? 1) == 1;

  /// Returns [clips] with the first and last clip re-rendered so the loop
  /// restart lines up, or [clips] unchanged when it cannot or need not.
  Future<LoopSeamBakeResult> alignClips(
    List<DivineVideoClip> clips, {
    required String taskId,
  }) async {
    if (clips.isEmpty) return LoopSeamBakeResult(clips: clips);
    final first = clips.first;
    final last = clips.last;
    if (!isEligible(first) || !isEligible(last)) {
      Log.info(
        'Loop seam: skipped, first or last clip is not a plain video clip',
        name: _logName,
        category: LogCategory.video,
      );
      return LoopSeamBakeResult(clips: clips);
    }

    final written = <String>[];
    try {
      // A user cancel targets the export id, which this bake does not render
      // under. Check it before the measurement and again before each encode so
      // a cancel during the first clip does not start the second.
      RenderCancellationRegistry.throwIfRequested(taskId);
      final firstPath = await first.requireVideo.safeFilePath();
      final lastPath = await last.requireVideo.safeFilePath();
      final firstInfo = await _readInfo(firstPath);
      final lastInfo = clips.length == 1
          ? firstInfo
          : await _readInfo(lastPath);
      if (firstInfo.resolution != lastInfo.resolution) {
        Log.info(
          'Loop seam: skipped, first and last clip differ in resolution',
          name: _logName,
          category: LogCategory.video,
        );
        return LoopSeamBakeResult(clips: clips);
      }

      final estimate = await _estimate(
        first: first,
        firstPath: firstPath,
        last: last,
        lastPath: lastPath,
        lastInfo: lastInfo,
      );
      if (estimate == null) return LoopSeamBakeResult(clips: clips);
      Log.info(
        'Loop seam: ${estimate.alignment}, '
        'rejection=${estimate.rejection?.name ?? 'none'}',
        name: _logName,
        category: LogCategory.video,
      );
      if (!estimate.isUsable) return LoopSeamBakeResult(clips: clips);

      final result = [...clips];
      if (clips.length == 1) {
        RenderCancellationRegistry.throwIfRequested(taskId);
        final baked = await _bakeClip(
          clip: first,
          path: firstPath,
          info: firstInfo,
          side: LoopSeamSide.both,
          alignment: estimate.alignment,
          taskId: taskId,
          renderId: VideoEditorRenderService.loopSeamRenderIdPrefix(taskId),
          written: written,
        );
        if (baked == null) return LoopSeamBakeResult(clips: clips);
        result[0] = baked;
      } else {
        RenderCancellationRegistry.throwIfRequested(taskId);
        final bakedFirst = await _bakeClip(
          clip: first,
          path: firstPath,
          info: firstInfo,
          side: LoopSeamSide.head,
          alignment: estimate.alignment,
          taskId: taskId,
          renderId:
              '${VideoEditorRenderService.loopSeamRenderIdPrefix(taskId)}-head',
          written: written,
        );
        // Without the head there is no seam to meet, so the tail is not worth
        // an encode.
        if (bakedFirst == null) return LoopSeamBakeResult(clips: clips);
        RenderCancellationRegistry.throwIfRequested(taskId);
        final bakedLast = await _bakeClip(
          clip: last,
          path: lastPath,
          info: lastInfo,
          side: LoopSeamSide.tail,
          alignment: estimate.alignment,
          taskId: taskId,
          renderId:
              '${VideoEditorRenderService.loopSeamRenderIdPrefix(taskId)}-tail',
          written: written,
        );
        if (bakedLast == null) {
          await _deleteAll(written);
          return LoopSeamBakeResult(clips: clips);
        }
        result[0] = bakedFirst;
        result[result.length - 1] = bakedLast;
      }
      return LoopSeamBakeResult(clips: result, bakedPaths: written);
    } on RenderCanceledException {
      await _deleteAll(written);
      rethrow;
    } catch (e, stackTrace) {
      Log.warning(
        'Loop seam: bake failed, exporting without it: $e\n$stackTrace',
        name: _logName,
        category: LogCategory.video,
      );
      // A failed encode stays a log line; a programming error still reaches
      // crash reporting, like the other fallback render callers (#7125).
      VideoRenderWatchdog.reportFailure(
        e,
        stackTrace,
        reportEveryFailure: false,
        reason: 'loop seam bake failed',
      );
      await _deleteAll(written);
      return LoopSeamBakeResult(clips: clips);
    }
  }

  Future<LoopSeamEstimate?> _estimate({
    required DivineVideoClip first,
    required String firstPath,
    required DivineVideoClip last,
    required String lastPath,
    required LoopSeamSourceInfo lastInfo,
  }) async {
    final size = analysisSizeFor(lastInfo.resolution);
    final frameRate = _frameRateOf(lastInfo);
    final frameUs = (Duration.microsecondsPerSecond / frameRate).round();
    final lastVisible = last.trimStart + last.trimmedDuration;
    final lastFrameAt = Duration(
      microseconds: (lastVisible.inMicroseconds - frameUs).clamp(
        0,
        lastVisible.inMicroseconds,
      ),
    );

    final firstFrame = await _grabFrame(firstPath, first.trimStart, size);
    final lastFrame = await _grabFrame(lastPath, lastFrameAt, size);
    if (firstFrame == null ||
        lastFrame == null ||
        firstFrame.width != lastFrame.width ||
        firstFrame.height != lastFrame.height) {
      Log.info(
        'Loop seam: skipped, could not read both seam frames',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    return compute(_estimateInIsolate, (lastFrame, firstFrame, _limits));
  }

  Future<DivineVideoClip?> _bakeClip({
    required DivineVideoClip clip,
    required String path,
    required LoopSeamSourceInfo info,
    required LoopSeamSide side,
    required LoopSeamAlignment alignment,
    required String taskId,
    required String renderId,
    required List<String> written,
  }) async {
    final pieces = planLoopSeamPieces(
      alignment: alignment,
      side: side,
      canvas: info.resolution,
      sourceDuration: info.duration,
      visibleStart: clip.trimStart,
      visibleEnd: clip.trimStart + clip.trimmedDuration,
      frameRate: _frameRateOf(info),
    );
    if (pieces == null) {
      Log.info(
        'Loop seam: skipped clip ${clip.id}, too short for a ramp',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final outputDirectory = await _outputDirectory();
    // A cancel that landed while the directory resolved found no encode under
    // this bake's ids to stop, so it has to be seen here, before one starts.
    RenderCancellationRegistry.throwIfRequested(taskId);
    final outputPath = p.join(
      outputDirectory,
      '${clip.id}_loopseam_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    if (p.equals(path, outputPath)) {
      throw StateError('Loop seam bake would overwrite its input ($path)');
    }
    written.add(outputPath);
    await _render(
      outputPath,
      buildTask(
        renderId: renderId,
        inputPath: path,
        info: info,
        pieces: pieces,
      ),
    );
    return clip.copyWith(video: EditorVideo.file(outputPath));
  }

  /// Builds the composition render that bakes [pieces] into one file.
  ///
  /// Every piece is the same source, drawn at its own placement. The pieces
  /// are silent and the source's audio rides along as one continuous track,
  /// so cutting the picture into single frames cannot cut the sound.
  @visibleForTesting
  static VideoRenderData buildTask({
    required String renderId,
    required String inputPath,
    required LoopSeamSourceInfo info,
    required List<LoopSeamPiece> pieces,
  }) {
    final video = EditorVideo.file(inputPath);
    return VideoRenderData(
      id: renderId,
      shouldOptimizeForNetworkUse: true,
      audioTracks: [
        if (info.hasAudio) VideoAudioTrack(path: inputPath),
      ],
      composition: VideoComposition(
        canvasSize: info.resolution,
        layers: [
          VideoLayer(
            clips: [
              for (final piece in pieces)
                VideoSegment(
                  video: video,
                  startTime: piece.start == Duration.zero ? null : piece.start,
                  endTime: piece.end,
                  volume: 0,
                  transform: switch (piece.placement) {
                    null => null,
                    final rect => SegmentTransform(
                      offset: rect.topLeft,
                      size: rect.size,
                      fit: SegmentFit.fill,
                    ),
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The analysis frame size for a source of [resolution]: the same aspect,
  /// long side [analysisLongSide], rounded to even pixels.
  @visibleForTesting
  static Size analysisSizeFor(Size resolution) {
    final scale =
        analysisLongSide /
        (resolution.width > resolution.height
            ? resolution.width
            : resolution.height);
    int even(double v) => ((v * scale) / 2).round() * 2;
    return Size(
      even(resolution.width).toDouble(),
      even(resolution.height).toDouble(),
    );
  }

  static double _frameRateOf(LoopSeamSourceInfo info) =>
      info.frameRate > 1 ? info.frameRate : _fallbackFrameRate;

  static Future<void> _deleteAll(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } on FileSystemException catch (e) {
        Log.warning(
          'Loop seam: could not delete $path: $e',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }
  }

  static Future<LoopSeamSourceInfo> _defaultReadInfo(String path) async {
    final metadata = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(path),
    );
    return LoopSeamSourceInfo(
      resolution: metadata.resolution,
      duration: metadata.duration,
      frameRate: metadata.frameRate ?? _fallbackFrameRate,
      hasAudio: (metadata.audioDuration ?? Duration.zero) > Duration.zero,
    );
  }

  static Future<GrayFrame?> _defaultGrabFrame(
    String path,
    Duration at,
    Size size,
  ) async {
    final thumbnails = await ProVideoEditor.instance.getThumbnails(
      ThumbnailConfigs(
        video: EditorVideo.file(path),
        outputSize: size,
        timestamps: [at],
        outputFormat: ThumbnailFormat.png,
      ),
    );
    if (thumbnails.isEmpty) return null;
    final decoded = img.decodePng(thumbnails.first);
    if (decoded == null) return null;
    final rgba = decoded.convert(numChannels: 4, format: img.Format.uint8);
    return GrayFrame.fromRgba(
      rgba.width,
      rgba.height,
      rgba.getBytes(order: img.ChannelOrder.rgba),
    );
  }

  static Future<void> _defaultRender(String outputPath, VideoRenderData task) =>
      VideoEditorRenderService.renderNativeVideoToFile(outputPath, task);

  static Future<String> _defaultOutputDirectory() async =>
      (await getTemporaryDirectory()).path;
}

LoopSeamEstimate _estimateInIsolate(
  (GrayFrame last, GrayFrame first, LoopSeamLimits limits) args,
) => estimateLoopSeamAlignment(
  last: args.$1,
  first: args.$2,
  limits: args.$3,
);
