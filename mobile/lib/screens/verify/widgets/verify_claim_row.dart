// ABOUTME: One linked account on the verify dashboard — handle, verdict pill
// ABOUTME: and the unlink affordance.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:profile_repository/profile_repository.dart';

/// A single linked account, verified or not.
class VerifyClaimRow extends StatelessWidget {
  /// Creates a [VerifyClaimRow].
  const VerifyClaimRow({
    required this.claim,
    required this.isVerified,
    required this.isRemoving,
    required this.onRemove,
    super.key,
  });

  /// The claim this row renders.
  final IdentityClaim claim;

  /// Whether the verifier confirmed the claim.
  final bool isVerified;

  /// Whether this row's unlink is in flight.
  final bool isRemoving;

  /// Unlinks the account. Null while another unlink owns the screen.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            spacing: 12,
            children: [
              // Platform, handle and verdict are one announcement; the unlink
              // button stays outside the merge so it keeps its own node and
              // its own action.
              Expanded(
                child: MergeSemantics(
                  child: Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              verifyPlatformLabel(claim.platform),
                              style: VineTheme.labelMediumFont(
                                color: context.vineColors.mutedText,
                              ),
                            ),
                            Text(
                              claim.identity,
                              style: VineTheme.bodyMediumFont(
                                color: context.vineColors.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _VerdictPill(isVerified: isVerified),
                    ],
                  ),
                ),
              ),
              if (isRemoving)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(child: BrandedLoadingIndicator(size: 32)),
                )
              else
                DivineIconButton(
                  icon: DivineIconName.trash,
                  type: .secondary,
                  size: .small,
                  onPressed: onRemove,
                  semanticLabel: l10n.verifyUnlinkSemanticLabel(
                    verifyPlatformLabel(claim.platform),
                    claim.identity,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerdictPill extends StatelessWidget {
  const _VerdictPill({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = isVerified ? VineTheme.primary : context.vineColors.mutedText;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          isVerified ? l10n.verifyStatusVerified : l10n.verifyStatusUnverified,
          style: VineTheme.labelSmallFont(color: color),
        ),
      ),
    );
  }
}
