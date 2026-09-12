import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

/// Semi-transparent overlay of the last recorded clip's final frame.
///
/// Helps the user align the next shot with the previous one.
/// Uses [AnimatedSwitcher] for smooth fade transitions when the ghost
/// frame changes or disappears.
class VideoRecorderGhostFrame extends ConsumerWidget {
  /// Creates a video recorder ghost frame widget.
  const VideoRecorderGhostFrame({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      showOverlay,
      capturesStills,
      stopMotionLastFrame,
      isFrontCamera,
    ) = context.select(
      (VideoRecorderBloc b) => (
        b.state.showLastClipOverlay,
        b.state.recorderMode.capturesStills,
        b.state.stopMotionLastFrame,
        b.state.isFrontCamera,
      ),
    );

    // Use the last clip that has a ghost frame, not just the last clip.
    // This prevents the overlay from disappearing while recording a new
    // clip that doesn't have a ghost frame yet.
    final clipGhost = ref.watch(
      clipManagerProvider.select((s) {
        for (var i = s.clips.length - 1; i >= 0; i--) {
          final clip = s.clips[i];
          if (clip.ghostFramePath != null) {
            return (
              path: clip.ghostFramePath!,
              isFrontCamera: clip.isFrontCameraLens,
            );
          }
        }
        return null;
      }),
    );

    // Stop-motion assembles at the end, so there are no clips during capture —
    // align the next pose against the last captured still instead. The overlay
    // sits on top of the live preview, which is mirrored for the front camera,
    // so mirror the ghost to match whenever the active lens is front-facing.
    final ghostData = capturesStills
        ? (stopMotionLastFrame != null
              ? (path: stopMotionLastFrame, isFrontCamera: isFrontCamera)
              : null)
        : clipGhost;

    final showGhost = showOverlay && ghostData != null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: showGhost
          ? IgnorePointer(
              key: ValueKey('ghost-frame-${ghostData.path}'),
              child: Opacity(
                opacity: 0.48,
                child: Transform.flip(
                  flipX: ghostData.isFrontCamera,
                  child: ClipThumbnailImage(
                    path: ghostData.path,
                    fit: .cover,
                    width: .infinity,
                    height: .infinity,
                    // Captured stills are full camera resolution (~12MP);
                    // bound the decode to the screen height so a full-screen
                    // live overlay doesn't decode at full resolution.
                    cacheHeight:
                        (MediaQuery.sizeOf(context).height *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    placeholder: const SizedBox.shrink(),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
