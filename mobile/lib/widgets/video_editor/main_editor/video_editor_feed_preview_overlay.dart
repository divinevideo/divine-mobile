// ABOUTME: Semi-transparent feed UI overlay for the video editor canvas.
// ABOUTME: Shows where action buttons and author info will appear in the feed,
// ABOUTME: so creators can position layers to avoid being hidden.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

/// Overlay that simulates how the feed UI will look on top of the video.
///
/// This helps creators see where action buttons (like, comment, share) and
/// author info will appear, so they can position layers to avoid being hidden.
///
/// The overlay uses the device's screen aspect ratio to compute a
/// phone-screen-shaped frame in the editor's coordinate space. The frame
/// is centered vertically on the video content — matching how the feed
/// renders videos of any aspect ratio.
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

    final screenSize = MediaQuery.sizeOf(context);
    final viewPadding = View.of(context).viewPadding;

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: _animationDuration,
        opacity: isFeedPreviewVisible ? 0.3 : 0.0,
        curve: Curves.easeInOut,
        child: Center(
          child: FittedBox(
            child: SizedBox(
              width: screenSize.width,
              height:
                  screenSize.height -
                  kBottomNavigationBarHeight -
                  viewPadding.bottom,
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
                      content: context.l10n.videoEditorFeedPreviewContent,
                    ),
                    isVisible: true,
                    isActive: true,
                    isPreviewMode: true,
                    isFullscreen: true,
                    showBottomGradient: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
