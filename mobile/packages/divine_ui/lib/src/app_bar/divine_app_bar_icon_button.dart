import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A styled icon button for use in [DiVineAppBar].
///
/// Delegates its rendering to [DivineIconButton] at
/// [DivineIconButtonSize.small] (40px visible / 24px icon / 16px border
/// radius / 48px tap target) — every [DiVineAppBarStyle] preset in the app
/// uses exactly these dimensions, so no configurable size is exposed here.
///
/// Example usage:
/// ```dart
/// DivineAppBarIconButton(
///   icon: const SvgIconSource('assets/icon/CaretLeft.svg'),
///   onPressed: () => context.pop(),
///   semanticLabel: 'Go back',
/// )
/// ```
class DivineAppBarIconButton extends StatelessWidget {
  /// Creates a DiVineAppBar icon button.
  const DivineAppBarIconButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.semanticIdentifier,
    this.backgroundColor,
    this.borderSide,
    this.iconColor,
    super.key,
  });

  /// The icon to display.
  final IconSource icon;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// Tooltip text shown on long press.
  final String? tooltip;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// Stable `Semantics(identifier:)` value used as a UI-test anchor.
  ///
  /// Surfaces as an iOS `accessibilityIdentifier` / Android resource id, so
  /// E2E tests can target the button by id instead of by its localized label.
  final String? semanticIdentifier;

  /// Background color of the button container.
  ///
  /// Defaults to the `iconButton` color of the active appearance mode.
  final Color? backgroundColor;

  /// Optional border for the button container.
  ///
  /// When non-null, the button renders as [DivineIconButtonType.secondary],
  /// whose built-in 2px semantic `outlineMuted` border matches every
  /// current usage of this param exactly. The supplied [BorderSide]'s own
  /// color/width are not independently honored.
  final BorderSide? borderSide;

  /// Color of the icon.
  ///
  /// Defaults to the `onNav` color of the active appearance mode.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return DivineIconButton.fromSource(
      icon: icon,
      onPressed: onPressed,
      type: borderSide != null
          ? DivineIconButtonType.secondary
          : DivineIconButtonType.primary,
      size: DivineIconButtonSize.small,
      backgroundColor: backgroundColor ?? context.vineColors.iconButton,
      foregroundColor: iconColor ?? context.vineColors.onNav,
      showShadow: false,
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      semanticIdentifier: semanticIdentifier,
    );
  }
}
