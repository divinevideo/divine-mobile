// ABOUTME: Decides which profiles carry the Divine team checkmark.
// ABOUTME: Keeps the team badge separate from generic NIP-05 validation.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';

/// Whether [pubkeyHex] carries the Divine team checkmark.
///
/// Matches on pubkey alone. A NIP-05 identifier is not an input: the name
/// server can reassign a handle, which would carry the checkmark to whoever
/// claims it next.
///
/// Takes the pubkey rather than the profile so the badge does not wait on a
/// kind-0 that cannot change the answer — a team member whose profile is slow
/// or never resolves still gets their checkmark on first paint.
bool shouldShowSpecialProfileCheckmark(String? pubkeyHex) {
  if (pubkeyHex == null) return false;
  final pubkey = pubkeyHex.toLowerCase();
  return kDivineTeamPubkeys.contains(pubkey);
}

class SpecialProfileCheckmark extends StatelessWidget {
  const SpecialProfileCheckmark({
    super.key,
    this.iconSize = 10,
    this.padding = 2,
    this.leadingGap = 4,
  });

  final double iconSize;
  final double padding;
  final double leadingGap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.profileBadgeCheckmarkTitle,
      container: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: leadingGap),
          child: Container(
            padding: EdgeInsets.all(DivineIcon.scaleSize(context, padding)),
            decoration: const BoxDecoration(
              color: VineTheme.info,
              shape: BoxShape.circle,
            ),
            child: DivineIcon(
              icon: DivineIconName.check,
              color: context.vineColors.primaryText,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
