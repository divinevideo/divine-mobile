// ABOUTME: Fades a chrome layer out while the feed is in immersive mode.
// ABOUTME: Wraps the feed-mode header, the fullscreen app bar, and the
// ABOUTME: per-item overlay so they all disappear on the same signal.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';

/// How long the chrome takes to fade out and back in.
///
/// Short enough that releasing feels immediate, long enough that the chrome
/// doesn't pop.
const Duration kFeedImmersiveFadeDuration = Duration(milliseconds: 180);

/// Hides [child] while [FeedImmersiveCubit] reports immersive viewing.
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

  @override
  Widget build(BuildContext context) {
    final isImmersive = context.select<FeedImmersiveCubit?, bool>(
      (cubit) => cubit?.state.isImmersive ?? false,
    );
    return IgnorePointer(
      // Blocked immediately on the way out, and until the fade completes on
      // the way back in — the chrome is never tappable while invisible.
      ignoring: isImmersive || !_fullyVisible,
      child: AnimatedOpacity(
        opacity: isImmersive ? 0.0 : 1.0,
        // Reduced motion gets the same end state without the cross-fade.
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : kFeedImmersiveFadeDuration,
        curve: Curves.easeOut,
        onEnd: () {
          final visible = !isImmersive;
          if (visible != _fullyVisible) {
            setState(() => _fullyVisible = visible);
          }
        },
        child: widget.child,
      ),
    );
  }
}
