// ABOUTME: Post-submission confirmation state of the report bottom sheet.
// ABOUTME: Split into a scrollable body and the actions that ride the footer.

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:url_launcher/url_launcher.dart';

/// Scrollable content shown after a report is accepted.
class ReportConfirmationBody extends StatelessWidget {
  /// Creates a [ReportConfirmationBody].
  const ReportConfirmationBody({required this.moderationDmFailed, super.key});

  /// Whether the secondary NIP-17 DM to the moderation team failed to
  /// send. The report itself still succeeded; this only drives a calm
  /// informational notice so the user isn't misled.
  final bool moderationDmFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          spacing: 12,
          children: [
            DivineIcon(
              icon: DivineIconName.checkCircle,
              color: context.vineColors.accentPositive,
              size: 28,
            ),
            Expanded(
              child: Text(
                l10n.reportReceivedTitle,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.reportReceivedThankYou,
          style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.reportReceivedReviewNotice,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        if (moderationDmFailed) ...[
          const SizedBox(height: 12),
          Text(
            l10n.reportModerationDmDelayed,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
        ],
        const SizedBox(height: 8),
        const _SafetyPolicyLink(),
      ],
    );
  }
}

class _SafetyPolicyLink extends StatelessWidget {
  const _SafetyPolicyLink();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // No `label:` here — the Text.rich below already supplies one, and a
    // label on the annotation is prepended to it rather than replacing it,
    // so the URL would be announced twice.
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.parse('https://divine.video/safety');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${l10n.reportLearnMoreAt} ',
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
              TextSpan(
                text: l10n.reportSafetyUrl,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.accentPositive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer actions for the post-submission confirmation.
class ReportConfirmationActions extends ConsumerWidget {
  /// Creates a [ReportConfirmationActions].
  const ReportConfirmationActions({required this.isFromShareMenu, super.key});

  /// Whether the sheet was opened from the share menu, which needs a second
  /// pop to also dismiss the menu underneath.
  final bool isFromShareMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currentPubkey = ref.read(authServiceProvider).currentPublicKeyHex;
    final moderationPubkey = ref
        .read(moderationLabelServiceProvider)
        .divineModerationPubkeyHex;
    // The moderation conversation is an ordinary NIP-17 thread; deep-link
    // straight to it so the user can follow up about their report. Null
    // when we have no current pubkey (signed out) — the button hides.
    final moderationConversationId =
        (currentPubkey != null && currentPubkey.isNotEmpty)
        ? DmRepository.computeConversationId([currentPubkey, moderationPubkey])
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (moderationConversationId case final conversationId?)
          DivineButton(
            label: l10n.reportContactModeration,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: () {
              // Capture the router before popping the sheet so the push
              // doesn't run against a defunct context.
              final router = GoRouter.of(context);
              final navigator = Navigator.of(context);
              navigator.pop();
              if (isFromShareMenu) {
                navigator.pop();
              }
              router.push(
                ConversationPage.pathForId(conversationId),
                extra: [moderationPubkey],
              );
            },
          ),
        DivineButton(
          label: l10n.reportClose,
          expanded: true,
          onPressed: () {
            Navigator.of(context).pop();
            if (isFromShareMenu) {
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}
