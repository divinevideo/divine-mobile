import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The state of a checkbox.
enum DivineCheckboxState {
  /// Checkbox is not selected.
  unselected,

  /// Checkbox is selected (checked).
  selected,

  /// Checkbox is in an intermediate/indeterminate state.
  intermediate,

  /// Checkbox is disabled and cannot be interacted with.
  disabled,
}

/// A 24x24 sprite-based checkbox that displays different states
/// by showing different portions of a sprite image.
///
/// Two sprites share the same geometry and differ only in the unselected
/// band's box fill — a dark green that reads as an empty box on a dark
/// surface, and a pale one that does the same on a light surface. The
/// selected and indeterminate bands are brand green in both, so they are
/// identical across the pair. Keeping a single widget (rather than swapping
/// in a drawn box for the unselected state) preserves the sliding
/// state-transition animation.
class DivineSpriteCheckbox extends StatelessWidget {
  /// Creates a sprite-based checkbox.
  const DivineSpriteCheckbox({
    required this.state,
    this.animationDuration = const Duration(milliseconds: 100),
    super.key,
  });

  /// Sprite used on the dark palette.
  static const darkSpriteAsset = 'assets/icon/checkbox-sprite.svg';

  /// Sprite used on the light palette.
  static const lightSpriteAsset = 'assets/icon/checkbox-sprite-light.svg';

  /// The current state of the checkbox.
  final DivineCheckboxState state;

  /// Duration for state transition animations.
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    // Sprite is 24x72 with three 24x24 sections stacked vertically
    // Top (0-24): unselected, Middle (24-48): selected,
    // Bottom (48-72): intermediate
    final yOffset = switch (state) {
      DivineCheckboxState.unselected || DivineCheckboxState.disabled => 0.0,
      DivineCheckboxState.selected => -24.0,
      DivineCheckboxState.intermediate => -48.0,
    };

    final opacity = state == DivineCheckboxState.disabled ? 0.5 : 1.0;

    return AnimatedOpacity(
      opacity: opacity,
      duration: animationDuration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.86),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: animationDuration,
                curve: Curves.easeInOut,
                top: yOffset,
                left: 0,
                child: SvgPicture.asset(
                  context.vineColors.isLight
                      ? lightSpriteAsset
                      : darkSpriteAsset,
                  width: 24,
                  height: 72,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Checkbox with label - combines DivineSpriteCheckbox with a text label.
class DivineCheckbox extends StatelessWidget {
  /// Creates a checkbox with a label.
  const DivineCheckbox({
    required this.state,
    required this.label,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.animationDuration = const Duration(milliseconds: 100),
    super.key,
  });

  /// The current state of the checkbox.
  final DivineCheckboxState state;

  /// The label widget displayed next to the checkbox.
  final Widget label;

  /// How the checkbox and label are aligned vertically.
  final CrossAxisAlignment crossAxisAlignment;

  /// Duration for state transition animations.
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        DivineSpriteCheckbox(
          state: state,
          animationDuration: animationDuration,
        ),
        const SizedBox(width: 16),
        Expanded(child: label),
      ],
    );
  }
}

/// Row checkbox with animated border.
///
/// Wraps [DivineCheckbox] in an interactive container with a border
/// that changes color based on selection state.
class DivineRowCheckbox extends StatelessWidget {
  /// Creates a row checkbox with an animated border.
  const DivineRowCheckbox({
    required this.state,
    required this.onChanged,
    required this.label,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.animationDuration = const Duration(milliseconds: 100),
    super.key,
  });

  /// The current state of the checkbox.
  final DivineCheckboxState state;

  /// Called when the checkbox is tapped with the new selection state.
  final ValueChanged<bool> onChanged;

  /// The label widget displayed next to the checkbox.
  final Widget label;

  /// How the checkbox and label are aligned vertically.
  final CrossAxisAlignment crossAxisAlignment;

  /// Duration for state transition animations.
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final isSelected =
        state == DivineCheckboxState.selected ||
        state == DivineCheckboxState.intermediate;
    final isDisabled = state == DivineCheckboxState.disabled;
    final isIntermediate = state == DivineCheckboxState.intermediate;

    // Expose a proper checkbox semantics node: role (via checked/mixed),
    // checked state, and enabled state — merged with the label and tap action
    // into a single node so screen readers announce e.g. "Agree, checkbox,
    // checked". A disabled checkbox is non-interactive (no onChanged, no tap).
    return MergeSemantics(
      child: Semantics(
        enabled: !isDisabled,
        checked: isIntermediate ? null : state == DivineCheckboxState.selected,
        mixed: isIntermediate ? true : null,
        child: GestureDetector(
          onTap: isDisabled ? null : () => onChanged(!isSelected),
          child: AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? context.vineColors.accentPositive
                    : context.vineColors.outlineMuted,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
            child: DivineCheckbox(
              state: state,
              label: label,
              crossAxisAlignment: crossAxisAlignment,
              animationDuration: animationDuration,
            ),
          ),
        ),
      ),
    );
  }
}
