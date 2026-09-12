// ABOUTME: Thin three-segment budget bar with a label, shown in the top bar
// ABOUTME: Shared by capture-mode recording progress and the stop-motion budget

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Thin three-segment budget bar with a label.
///
/// Segments are laid out by flex, so their unit is the caller's: milliseconds
/// for capture mode's recording progress, captured stills for stop-motion's
/// shot budget. [overflow] renders whatever ran past the limit, which makes
/// [filled] appear to shrink back once the budget is blown.
///
/// Sizes to its content and stretches to whatever width the caller gives it,
/// so it works both full-width in place of the top bar's button row and
/// squeezed into that row's center slot. Callers own the insets.
class VideoRecorderProgressBar extends StatelessWidget {
  const VideoRecorderProgressBar({
    required this.filled,
    required this.remaining,
    required this.overflow,
    required this.label,
    this.labelAbove = false,
    this.labelSpacing = 14,
    super.key,
  });

  /// Consumed part of the budget, capped at the limit.
  final int filled;

  /// Part of the budget still available.
  final int remaining;

  /// Amount consumed beyond the limit.
  final int overflow;

  /// Text rendered next to the bar.
  final String label;

  /// Whether [label] sits above the bar instead of below it.
  final bool labelAbove;

  /// Gap between the bar and its label.
  ///
  /// A caller that needs the bar itself (rather than the whole group) on a
  /// given center line has to mirror this gap on the bar's other side.
  final double labelSpacing;

  /// Style of the label. Public so a mirrored spacer measures the same text.
  static TextStyle get labelStyle =>
      VineTheme.titleSmallFont(color: VineTheme.whiteText);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        mainAxisSize: .min,
        spacing: labelSpacing,
        children: [
          if (labelAbove) Text(label, style: labelStyle),
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: .circular(2),
              color: VineTheme.onSurfaceDisabled,
            ),
            clipBehavior: .antiAlias,
            child: Row(
              children: [
                if (filled > 0)
                  Flexible(
                    flex: filled,
                    child: Container(color: VineTheme.primary),
                  ),
                if (remaining > 0)
                  Flexible(
                    flex: remaining,
                    child: Container(color: VineTheme.onSurfaceDisabled),
                  ),
                if (overflow > 0)
                  Flexible(
                    flex: overflow,
                    child: Container(color: VineTheme.primaryContainer),
                  ),
              ],
            ),
          ),
          if (!labelAbove) Text(label, style: labelStyle),
        ],
      ),
    );
  }
}
