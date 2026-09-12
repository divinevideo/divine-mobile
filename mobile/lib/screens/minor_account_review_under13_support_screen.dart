// ABOUTME: Support instructions screen for likely under-13 cases in the
// ABOUTME: parental consent / minor-account review flow.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:unified_logger/unified_logger.dart';

class MinorAccountReviewUnder13SupportScreen extends ConsumerWidget {
  static const routeName = 'minor-account-review-under13-support';
  static const path = '/account-review/under-13-support';

  const MinorAccountReviewUnder13SupportScreen({
    super.key,
    this.composeEmail,
  });

  final MinorAccountReviewComposeEmail? composeEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(currentMinorAccountReviewStatusProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.minorAccountReviewUnder13SupportTitle,
        showBackButton: true,
        onBackPressed: () =>
            context.safePop(fallback: MinorAccountReviewScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: statusAsync.when(
              loading: () =>
                  const Center(child: PartialCircleSpinner(progress: 0.33)),
              error: (error, _) {
                Log.error(
                  'Failed to load under-13 support instructions: $error',
                  name: 'MinorAccountReviewUnder13SupportScreen',
                  category: LogCategory.ui,
                );
                return _MinorAccountReviewLoadErrorView(
                  title: context.l10n.minorAccountReviewErrorTitle,
                  body: context.l10n.minorAccountReviewErrorBody,
                  buttonLabel: context.l10n.minorAccountReviewTryAgain,
                  onPressed: () =>
                      ref.invalidate(currentMinorAccountReviewStatusProvider),
                );
              },
              data: (status) => _Under13SupportBody(
                status: status,
                composeEmail:
                    composeEmail ??
                    ref.watch(minorAccountReviewSupportEmailComposerProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Under13SupportBody extends StatelessWidget {
  const _Under13SupportBody({required this.status, required this.composeEmail});

  final MinorAccountReviewStatus status;
  final MinorAccountReviewComposeEmail composeEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reviewCase = status.currentCase;
    final supportEmail = reviewCase?.supportEmail ?? AppConstants.supportEmail;
    final caseId = reviewCase?.id ?? l10n.minorAccountReviewUnavailable;
    final emailSubject = l10n.minorAccountReviewUnder13EmailSubject(caseId);
    final emailBody = l10n.minorAccountReviewUnder13EmailBody(caseId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Text(
          l10n.minorAccountReviewUnder13Heading,
          style: VineTheme.headlineMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.minorAccountReviewUnder13SupportBody,
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
        const SizedBox(height: 24),
        _ValueCard(
          title: l10n.minorAccountReviewSupportEmailLabel,
          value: supportEmail,
          tooltip: l10n.minorAccountReviewCopySupportEmail,
          onCopy: () => _copyMinorAccountReviewValue(
            context,
            supportEmail,
            l10n.minorAccountReviewSupportEmailCopied,
          ),
        ),
        const SizedBox(height: 16),
        _ValueCard(
          title: l10n.minorAccountReviewCaseIdShortLabel,
          value: caseId,
          tooltip: l10n.minorAccountReviewCopyCaseId,
          onCopy: () => _copyMinorAccountReviewValue(
            context,
            caseId,
            l10n.minorAccountReviewCaseIdCopied,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.minorAccountReviewUnder13Instructions,
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
        const SizedBox(height: 24),
        DivineButton(
          label: l10n.authOpenEmailApp,
          expanded: true,
          onPressed: () => _openMinorAccountReviewEmailApp(
            context: context,
            composeEmail: composeEmail,
            supportEmail: supportEmail,
            subject: emailSubject,
            body: emailBody,
          ),
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: l10n.minorAccountReviewBackToReview,
          expanded: true,
          onPressed: () => context.go(MinorAccountReviewScreen.path),
        ),
      ],
    );
  }
}

Future<void> _copyMinorAccountReviewValue(
  BuildContext context,
  String text,
  String successMessage,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(DivineSnackbarContainer.snackBar(successMessage));
}

Future<void> _openMinorAccountReviewEmailApp({
  required BuildContext context,
  required MinorAccountReviewComposeEmail composeEmail,
  required String supportEmail,
  required String subject,
  required String body,
}) async {
  try {
    await composeEmail(
      toEmail: supportEmail,
      subject: subject,
      body: body,
      sharePositionOrigin: shareAnchorForContext(context),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.authCouldNotOpenEmail(supportEmail),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.title,
    required this.value,
    required this.tooltip,
    required this.onCopy,
  });

  final String title;
  final String value;
  final String tooltip;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: VineTheme.labelMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: tooltip,
            child: DivineIconButton(
              icon: DivineIconName.copy,
              type: DivineIconButtonType.secondary,
              size: DivineIconButtonSize.small,
              semanticLabel: tooltip,
              onPressed: onCopy,
            ),
          ),
        ],
      ),
    );
  }
}

class _MinorAccountReviewLoadErrorView extends StatelessWidget {
  const _MinorAccountReviewLoadErrorView({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          DivineButton(
            label: buttonLabel,
            expanded: true,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
