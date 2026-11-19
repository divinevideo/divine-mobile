// ABOUTME: Fades a chrome layer out while the feed is in immersive mode.
// ABOUTME: Wraps the feed-mode header, the fullscreen app bar, and the
// ABOUTME: per-item overlay so they all disappear on the same signal.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_transition_target.dart';

/// How long the chrome takes to fade out and back in.
///
/// Short enough that releasing feels immediate, long enough that the chrome
/// doesn't pop.
const Duration kFeedImmersiveFadeDuration = Duration(milliseconds: 180);

/// Hides [child] while [FeedImmersiveCubit] reports immersive viewing.
///
/// While a grid tile's picture flies over the player
/// ([VideoTileTransitionScope.hasLandedOf]), [child] is hidden in place and a
/// copy of it flies with the picture instead, above it in the overlay, laid
/// out at the size [child] has here. When the picture lands the copy goes
/// and [child] shows at once, in the same place.
///
/// The cubit is looked up nullably, so surfaces that render feed chrome
/// outside a feed page — the video-editor preview's [FeedModeSwitch], widget
/// tests pumping a single overlay — simply never go immersive instead of
/// throwing for a missing provider.
///
/// [child] is passed through untouched on every rebuild, so a fade toggle
/// re-runs only this widget's build, not the (expensive) chrome subtree.
class FeedImmersiveChrome extends StatefulWidget {
  const FeedImmersiveChrome({required this.child, super.key});

  final Widget child;

  @override
  State<FeedImmersiveChrome> createState() => _FeedImmersiveChromeState();
}

class _FeedImmersiveChromeState extends State<FeedImmersiveChrome> {
  /// Whether the chrome has finished fading back in.
  ///
  /// Pointers stay blocked until this is true. Blocking is driven off the
  /// fade rather than off the flag alone because the flag drops the instant
  /// the viewer lifts or taps to restore it, while the chrome needs
  /// [kFeedImmersiveFadeDuration] to become visible again — and a control
  /// that accepts a tap before the viewer can see it publishes a like or
  /// opens a report they never chose.
  bool _fullyVisible = true;

  /// Whether a tile's picture had landed at the last build.
  bool? _wasLanded;

  final _flyingCopy = OverlayPortalController()..show();

  @override
  Widget build(BuildContext context) {
    final isImmersive = context.select<FeedImmersiveCubit?, bool>(
      (cubit) => cubit?.state.isImmersive ?? false,
    );
    final landed = VideoTileTransitionScope.hasLandedOf(context);
    final hidden = isImmersive || !landed;
    // The flying copy stands in for the chrome on either side of a landing,
    // so the chrome swaps with it at once instead of fading.
    final swapsWithCopy = _wasLanded != null && _wasLanded != landed;
    _wasLanded = landed;
    if (swapsWithCopy) _fullyVisible = !hidden;
    final chrome = IgnorePointer(
      // Blocked immediately on the way out, and until the fade completes on
      // the way back in — the chrome is never tappable while invisible.
      ignoring: hidden || !_fullyVisible,
      child: AnimatedOpacity(
        opacity: hidden ? 0.0 : 1.0,
        // Reduced motion gets the same end state without the cross-fade.
        duration: MediaQuery.disableAnimationsOf(context) || swapsWithCopy
            ? Duration.zero
            : kFeedImmersiveFadeDuration,
        curve: Curves.easeOut,
        onEnd: () {
          final visible = !hidden;
          if (visible != _fullyVisible) {
            setState(() => _fullyVisible = visible);
          }
        },
        child: widget.child,
      ),
    );
    final flight = VideoTileTransitionScope.flightOf(context);
    if (flight == null) return chrome;
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _flyingCopy,
      overlayChildBuilder: (_, layout) => isImmersive
          ? const SizedBox.shrink()
          : _FlyingChrome(
              flight: flight,
              layout: layout,
              // The overlay child sees the overlay's media query, whose padding
              // the page may have removed here.
              mediaQuery: MediaQuery.of(context),
              child: widget.child,
            ),
      child: chrome,
    );
  }
}

/// The copy of a chrome layer that flies with a grid tile's picture, laid out
/// at the size the chrome has in its place and drawn where the current
/// [VideoTileFlightFrame] puts it.
class _FlyingChrome extends StatelessWidget {
  const _FlyingChrome({
    required this.flight,
    required this.layout,
    required this.mediaQuery,
    required this.child,
  });

  final ValueListenable<VideoTileFlightFrame?> flight;
  final OverlayChildLayoutInfo layout;

  /// The media query the chrome lays itself out with in its place.
  final MediaQueryData mediaQuery;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoTileFlightFrame?>(
      valueListenable: flight,
      builder: (context, frame, _) {
        if (frame == null) return const SizedBox.shrink();
        return VideoTileFlightGated(
          gate: frame.gate,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: ClipRRect(
                clipper: _FixedRRect(frame.bounds),
                child: ClipRRect(
                  clipper: _FixedRRect(frame.clip),
                  child: Transform(
                    transform: frame.transform.multiplied(
                      layout.childPaintTransform,
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox.fromSize(
                        size: layout.childSize,
                        child: Opacity(
                          opacity: frame.opacity,
                          child: MediaQuery(
                            data: mediaQuery,
                            child: VideoTileFlightCopy(child: child),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Clips to a rounded rect given in the overlay's coordinates.
class _FixedRRect extends CustomClipper<RRect> {
  const _FixedRRect(this.rrect);

  final RRect rrect;

  @override
  RRect getClip(Size size) => rrect;

  @override
  bool shouldReclip(_FixedRRect oldClipper) => rrect != oldClipper.rrect;
}
