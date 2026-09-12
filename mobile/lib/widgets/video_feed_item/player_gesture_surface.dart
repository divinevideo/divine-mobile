// ABOUTME: The full-bleed gesture surface over a feed video: tap to play/pause,
// ABOUTME: double-tap to like, press-and-hold to peek at the unobstructed frame.
// ABOUTME: Extracted so its semantics can be tested without a video player pool.

import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// The tap/double-tap/long-press surface painted under a feed item's chrome.
///
/// Pulled out of `feed_videos.dart` for one reason: in place, its tap action is
/// gated on a controller that has rendered a first frame, `FeedVideos` takes no
/// controller (it comes from an internal pool), and so no widget test could
/// make the surface interactive. The labelling below shipped broken precisely
/// because nothing could assert it. Here [interactiveReady] is a parameter, so
/// a test can pump the real thing in its real state.
class PlayerGestureSurface extends StatelessWidget {
  /// Creates a [PlayerGestureSurface].
  const PlayerGestureSurface({
    required this.interactiveReady,
    required this.isOwnVideo,
    required this.onTap,
    required this.onDoubleTapDown,
    required this.onLongPressStart,
    super.key,
  });

  /// Whether the player can accept play/pause and like gestures yet.
  final bool interactiveReady;

  /// Suppresses the double-tap-to-like hint on the viewer's own video.
  final bool isOwnVideo;

  /// Play or pause the video.
  final VoidCallback onTap;

  /// Publish a like, anchored at the tap position.
  final void Function(TapDownDetails details) onDoubleTapDown;

  /// Enter immersive mode — hide chrome while the press is held.
  final VoidCallback onLongPressStart;

  @override
  Widget build(BuildContext context) {
    // The annotation must sit DIRECTLY above the GestureDetector. In the
    // original tree it wrapped the whole Stack instead, several layers up and
    // around the chrome siblings, so it annotated a node that owned no tap
    // action while the real tappable node stayed anonymous — on device,
    // SemanticsNode#7(Rect 0,0,440,850, actions: [tap]) with no label. Here
    // there is nothing between the two, so the annotation merges onto the
    // gesture node. (MergeSemantics was tried first and is NOT what fixes
    // this: with the widget extracted, a mutation removing it changes
    // nothing.)
    return Semantics(
      button: true,
      label: context.l10n.videoPlayerPlayVideo,
      hint: isOwnVideo ? null : context.l10n.videoPlayerTapHint,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: interactiveReady ? onTap : null,
        onDoubleTapDown: interactiveReady ? onDoubleTapDown : null,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Press and hold to peek at the unobstructed frame. Deliberately
          // not gated on [interactiveReady] the way tap and double-tap are:
          // those mutate the player or publish a like, while this only hides
          // chrome, which is just as valid over a still-loading frame.
          //
          // Excluded from semantics, and kept on its own detector so the tap
          // action above is still published. A `GestureDetector` publishes
          // `SemanticsAction.longPress` for ANY long-press callback,
          // `onLongPressStart` included — and firing that action delivers no
          // pointer events, so the release path in the parent would never run
          // and a screen-reader user would be left with every control hidden
          // and pointer-blocked until the item was disposed.
          excludeFromSemantics: true,
          onLongPressStart: (_) => onLongPressStart(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
