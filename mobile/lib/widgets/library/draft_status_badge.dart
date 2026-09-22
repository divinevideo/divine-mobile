// ABOUTME: Small pill badge beside a library row title: the autosave's
// ABOUTME: "in progress", or a scheduled post's queue state.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The badge's colour role.
enum DraftStatusBadgeTone {
  /// Healthy: in progress, scheduled.
  positive,

  /// Needs attention: the post did not go out.
  warning,

  /// Waiting: the relay has not confirmed yet.
  muted,
}

/// Pill badge beside a library row title.
class DraftStatusBadge extends StatelessWidget {
  const DraftStatusBadge({
    required this.label,
    this.tone = DraftStatusBadgeTone.positive,
    super.key,
  });

  final String label;
  final DraftStatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final accent = switch (tone) {
      DraftStatusBadgeTone.positive => colors.accentPositive,
      DraftStatusBadgeTone.warning => colors.accentWarning,
      DraftStatusBadgeTone.muted => colors.onSurfaceMuted,
    };
    final fill = switch (tone) {
      DraftStatusBadgeTone.positive => VineTheme.vineGreen,
      DraftStatusBadgeTone.warning => VineTheme.accentOrange,
      DraftStatusBadgeTone.muted => colors.onSurfaceMuted,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: VineTheme.labelSmallFont(color: accent),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
