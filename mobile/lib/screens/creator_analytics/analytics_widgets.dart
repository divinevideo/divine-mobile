// ABOUTME: Building blocks shared by the Creator Analytics dashboard cards.
// ABOUTME: Card chrome, rank badge, and localized failure messages.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/l10n/l10n.dart';

/// Titled card that frames one section of the Creator Analytics dashboard.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    required this.title,
    required this.child,
    this.info,
    super.key,
  });

  final String title;
  final Widget child;

  /// Optional info affordance rendered as a trailing icon button in the title
  /// row. [label] is its accessibility label and tooltip. #8276.
  final ({VoidCallback onPressed, String label})? info;

  @override
  Widget build(BuildContext context) {
    final info = this.info;
    final titleText = Text(
      title,
      style: VineTheme.titleSmallFont(color: context.vineColors.primaryText),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info == null)
            titleText
          else
            Row(
              children: [
                Expanded(child: titleText),
                DivineIconButton(
                  icon: DivineIconName.info,
                  onPressed: info.onPressed,
                  semanticLabel: info.label,
                  tooltip: info.label,
                  type: DivineIconButtonType.ghostSecondary,
                  size: DivineIconButtonSize.small,
                  showShadow: false,
                ),
              ],
            ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Round position marker for a ranked analytics row.
class AnalyticsRankBadge extends StatelessWidget {
  const AnalyticsRankBadge({required this.rank, super.key});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VineTheme.vineGreen.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$rank',
        style: VineTheme.bodySmallFont(color: context.vineColors.primaryText),
      ),
    );
  }
}

/// User-facing copy for a failed creator analytics load.
extension CreatorAnalyticsFailureKindL10n on CreatorAnalyticsFailureKind {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    CreatorAnalyticsFailureKind.serverUnavailable =>
      l10n.analyticsServerUnavailable,
    CreatorAnalyticsFailureKind.connectionIssue =>
      l10n.analyticsConnectionIssue,
    CreatorAnalyticsFailureKind.unableToLoad => l10n.analyticsUnableToLoad,
  };
}
