// ABOUTME: Shared Hero helpers for video clip grid-to-preview transitions
// ABOUTME: Keeps tags and decorative fallback thumbnails consistent

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

String videoClipPreviewHeroTag(String clipId) => 'Video-Clip-Preview-$clipId';

class VideoClipThumbnailPlaceholder extends StatelessWidget {
  const VideoClipThumbnailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return DivineIcon(
      icon: DivineIconName.videoCamera,
      color: context.vineColors.mutedText,
      size: 32,
    );
  }
}

/// [VideoClipThumbnailPlaceholder] with the ground the grid card paints
/// behind it.
///
/// The card's [ColoredBox] sits *outside* its [Hero], so a shuttle flying in
/// the navigator overlay has nothing behind it: a clip whose thumbnail file
/// is gone would fly as a bare icon over the scrim instead of the tile the
/// user just tapped. A flight brings its own ground.
class VideoClipThumbnailTile extends StatelessWidget {
  const VideoClipThumbnailTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.card,
      child: const VideoClipThumbnailPlaceholder(),
    );
  }
}
