import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_cover_screen.dart';
import 'package:openvine/widgets/video_editor/video_editor_processing_overlay.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_preview_thumbnail.dart';

/// Video clip preview widget with thumbnail and play button.
///
/// Displays a thumbnail of the recorded video and allows opening
/// the full-screen preview when tapped. Shows processing overlay
/// while the video is being rendered.
class VideoMetadataCaptureClipPreview extends ConsumerWidget {
  /// Creates a video metadata clip preview.
  const VideoMetadataCaptureClipPreview({super.key});

  /// Opens the cover selection screen.
  Future<void> _openCoverEditor(
    BuildContext context,
    DivineVideoClip clip,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'video_metadata_cover'),
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (_, _, _) => VideoMetadataCoverScreen(clip: clip),
        transitionsBuilder: (_, animation, _, child) {
          if (reduceMotion) return child;
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the first (and only) clip from manager
    final clips = ref.watch(clipManagerProvider).clips;
    if (clips.isEmpty) return const SizedBox.shrink();
    // Watch processing state and rendered clip
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          isProcessing: s.isProcessing,
          renderFailed: s.renderFailed,
          finalRenderedClip: s.finalRenderedClip,
        ),
      ),
    );
    final clip = state.finalRenderedClip ?? clips.first;
    final isReady = state.finalRenderedClip != null;

    return Center(
      child: SizedBox(
        height: 200,
        // Rounds the thumbnail from outside the Hero: a clip inside the Hero
        // child rides into the flight shuttle and fights the shape the
        // preview's flightShuttleBuilder is morphing towards.
        child: ClipRRect(
          borderRadius: .circular(VideoEditorConstants.clipPreviewCornerRadius),
          // Hero animation to preview screen
          child: Hero(
            tag: VideoEditorConstants.heroMetaPreviewId,
            // Use linear flight path instead of curved arc
            createRectTween: (begin, end) => RectTween(begin: begin, end: end),
            child: AspectRatio(
              aspectRatio: clip.targetAspectRatio.value,
              child: Semantics(
                button: true,
                enabled: isReady,
                label: context.l10n.videoMetadataOpenPreviewSemanticLabel,
                child: GestureDetector(
                  onTap: isReady
                      ? () =>
                            _openCoverEditor(context, state.finalRenderedClip!)
                      : null,
                  child: Stack(
                    children: [
                      // Video thumbnail or placeholder
                      ExcludeSemantics(
                        child: AnimatedSwitcher(
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                fit: .expand,
                                alignment: .center,
                                children: [...previousChildren, ?currentChild],
                              ),

                          duration: const Duration(milliseconds: 150),
                          child: clip.thumbnailPath != null
                              ? // Video thumbnail image
                                VideoMetadataCapturePreviewThumbnail(clip: clip)
                              : // Fallback placeholder
                                ColoredBox(
                                  color: context.vineColors.onSurfaceMuted,
                                  child: const DivineIcon(
                                    icon: .playCircle,
                                    size: 64,
                                    color: VineTheme.whiteText,
                                  ),
                                ),
                        ),
                      ),
                      // Processing overlay with edit-cover icon
                      VideoEditorProcessingOverlay(
                        clip: clip,
                        isProcessing:
                            state.finalRenderedClip == null ||
                            state.isProcessing,
                        hasFailed: state.renderFailed,
                        onRetry: () => ref
                            .read(videoEditorProvider.notifier)
                            .startRenderVideo(),
                        inactivePlaceholder: Center(
                          child: DivineIconButton(
                            icon: .pencilSimpleLine,
                            type: .ghostOverMedia,
                            size: .small,
                            semanticLabel:
                                context.l10n.videoMetadataEditCoverTitle,
                            onPressed: () => _openCoverEditor(
                              context,
                              state.finalRenderedClip!,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
