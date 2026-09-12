import 'dart:async';

import 'package:divine_ui/src/skeleton/vine_skeleton_effect.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Wraps an avatar + name subtree with the identity-loading skeleton pattern
/// originally tuned in `_ProfileHeaderWidgetState` (#4163 / #4183).
///
/// While [isLoading] is `true`, the subtree shimmers via [Skeletonizer]. After
/// [fallthroughTimeout] elapses without [isLoading] flipping to `false`, the
/// shimmer dissolves so the underlying widgets — typically a generated-name
/// fallback or identicon — become visible. This avoids an indefinite shimmer
/// for users whose Kind 0 profile genuinely never resolves (classic Viners).
///
/// The fallthrough timer is reconciled in `initState` and `didUpdateWidget`,
/// so `build()` is a pure function of [isLoading] and the expired flag.
/// Repeated rebuilds with the same [isLoading] value are no-ops; the timer
/// only restarts when [isLoading] flips.
///
/// Static chrome inside the wrapped subtree (timestamps, "You" pills, link
/// affordances) should be wrapped in `Skeleton.keep` so it stays interactive
/// during the loading window — the same pattern used on the profile header.
class IdentitySkeletonizer extends StatefulWidget {
  /// Wraps [child] in a skeleton shimmer while [isLoading] is `true`,
  /// dissolving the shimmer after [fallthroughTimeout] regardless.
  const IdentitySkeletonizer({
    required this.isLoading,
    required this.child,
    this.fallthroughTimeout = const Duration(seconds: 7),
    this.excludeSemantics = false,
    super.key,
  });

  /// Whether the underlying identity is still resolving. The caller is
  /// responsible for deriving this from its own loading source (BLoC state,
  /// Riverpod `AsyncValue`, nullable profile field, etc.).
  final bool isLoading;

  /// Maximum window during which the shimmer is shown. After this elapses
  /// the shimmer dissolves even if [isLoading] is still `true`, so a user
  /// who genuinely has no Kind 0 sees the underlying generated-name
  /// fallback instead of an infinite shimmer.
  final Duration fallthroughTimeout;

  /// Hides placeholder identity semantics while the shimmer is active.
  ///
  /// Opt in only when the child is wholly placeholder content. Interactive
  /// [Skeleton.keep] descendants must remain available to assistive tech.
  final bool excludeSemantics;

  /// The avatar + name subtree to skeletonize.
  final Widget child;

  @override
  State<IdentitySkeletonizer> createState() => _IdentitySkeletonizerState();
}

/// Lays the switch animation out from the leading edge, filling the slot.
///
/// `AnimatedSwitcher`'s default layout builder is a `Stack` with
/// `alignment: Alignment.center`, so every name wrapped by this widget was
/// centred inside whatever slot it was given — visibly so in the inbox, where
/// the conversation title floated while the preview beneath it stayed
/// left-aligned. The switch animation is worth keeping; the centring is not.
///
/// The fit stays **loose** on purpose. `StackFit.expand` also lead-aligns, but
/// it forces tight constraints on the child, which throws
/// `RenderBox was not laid out` wherever the slot is horizontally unbounded —
/// the following bar's horizontal list, for one. Loose constraints still carry
/// the slot's `maxWidth`, so a long name ellipsizes at the same width it always
/// did; only the leading alignment changes.
Widget _leadingAlignedSwitcherLayout(
  Widget? currentChild,
  List<Widget> previousChildren,
) {
  return Stack(
    alignment: AlignmentDirectional.centerStart,
    children: <Widget>[
      ...previousChildren,
      ?currentChild,
    ],
  );
}

class _IdentitySkeletonizerState extends State<IdentitySkeletonizer> {
  Timer? _timer;
  bool _timeoutExpired = false;
  bool? _wasLoading;

  @override
  void initState() {
    super.initState();
    _syncTimer(isLoading: widget.isLoading);
  }

  @override
  void didUpdateWidget(IdentitySkeletonizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer(isLoading: widget.isLoading);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer({required bool isLoading}) {
    if (_wasLoading == isLoading) return;
    _wasLoading = isLoading;
    _timer?.cancel();
    _timer = null;
    _timeoutExpired = false;
    if (!isLoading) return;
    _timer = Timer(widget.fallthroughTimeout, () {
      if (mounted) setState(() => _timeoutExpired = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSkeletonized = widget.isLoading && !_timeoutExpired;
    final skeleton = Skeletonizer(
      enabled: isSkeletonized,
      enableSwitchAnimation: true,
      switchAnimationConfig: const SwitchAnimationConfig(
        layoutBuilder: _leadingAlignedSwitcherLayout,
      ),
      effect: vineSkeletonEffectOf(context),
      child: widget.child,
    );
    if (!widget.excludeSemantics) return skeleton;
    return ExcludeSemantics(excluding: isSkeletonized, child: skeleton);
  }
}
