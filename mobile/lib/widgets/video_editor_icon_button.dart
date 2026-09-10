// ABOUTME: Reusable rounded icon button for video editor controls
// ABOUTME: Customizable size, colors, and shadow styling

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Rounded icon button for video editor controls.
///
/// Note: For design system buttons, use [DivineIconButton] from divine_ui.
class VideoEditorIconButton extends StatelessWidget {
  /// Creates a video editor icon button.
  const VideoEditorIconButton({
    required this.icon,
    super.key,
    this.backgroundColor = VineTheme.backgroundColor,
    this.iconColor = VineTheme.whiteText,
    this.iconSize = 32,
    this.size = 48,
    this.radius = 20,
    this.onTap,
    this.semanticLabel,
  });

  /// The name of the icon.
  final DivineIconName icon;

  /// Background color of the button.
  final Color backgroundColor;

  /// Color of the icon.
  final Color iconColor;

  /// Size of the icon.
  final double iconSize;

  /// Size of the button container.
  final double size;

  /// Callback when the button is tapped.
  final VoidCallback? onTap;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: DivineIcon(size: iconSize, icon: icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}
