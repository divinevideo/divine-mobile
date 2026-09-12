import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/share_position_origin.dart';

class MinorAccountReviewParentConsentScreen extends ConsumerWidget {
  static const routeName = 'minor-account-review-parent-consent';
  static const path = '/account-review/parent-consent';

  const MinorAccountReviewParentConsentScreen({
    super.key,
    this.composeEmail,
  });

  final MinorAccountReviewComposeEmail? composeEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.minorAccountReviewTitle,
        showBackButton: true,
      ),
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Text(
                  context.l10n.minorAccountReviewParentConsentTitle,
                  style: VineTheme.headlineMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                const SizedBox(height: 20),
                _InfoCard(
                  title:
                      context.l10n.minorAccountReviewParentConsentHonestyTitle,
                  body:
                      '${context.l10n.minorAccountReviewParentConsentHonestyBody}'
                      '\n\n'
                      '${context.l10n.minorAccountReviewParentConsentBody}',
                  backgroundColor: context.vineColors.inverseSurface,
                  borderColor: context.vineColors.inverseOnSurface,
                  textColor: context.vineColors.inverseOnSurface,
                ),
                const SizedBox(height: 16),
                _ChecklistCard(
                  title: context.l10n.minorAccountReviewParentConsentChecklist,
                  items: [
                    context.l10n.minorAccountReviewParentConsentChecklistKid,
                    context
                        .l10n
                        .minorAccountReviewParentConsentChecklistPermission,
                    context
                        .l10n
                        .minorAccountReviewParentConsentChecklistAgeBand,
                    context
                        .l10n
                        .minorAccountReviewParentConsentChecklistSupervision,
                  ],
                ),
                const SizedBox(height: 16),
                _ChecklistCard(
                  title: context.l10n.minorAccountReviewParentConsentPrivacy,
                  items: [
                    context.l10n.minorAccountReviewParentConsentNeverPost,
                    context.l10n.minorAccountReviewParentConsentDoNotSave,
                    context.l10n.minorAccountReviewParentConsentOneMove,
                  ],
                ),
                const SizedBox(height: 24),
                DivineButton(
                  label: context.l10n.minorAccountReviewParentConsentEmailCta,
                  expanded: true,
                  onPressed: () => _emailSupport(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _emailSupport(BuildContext context, WidgetRef ref) async {
    final MinorAccountReviewComposeEmail composer =
        composeEmail ??
        ref.read(minorAccountReviewSupportEmailComposerProvider);
    try {
      await composer(
        toEmail: AppConstants.supportEmail,
        subject: context.l10n.minorAccountReviewParentConsentEmailSubject,
        body: context.l10n.minorAccountReviewParentConsentEmailBody,
        sharePositionOrigin: shareAnchorForContext(context),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.authCouldNotOpenEmail(AppConstants.supportEmail),
        ),
      );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.body,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.title,
  });

  final String? title;
  final String body;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: VineTheme.titleMediumFont(color: textColor)),
            const SizedBox(height: 8),
          ],
          Text(
            body,
            style: VineTheme.bodyMediumFont(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: ExcludeSemantics(
                      child: DivineIcon(
                        icon: DivineIconName.checkCircle,
                        size: 16,
                        color: VineTheme.vineGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
