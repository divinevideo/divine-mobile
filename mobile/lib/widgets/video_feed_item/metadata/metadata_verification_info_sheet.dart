// ABOUTME: Explainer sheet for the four verification checks in the metadata
// ABOUTME: sheet. States what each check proves, and what a missing one does
// ABOUTME: not mean.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_recorder/modes/upload/upload_explainer_constants.dart';

/// Vertical slack around the learn-more link so its tap target clears the
/// 48 dp minimum. The link text is 20 dp tall, so 14 dp on each side.
const _linkTapSlack = 14.0;

/// Bottom sheet explaining the ProofMode / C2PA checks listed by
/// [MetadataVerificationSection].
///
/// The checklist labels ("Device attestation", "PGP signature", …) are
/// domain jargon on their own — four green ticks read as decoration until
/// the viewer knows what each one is evidence of. This sheet supplies that,
/// including the deliberate limit: a missing check is not evidence of
/// forgery.
class MetadataVerificationInfoSheet extends StatelessWidget {
  @visibleForTesting
  const MetadataVerificationInfoSheet({super.key});

  /// Opens the explainer over the metadata sheet.
  static Future<void> show(BuildContext context) {
    return context.showVideoPausingVineBottomSheet<void>(
      contentTitle: context.l10n.metadataVerificationInfoTitle,
      scrollable: false,
      isScrollControlled: true,
      body: const SingleChildScrollView(child: MetadataVerificationInfoSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      // The learn-more link carries its own vertical padding to reach a 48 dp
      // tap target, so the sheet gives that much back at the bottom.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24 - _linkTapSlack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 20,
        children: [
          Text(
            l10n.metadataVerificationInfoIntro,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          _CheckExplanation(
            label: l10n.metadataDeviceAttestation,
            description: l10n.metadataVerificationInfoDeviceAttestation,
          ),
          _CheckExplanation(
            label: l10n.metadataPgpSignature,
            description: l10n.metadataVerificationInfoPgpSignature,
          ),
          _CheckExplanation(
            label: l10n.metadataC2paCredentials,
            description: l10n.metadataVerificationInfoC2paCredentials,
          ),
          _CheckExplanation(
            label: l10n.metadataProofManifest,
            description: l10n.metadataVerificationInfoProofManifest,
          ),
          Text(
            l10n.metadataVerificationInfoFootnote,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          const _LearnMoreLink(),
        ],
      ),
    );
  }
}

/// One check: its checklist label, then what that check is evidence of.
class _CheckExplanation extends StatelessWidget {
  const _CheckExplanation({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            label,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Text(
            description,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Outbound link to the public ProofMode page.
///
/// The URL sits in the sentence as a placeholder rather than after a fixed
/// prefix, so languages that put it elsewhere — or that need punctuation
/// instead of a trailing space — can move it.
class _LearnMoreLink extends StatelessWidget {
  const _LearnMoreLink();

  @override
  Widget build(BuildContext context) {
    // Shown without the scheme, so the label can never drift from the URL.
    final displayUrl = proofmodeLearnMoreUrl.replaceFirst('https://', '');
    final sentence = context.l10n.metadataVerificationInfoLearnMore(displayUrl);

    return Semantics(
      link: true,
      label: sentence,
      child: GestureDetector(
        onTap: () => openExternalLink(context, proofmodeLearnMoreUrl),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _linkTapSlack),
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(children: _spans(context, sentence, displayUrl)),
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Splits [sentence] around [url] so only the URL is underlined.
  ///
  /// A translation that dropped the placeholder yields a single span, which
  /// still reads correctly — it just loses the underline.
  List<TextSpan> _spans(BuildContext context, String sentence, String url) {
    final linkStyle =
        VineTheme.bodyMediumFont(
          color: context.vineColors.primaryText,
        ).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: context.vineColors.primaryText,
        );

    return [
      for (final (index, part) in sentence.split(url).indexed) ...[
        if (index > 0) TextSpan(text: url, style: linkStyle),
        TextSpan(text: part),
      ],
    ];
  }
}
