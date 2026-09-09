// ABOUTME: Renders the still clip that fills a timeline slot a clip was
// ABOUTME: detached from — a solid colour or a photographed image

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:unified_logger/unified_logger.dart';

const _logName = 'ClipPlaceholderRenderService';

/// What fills the timeline slot a clip was detached from.
sealed class ClipPlaceholderFill {
  const ClipPlaceholderFill();
}

/// Fill the slot with a solid colour.
class ClipPlaceholderColorFill extends ClipPlaceholderFill {
  const ClipPlaceholderColorFill(this.color);

  final Color color;
}

/// Fill the slot with a photographed image, held for the clip's length.
class ClipPlaceholderImageFill extends ClipPlaceholderFill {
  const ClipPlaceholderImageFill(this.imagePath);

  /// Absolute path to the image file.
  final String imagePath;
}

/// Renders the still that stands in for a detached clip on the timeline.
///
/// The result is a plain video clip, not a stop-motion one: the timeline gives
/// a frames-based clip a frame-first action bar (delete / duplicate / hold the
/// selected still), which makes no sense for a one-image backdrop. Only the
/// *renderer* is borrowed — [StopMotionRenderService] already turns a held
/// still into an mp4 at the composition's resolution, which is exactly the job.
class ClipPlaceholderRenderService {
  const ClipPlaceholderRenderService._();

  /// Edge length of the generated solid-colour source image.
  ///
  /// The renderer scales it up to the output resolution with
  /// `StopMotionFit.cover`; a flat colour loses nothing to that, so a small
  /// bitmap keeps the encode cheap.
  static const int colorSourceSize = 64;

  /// Overrides the render for tests, so the placeholder path can be exercised
  /// without a platform channel. Returns the output file path, or `null` for a
  /// failed render.
  @visibleForTesting
  static Future<String?> Function({
    required List<StopMotionClipFrame> frames,
    required model.AspectRatio aspectRatio,
    String? taskId,
  })?
  assembleOverride;

  /// Renders [fill] into a clip that occupies [duration] on the timeline.
  ///
  /// [source] is the clip being detached: the placeholder inherits its
  /// duration, aspect ratio and id-prefix so the slot keeps its shape. Returns
  /// `null` when the render fails; the caller surfaces that rather than
  /// silently leaving a hole in the composition.
  ///
  /// [taskId] keys the encoder's progress stream, so the editor can put a real
  /// progress figure over the wait instead of a bare spinner.
  static Future<DivineVideoClip?> render({
    required ClipPlaceholderFill fill,
    required DivineVideoClip source,
    String? taskId,
  }) async {
    final duration = source.playbackDuration;
    if (duration <= Duration.zero) {
      Log.warning(
        'Refusing to render a placeholder for zero-length clip ${source.id}',
        name: _logName,
        category: LogCategory.video,
      );
      if (fill is ClipPlaceholderImageFill) {
        await _deleteUnusedSourceImage(fill.imagePath);
      }
      return null;
    }

    final imagePath = switch (fill) {
      ClipPlaceholderImageFill(:final imagePath) => imagePath,
      ClipPlaceholderColorFill(:final color) => await _writeSolidColorImage(
        color,
      ),
    };
    if (imagePath == null || !File(imagePath).existsSync()) {
      Log.error(
        'Placeholder source image is missing; cannot fill the slot',
        name: _logName,
        category: LogCategory.video,
      );
      if (imagePath != null) await _deleteUnusedSourceImage(imagePath);
      return null;
    }

    final frames = [
      StopMotionClipFrame(
        path: imagePath,
        duration: duration,
        holdOverridden: true,
      ),
    ];

    final override = assembleOverride;
    final String? outputPath;
    try {
      outputPath = override != null
          ? await override(
              frames: frames,
              aspectRatio: source.targetAspectRatio,
              taskId: taskId,
            )
          : await StopMotionRenderService.assemble(
              frames: frames,
              aspectRatio: source.targetAspectRatio,
              taskId: taskId,
            );
    } catch (_) {
      await _deleteUnusedSourceImage(imagePath);
      rethrow;
    }

    if (outputPath == null) {
      Log.error(
        'Placeholder render produced no file for clip ${source.id}',
        name: _logName,
        category: LogCategory.video,
      );
      await _deleteUnusedSourceImage(imagePath);
      return null;
    }

    // A fresh id: this is a new clip standing in the old one's place, and
    // reusing the detached clip's id would collide with the layer that now
    // carries it.
    return DivineVideoClip(
      id: 'placeholder_${DateTime.now().microsecondsSinceEpoch}',
      video: EditorVideo.file(File(outputPath)),
      duration: duration,
      recordedAt: DateTime.now(),
      targetAspectRatio: source.targetAspectRatio,
      originalAspectRatio: source.targetAspectRatio.value,
      thumbnailPath: imagePath,
      // Keeps Detach off it: lifting a still onto the canvas would only ask
      // for a second still to fill the slot it just vacated.
      isPlaceholder: true,
      // The still carries no sound of its own. The detached clip keeps its own
      // volume on its layer, so muting here does not silence anything the user
      // could still hear.
      volume: 0,
    );
  }

  static Future<void> _deleteUnusedSourceImage(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (error) {
      Log.warning(
        '⚠️ Failed to delete unused placeholder source image $path: $error',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  /// Writes a solid [color] bitmap into the documents directory and returns its
  /// path, or `null` when encoding fails.
  ///
  /// Lives beside the clip files rather than in the cache directory: the
  /// renderer opens a file-backed frame while it encodes, and a cache file the
  /// system reclaims under storage pressure fails the export.
  static Future<String?> _writeSolidColorImage(Color color) async {
    try {
      final bytes = await encodeSolidColorPng(color);
      if (bytes == null) return null;
      final documentsPath = await getDocumentsPath();
      final path = p.join(
        documentsPath,
        'clip_placeholder_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (error, stackTrace) {
      Log.error(
        'Failed to write the solid-colour placeholder image',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Encodes a [colorSourceSize]-square PNG filled with [color].
  ///
  /// The alpha channel is forced opaque: mp4 carries none, so a translucent
  /// pick would be flattened against black by the encoder and come out darker
  /// than the swatch the user tapped.
  @visibleForTesting
  static Future<Uint8List?> encodeSolidColorPng(Color color) async {
    final recorder = ui.PictureRecorder();
    final bounds = Rect.fromLTWH(
      0,
      0,
      colorSourceSize.toDouble(),
      colorSourceSize.toDouble(),
    );
    Canvas(
      recorder,
      bounds,
    ).drawRect(bounds, Paint()..color = color.withValues(alpha: 1));
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(colorSourceSize, colorSourceSize);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}
