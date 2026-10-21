import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/widgets/minor_account_review_checklist_card.dart';

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
    // This screen is public, but a recording is submitted by the signed-in
    // account, so a signed-out visitor is offered only the email route.
    final isSignedIn =
        ref.watch(currentAuthStateProvider) == AuthState.authenticated;
    final canRecordInApp =
        isSignedIn &&
        ref.watch(
          isFeatureEnabledProvider(FeatureFlag.minorConsentInAppRecording),
        );
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
                      '${canRecordInApp ? context.l10n.minorAccountReviewRecordConsentBody : context.l10n.minorAccountReviewParentConsentBody}',
                  backgroundColor: context.vineColors.inverseSurface,
                  borderColor: context.vineColors.inverseOnSurface,
                  textColor: context.vineColors.inverseOnSurface,
                ),
                const SizedBox(height: 16),
                MinorAccountReviewChecklistCard(
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
                MinorAccountReviewChecklistCard(
                  title: context.l10n.minorAccountReviewParentConsentPrivacy,
                  items: [
                    if (canRecordInApp)
                      context.l10n.minorAccountReviewRecordConsentPrivacyBody
                    else
                      context.l10n.minorAccountReviewParentConsentNeverPost,
                    context.l10n.minorAccountReviewParentConsentDoNotSave,
                    context.l10n.minorAccountReviewParentConsentOneMove,
                  ],
                ),
                const SizedBox(height: 24),
                if (isSignedIn) ...[
                  DivineSwitchTile(
                    title: context.l10n.minorAccountReviewRecordConsentTitle,
                    value: canRecordInApp,
                    onChanged: (enabled) async {
                      await ref
                          .read(featureFlagServiceProvider)
                          .setFlag(
                            FeatureFlag.minorConsentInAppRecording,
                            enabled,
                          );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (canRecordInApp) ...[
                  DivineButton(
                    label:
                        context.l10n.minorAccountReviewParentConsentRecordCta,
                    leadingIcon: DivineIconName.videoCamera,
                    expanded: true,
                    onPressed: () => context.push(
                      MinorAccountReviewRecordConsentScreen.path,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                DivineButton(
                  label: context.l10n.minorAccountReviewParentConsentEmailCta,
                  type: canRecordInApp
                      ? DivineButtonType.secondary
                      : DivineButtonType.primary,
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
    final status = ref.read(currentMinorAccountReviewStatusProvider).value;
    final reviewCase = status?.currentCase;
    final caseId = reviewCase?.id;
    if (status?.isRestricted == true &&
        reviewCase?.allowsParentVideoOrEmail == true &&
        reviewCase?.state ==
            MinorReviewCaseState.restrictedPendingUserResponse) {
      await context.push<void>(MinorAccountReviewParentContactScreen.path);
      return;
    }
    final MinorAccountReviewComposeEmail composer =
        composeEmail ??
        ref.read(minorAccountReviewSupportEmailComposerProvider);
    try {
      await composer(
        toEmail: AppConstants.supportEmail,
        subject: context.l10n.minorAccountReviewParentConsentEmailSubject,
        body: [
          context.l10n.minorAccountReviewParentConsentEmailBody,
          if (caseId != null) context.l10n.minorAccountReviewCaseId(caseId),
        ].join('\n\n'),
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
