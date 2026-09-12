// ABOUTME: Pill showing whether a badge award has been pinned to a profile.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A small status pill for badge acceptance state.
///
/// Green when [accepted], amber while the award is still only addressed to
/// someone and not yet on their profile.
class BadgeStatusPill extends StatelessWidget {
  /// Creates the pill.
  const BadgeStatusPill({
    required this.label,
    required this.accepted,
    super.key,
  });

  /// Text shown inside the pill.
  final String label;

  /// Whether the award has been accepted.
  final bool accepted;

  @override
  Widget build(BuildContext context) {
    final pending = context.vineColors.accentChipYellow;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accepted
            ? VineTheme.vineGreen.withValues(alpha: 0.14)
            : pending.container,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accepted
              ? context.vineColors.accentPositive
              : pending.onContainer,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: VineTheme.labelSmallFont(
            color: accepted
                ? context.vineColors.accentPositive
                : pending.onContainer,
          ),
        ),
      ),
    );
  }
}
