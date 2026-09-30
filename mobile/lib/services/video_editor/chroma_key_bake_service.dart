// ABOUTME: Bakes a clip's green screen into a new local clip file, so the rest
// ABOUTME: of the editor and the export treat it as ordinary footage.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

class ChromaKeyBackdropMissingException implements Exception {
  const ChromaKeyBackdropMissingException(this.path);

  final String path;

  @override
  String toString() => 'ChromaKeyBackdropMissingException: $path';
}

/// Renders [sourceClip] with [chromaKey] burned in, returning the new file and
/// the input it was rendered from.
///
/// Injected into the clip editor bloc so tests can swap the render out.
typedef ChromaKeyBakeFn =
    Future<({EditorVideo video, String source})> Function({
      required DivineVideoClip sourceClip,
      required ClipChromaKey chromaKey,
      required String renderId,
    });

/// Burns a green screen into a clip.
///
/// The key is applied once, on confirm, rather than carried on the clip and
/// applied at export. That keeps one source of truth: afterwards the clip is
/// ordinary footage, so the editor preview, the timeline thumbnails and the
/// exported file all show the same thing — and a later feature that composites
/// clips (overlays) can build on the baked result instead of re-deriving it.
abstract class ChromaKeyBakeService {
  static const _logName = 'ChromaKeyBakeService';

  /// How many times a short backdrop may repeat to cover the clip.
  ///
  /// A one-second backdrop under a one-minute clip is a legitimate 60 repeats;
  /// a 40ms one would be 1500 segments and is not worth building. Past the cap
  /// the backdrop simply ends and the composition's background shows.
  static const maxBackdropRepeats = 60;

  /// The render task id for keying [clipId].
  ///
  /// Namespaced so a bake never shares an id with a concurrent reverse or
  /// transform render on the same clip — both would otherwise key on the clip
  /// id, letting one cancel the other. Shared so the screen can follow the
  /// render's progress stream by the same id the bloc renders under.
  static String renderIdFor(String clipId) => '${clipId}_chromakey';

  /// Renders the full clip with [chromaKey] applied, returning the new file
  /// and the input it was rendered from.
  ///
  /// The *whole* source clip is rendered, not the trimmed window: trim, speed
  /// and transitions stay in clip state and are applied to the baked file
  /// downstream, exactly as the crop/rotate bake does.
  ///
  /// Re-keying a clip renders from [DivineVideoClip.chromaKeySourcePath] — the
  /// footage as it was *before* the first bake — so adjusting the key neither
  /// stacks it on already-keyed pixels nor loses a generation. The returned
  /// `source` is that input, for the caller to carry forward.
  ///
  /// [renderId] is cancellable through [VideoEditorRenderService.cancelTask]
  /// for the whole call, including the preparation before the native render
  /// registers — which is when a starting recording stops a background bake.
  ///
  /// Throws when the render fails or is cancelled, leaving the clip untouched.
  static Future<({EditorVideo video, String source})> bakeClip({
    required DivineVideoClip sourceClip,
    required ClipChromaKey chromaKey,
    required String renderId,
  }) async {
    // Registered before the task is built, not by the native render: building
    // it reads metadata over the platform channel, and a cancel landing in
    // that gap had no generation to mark, so the render ran anyway.
    final renderToken = RenderCancellationRegistry.start(renderId);
    try {
      return await _bakeClip(
        sourceClip: sourceClip,
        chromaKey: chromaKey,
        renderId: renderId,
      );
    } finally {
      RenderCancellationRegistry.finish(renderId, renderToken);
    }
  }

  static Future<({EditorVideo video, String source})> _bakeClip({
    required DivineVideoClip sourceClip,
    required ClipChromaKey chromaKey,
    required String renderId,
  }) async {
    final documentsPath = await getDocumentsPath();
    final inputPath = await _resolveInputPath(sourceClip);
    // Unique per render so keying the same clip twice never targets the file it
    // is reading from. The prior file is intentionally left on disk — undo
    // history points back at it.
    final outputPath = p.join(
      documentsPath,
      '${sourceClip.id}_chromakey_'
      '${DateTime.now().microsecondsSinceEpoch}.mp4',
    );

    // Defensive: the output is deleted before rendering, so a collision with
    // the input would destroy the source video in place.
    if (p.equals(inputPath, outputPath)) {
      throw StateError(
        'Chroma-key render aborted: input path equals output path ($inputPath)',
      );
    }

    final inputVideo = EditorVideo.file(inputPath);
    final outputFile = File(outputPath);

    Log.info(
      '🟩 Baking the chroma key into clip ${sourceClip.id} '
      '(${chromaKey.backgroundType.name} background)',
      name: _logName,
      category: LogCategory.video,
    );

    try {
      if (outputFile.existsSync()) await outputFile.delete();

      // Joins the generation [bakeClip] registered, so a cancel issued while
      // the task was still being built stops the render before it starts.
      await VideoEditorRenderService.cancelAndRender(
        outputPath,
        await buildTask(
          renderId: renderId,
          sourceClip: sourceClip,
          inputVideo: inputVideo,
          chromaKey: chromaKey,
        ),
      );

      return (video: EditorVideo.file(outputPath), source: inputPath);
    } catch (_) {
      if (outputFile.existsSync()) {
        try {
          await outputFile.delete();
        } catch (deleteError) {
          Log.warning(
            '⚠️ Failed to delete partial chroma-key output $outputPath: '
            '$deleteError',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }
      rethrow;
    }
  }

  /// The file a bake renders from: the pre-key original when one is recorded
  /// and still on disk, otherwise the clip's current video.
  ///
  /// The fallback matters because the original is a plain documents-dir file
  /// that a storage cleanup can remove; re-keying the current video then costs
  /// a generation but still produces the effect the user asked for.
  static Future<String> _resolveInputPath(DivineVideoClip clip) async {
    final source = clip.chromaKeySourcePath;
    if (source != null && File(source).existsSync()) return source;
    if (source != null) {
      Log.warning(
        'Chroma-key source $source is gone; re-keying the current video',
        name: _logName,
        category: LogCategory.video,
      );
    }
    return clip.requireVideo.safeFilePath();
  }

  /// Builds the render task for [chromaKey].
  ///
  /// Exposed for testing: the two background shapes (single track vs.
  /// composition) are the substance of this service, and they can be asserted
  /// without a platform channel.
  @visibleForTesting
  static Future<VideoRenderData> buildTask({
    required String renderId,
    required DivineVideoClip sourceClip,
    required EditorVideo inputVideo,
    required ClipChromaKey chromaKey,
  }) async {
    // A colour or image fill lives inside the key itself, so one keyed track
    // is all it takes.
    if (!chromaKey.needsComposition) {
      return VideoRenderData(
        id: renderId,
        videoSegments: [
          VideoSegment(video: inputVideo, chromaKey: chromaKey.key),
        ],
        shouldOptimizeForNetworkUse: true,
      );
    }

    final backdropPath = chromaKey.backgroundVideoPath;
    if (backdropPath != null && !File(backdropPath).existsSync()) {
      throw ChromaKeyBackdropMissingException(backdropPath);
    }

    // Everything else needs a second track — or, for a transparent key, at
    // least a canvas to show through. H.264 carries no alpha, and the renderer
    // rejects a transparent key on the single-track path outright rather than
    // silently flattening it, so "nothing behind the subject" is expressed as
    // a lone keyed layer over the composition's own (opaque black) canvas.
    final editor = ProVideoEditor.instance;
    final metadata = await editor.getMetadata(inputVideo);

    return VideoRenderData(
      id: renderId,
      shouldOptimizeForNetworkUse: true,
      composition: VideoComposition(
        // Without this the canvas would be sized from the first clip of the
        // bottom layer — the backdrop — and the subject would be rescaled to
        // whatever the user happened to pick.
        canvasSize: metadata.resolution,
        layers: [
          if (backdropPath != null)
            VideoLayer(
              clips: backdropSegments(
                path: backdropPath,
                backdropDuration: (await editor.getMetadata(
                  EditorVideo.file(backdropPath),
                )).duration,
                coverDuration: sourceClip.duration,
              ),
            ),
          VideoLayer(
            clips: [VideoSegment(video: inputVideo)],
            chromaKey: chromaKey.key,
          ),
        ],
      ),
    );
  }

  /// Tiles [path] along the timeline until it covers [coverDuration].
  ///
  /// A backdrop shorter than the clip loops rather than cutting to black
  /// partway through, which is what a user picking a short clip as a backdrop
  /// expects.
  @visibleForTesting
  static List<VideoSegment> backdropSegments({
    required String path,
    required Duration backdropDuration,
    required Duration coverDuration,
  }) {
    final video = EditorVideo.file(path);
    // The backdrop is a picture, not a soundtrack: its own audio would fight
    // the clip's.
    if (backdropDuration <= Duration.zero) {
      return [VideoSegment(video: video, volume: 0)];
    }

    final segments = <VideoSegment>[];
    var start = Duration.zero;
    while (start < coverDuration && segments.length < maxBackdropRepeats) {
      final remaining = coverDuration - start;
      segments.add(
        VideoSegment(
          video: video,
          volume: 0,
          timelineStart: start == Duration.zero ? null : start,
          endTime: remaining < backdropDuration ? remaining : null,
        ),
      );
      start += backdropDuration;
    }

    if (start < coverDuration) {
      Log.warning(
        'Chroma-key backdrop stops at $start of $coverDuration: '
        'it would need more than $maxBackdropRepeats repeats',
        name: _logName,
        category: LogCategory.video,
      );
    }

    return segments;
  }
}
