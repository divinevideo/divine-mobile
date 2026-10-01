// ABOUTME: The check button in a list info sheet's header, and the spinner
// ABOUTME: that stands in for it while a save runs.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';

/// The header's check button.
///
/// Disabled until the form can be saved, and replaced by a spinner while a
/// save runs so a second tap cannot start another one.
class ListInfoCheckButton extends StatelessWidget {
  /// Creates the check button.
  const ListInfoCheckButton({
    required this.semanticLabel,
    required this.isSaving,
    required this.onPressed,
    super.key,
  });

  /// Edge of the small icon button's tap target, which the spinner takes
  /// over so that the header does not shift when a save starts.
  static const double _tapTargetSize = 48;

  /// Diameter of the spinner.
  static const double _spinnerSize = 20;

  /// What the button does, for assistive tech.
  final String semanticLabel;

  /// Whether a save is running.
  final bool isSaving;

  /// Saves the form; null while it cannot be saved.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (isSaving) {
      return SizedBox.square(
        dimension: DivineIcon.scaleSize(context, _tapTargetSize),
        child: Center(
          child: SizedBox.square(
            dimension: DivineIcon.scaleSize(context, _spinnerSize),
            child: DivineCircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.primary,
              semanticsLabel: semanticLabel,
            ),
          ),
        ),
      );
    }

    return DivineIconButton(
      icon: DivineIconName.check,
      size: DivineIconButtonSize.small,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
    );
  }
}
