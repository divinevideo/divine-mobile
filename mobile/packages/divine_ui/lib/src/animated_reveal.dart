// ABOUTME: Grows late-arriving content into place instead of snapping it in.
// ABOUTME: A null child is the empty state, keeping the box mounted at 0 high.

import 'package:material_ui/material_ui.dart';

/// Reveals content that arrives after its surroundings have painted.
///
/// Asynchronous data — a relay round-trip, a profile fetch, a confirmation
/// status — lands on an already-painted screen. Swapping an empty box for the
/// finished widget in a single frame shoves everything below it down. This
/// grows the box into place instead, so its siblings slide rather than jump:
///
/// ```dart
/// AnimatedReveal(
///   child: reposters.isEmpty ? null : RepostersRow(reposters),
/// )
/// ```
///
/// A null [child] is the empty state. Keep this widget mounted while empty
/// rather than dropping it from the tree behind a conditional — one that only
/// appears together with its content mounts at its final size and has nothing
/// to animate from.
///
/// Layout-transparent: the child is laid out under the constraints this
/// widget receives, so wrapping an existing widget does not move or resize
/// it. Content already present when this mounts is not animated. Honours
/// [MediaQueryData.disableAnimations].
///
/// Needs a bounded-width parent: the empty state spans the full available
/// width so only the height animates, which throws under an unbounded width
/// (an unconstrained [Row] child, a horizontal list).
class AnimatedReveal extends StatefulWidget {
  /// Creates an [AnimatedReveal].
  const AnimatedReveal({
    this.child,
    this.duration = _defaultDuration,
    super.key,
  });

  static const _defaultDuration = Duration(milliseconds: 220);

  /// The content to reveal, or null while there is nothing to show.
  final Widget? child;

  /// How long the reveal takes.
  final Duration duration;

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal> {
  /// Content that is already there when this mounts has not "arrived", so it
  /// must not fade in on first paint.
  late final bool _startsRevealed = widget.child != null;

  @override
  Widget build(BuildContext context) {
    final content = widget.child;
    // Drop the animators entirely under reduce motion rather than passing them
    // Duration.zero: a zero-duration AnimatedSize completes its controller
    // synchronously inside performLayout, which re-dirties the render object
    // mid-layout and trips a framework assertion.
    if (MediaQuery.disableAnimationsOf(context)) {
      return content ?? const SizedBox(width: .infinity);
    }

    return AnimatedSize(
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.topStart,
      // The empty state spans the full available width so only the height
      // animates when content arrives.
      child: content == null
          ? const SizedBox(width: .infinity)
          // Opacity rather than an AnimatedSwitcher: the switcher stacks its
          // children and hands them loose constraints, which shrink-wraps and
          // centres a child that the surrounding layout meant to stretch.
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: _startsRevealed ? 1.0 : 0.0, end: 1),
              duration: widget.duration,
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: content,
            ),
    );
  }
}
