// ABOUTME: Semi-transparent feed UI overlay for the video editor canvas.
// ABOUTME: Shows where action buttons and author info will appear in the feed,
// ABOUTME: so creators can position layers to avoid being hidden.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/widgets/caption_pill.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

/// Overlay that simulates how the feed UI will look on top of the video.
///
/// This helps creators see where action buttons (like, comment, share) and
/// author info will appear, so they can position layers to avoid being hidden.
///
/// The overlay frames the video like the feed does: the screen minus the
/// bottom nav (or the comment bar, which is as tall) and the bottom inset.
/// The frame is centered vertically on the video content — matching how the
/// feed renders videos of any aspect ratio.
///
/// The title, description, sound and captions are only settled when the
/// video is published, and each line of them pushes the author row up. So
/// the overlay shows the tallest form of each: a title line, a full
/// two-line description, a sound row and a caption pill.
class VideoEditorFeedPreviewOverlay extends ConsumerWidget {
  /// Creates a [VideoEditorFeedPreviewOverlay].
  const VideoEditorFeedPreviewOverlay({
    required this.targetAspectRatio,
    required this.isFeedPreviewVisible,
    super.key,
  });

  static const _animationDuration = Duration(milliseconds: 200);

  /// The target aspect ratio of the video being edited.
  final double targetAspectRatio;

  /// Whether the feed preview is currently visible.
  final bool isFeedPreviewVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicKey = ref.watch(
      nostrServiceProvider.select((s) => s.publicKey),
    );
    final captionCue = context.select(
      (TimelineOverlayBloc bloc) => _longestCaptionCue(bloc.state),
    );
    final l10n = context.l10n;

    final screenSize = MediaQuery.sizeOf(context);
    // Read from the window: the editor's own MediaQuery has the bottom inset
    // removed already. The window reports it in physical pixels.
    final view = View.of(context);
    final bottomInset = view.viewPadding.bottom / view.devicePixelRatio;

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: _animationDuration,
        opacity: isFeedPreviewVisible ? 0.3 : 0.0,
        curve: Curves.easeInOut,
        child: Center(
          child: FittedBox(
            child: SizedBox(
              width: screenSize.width,
              height: screenSize.height - vineBottomNavBarHeight - bottomInset,
              // The feed's video ends above the bottom nav, so its overlay
              // sees no bottom inset.
              child: MediaQuery.removeViewPadding(
                context: context,
                removeBottom: true,
                child: Stack(
                  fit: .expand,
                  children: [
                    const FeedModeSwitch(isPreviewMode: true),

                    VideoOverlayActions(
                      video: VideoEvent(
                        id: 'preview',
                        pubkey: publicKey,
                        timestamp: DateTime.now(),
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                        title: l10n.videoMetadataTitleLabel,
                        // The line break keeps the description at its full
                        // two lines, however short each line is.
                        content:
                            '${l10n.videoMetadataDescriptionLabel}\n'
                            '${l10n.videoEditorFeedPreviewContent}',
                      ),
                      subtitleLayer: Padding(
                        padding: const EdgeInsets.only(
                          bottom: videoOverlaySubtitleGap,
                        ),
                        child: CaptionPill(
                          text: captionCue ?? l10n.videoEditorCaptionsLabel,
                        ),
                      ),
                      isVisible: true,
                      isActive: true,
                      isPreviewMode: true,
                      isFullscreen: true,
                      showBottomGradient: false,
                      showSoundRowPlaceholder: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The longest of the edit's own caption cues the feed shows in its caption
/// pill, or `null` when it has none.
///
/// Burned-in captions are part of the video instead. Without cues of its own
/// the feed can still show a transcript of the video's speech.
String? _longestCaptionCue(TimelineOverlayState state) {
  if (state.captionsBurnIn) return null;
  String? longest;
  for (final item in state.items) {
    if (item.type != TimelineOverlayType.captions || item.layer != null) {
      continue;
    }
    final text = item.label.trim();
    if (text.length > (longest?.length ?? 0)) longest = text;
  }
  return longest;
}
