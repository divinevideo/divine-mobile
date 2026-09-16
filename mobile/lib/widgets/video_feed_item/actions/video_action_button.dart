// ABOUTME: Shared base widget for video overlay action buttons.
// ABOUTME: 48x48 tap target containing a 24 icon over a label/count.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/string_utils.dart';

/// Base widget for video overlay action buttons (like, comment, repost, share).
///
/// Matches Figma node `15314:53971`: a 48x48 fully tappable container with a
/// 24 icon over an 8 px gap and a label/small caption. 48x48 is a *minimum* —
/// the column may grow past it so caption text never clips.
///
/// Example usage:
/// ```dart
/// VideoActionButton(
///   icon: DivineIconName.heart,
///   semanticIdentifier: 'like_button',
///   semanticLabel: 'Like video',
///   onPressed: () => handleLike(),
///   iconColor: isLiked ? Colors.red : VineTheme.whiteText,
///   count: totalLikes,
///   labelWhenZero: 'Like',
/// )
/// ```
class VideoActionButton extends StatefulWidget {
  const VideoActionButton({
    required this.icon,
    required this.semanticIdentifier,
    required this.semanticLabel,
    this.onPressed,
    this.onLongPress,
    this.iconColor = VineTheme.whiteText,
    this.count = 0,
    this.isLoading = false,
    this.caption,
    this.labelWhenZero,
    super.key,
  });

  /// The icon to display from the Divine design system.
  final DivineIconName icon;

  /// Semantics identifier for testing (e.g. 'like_button').
  final String semanticIdentifier;

  /// Accessibility label (e.g. 'Like video').
  final String semanticLabel;

  /// Called when the button is tapped. Null disables the button.
  final VoidCallback? onPressed;

  /// Called when the button is long-pressed. Optional secondary affordance —
  /// e.g. opens the list of users who reacted/reposted.
  final VoidCallback? onLongPress;

  /// Color applied to the SVG icon. Defaults to white.
  final Color iconColor;

  /// Count to display beneath the icon. Shows empty space when 0 unless
  /// [labelWhenZero] is provided.
  final int count;

  /// When true, shows a loading spinner instead of the icon.
  final bool isLoading;

  /// Optional fixed caption shown beneath the icon instead of a count or
  /// zero-label. When set, always wins over [count] and [labelWhenZero].
  final String? caption;

  /// Short placeholder label shown beneath the icon when [count] is 0 and
  /// no [caption] is set (e.g. "Like", "Reply"). When null, the caption
  /// slot stays empty at zero count.
  final String? labelWhenZero;

  @override
  State<VideoActionButton> createState() => _VideoActionButtonState();
}

class _VideoActionButtonState extends State<VideoActionButton> {
  /// Cached icon subtree. The [ShadowedDivineIcon] depends only on
  /// [VideoActionButton.icon] and [VideoActionButton.iconColor], never on the
  /// [VideoActionButton.count]. Reusing the same widget instance across
  /// rebuilds lets Flutter skip re-running the icon when only the interaction
  /// count changes, which happens once per incoming like/comment/repost event
  /// during the cold-start flood.
  Widget? _icon;

  @override
  void didUpdateWidget(VideoActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.icon != widget.icon ||
        oldWidget.iconColor != widget.iconColor) {
      _icon = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon ??= ShadowedDivineIcon(
      icon: widget.icon,
      color: widget.iconColor,
    );
    return Semantics(
      identifier: widget.semanticIdentifier,
      container: true,
      explicitChildNodes: true,
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isLoading ? null : widget.onPressed,
        onLongPress: widget.isLoading ? null : widget.onLongPress,
        child: SizedBox(
          width: 48,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  const SizedBox.square(
                    dimension: 24,
                    child: DivineCircularProgressIndicator(
                      strokeWidth: 2,
                      color: VineTheme.whiteText,
                    ),
                  )
                else
                  icon,
                if (!widget.isLoading)
                  _VideoActionCaption(
                    caption: widget.caption,
                    count: widget.count,
                    labelWhenZero: widget.labelWhenZero,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Caption slot beneath a [VideoActionButton] icon.
///
/// Resolves the displayed text in priority order:
/// 1. [caption] — fixed override from the caller.
/// 2. The formatted [count] — once there's at least one interaction.
/// 3. [labelWhenZero] — placeholder word like "Like" / "Reply" when no
///    interactions have landed yet.
///
/// Returns [SizedBox.shrink] when none of the three apply, so the Column
/// above collapses the slot without the 8 px leading gap.
class _VideoActionCaption extends StatelessWidget {
  const _VideoActionCaption({
    required this.caption,
    required this.count,
    required this.labelWhenZero,
  });

  final String? caption;
  final int count;
  final String? labelWhenZero;

  @override
  Widget build(BuildContext context) {
    final text = switch ((caption, count, labelWhenZero)) {
      (final String c, _, _) => c,
      (_, final int n, _) when n > 0 => StringUtils.formatCompactNumber(n),
      (_, _, final String zero) => zero,
      _ => null,
    };

    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: VineTheme.labelSmallFont(color: VineTheme.whiteText).copyWith(
          shadows: VineTheme.buttonShadows,
        ),
        textAlign: TextAlign.center,
        // `softWrap: false` keeps a long count on one line so the width
        // genuinely overflows; with the default the text wraps, is cut at
        // one line, and ellipsizes off the wrap instead of the width.
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
