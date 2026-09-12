// ABOUTME: One platform on offer in the verify dashboard's add-a-link list.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:profile_repository/profile_repository.dart';

/// A tappable platform that has no link yet.
class VerifyPlatformRow extends StatelessWidget {
  /// Creates a [VerifyPlatformRow].
  const VerifyPlatformRow({
    required this.platform,
    required this.onTap,
    super.key,
  });

  /// The platform on offer.
  final VerifierPlatform platform;

  /// Opens the connect flow for [platform].
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = verifyPlatformLabel(platform.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: l10n.verifyLinkSemanticLabel(label),
        child: Material(
          color: context.vineColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          label,
                          style: VineTheme.bodyMediumFont(
                            color: context.vineColors.primaryText,
                          ),
                        ),
                      ),
                    ),
                    if (platform.supportsOAuth)
                      ExcludeSemantics(
                        child: Text(
                          l10n.verifyOneTapBadge,
                          style: VineTheme.labelSmallFont(
                            color: context.vineColors.mutedText,
                          ),
                        ),
                      ),
                    DivineIcon(
                      icon: DivineIconName.caretRight,
                      size: 16,
                      color: context.vineColors.mutedText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
