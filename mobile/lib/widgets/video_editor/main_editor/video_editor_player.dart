import 'package:divine_video_player/divine_video_player.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/stop_motion/stop_motion_player.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';

/// The clip surface inside the editor canvas.
///
/// The canvas hands this widget a box shaped like the *recording* (the first
/// clip's `originalAspectRatio`), and the native surface stretches to whatever
/// box it gets — so the frames are laid out at [videoAspectRatio], covering the
/// target rect that [targetAspectRatio] cuts out of the box. For a clip whose
/// file still has the recording's shape that surface *is* the box; for one
/// whose file a crop / rotate transform reshaped it is the target rect itself,
/// rather than the file squeezed to the recording's shape.
class VideoEditorPlayer extends StatelessWidget {
  const VideoEditorPlayer({
    required this.controller,
    required this.targetAspectRatio,
    required this.videoAspectRatio,
    required this.bodySize,
    required this.renderSize,
    this.stopMotionFrames,
    this.stopMotionPosition,
    super.key,
  });

  final model.AspectRatio targetAspectRatio;

  /// Aspect ratio of the frames the surface shows — the file at the playhead,
  /// not the recording the canvas is shaped after.
  final double videoAspectRatio;
  final DivineVideoPlayerController? controller;
  final Size bodySize;
  final Size renderSize;

  /// Captured stills when editing a stop-motion clip. When non-null the preview
  /// plays the frame sequence via [StopMotionPlayer] instead of a video — the
  /// clip has no mp4 (it is rendered only at publish).
  final List<StopMotionClipFrame>? stopMotionFrames;

  /// Current editor-timeline position, forwarded to the controlled
  /// [StopMotionPlayer] so the shown frame follows play/pause and scrubbing
  /// instead of free-running. Only meaningful when [stopMotionFrames] is set.
  final Duration? stopMotionPosition;

  @override
  Widget build(BuildContext context) {
    final frames = stopMotionFrames;

    return ClipPath(
      clipper: _RoundedRectClipper(
        bodySize: bodySize,
        targetAspectRatio: targetAspectRatio.value,
        borderRadius: VideoEditorConstants.canvasRadius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final surfaceSize = computeSurfaceSize(
            widgetSize: constraints.biggest,
            bodySize: bodySize,
            targetAspectRatio: targetAspectRatio.value,
            videoAspectRatio: videoAspectRatio,
          );
          // Centred in the box; a file wider than it (a landscape import in
          // a portrait session) covers the target rect by overflowing the box
          // sideways, and the clipper above cuts it back to the rect.
          return OverflowBox(
            minWidth: surfaceSize.width,
            maxWidth: surfaceSize.width,
            minHeight: surfaceSize.height,
            maxHeight: surfaceSize.height,
            child: frames != null
                ? StopMotionPlayer(
                    frames: frames,
                    position: stopMotionPosition,
                    cacheHeight:
                        (renderSize.height *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                  )
                : DivineVideoPlayer(
                    controller: controller,
                    placeholder: VideoEditorThumbnail(contentSize: renderSize),
                    // The editor swaps an external thumbnail spinner straight
                    // to the player once the frame is decoded, so the first
                    // frame is already rendered when this mounts. Cross-fade
                    // the thumbnail out instead of hard-cutting (which read as
                    // a flicker).
                    crossFadePlaceholder: true,
                  ),
          );
        },
      ),
    );
  }
}

class _RoundedRectClipper extends CustomClipper<Path> {
  const _RoundedRectClipper({
    required this.bodySize,
    required this.targetAspectRatio,
    required this.borderRadius,
  });

  final Size bodySize;
  final double targetAspectRatio;
  final double borderRadius;

  @override
  Path getClip(Size size) {
    final clipSize = computeClipSize(
      widgetSize: size,
      bodySize: bodySize,
      targetAspectRatio: targetAspectRatio,
    );

    // Convert 32px screen radius to widget coordinates
    final radius = Radius.circular(
      borderRadius * clipSize.width / bodySize.width,
    );

    return Path()..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: clipSize.width,
          height: clipSize.height,
        ),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
    );
  }

  @override
  bool shouldReclip(_RoundedRectClipper oldClipper) =>
      bodySize != oldClipper.bodySize ||
      targetAspectRatio != oldClipper.targetAspectRatio ||
      borderRadius != oldClipper.borderRadius;
}

/// Computes the clipped region for the video player.
///
/// Exposed for testing only.
@visibleForTesting
Size computeClipSize({
  required Size widgetSize,
  required Size bodySize,
  required double targetAspectRatio,
}) {
  if (widgetSize.aspectRatio > targetAspectRatio) {
    return Size(widgetSize.height * targetAspectRatio, widgetSize.height);
  }
  return Size(widgetSize.width, widgetSize.width / targetAspectRatio);
}

/// Size the native surface is laid out at: frames of [videoAspectRatio]
/// scaled to cover the [computeClipSize] rect, the way the export centre-crops
/// every clip to the composition's ratio.
///
/// When [videoAspectRatio] is the ratio of [widgetSize] itself — the canvas box
/// shaped like the recording — this is [widgetSize], so an untransformed clip
/// fills the box exactly.
///
/// Exposed for testing only.
@visibleForTesting
Size computeSurfaceSize({
  required Size widgetSize,
  required Size bodySize,
  required double targetAspectRatio,
  required double videoAspectRatio,
}) {
  final clipSize = computeClipSize(
    widgetSize: widgetSize,
    bodySize: bodySize,
    targetAspectRatio: targetAspectRatio,
  );
  if (videoAspectRatio > targetAspectRatio) {
    return Size(clipSize.height * videoAspectRatio, clipSize.height);
  }
  return Size(clipSize.width, clipSize.width / videoAspectRatio);
}
