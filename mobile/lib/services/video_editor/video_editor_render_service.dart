// ABOUTME: Service for rendering final videos from multiple clips
// ABOUTME: Handles aspect ratio cropping, clip concatenation, and export transformation

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/extensions/complete_parameters_extensions.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/clip_normalization_models.dart';
import 'package:openvine/services/video_editor/native_render_task_registry.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_audio_render.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/services/video_editor/video_render_failures.dart';

class _RenderProgressTracker {
  _RenderProgressTracker({
    required this.taskId,
    required int clipCount,
    bool hasAssemblyPhase = false,
  }) : _proofBudget =
           VideoEditorRenderService.proofModeProgressBudgetForClipCount(
             clipCount,
           ),
       _proofSteps = clipCount + 1,
       _hasAssemblyPhase = hasAssemblyPhase;

  /// Share of the non-proof budget reserved for the stop-motion assembly
  /// pass. Assembly (stills → base mp4) and the composite render are both
  /// full encode passes over the same output duration, so they get equal
  /// halves.
  static const double _assemblyShare = 0.5;

  final String taskId;
  final double _proofBudget;
  final int _proofSteps;
  final bool _hasAssemblyPhase;
  StreamSubscription<ProgressModel>? _renderSubscription;
  StreamSubscription<ProgressModel>? _assemblySubscription;
  double _lastProgress = 0;

  double get _assemblyBudget =>
      _hasAssemblyPhase ? (1 - _proofBudget) * _assemblyShare : 0;
  double get _renderBudget => 1 - _proofBudget - _assemblyBudget;

  void start() {
    // Emit an explicit reset so a reused broadcast stream does not keep showing
    // the completed progress of a previous render.
    _lastProgress = 0;
    VideoEditorRenderService._emitCompositeProgress(
      taskId: taskId,
      progress: 0,
    );
    _renderSubscription = ProVideoEditor.instance
        .progressStreamById(taskId)
        .listen((progressModel) {
          _emit(_assemblyBudget + progressModel.progress * _renderBudget);
        });
  }

  /// Routes the native progress of the stop-motion assembly running under
  /// [assemblyTaskId] (step [step] of [stepCount]) into the assembly slice
  /// of the composite progress.
  void startAssemblyStep({
    required String assemblyTaskId,
    required int step,
    required int stepCount,
  }) {
    _assemblySubscription?.cancel();
    _assemblySubscription = ProVideoEditor.instance
        .progressStreamById(assemblyTaskId)
        .listen((progressModel) {
          _emit(_assemblyBudget * (step + progressModel.progress) / stepCount);
        });
  }

  Future<void> markAssemblyComplete() async {
    // Stop listening so late assembly events cannot regress the composite
    // progress during the render phase.
    await _assemblySubscription?.cancel();
    _assemblySubscription = null;
    _emit(_assemblyBudget);
  }

  Future<void> markRenderComplete() async {
    // Stop listening to render progress so late events from the render stream
    // cannot regress the composite progress during the proof phase.
    await _renderSubscription?.cancel();
    _renderSubscription = null;
    _emit(1 - _proofBudget);
  }

  void markProofStepComplete(int completedSteps) {
    final normalizedSteps = completedSteps.clamp(0, _proofSteps);
    _emit(1 - _proofBudget + (_proofBudget * normalizedSteps / _proofSteps));
  }

  Future<void> dispose() async {
    await _renderSubscription?.cancel();
    _renderSubscription = null;
    await _assemblySubscription?.cancel();
    _assemblySubscription = null;
  }

  /// Emits a monotonically increasing composite progress value, guarding
  /// against backwards jumps caused by out-of-order stream events.
  void _emit(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= _lastProgress) return;
    _lastProgress = clamped;
    VideoEditorRenderService._emitCompositeProgress(
      taskId: taskId,
      progress: clamped,
    );
  }
}

/// Service for rendering final video from multiple clips.
///
/// Handles video rendering with aspect ratio cropping and clip concatenation.
class VideoEditorRenderService {
  VideoEditorRenderService._();
  static CrashReporter crashReporter = const SilentCrashReporter();

  static const _logName = 'VideoEditorRenderService';

  static final _compositeProgressController =
      StreamController<ProgressModel>.broadcast();

  @visibleForTesting
  static double proofModeProgressBudgetForClipCount(int clipCount) {
    final normalizedClipCount = clipCount < 1 ? 1 : clipCount;
    return (normalizedClipCount * 0.01).clamp(0.05, 0.10);
  }

  static Stream<ProgressModel> compositeProgressStreamById(String taskId) {
    return _compositeProgressController.stream.where(
      (progress) => progress.id == taskId,
    );
  }

  static void _emitCompositeProgress({
    required String taskId,
    required double progress,
  }) {
    _compositeProgressController.add(
      ProgressModel(id: taskId, progress: progress.clamp(0.0, 1.0)),
    );
  }

  @visibleForTesting
  static Set<String> get activeNativeTaskIdsForTesting =>
      NativeRenderTaskRegistry.activeTaskIds;

  @visibleForTesting
  static void resetActiveNativeTaskIdsForTesting() {
    NativeRenderTaskRegistry.reset();
    RenderCancellationRegistry.reset();
  }

  @visibleForTesting
  static bool isTaskCancellationRequestedForTesting(String taskId) =>
      RenderCancellationRegistry.isCancellationRequested(taskId);

  @visibleForTesting
  static void emitCompositeProgressForTesting({
    required String taskId,
    required double progress,
  }) {
    _emitCompositeProgress(taskId: taskId, progress: progress);
  }

  /// Test-only override for [renderVideoToClip].
  ///
  /// When set, [renderVideoToClip] delegates to this callback instead of
  /// running the real render pipeline. Reset to `null` in `tearDown`.
  @visibleForTesting
  static Future<(DivineVideoClip, String? proofManifestJson)> Function({
    required List<DivineVideoClip> clips,
    required Map<String, dynamic> editorStateHistory,
    CompleteParameters? parameters,
    String? taskId,
  })?
  renderVideoToClipOverride;

  /// Test-only override for [renderVideo].
  ///
  /// When set, [renderVideo] delegates to this callback instead of running the
  /// real render pipeline. Reset to `null` in `tearDown`.
  @visibleForTesting
  static Future<String?> Function({
    required List<DivineVideoClip> clips,
    required bool usePersistentStorage,
    model.AspectRatio? aspectRatio,
    CompleteParameters? parameters,
    String? taskId,
    Duration? maxOutputDuration,
  })?
  renderVideoOverride;

  /// Test-only override for [limitClipDuration].
  ///
  /// When set, [limitClipDuration] delegates to this callback instead of
  /// running the real render pipeline. Reset to `null` in `tearDown`.
  @visibleForTesting
  static Future<void> Function({
    required DivineVideoClip clip,
    required Duration duration,
    required ValueChanged<bool> onComplete,
  })?
  limitClipDurationOverride;

  @visibleForTesting
  static void Function(Object error, StackTrace stackTrace)?
  get crashReporterOverride => VideoRenderWatchdog.crashReporterOverride;

  @visibleForTesting
  static set crashReporterOverride(
    void Function(Object error, StackTrace stackTrace)? value,
  ) => VideoRenderWatchdog.crashReporterOverride = value;

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Renders multiple clips into a [DivineVideoClip] ready for publishing.
  ///
  /// This is a convenience wrapper around [renderVideo] that also extracts
  /// metadata, generates ProofMode attestation, and creates a [DivineVideoClip].
  ///
  /// Returns a record containing:
  /// - The rendered [DivineVideoClip]
  /// - The proofManifestJson (or null if ProofMode unavailable)
  ///
  /// Throws:
  ///
  /// * [VideoRenderFailedException] if the render produced no video — the
  ///   reason distinguishes an empty clip list, a failed stop-motion assembly,
  ///   a native render failure, a cancellation, and a timed-out export.
  static Future<(DivineVideoClip, String? proofManifestJson)>
  renderVideoToClip({
    required List<DivineVideoClip> clips,
    required Map<String, dynamic> editorStateHistory,
    CompleteParameters? parameters,
    String? taskId,
  }) {
    final render = _renderVideoToClip(
      clips: clips,
      editorStateHistory: editorStateHistory,
      parameters: parameters,
      taskId: taskId,
    );
    final effectiveTaskId = taskId ?? (clips.isEmpty ? null : clips.first.id);

    // Bound the shared final-export operation rather than either caller: a
    // suspended native call otherwise reaches neither the editor retry overlay
    // nor the draft-publish error message (#8488).
    return VideoRenderWatchdog.run(
      render: render,
      taskId: effectiveTaskId,
      cancelTask: cancelTask,
    );
  }

  static Future<(DivineVideoClip, String? proofManifestJson)>
  _renderVideoToClip({
    required List<DivineVideoClip> clips,
    required Map<String, dynamic> editorStateHistory,
    CompleteParameters? parameters,
    String? taskId,
  }) async {
    if (renderVideoToClipOverride != null) {
      return renderVideoToClipOverride!(
        clips: clips,
        editorStateHistory: editorStateHistory,
        parameters: parameters,
        taskId: taskId,
      );
    }

    if (clips.isEmpty) {
      throw const VideoRenderFailedException(
        VideoRenderFailureReason.emptyClips,
      );
    }

    final effectiveTaskId = taskId ?? clips.first.id;
    final renderToken = RenderCancellationRegistry.start(effectiveTaskId);
    // Frames-only stop-motion clips need an assembly pass (stills → base mp4)
    // before the composite render. That pass gets its own slice of the
    // progress budget — without it the bar sits at 0% for the whole (slow)
    // assembly and then jumps once the (fast) composite render starts.
    final assemblyStepCount = clips
        .where((clip) => clip.video == null && clip.isStopMotion)
        .length;
    final progressTracker = _RenderProgressTracker(
      taskId: effectiveTaskId,
      clipCount: clips.length,
      hasAssemblyPhase: assemblyStepCount > 0,
    )..start();

    // Base mp4s assembled from stop-motion stills for this render only. They
    // are muxed into the composite output below, then deleted in `finally` so
    // they don't accumulate in the documents directory (each is a full extra
    // video per export).
    final intermediateStopMotionPaths = <String>[];

    try {
      final renderClips = <DivineVideoClip>[];
      var assemblyStep = 0;
      for (final clip in clips) {
        if (clip.video == null && clip.isStopMotion) {
          final assemblyTaskId = '$effectiveTaskId-stop-motion-$assemblyStep';
          progressTracker.startAssemblyStep(
            assemblyTaskId: assemblyTaskId,
            step: assemblyStep,
            stepCount: assemblyStepCount,
          );
          assemblyStep++;
          final DivineVideoClip materialized;
          try {
            final assembled = await StopMotionRenderService.materialize(
              clip,
              taskId: assemblyTaskId,
            );
            if (assembled == null) {
              throw const VideoRenderFailedException(
                VideoRenderFailureReason.stopMotionAssembly,
              );
            }
            materialized = assembled;
          } on RenderCanceledException catch (e) {
            // Detach / cancelActiveNativeTasks during assembly must not land
            // in the stop_motion_assembly bucket — same incomplete semantics
            // as a cancelled composite render.
            throw VideoRenderFailedException(
              VideoRenderFailureReason.canceled,
              cause: e,
            );
          }
          final intermediatePath = materialized.video?.file?.path;
          if (intermediatePath != null) {
            intermediateStopMotionPaths.add(intermediatePath);
          }
          renderClips.add(materialized);
        } else {
          renderClips.add(clip);
        }
      }
      await progressTracker.markAssemblyComplete();

      Log.debug(
        '🎬 renderVideoToClip: clips=${renderClips.length}, '
        'parameters=${parameters?.toLogString()}',
        name: _logName,
        category: LogCategory.video,
      );

      final outputPath = await _renderVideoOrThrow(
        clips: renderClips,
        aspectRatio: renderClips.first.targetAspectRatio,
        usePersistentStorage: true,
        parameters: parameters,
        taskId: effectiveTaskId,
        reportEveryFailure: true,
      );

      await progressTracker.markRenderComplete();

      final metaData = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(outputPath),
      );

      // Generate ProofMode attestation
      Log.debug(
        '🔐 Generating proofmode attestation for video',
        name: _logName,
        category: LogCategory.video,
      );

      // Ensure all clips have proof attestations before generating the
      // final combined proof. Clips recorded before the feature was added
      // or where proof generation failed will be attested now.
      var completedProofSteps = 0;
      final attestedClips = await _ensureClipProofs(
        renderClips,
        onClipProcessed: () {
          completedProofSteps++;
          progressTracker.markProofStepComplete(completedProofSteps);
        },
      );

      final proofData = await NativeProofModeService.proofFile(
        File(outputPath),
        clips: attestedClips,
        editorStateHistory: editorStateHistory,
      );
      progressTracker.markProofStepComplete(completedProofSteps + 1);
      final String? proofManifestJson = proofData != null
          ? jsonEncode(proofData)
          : null;

      if (proofManifestJson != null) {
        Log.info(
          '✅ Proofmode attestation generated',
          name: _logName,
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          '⚠️ No proofmode data available',
          name: _logName,
          category: LogCategory.video,
        );
      }

      // The cover must come from the rendered file, not from the first source
      // clip: the render trims, re-times, crops and filters, so an inherited
      // frame has no matching position in the output. That mismatch is visible
      // in the cover picker, which opens the preview at the clip's
      // thumbnailTimestamp and would land on a different frame than the cover
      // it just showed. Falling back to the source thumbnail keeps a render
      // whose extraction failed from losing its preview entirely.
      final cover = await VideoThumbnailService.extractThumbnail(
        videoPath: outputPath,
      );

      final clip = DivineVideoClip(
        id: 'clip-${DateTime.now().millisecondsSinceEpoch}',
        video: EditorVideo.file(outputPath),
        duration: metaData.duration,
        recordedAt: DateTime.now(),
        originalAspectRatio: renderClips.first.originalAspectRatio,
        targetAspectRatio: renderClips.first.targetAspectRatio,
        thumbnailPath: cover?.path ?? renderClips.first.thumbnailPath,
        thumbnailTimestamp: cover?.timestamp,
      );

      return (clip, proofManifestJson);
    } finally {
      RenderCancellationRegistry.finish(effectiveTaskId, renderToken);
      await progressTracker.dispose();
      await _cleanupTempFiles(intermediateStopMotionPaths);
    }
  }

  /// Re-runs ProofMode / C2PA signing on an already-rendered clip's file,
  /// without re-encoding the video.
  ///
  /// Used when the render succeeded but the C2PA content credential could not
  /// be attached (e.g. offline) — re-attaching provenance must not pay the cost
  /// of a full re-render (#6058). Returns the refreshed proofManifestJson, or
  /// null when no proof is available.
  static Future<String?> reproofRenderedClip({
    required DivineVideoClip clip,
    required List<DivineVideoClip> clips,
    required Map<String, dynamic> editorStateHistory,
  }) async {
    final path = clip.video?.file?.path;
    if (path == null) return null;

    final attestedClips = await _ensureClipProofs(clips);
    final proofData = await NativeProofModeService.proofFile(
      File(path),
      clips: attestedClips,
      editorStateHistory: editorStateHistory,
    );
    return proofData != null ? jsonEncode(proofData) : null;
  }

  /// Ensures every clip has a [proofManifestJson].
  ///
  /// Clips that already have proof data are returned as-is. For clips without
  /// proof, [NativeProofModeService.proofFile] is called on the clip's video
  /// file and the clip is updated with the result.
  static Future<List<DivineVideoClip>> _ensureClipProofs(
    List<DivineVideoClip> clips, {
    VoidCallback? onClipProcessed,
  }) async {
    final result = <DivineVideoClip>[];
    for (final clip in clips) {
      if (clip.proofManifestJson != null) {
        result.add(clip);
        onClipProcessed?.call();
        continue;
      }

      final videoFile = clip.video?.file;
      if (videoFile == null) {
        result.add(clip);
        onClipProcessed?.call();
        continue;
      }

      Log.debug(
        '🔐 Generating missing proof for clip ${clip.id}',
        name: _logName,
        category: LogCategory.video,
      );

      final proofData = await NativeProofModeService.proofFile(
        File(videoFile.path),
      );

      if (proofData != null) {
        result.add(clip.copyWith(proofManifestJson: jsonEncode(proofData)));
        Log.info(
          '✅ Backfilled proof for clip ${clip.id}',
          name: _logName,
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          '⚠️ Could not generate proof for clip ${clip.id}',
          name: _logName,
          category: LogCategory.video,
        );
        result.add(clip);
      }
      onClipProcessed?.call();
    }
    return result;
  }

  /// Renders multiple clips into a single video file with aspect ratio cropping.
  ///
  /// When [customAudioPath] is provided, the custom audio track is mixed into
  /// the output.
  ///
  /// When [imageBytes] is provided (PNG with transparency), it is composited
  /// on top of the video as a watermark overlay.
  ///
  /// Returns the path to the rendered video file, or null if cancelled/failed.
  ///
  /// If [usePersistentStorage] is true, the output file will be saved to the
  /// documents directory instead of the temporary directory. Use this when
  /// the rendered video should persist across app restarts.
  ///
  /// [maxOutputDuration] caps the rendered output length. It defaults to
  /// [VideoEditorConstants.maxDuration] for the final-export path; pass `null`
  /// to render the full concatenation uncapped (e.g. when merging clips into an
  /// intermediate editor clip that the user can still trim).
  ///
  /// Every failure — a cancellation included — collapses to `null` here, so
  /// callers cannot tell them apart, and only a programming-invariant
  /// violation (an `Error` subtype) is reported to Crashlytics. The
  /// final-export path ([renderVideoToClip]) instead surfaces a
  /// [VideoRenderFailedException] naming the reason, and reports every
  /// failure.
  static Future<String?> renderVideo({
    required List<DivineVideoClip> clips,
    bool usePersistentStorage = false,
    model.AspectRatio? aspectRatio,
    CompleteParameters? parameters,
    String? taskId,
    Duration? maxOutputDuration = VideoEditorConstants.maxDuration,
  }) async {
    try {
      return await _renderVideoOrThrow(
        clips: clips,
        usePersistentStorage: usePersistentStorage,
        aspectRatio: aspectRatio,
        parameters: parameters,
        taskId: taskId,
        maxOutputDuration: maxOutputDuration,
      );
    } on VideoRenderFailedException {
      return null;
    }
  }

  /// [renderVideo], but throws [VideoRenderFailedException] instead of
  /// returning null so the caller can report why the render produced nothing.
  ///
  /// [reportEveryFailure] widens Crashlytics reporting from `Error` subtypes to
  /// every failure. Only the final export ([renderVideoToClip]) passes it —
  /// see [_reportRenderFailure].
  static Future<String> _renderVideoOrThrow({
    required List<DivineVideoClip> clips,
    bool usePersistentStorage = false,
    model.AspectRatio? aspectRatio,
    CompleteParameters? parameters,
    String? taskId,
    Duration? maxOutputDuration = VideoEditorConstants.maxDuration,
    bool reportEveryFailure = false,
  }) async {
    final tempFilePaths = <String>[];
    // Tracked so a cancel or a failed final encoder attempt mid-concatenation
    // can delete the partial output. _concatenateSegments only returns the path
    // on success, so without this the file it wrote (in the documents directory
    // for a persistent export) is orphaned. #8818.
    String? finalOutputPath;

    try {
      final override = renderVideoOverride;
      if (override != null) {
        final overridden = await override(
          clips: clips,
          usePersistentStorage: usePersistentStorage,
          aspectRatio: aspectRatio,
          parameters: parameters,
          taskId: taskId,
          maxOutputDuration: maxOutputDuration,
        );
        if (overridden == null) {
          throw const VideoRenderFailedException(
            VideoRenderFailureReason.nativeRender,
          );
        }
        return overridden;
      }

      final cacheDir = await getTemporaryDirectory();
      final outputDir = usePersistentStorage
          ? await getApplicationDocumentsDirectory()
          : cacheDir;

      // Resolve the final output path up front so it can be cleaned up on a
      // cancel/failure that throws out of _concatenateSegments before it
      // returns the path. #8818.
      final resolvedOutputPath = path.join(
        outputDir.path,
        'divine_${DateTime.now().microsecondsSinceEpoch}.mp4',
      );
      finalOutputPath = resolvedOutputPath;

      Log.debug(
        '🎞️ Rendering ${clips.length} clip(s) to final video',
        name: _logName,
        category: .video,
      );

      // Wait all clips finish processing
      for (final clip in clips) {
        await clip.processingCompleter?.future;
      }

      final effectiveTaskId = taskId ?? clips.first.id;

      // Intermediate normalized clips always go to cache (they get deleted)
      final result = await _normalizeClipsToAspectRatio(
        clips: clips,
        aspectRatio: aspectRatio ?? clips.first.targetAspectRatio,
        cacheDir: cacheDir,
        parameters: parameters,
        taskId: effectiveTaskId,
        tempFilePaths: tempFilePaths,
      );

      final outputPath = await _concatenateSegments(
        clips: clips,
        segments: result.segments,
        taskId: effectiveTaskId,
        outputPath: resolvedOutputPath,
        globalTransform: result.globalTransform,
        aspectRatio: aspectRatio ?? clips.first.targetAspectRatio,
        parameters: parameters,
        maxOutputDuration: maxOutputDuration,
      );

      // Fire-and-forget: temp cleanup is non-critical and handles
      // errors internally
      unawaited(_cleanupTempFiles(tempFilePaths));

      Log.info(
        '✅ Video file rendered to: $outputPath',
        name: _logName,
        category: .video,
      );

      return outputPath;
    } on VideoRenderFailedException {
      // Already classified (the test override's null return) — re-wrapping it
      // below would report it a second time under the wrong cause.
      rethrow;
    } on RenderCanceledException catch (e) {
      Log.info(
        '🚫 Video render cancelled by user',
        name: _logName,
        category: .video,
      );
      // Also remove the partial final output the cancelled concatenation may
      // have written; on success this path is the returned result, so it is
      // only cleaned on the failure/cancel exits. #8818.
      await _cleanupTempFiles([...tempFilePaths, ?finalOutputPath]);
      throw VideoRenderFailedException(
        VideoRenderFailureReason.canceled,
        cause: e,
      );
    } catch (e, stack) {
      Log.error('❌ Video render failed: $e', name: _logName, category: .video);
      await _cleanupTempFiles([...tempFilePaths, ?finalOutputPath]);
      VideoRenderWatchdog.reportFailure(
        e,
        stack,
        reportEveryFailure: reportEveryFailure,
      );
      throw VideoRenderFailedException(
        VideoRenderFailureReason.nativeRender,
        cause: e,
      );
    }
  }

  /// Limits a clip's duration to a specified length.
  static Future limitClipDuration({
    required DivineVideoClip clip,
    required Duration duration,
    required ValueChanged<bool> onComplete,
  }) async {
    final override = limitClipDurationOverride;
    if (override != null) {
      return override(clip: clip, duration: duration, onComplete: onComplete);
    }

    try {
      final inputPath = await clip.requireVideo.safeFilePath();

      // Write to a new temporary file to avoid file locking issues
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        'trimmed_${DateTime.now().microsecondsSinceEpoch}.mp4',
      );

      final taskId = DateTime.now().microsecondsSinceEpoch.toString();
      await _cancelAndRender(
        outputPath,
        VideoRenderData(
          id: taskId,
          videoSegments: [VideoSegment(video: clip.requireVideo)],
          endTime: duration,
        ),
      );

      // Replace the original file with the trimmed version. A concurrent
      // cleanup (draft deletion, clip removal) can delete the source while
      // this render runs, so deleting it is best-effort: a missing source is
      // a recoverable outcome, not a failure — the trimmed output simply
      // takes its place.
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);

      if (outputFile.existsSync()) {
        try {
          await inputFile.delete();
        } on PathNotFoundException {
          // The source can disappear between render completion and cleanup.
        }
        await outputFile.rename(inputPath);
      }

      onComplete(true);
    } on RenderCanceledException {
      Log.info(
        '🚫 Clip duration limit cancelled',
        name: 'VideoEditorRenderService',
        category: .video,
      );
      onComplete(false);
    } catch (e, stack) {
      Log.error(
        '❌ Failed to limit clip duration: $e',
        name: 'VideoEditorRenderService',
        category: .video,
      );
      crashReporter.recordError(
        e,
        stack,
        reason: 'limitClipDuration failed',
      );
      onComplete(false);
    }
  }

  /// Crops a video to the specified aspect ratio.
  ///
  /// Returns the path to the cropped video file, or the original path if no
  /// cropping is needed.
  static Future<String> cropToAspectRatio({
    required EditorVideo video,
    required model.AspectRatio aspectRatio,
    bool enableAudio = true,
    VideoMetadata? metadata,
  }) async {
    metadata ??= await ProVideoEditor.instance.getMetadata(video);
    final resolution = metadata.resolution;
    final cropParams = CropParameters.forAspectRatio(
      resolution: resolution,
      aspectRatio: aspectRatio,
    );

    // No cropping needed if video already matches target aspect ratio
    if (!cropParams.needsCropping(resolution)) {
      Log.debug(
        '⏭️ Video already matches target aspect ratio - no crop needed',
        name: _logName,
        category: .video,
      );
      return video.safeFilePath();
    }

    Log.debug(
      '✂️ Cropping video from ${resolution.width.round()}x${resolution.height.round()} '
      'to ${cropParams.width}x${cropParams.height}',
      name: _logName,
      category: .video,
    );

    final tempDir = await getTemporaryDirectory();
    final outputPath = path.join(
      tempDir.path,
      'cropped_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );

    final task = VideoRenderData(
      videoSegments: [VideoSegment(video: video)],
      enableAudio: enableAudio,
      shouldOptimizeForNetworkUse: true,
      transform: cropParams.toExportTransform(),
    );

    await _cancelAndRender(outputPath, task);

    Log.debug(
      '✅ Video cropped to: $outputPath',
      name: _logName,
      category: .video,
    );

    return outputPath;
  }

  /// Normalizes all clips to the target aspect ratio.
  ///
  /// Optimizes rendering by:
  /// - Using a single global transform if all clips have the same resolution
  /// - Only pre-rendering clips that differ from the majority
  ///
  /// Returns video segments ready for concatenation and temp file paths for cleanup.
  ///
  /// [taskId] is the export's own id — the one a user cancel targets — so this
  /// pass can stop between clips instead of rendering the whole set (#7833).
  /// [tempFilePaths] is owned by the caller so partial output remains visible
  /// to its cleanup handlers when this pass throws.
  static Future<NormalizationResult> _normalizeClipsToAspectRatio({
    required List<DivineVideoClip> clips,
    required model.AspectRatio aspectRatio,
    required Directory cacheDir,
    required CompleteParameters? parameters,
    required String taskId,
    required List<String> tempFilePaths,
  }) async {
    // Analyze all clips first to determine the optimal rendering strategy
    final clipAnalysis = await _analyzeClips(clips, aspectRatio);

    // A transition overlaps the tail of its clip and the head of the next, so
    // clamp it to a duration both clips can sustain. Without this the native
    // render fails on a transition longer than a (possibly later-trimmed) clip,
    // even though the lightweight seam preview clamps independently.
    final clampedTransitions = clampTransitions(clips);

    // If all clips have the same crop params, use global transform (most efficient)
    if (clipAnalysis.allSameCropParams) {
      Log.debug(
        '⚡ All ${clips.length} clips have identical resolution - using global transform',
        name: _logName,
        category: .video,
      );
      return NormalizationResult(
        segments: clips
            .map(
              (c) => VideoSegment(
                video: c.requireVideo,
                startTime: c.trimStart == .zero ? null : c.trimStart,
                endTime: c.trimStart + c.trimmedDuration,
                volume: c.volume,
                playbackSpeed: c.playbackSpeed,
                transition: clampedTransitions[c.id],
              ),
            )
            .toList(),
        globalTransform:
            clipAnalysis.entries.first.cropParams.needsCropping(
              clipAnalysis.entries.first.resolution,
            )
            ? clipAnalysis.entries.first.cropParams
            : null,
      );
    }

    // Mixed resolutions: normalize clips that differ from the target
    Log.debug(
      '🔄 Mixed resolutions detected - normalizing individual clips',
      name: _logName,
      category: .video,
    );

    final segments = <VideoSegment>[];
    for (int i = 0; i < clips.length; i++) {
      _throwIfCancellationRequested(taskId);
      final entry = clipAnalysis.entries[i];
      final needsCrop = entry.cropParams.needsCropping(entry.resolution);

      Log.debug(
        '🎯 Clip ${entry.clip.id}: ${entry.resolution.width.round()}x${entry.resolution.height.round()}, '
        'crop: ${entry.cropParams}, needsCrop: $needsCrop',
        name: _logName,
        category: .video,
      );

      if (!needsCrop) {
        segments.add(
          VideoSegment(
            video: entry.clip.requireVideo,
            startTime: entry.clip.trimStart == .zero
                ? null
                : entry.clip.trimStart,
            endTime: entry.clip.trimStart + entry.clip.trimmedDuration,
            volume: entry.clip.volume,
            playbackSpeed: entry.clip.playbackSpeed,
            transition: clampedTransitions[entry.clip.id],
          ),
        );
      } else {
        final normalizedPath = path.join(
          cacheDir.path,
          'normalized_${i}_${DateTime.now().microsecondsSinceEpoch}.mp4',
        );
        tempFilePaths.add(normalizedPath);
        await _renderNormalizedClip(
          clip: entry.clip,
          cropParams: entry.cropParams,
          outputPath: normalizedPath,
          parameters: parameters,
          ownerTaskId: taskId,
        );
        segments.add(
          VideoSegment(
            video: EditorVideo.file(File(normalizedPath)),
            transition: clampedTransitions[entry.clip.id],
          ),
        );
      }
    }

    return NormalizationResult(
      segments: segments,
    );
  }

  /// Analyzes all clips to determine their crop parameters.
  static Future<ClipAnalysis> _analyzeClips(
    List<DivineVideoClip> clips,
    model.AspectRatio aspectRatio,
  ) async {
    final entries = <ClipAnalysisEntry>[];

    for (final clip in clips) {
      final metaData = await ProVideoEditor.instance.getMetadata(
        clip.requireVideo,
      );
      final resolution = metaData.resolution;
      final cropParams = CropParameters.forAspectRatio(
        resolution: resolution,
        aspectRatio: aspectRatio,
      );
      entries.add(
        ClipAnalysisEntry(
          clip: clip,
          resolution: resolution,
          cropParams: cropParams,
        ),
      );
    }

    return ClipAnalysis(entries: entries);
  }

  /// Renders a single clip with crop transform to normalize its aspect ratio.
  static Future<String> _renderNormalizedClip({
    required DivineVideoClip clip,
    required CropParameters cropParams,
    required String outputPath,
    required CompleteParameters? parameters,
    required String ownerTaskId,
  }) async {
    final task = VideoRenderData(
      id: '${clip.id}_normalized',
      videoSegments: [
        VideoSegment(
          video: clip.requireVideo,
          startTime: clip.trimStart == .zero ? null : clip.trimStart,
          endTime: clip.trimStart + clip.trimmedDuration,
          volume: clip.volume,
          playbackSpeed: clip.playbackSpeed,
        ),
      ],
      shouldOptimizeForNetworkUse: true,
      imageBytesWithCropping: true,
      transform: ExportTransform(
        x: cropParams.x,
        y: cropParams.y,
        width: cropParams.width,
        height: cropParams.height,
        flipX: parameters?.flipX ?? false,
        flipY: parameters?.flipY ?? false,
        rotateTurns: parameters?.rotateTurns ?? 0,
      ),
    );

    await renderWithEncoderFallback(
      baseTask: task,
      encode: (attemptTask) => _cancelAndRender(outputPath, attemptTask),
      ownerTaskId: ownerTaskId,
    );

    Log.debug(
      '✅ Clip ${clip.id} normalized to: $outputPath',
      name: _logName,
      category: .video,
    );

    return outputPath;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Video Concatenation
  // ─────────────────────────────────────────────────────────────────────────

  /// Concatenates all segments; [globalTransform] applies in one pass.
  ///
  /// `trimToCommonTrackEnd` stays off because it would shift authored anchors;
  /// see `docs/VIDEO_TRACK_END_MISMATCH.md` for the export/playback distinction.
  static Future<String> _concatenateSegments({
    required List<DivineVideoClip> clips,
    required List<VideoSegment> segments,
    required String taskId,
    required String outputPath,
    required CompleteParameters? parameters,
    required model.AspectRatio aspectRatio,
    required Duration? maxOutputDuration,
    CropParameters? globalTransform,
  }) async {
    // Overlap transitions shorten the rendered output, so the true video
    // length is the transition-mapped output duration, capped by
    // [maxOutputDuration]. Audio windows are clamped to it below so a short
    // stop-motion export muxed with a full-length song can't produce an mp4
    // whose audio outlives its video (which freezes the last frame on iOS).
    final timelineMap = TransitionTimelineMap.fromClips(clips);
    final videoContentDuration =
        maxOutputDuration != null &&
            maxOutputDuration < timelineMap.outputDuration
        ? maxOutputDuration
        : timelineMap.outputDuration;

    final customTracks = parameters?.audioTracks ?? const <AudioTrack>[];
    final audioTracks = await resolveRenderAudioTracks(
      customTracks,
      logName: _logName,
      videoDuration: videoContentDuration,
    );

    final volumeSegments = segments
        .map((s) => s.copyWith(volume: s.volume))
        .toList();

    Size? renderResolution;
    if (parameters?.capturedLayers.isNotEmpty == true &&
        volumeSegments.isNotEmpty) {
      final metadata = await ProVideoEditor.instance.getMetadata(
        volumeSegments.first.video,
      );
      renderResolution = metadata.resolution;
    }

    // Overlay/effect time windows are authored on the editor timeline (clips at
    // full length). Overlap transitions (dissolve/slide/push/wipe) shorten the
    // rendered output, so every time anchor is mapped onto the output axis via
    // [timelineMap] (computed above); otherwise anything near the end — a
    // layer's leave animation especially — lands past the real video end and is
    // clipped ("animation missing at the end"). Identity when no overlap
    // transition is present.
    final videoSize =
        renderResolution ??
        VideoEditorConstants.quality.resolutionForAspectRatio(aspectRatio);

    final task = VideoRenderData(
      id: taskId,
      videoSegments: volumeSegments,
      endTime: maxOutputDuration,
      shouldOptimizeForNetworkUse: true,
      audioTracks: audioTracks,
      imageLayers: buildImageLayers(
        capturedLayers: parameters?.capturedLayers ?? const [],
        bodySize: parameters?.bodySize,
        videoSize: videoSize,
        timelineMap: timelineMap,
      ),
      blur: parameters?.blur,
      colorFilters: buildColorFilters(
        tuneAdjustments: parameters?.tuneAdjustments ?? const [],
        filterStates: parameters?.filterStates ?? const [],
        timelineMap: timelineMap,
      ),
      imageBytesWithCropping: true,
      qualityConfig: VideoQualityConfig.custom(
        bitrate: VideoEditorConstants.quality.bitrate,
        resolution: VideoEditorConstants.quality.resolutionForAspectRatio(
          aspectRatio,
        ),
      ),
      transform: globalTransform != null
          ? ExportTransform(
              x: globalTransform.x,
              y: globalTransform.y,
              width: globalTransform.width,
              height: globalTransform.height,
              flipX: parameters?.flipX ?? false,
              flipY: parameters?.flipY ?? false,
              rotateTurns: parameters?.rotateTurns ?? 0,
            )
          : null,
    );

    await renderWithEncoderFallback(
      baseTask: task,
      encode: (attemptTask) => _cancelAndRender(outputPath, attemptTask),
      fallbackAspectRatio: aspectRatio,
    );

    return outputPath;
  }

  /// Runs the export [encode] for [baseTask], recovering from device
  /// encoder-init failures (`RenderEncoderException`).
  ///
  /// The exception signals that `pro_video_editor`'s own in-process fallback
  /// chain (operating-rate cap/removal, profile downgrade, and a conditional
  /// software encoder when the device has one usable for the target MIME) could
  /// not initialise an encoder. On codec-limited devices that is usually
  /// transient contention rather than a true format incompatibility: the
  /// preview decoder the editor just released (the #5522 decoder-release gate)
  /// — or another app codec — has not been reclaimed by the OS media server
  /// yet, and the plugin runs every attempt within a few hundred ms, so it
  /// cannot outlast that window. We retry at the Dart level with a
  /// [settleDelay] (letting the codec free up). When [fallbackAspectRatio] is
  /// provided, it then retries once more at
  /// [VideoEditorConstants.encoderFallbackQuality] for devices genuinely at
  /// their 1080p encoder ceiling. Only if every attempt fails does the
  /// exception propagate to the UI's retry affordance (#6058).
  ///
  /// The happy path pays no extra latency: the first attempt runs immediately
  /// and only failures incur a settle.
  ///
  /// [ownerTaskId] names the export this render belongs to, for passes that
  /// render under an id of their own. A user cancel targets the export's id,
  /// so without it a retry fires after the settle and finishes work nobody is
  /// waiting for any more (#7833).
  @visibleForTesting
  static Future<void> renderWithEncoderFallback({
    required VideoRenderData baseTask,
    required Future<void> Function(VideoRenderData task) encode,
    model.AspectRatio? fallbackAspectRatio,
    String? ownerTaskId,
    Duration settleDelay = VideoEditorConstants.encoderRetrySettleDelay,
  }) async {
    const fallbackQuality = VideoEditorConstants.encoderFallbackQuality;
    final reducedTask = fallbackAspectRatio == null
        ? null
        : baseTask.copyWith(
            qualityConfig: VideoQualityConfig.custom(
              bitrate: fallbackQuality.bitrate,
              resolution: fallbackQuality.resolutionForAspectRatio(
                fallbackAspectRatio,
              ),
            ),
          );

    final attempts = <({VideoRenderData task, Duration settle, bool reduced})>[
      (task: baseTask, settle: Duration.zero, reduced: false),
      (task: baseTask, settle: settleDelay, reduced: false),
      if (reducedTask != null)
        (task: reducedTask, settle: settleDelay, reduced: true),
    ];

    final renderGeneration = RenderCancellationRegistry.startIfIdle(
      baseTask.id,
    );
    try {
      for (var i = 0; i < attempts.length; i++) {
        final attempt = attempts[i];
        if (attempt.settle > Duration.zero) {
          await Future<void>.delayed(attempt.settle);
        }
        _throwIfCancellationRequested(baseTask.id, ownerTaskId);
        try {
          await encode(attempt.task);
          _throwIfCancellationRequested(baseTask.id, ownerTaskId);
          return;
        } on RenderEncoderException catch (e) {
          final isLast = i == attempts.length - 1;
          Log.warning(
            '⚠️ Export encoder init failed on attempt ${i + 1}/${attempts.length}'
            '${attempt.reduced ? ' (reduced resolution)' : ''}'
            '${isLast ? '' : '; retrying'}: $e',
            name: _logName,
            category: .video,
          );
          if (isLast) rethrow;
        }
      }
    } finally {
      if (renderGeneration.started) {
        RenderCancellationRegistry.finish(baseTask.id, renderGeneration.token);
      }
    }
  }

  /// Throws [RenderCanceledException] when a cancel is pending for [taskId]
  /// or for [ownerTaskId], consuming the request.
  ///
  /// Intermediate passes render under their own ids, so a user cancel — which
  /// targets the export's id — is invisible to them unless they also consult
  /// the owner.
  static void _throwIfCancellationRequested(
    String taskId, [
    String? ownerTaskId,
  ]) {
    final cancelled = RenderCancellationRegistry.consumeCancellation(taskId);
    final ownerCancelled =
        ownerTaskId != null &&
        ownerTaskId != taskId &&
        RenderCancellationRegistry.consumeCancellation(ownerTaskId);
    if (cancelled || ownerCancelled) {
      throw const RenderCanceledException();
    }
  }

  /// Builds the [ImageLayer]s composited over the exported video from the
  /// captured overlay layers.
  ///
  /// Each layer is scaled from editor body space ([bodySize]) into the rendered
  /// video's pixel space ([videoSize]), and its time window is mapped from the
  /// editor timeline onto the output axis via [timelineMap] — so an overlap
  /// transition can't push a layer (or its leave animation) past the real video
  /// end. Returns `null` when there is nothing to overlay.
  @visibleForTesting
  static List<ImageLayer>? buildImageLayers({
    required List<ExportedLayer> capturedLayers,
    required Size? bodySize,
    required Size videoSize,
    required TransitionTimelineMap timelineMap,
  }) {
    if (capturedLayers.isEmpty || bodySize == null) return null;
    final scale = videoSize.width / bodySize.width;
    return [
      for (final item in capturedLayers)
        ImageLayer(
          image: EditorLayerImage.memory(item.bytes),
          startTime: timelineMap.editorToOutputOrNull(item.layer.startTime),
          endTime: timelineMap.editorToOutputOrNull(item.layer.endTime),
          offset: Offset(
            (bodySize.width / 2 +
                    item.layer.offset.dx -
                    item.logicalSize.width / 2) *
                scale,
            (bodySize.height / 2 +
                    item.layer.offset.dy -
                    item.logicalSize.height / 2) *
                scale,
          ),
          size: Size(
            item.logicalSize.width * scale,
            item.logicalSize.height * scale,
          ),
          animations: item.layer.divineAnimations,
        ),
    ];
  }

  /// Builds the [ColorFilter]s applied to the exported video from the tune
  /// adjustments and filter states.
  ///
  /// Each filter's editor-timeline window is mapped onto the output axis via
  /// [timelineMap] — the same mapping [buildImageLayers] applies — so an
  /// overlap transition can't push a filter (or its leave animation) past the
  /// real video end. A `null` start/end stays un-anchored (spans the whole
  /// video). One [ColorFilter] is emitted per filter matrix.
  @visibleForTesting
  static List<ColorFilter> buildColorFilters({
    required List<TuneAdjustmentMatrix> tuneAdjustments,
    required List<FilterState> filterStates,
    required TransitionTimelineMap timelineMap,
  }) {
    return [
      for (final tune in tuneAdjustments)
        ColorFilter(
          matrix: tune.matrix,
          startTime: timelineMap.editorToOutputOrNull(tune.startTime),
          endTime: timelineMap.editorToOutputOrNull(tune.endTime),
        ),
      for (final filter in filterStates)
        for (final matrix in filter.matrices)
          ColorFilter(
            matrix: matrix,
            startTime: timelineMap.editorToOutputOrNull(filter.startTime),
            endTime: timelineMap.editorToOutputOrNull(filter.endTime),
          ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cleanup
  // ─────────────────────────────────────────────────────────────────────────

  /// Cleans up temporary normalized clip files.
  static Future<void> _cleanupTempFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
          Log.debug(
            '🗑️ Deleted temp file: $path',
            name: _logName,
            category: .video,
          );
        }
      } catch (e) {
        Log.warning(
          '⚠️ Failed to delete temp file: $path - $e',
          name: _logName,
          category: .video,
        );
      }
    }
  }

  /// Cancels any in-progress render for [task], then renders to [outputPath].
  static Future<void> _cancelAndRender(
    String outputPath,
    VideoRenderData task,
  ) async {
    await renderNativeVideoToFile(
      outputPath,
      task,
      reuseActiveCancellation: true,
    );
  }

  static Future<void> cancelTask(String id) async {
    RenderCancellationRegistry.cancel(id);
    await _cancelNativeTaskOnly(id);
  }

  static Future<void> _cancelNativeTaskOnly(String id) async {
    try {
      Log.info(
        '⏹️ Cancelling video render',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      await ProVideoEditor.instance.cancel(id);
      Log.info(
        '✅ Video render cancelled',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    } catch (e) {
      // May fail if render already completed or was cancelled - not an error
      Log.debug(
        '⏹️ Cancel video render returned: $e',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
  }

  /// Cancels any existing native render with [task.id], tracks this render
  /// instance, then renders to [outputPath].
  ///
  /// All app-owned `pro_video_editor` render entry points should use this
  /// helper so teardown cancellation has a complete view of native work.
  static Future<String> renderNativeVideoToFile(
    String outputPath,
    VideoRenderData task, {
    // Surface native renderer warnings through ProVideoEditorLogForwarder for
    // #4801 diagnostics while clean renders stay quiet.
    NativeLogLevel? nativeLogLevel = NativeLogLevel.warning,
    bool reuseActiveCancellation = false,
  }) async {
    final renderGeneration = reuseActiveCancellation
        ? RenderCancellationRegistry.startIfIdle(task.id)
        : (token: RenderCancellationRegistry.start(task.id), started: true);
    if (NativeRenderTaskRegistry.activeTaskIds.contains(task.id)) {
      await _cancelNativeTaskOnly(task.id);
    }
    return NativeRenderTaskRegistry.track(task.id, () {
      return Future.sync(() {
        _throwIfCancellationRequested(task.id);
        return ProVideoEditor.instance.renderVideoToFile(
          outputPath,
          task,
          nativeLogLevel: nativeLogLevel,
        );
      }).whenComplete(() {
        if (renderGeneration.started) {
          RenderCancellationRegistry.finish(task.id, renderGeneration.token);
        }
      });
    });
  }

  /// Cancels native `pro_video_editor` render tasks started by this app.
  ///
  /// Intended for genuine teardown such as `AppLifecycleState.detached`.
  /// Transient background states must not call this: exports may legitimately
  /// continue while the user briefly switches apps or locks the device.
  static Future<void> cancelActiveNativeTasks() async {
    final taskIds = List<String>.of(NativeRenderTaskRegistry.activeTaskIds);
    if (taskIds.isEmpty) return;

    Log.info(
      '⏹️ Cancelling ${taskIds.length} active video editor task(s)',
      name: _logName,
      category: .video,
    );

    await Future.wait<void>(taskIds.map(cancelTask));
  }
}
