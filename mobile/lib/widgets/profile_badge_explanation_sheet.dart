// ABOUTME: Explains compact profile badges that appear beside display names.
// ABOUTME: Keeps profile-badge copy separate from video verification modals.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

enum ProfileBadgeExplanationType { ogViner, ogBetaTester, profileCheckmark }

/// Opens the explainer for a compact profile badge.
///
/// Called from the profile header and from the inline chits in feeds,
/// comments, search and grids, so the disclaimer is reachable everywhere a
/// badge appears. Safe to open from inside an existing bottom sheet: it
/// stacks on the root navigator rather than replacing the sheet below it.
Future<void> showProfileBadgeExplanationSheet(
  BuildContext context,
  ProfileBadgeExplanationType type,
) {
  return context.showVideoPausingVineBottomSheet<void>(
    scrollable: false,
    expanded: false,
    contentTitle: type.title(context.l10n),
    children: [_ProfileBadgeExplanationContent(type: type)],
  );
}

class _ProfileBadgeExplanationContent extends StatelessWidget {
  const _ProfileBadgeExplanationContent({required this.type});

  final ProfileBadgeExplanationType type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DivineIcon(icon: type.icon, color: type.iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type.body(l10n),
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: DivineButton(
              label: l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
            ),
          ),
        ],
      ),
    );
  }
}

extension on ProfileBadgeExplanationType {
  String title(AppLocalizations l10n) {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => l10n.ogVinerBadgeLabel,
      ProfileBadgeExplanationType.ogBetaTester => l10n.ogBetaTesterBadgeLabel,
      ProfileBadgeExplanationType.profileCheckmark =>
        l10n.profileBadgeCheckmarkTitle,
    };
  }

  String body(AppLocalizations l10n) {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => l10n.profileBadgeOgVinerBody,
      ProfileBadgeExplanationType.ogBetaTester =>
        l10n.profileBadgeOgBetaTesterBody,
      ProfileBadgeExplanationType.profileCheckmark =>
        l10n.profileBadgeCheckmarkBody,
    };
  }

  DivineIconName get icon {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => DivineIconName.videoCamera,
      ProfileBadgeExplanationType.ogBetaTester => DivineIconName.sparkle,
      ProfileBadgeExplanationType.profileCheckmark => DivineIconName.check,
    };
  }

  Color get iconColor {
    return switch (this) {
      ProfileBadgeExplanationType.ogViner => VineTheme.primary,
      ProfileBadgeExplanationType.ogBetaTester => VineTheme.primary,
      ProfileBadgeExplanationType.profileCheckmark => VineTheme.info,
    };
  }
}
