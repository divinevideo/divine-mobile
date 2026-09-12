// ABOUTME: A reusable rounded-square icon button with border and shadow.
// ABOUTME: Used for auth screen navigation buttons (back, info, switch account).

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A rounded-square icon button matching the design system's "icon button"
/// component.
///
/// Used for navigation and action buttons in auth screens (back, info,
/// switch account). For circular video overlay buttons, use
/// [CircularIconButton] instead.
///
/// Example usage:
/// ```dart
/// RoundedIconButton(
///   onPressed: () => context.pop(),
///   semanticLabel: context.l10n.commonBack,
///   icon: DivineIcon(
///     icon: DivineIconName.caretLeft,
///     color: context.vineColors.onIconButton,
///   ),
/// )
/// ```
class RoundedIconButton extends StatelessWidget {
  /// Creates a rounded-square icon button.
  const RoundedIconButton({
    required this.onPressed,
    required this.icon,
    required this.semanticLabel,
    this.semanticIdentifier,
    super.key,
  });

  /// Called when the button is tapped. When null, the button is visually
  /// unchanged but the tap is ignored.
  final VoidCallback? onPressed;

  /// The icon to display inside the button.
  final Widget icon;

  /// Screen-reader label describing the action.
  ///
  /// Required: the icon alone carries no meaning, so a missing label leaves
  /// the button announced as nothing at all. Pass a localized string.
  final String semanticLabel;

  /// Stable `Semantics(identifier:)` value used as a UI-test anchor.
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      identifier: semanticIdentifier,
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 48,
          width: 48,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.vineColors.outlineMuted,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: VineTheme.innerShadow,
                blurRadius: 0.6,
                offset: Offset(0.4, 0.4),
              ),
              BoxShadow(
                color: VineTheme.innerShadow,
                blurRadius: 1,
                offset: Offset(1, 1),
              ),
            ],
          ),
          child: icon,
        ),
      ),
    );
  }
}
