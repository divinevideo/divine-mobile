// ABOUTME: Bullet point text row for use in confirmation dialogs
// ABOUTME: Reusable component for block/unblock confirmation views

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A bullet point text row for use in confirmation dialogs.
class BulletPoint extends StatelessWidget {
  /// Creates a bullet point with the given text.
  const BulletPoint(this.text, {super.key});

  /// The text to display after the bullet.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•  ',
          style: VineTheme.bodyLargeFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
