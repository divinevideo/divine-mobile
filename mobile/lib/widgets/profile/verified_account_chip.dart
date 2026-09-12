// ABOUTME: VerifiedAccountChip — single chip for one verified identity claim.
// ABOUTME: Public profiles are tappable; claims without a URL are informational.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:verifier_client/verifier_client.dart';

/// Pluggable URL launcher for tests.
typedef ChipUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Chip rendering a single verified [IdentityClaim].
///
/// Tapping opens the platform profile via [launchUrl] (override [launcher] in
/// tests). Platforms without a public profile URL are not interactive.
class VerifiedAccountChip extends StatelessWidget {
  /// Creates a chip for [claim]. [launcher] defaults to the system browser.
  const VerifiedAccountChip({
    required this.claim,
    super.key,
    this.launcher = _defaultLauncher,
  });

  /// The verified claim this chip represents.
  final IdentityClaim claim;

  /// URL launcher hook for tests.
  final ChipUrlLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uri = platformProfileUrl(claim.platform, claim.identity);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (uri != null)
            DivineIcon(
              icon: DivineIconName.globe,
              size: 14,
              color: context.vineColors.mutedText,
            ),
          Text(
            '${claim.platform}/${claim.identity}',
            style: VineTheme.labelMediumFont(
              color: uri == null
                  ? context.vineColors.mutedText
                  : context.vineColors.primaryText,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: uri != null,
      label: l10n.verifiedAccountChipSemanticLabel(
        claim.platform,
        claim.identity,
      ),
      child: Material(
        color: context.vineColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: context.vineColors.isLight
                ? context.vineColors.outlineMuted
                : VineTheme.neutral10,
          ),
        ),
        child: uri == null
            ? content
            : InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => launcher(uri),
                child: content,
              ),
      ),
    );
  }
}
