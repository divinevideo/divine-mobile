// ABOUTME: Shared Hero helpers for video clip grid-to-preview transitions
// ABOUTME: Keeps tags and decorative fallback thumbnails consistent

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

String videoClipPreviewHeroTag(String clipId) => 'Video-Clip-Preview-$clipId';

/// The tile a clip shows in place of a thumbnail it does not have: a soft
/// diagonal gradient with a camera icon in its centre.
///
/// It paints its own ground because the grid card's background sits
/// *outside* the card's [Hero]: a shuttle flying in the navigator overlay
/// would otherwise show a bare icon over the scrim instead of the tile the
/// user just tapped.
class VideoClipThumbnailPlaceholder extends StatelessWidget {
  const VideoClipThumbnailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    // Every caller hands this the tight constraints of a full tile, so the
    // icon is centred; unwrapped, it would be stretched across the tile.
    // Default icon size: the camera glyph is about 1.6 times as wide as it is
    // tall, so anything larger crowds a five-column grid tile.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [colors.containerLow, colors.surfaceContainer],
        ),
      ),
      child: Center(
        child: DivineIcon(
          icon: DivineIconName.videoCamera,
          color: colors.onSurfaceMuted,
        ),
      ),
    );
  }
}
