// ABOUTME: Content widget explaining Nostr for new users
// ABOUTME: Shows npub, nsec, and username explanations with bullet points

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Content widget for the Nostr information bottom sheet.
///
/// Explains Nostr basics including npub, nsec, and Nostr usernames
/// with formatted bullet points and a "Learn more" link.
class NostrInfoSheetContent extends StatelessWidget {
  /// Creates a Nostr info sheet content widget.
  const NostrInfoSheetContent({this.onDismiss, super.key});

  /// Called when the "Got it!" button is pressed.
  /// If null, uses Navigator.pop.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Introduction paragraph
          RichText(
            text: TextSpan(
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.onSurface,
              ),
              children: [
                TextSpan(
                  text: context.l10n.nostrInfoIntroBuiltOn,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: context.l10n.nostrInfoIntroDescription),
                TextSpan(
                  text: context.l10n.nostrInfoIntroIdentity,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.nostrInfoOwnership,
            style: VineTheme.bodyLargeFont(color: context.vineColors.onSurface),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.nostrInfoLingo,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          // npub explanation
          _NostrBulletPoint(
            boldText: context.l10n.nostrInfoNpubLabel,
            normalText: context.l10n.nostrInfoNpubDescription,
          ),
          const SizedBox(height: 8),
          // nsec explanation
          _NostrBulletPoint(
            boldText: context.l10n.nostrInfoNsecLabel,
            normalText: context.l10n.nostrInfoNsecDescription,
            italicSuffix: context.l10n.nostrInfoNsecWarning,
          ),
          const SizedBox(height: 8),
          // Nostr username explanation
          _NostrBulletPoint(
            boldText: context.l10n.nostrInfoUsernameLabel,
            normalText: context.l10n.nostrInfoUsernameDescription,
          ),
          const SizedBox(height: 16),
          // Learn more link
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://divine.video/about');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: RichText(
              text: TextSpan(
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.onSurface,
                ),
                children: [
                  TextSpan(text: context.l10n.nostrInfoLearnMoreAt),
                  TextSpan(
                    text: 'divine.video/about',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      decorationColor: context.vineColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Got it button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDismiss ?? () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                backgroundColor: context.vineColors.surfaceContainer,
                foregroundColor: context.vineColors.accentPositive,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                side: BorderSide(
                  color: context.vineColors.outlineMuted,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                context.l10n.nostrInfoGotIt,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.accentPositive,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bullet point with bold label, normal text, and optional italic suffix.
class _NostrBulletPoint extends StatelessWidget {
  const _NostrBulletPoint({
    required this.boldText,
    required this.normalText,
    this.italicSuffix,
  });

  final String boldText;
  final String normalText;
  final String? italicSuffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: VineTheme.bodyLargeFont(color: context.vineColors.onSurface),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.onSurface,
              ),
              children: [
                TextSpan(
                  text: boldText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: normalText),
                if (italicSuffix != null)
                  TextSpan(
                    text: italicSuffix,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
