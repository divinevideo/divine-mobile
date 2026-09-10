// ABOUTME: A reusable circular icon button with semi-transparent background.
// ABOUTME: Used for video overlay action buttons (like, comment, share, etc.)
// ABOUTME: and camera control buttons.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A circular icon button with a semi-transparent background.
///
/// This widget provides a consistent style for action buttons overlaid on
/// video content, such as like, comment, share, and repost buttons.
///
/// Example usage:
/// ```dart
/// CircularIconButton(
///   onPressed: () => handleLike(),
///   icon: Icon(Icons.favorite, color: VineTheme.error),
/// )
/// ```
class CircularIconButton extends StatelessWidget {
  /// Creates a circular icon button.
  ///
  /// The [onPressed] and [icon] parameters are required.
  const CircularIconButton({
    required this.onPressed,
    required this.icon,
    super.key,
    this.backgroundOpacity = 0.3,
    this.backgroundColor = VineTheme.backgroundColor,
    this.size,
    this.padding,
  });

  /// Called when the button is tapped.
  final VoidCallback onPressed;

  /// The icon to display inside the button.
  ///
  /// Typically an [Icon] widget with the desired icon data, color, and size.
  final Widget icon;

  /// The opacity of the background color.
  ///
  /// Defaults to 0.3 for video overlay buttons.
  /// Camera controls typically use 0.5.
  final double backgroundOpacity;

  /// The background color of the button.
  ///
  /// Defaults to [VineTheme.backgroundColor].
  final Color backgroundColor;

  /// The overall size of the button (width and height).
  ///
  /// When specified, the button will be constrained to this size.
  /// The icon should be sized appropriately to fit with padding.
  final double? size;

  /// The padding around the icon inside the button.
  ///
  /// Defaults to [EdgeInsets.zero] for legacy behavior.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      icon: icon,
      padding: padding ?? EdgeInsets.zero,
      constraints: size != null
          ? BoxConstraints.tightFor(width: size, height: size)
          : null,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: backgroundOpacity),
        shape: BoxShape.circle,
      ),
      child: button,
    );
  }
}
