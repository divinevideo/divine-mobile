// ABOUTME: Rounds the metadata clip-preview hero while it is in flight.
// ABOUTME: Both destinations on that tag wrap their shuttle in this.

import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';

/// Carries a rounded shape through a [VideoEditorConstants.heroMetaPreviewId]
/// flight.
///
/// The flying widget is lifted into the navigator overlay, above the
/// destination screen's own clip, so that clip cannot reach it — the corners
/// only appear once the flight lands. Clip the shuttle here instead, morphing
/// out of the thumbnail's all-round
/// [VideoEditorConstants.clipPreviewCornerRadius] into
/// [destinationBorderRadius].
///
/// The animation's endpoints mean the same thing in both directions — 0 is the
/// metadata screen, 1 is the destination — because a push drives it from the
/// pushed route's animation and a pop from the popped one. A pop runs 1 to 0,
/// so a single lerp covers the way back.
///
/// Set this from the *destination's* [Hero], not the thumbnail's: on a pop the
/// destination is the thumbnail, which has no builder, so Flutter falls back to
/// the route being left. A builder on the thumbnail would instead win over
/// every destination's.
class MetadataHeroCorners extends StatelessWidget {
  /// Creates the flight clip for a metadata clip-preview hero.
  const MetadataHeroCorners({
    required this.animation,
    required this.destinationBorderRadius,
    required this.child,
    super.key,
  });

  /// The flight's progress, 0 at the metadata screen and 1 at the destination.
  final Animation<double> animation;

  /// Shape the destination rests at, which the flight morphs into.
  final BorderRadius destinationBorderRadius;

  /// The flying hero's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => ClipRRect(
        borderRadius: BorderRadius.lerp(
          BorderRadius.circular(VideoEditorConstants.clipPreviewCornerRadius),
          destinationBorderRadius,
          animation.value,
        )!,
        child: child,
      ),
    );
  }
}
