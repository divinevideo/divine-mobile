// ABOUTME: Holds the frame under the playhead still for a beat: extracts it
// ABOUTME: from the clip and renders it into a trimmable still clip

import 'dart:io';
import 'dart:typed_data';

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'FreezeFrameRenderService';

/// Where a freeze lands relative to the clip it was taken from.
enum FreezeFramePlacement {
  /// The playhead sits on the clip's first frame: the freeze goes in front of
  /// the clip, which stays whole.
  before,

  /// The playhead sits inside the clip: the clip is cut there and the freeze
  /// goes between the two halves.
  split,

  /// The playhead sits on the clip's last frame: the freeze goes after the
  /// clip, which stays whole.
  after,
}

/// Where a freeze goes and which frame of the clip it holds.
typedef FreezeFramePlan = ({
  FreezeFramePlacement placement,

  /// Position of the held frame in the clip's source file.
  Duration framePosition,
});

/// Turns the frame under the playhead into a clip that holds it still.
///
/// The still is a plain video clip, rendered by the same encoder that turns a
/// placeholder's colour or photo into video. It is rendered at
/// [reserveDuration] and trimmed down to [defaultDuration], so dragging its trim
/// handle out lengthens the freeze instantly instead of asking for a second
/// render.
class FreezeFrameRenderService {
  const FreezeFrameRenderService._();

  /// How long a new freeze holds before the clip continues.
  static const defaultDuration = Duration(milliseconds: 500);

  /// Length the still is rendered at, and so the longest a freeze can be
  /// trimmed out to. A freeze cannot usefully outlast the whole video.
  static const Duration reserveDuration = VideoEditorConstants.maxDuration;

  /// How far before the trim-out point the last frame is read from.
  ///
  /// Asking for the trim-out point itself reads past the last frame the clip
  /// shows — or past the end of the file. Half a frame at 30 fps lands inside
  /// the last frame on both decoders: iOS returns the frame shown at the
  /// position, Android the frame whose timestamp is closest to it.
  static const _lastFrameLead = Duration(milliseconds: 17);

  /// JPEG quality of the held frame. It fills the screen for as long as the
  /// freeze lasts, so it gets more than a timeline thumbnail's default.
  static const _jpegQuality = 95;

  /// Where a freeze at [position] of [clip] goes and which frame it holds.
  ///
  /// [position] is measured in source time from the clip's trimmed start, the
  /// same coordinate a split takes. A position too close to either end to
  /// leave a valid half there freezes that end's frame instead of cutting off
  /// a sliver nobody could select.
  static FreezeFramePlan plan(DivineVideoClip clip, Duration position) {
    final trimOut = clip.trimStart + clip.trimmedDuration;
    if (position < VideoEditorSplitService.minClipDuration) {
      return (placement: .before, framePosition: clip.trimStart);
    }
    if (clip.trimmedDuration - position <
        VideoEditorSplitService.minClipDuration) {
      final lastFrame = trimOut - _lastFrameLead;
      return (
        placement: .after,
        framePosition: lastFrame < clip.trimStart ? clip.trimStart : lastFrame,
      );
    }
    return (placement: .split, framePosition: clip.trimStart + position);
  }

  /// Renders the frame of [source] at [framePosition] (source time) into a
  /// still clip trimmed to [defaultDuration].
  ///
  /// The still is cropped to [source]'s target aspect ratio the way the export
  /// crops footage, so the freeze lines up with the frames around it. It is
  /// silent: the clip's own sound pauses during the freeze, while music and
  /// voice-over on their own tracks play on.
  ///
  /// Returns `null` when the frame cannot be read or the render fails; nothing
  /// is left on disk then. [taskId] keys the encoder's progress stream.
  static Future<DivineVideoClip?> render({
    required DivineVideoClip source,
    required Duration framePosition,
    String? taskId,
  }) async {
    final bytes = await _extractFrame(source, framePosition);
    if (bytes == null || bytes.isEmpty) {
      Log.error(
        'Could not read the frame at ${framePosition.inMilliseconds}ms of '
        'clip ${source.id}',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    // Beside the clip files rather than in the cache directory: the renderer
    // opens the still while it encodes, and the clip keeps it as its poster.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final imagePath = p.join(
      await getDocumentsPath(),
      'freeze_frame_$stamp.jpg',
    );
    await File(imagePath).writeAsBytes(bytes, flush: true);

    final frames = [
      StopMotionClipFrame(
        path: imagePath,
        duration: reserveDuration,
        holdOverridden: true,
      ),
    ];

    final String? outputPath;
    try {
      outputPath = await StopMotionRenderService.assemble(
        frames: frames,
        aspectRatio: source.targetAspectRatio,
        taskId: taskId,
      );
    } catch (_) {
      await _deleteQuietly(imagePath);
      rethrow;
    }

    if (outputPath == null) {
      Log.error(
        'Freeze frame render produced no file for clip ${source.id}',
        name: _logName,
        category: LogCategory.video,
      );
      await _deleteQuietly(imagePath);
      return null;
    }

    // The encoder can land a frame short of the requested length; trimming
    // against more than the file holds would ask the export for frames past
    // its end.
    final probed = await _probeDuration(outputPath);
    final duration = probed != null && probed > Duration.zero
        ? probed
        : reserveDuration;
    final trimEnd = duration > defaultDuration
        ? duration - defaultDuration
        : Duration.zero;

    return DivineVideoClip(
      id: 'freeze_$stamp',
      video: EditorVideo.file(outputPath),
      duration: duration,
      trimEnd: trimEnd,
      recordedAt: DateTime.now(),
      targetAspectRatio: source.targetAspectRatio,
      // The first clip's ratio is the canvas coordinate system; a freeze put
      // in front of the first clip must not move every layer authored on it.
      originalAspectRatio: source.originalAspectRatio,
      // What the rendered file actually is: already cropped to the target.
      videoAspectRatio: source.targetAspectRatio.value,
      thumbnailPath: imagePath,
      isFreezeFrame: true,
      // The rendered still carries no sound; a zero volume says so to every
      // control that offers to turn it up.
      volume: 0,
      // Still footage of the source, so it still credits the source's author
      // and is signed against the media the frame came from.
      sourceCredits: source.sourceCredits,
      derivedFrom: source.signingSources,
    );
  }

  static Future<Uint8List?> _extractFrame(
    DivineVideoClip clip,
    Duration position,
  ) async {
    final thumbnails = await ProVideoEditor.instance.getThumbnails(
      ThumbnailConfigs(
        video: clip.requireVideo,
        outputSize: VideoEditorConstants.quality.resolutionForAspectRatio(
          clip.targetAspectRatio,
        ),
        timestamps: [position],
        jpegQuality: _jpegQuality,
      ),
    );
    return thumbnails.isEmpty ? null : thumbnails.first;
  }

  static Future<Duration?> _probeDuration(String path) async {
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(path),
      );
      return metadata.duration;
    } catch (error) {
      Log.warning(
        '⚠️ Could not probe the freeze frame render; assuming '
        '${reserveDuration.inMilliseconds}ms: $error',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      Log.warning(
        '⚠️ Failed to delete unused freeze frame image $path: $error',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }
}
