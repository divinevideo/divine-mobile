// ABOUTME: One option row in a list owner's `...` bottom sheet.
// ABOUTME: Shared by the video-list and people-list screens so both sheets
// ABOUTME: render their options identically.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';

/// An icon-and-label option in a list owner's actions sheet.
///
/// Tapping it pops the enclosing route with [action], so the sheet caller
/// receives the choice from `VineBottomSheet.show<T>`. A disabled tile is
/// still listed, greyed out and inert, so the user learns the option exists.
class ListOwnerActionTile<T extends Object> extends StatelessWidget {
  const ListOwnerActionTile({
    required this.identifier,
    required this.label,
    required this.icon,
    required this.action,
    this.isDestructive = false,
    this.enabled = true,
    super.key,
  });

  /// Semantics identifier for integration and widget tests.
  final String identifier;

  /// Visible label, also read as the row's semantic label.
  final String label;

  /// Leading icon.
  final DivineIconName icon;

  /// Value the sheet pops with when this row is tapped.
  final T action;

  /// Renders the row in the destructive color when true.
  final bool isDestructive;

  /// Whether the row responds to taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // onErrorContainer, not fixed likeRed/error: the sheet surface follows
    // the palette and the token keeps destructive contrast in both
    // appearances (#7147, matching the comment options sheet).
    final Color color;
    if (!enabled) {
      color = context.vineColors.onSurfaceMuted;
    } else if (isDestructive) {
      color = context.vineColors.onErrorContainer;
    } else {
      color = context.vineColors.onSurface;
    }

    void select() => Navigator.of(context).pop(action);

    return Semantics(
      identifier: identifier,
      button: true,
      enabled: enabled,
      label: label,
      // excludeSemantics drops the child subtree — including the
      // GestureDetector's tap action — so the action is re-declared here.
      onTap: enabled ? select : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? select : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 16,
            children: [
              DivineIcon(icon: icon, color: color),
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.titleMediumFont(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
