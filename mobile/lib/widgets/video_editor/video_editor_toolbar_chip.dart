// ABOUTME: A tappable pill for the editor toolbar's centre slot, between the
// ABOUTME: back and done buttons, such as the stop-motion frames chip.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/text_scale_limits.dart';

/// A tappable pill with an [icon] and a [label], sized for the centre slot
/// of a `VideoEditorToolbar`.
///
/// The pill keeps its natural size, and a long [label] ellipsizes when the
/// slot is narrower. Its hit area grows to the 48 dp minimum touch target.
class VideoEditorToolbarChip extends StatelessWidget {
  /// Creates a chip that calls [onTap].
  const VideoEditorToolbarChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticValue,
    this.liveRegion = false,
    super.key,
  });

  /// The icon before the label.
  final DivineIconName icon;

  /// The visible text, which is also what a screen reader announces.
  final String label;

  /// Called when the chip is tapped.
  final VoidCallback onTap;

  /// Extra state a screen reader announces after [label].
  final String? semanticValue;

  /// Whether a screen reader announces the chip when it appears or its
  /// [label] changes, for a chip that comes and goes on its own.
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      value: semanticValue,
      liveRegion: liveRegion,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The width/height factors are essential: the toolbar row is laid out
        // with loose (near-full-height) constraints, so a plain Center would
        // grow to fill them and stretch the whole toolbar down the editor.
        // Sizing to the child means the ConstrainedBox only enforces the 48dp
        // minimum.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.vineColors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    DivineIcon(
                      icon: icon,
                      color: context.vineColors.mutedText,
                      size: 16,
                    ),
                    Flexible(
                      // Capped like the editor's other chips, so a large
                      // system font does not push the toolbar buttons out.
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: chipLabelTextScaleLimit,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VineTheme.labelLargeFont(
                            color: context.vineColors.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
