// ABOUTME: Verification section for the metadata expanded sheet.
// ABOUTME: Shows a checklist of ProofMode/C2PA verification signals present
// ABOUTME: on the video.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_verification_info_sheet.dart';

/// Verification section showing which ProofMode / C2PA signals are present.
///
/// Returns [SizedBox.shrink] when the video has no proof data at all.
class MetadataVerificationSection extends StatelessWidget {
  const MetadataVerificationSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    if (!video.hasProofMode) return const SizedBox.shrink();

    final l10n = context.l10n;
    return Semantics(
      identifier: SemanticIds.verificationSection,
      child: MetadataSection(
        label: l10n.metadataVerificationLabel,
        info: (
          onPressed: () => MetadataVerificationInfoSheet.show(context),
          label: l10n.metadataVerificationInfoTooltip,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            _VerificationCheckItem(
              label: l10n.metadataDeviceAttestation,
              passed: video.hasProofModeDeviceAttestation,
            ),
            _VerificationCheckItem(
              label: l10n.metadataPgpSignature,
              passed: video.hasProofModePgpFingerprint,
            ),
            _VerificationCheckItem(
              label: l10n.metadataC2paCredentials,
              passed: video.hasProofModeC2paManifestId,
            ),
            _VerificationCheckItem(
              label: l10n.metadataProofManifest,
              passed: video.hasProofModeManifest,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single check item showing pass/fail status.
///
/// Label sits on the left and the status icon on the right with a
/// `space-between` row layout, matching Figma node `15675:27860`.
/// A green check marks a passed signal; a muted X marks a missing one.
class _VerificationCheckItem extends StatelessWidget {
  const _VerificationCheckItem({required this.label, required this.passed});

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: VineTheme.bodyMediumFont(
              color: passed
                  ? context.vineColors.primaryText
                  : context.vineColors.onSurfaceMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DivineIcon(
          icon: passed ? DivineIconName.check : DivineIconName.x,
          color: passed ? VineTheme.success : context.vineColors.onSurfaceMuted,
        ),
      ],
    );
  }
}
