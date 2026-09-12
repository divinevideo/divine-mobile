// ABOUTME: Green pill indicator showing the count of new real-time comments
// ABOUTME: Displayed next to the comments title; tapping scrolls to top

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A green capsule pill that shows "# new" for unread real-time comments.
///
/// Tapping the pill triggers [onTap], which typically scrolls the list
/// to the top and acknowledges the new comments.
class NewCommentsPill extends StatelessWidget {
  const NewCommentsPill({required this.count, required this.onTap, super.key});

  /// The number of new comments to display.
  final int count;

  /// Called when the pill is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: VineTheme.vineGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count new',
          style: VineTheme.labelMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
      ),
    );
  }
}
