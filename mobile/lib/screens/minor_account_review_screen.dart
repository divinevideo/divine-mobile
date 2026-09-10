// ABOUTME: Hard-gate screen shown when an authenticated account is restricted
// ABOUTME: pending parental consent / minor-account review.

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

enum MinorAccountReviewEntryPoint { welcome, moderation }

/// Re-reads the review status AND the protected-minor flag together (#176).
///
/// A review-status refresh is the approval-discovery signal on this screen: an
/// approved teen may now carry the `verified_minor` flag, so the protected-minor
/// state must be invalidated in lockstep. Otherwise `isProtectedMinorProvider`
/// keeps its stale value and the DM/content restrictions wouldn't apply until
/// the next relaunch or auth transition. Invalidating is strictly fail-closed:
/// the sticky store never lets a refetch weaken protection.
void refreshMinorAccountState(WidgetRef ref) {
  ref.invalidate(currentMinorAccountReviewStatusProvider);
  ref.invalidate(protectedMinorStatusProvider);
}

class MinorAccountReviewScreen extends ConsumerWidget {
  static const routeName = 'minor-account-review';
  static const String path = RoutePaths.minorAccountReview;
  static const welcomePath = '/account-review/welcome';

  static String pathFor({
    MinorAccountReviewEntryPoint entryPoint =
        MinorAccountReviewEntryPoint.welcome,
  }) => entryPoint == MinorAccountReviewEntryPoint.welcome ? welcomePath : path;

  const MinorAccountReviewScreen({
    this.entryPoint = MinorAccountReviewEntryPoint.moderation,
    super.key,
  });

  final MinorAccountReviewEntryPoint entryPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entryPoint == MinorAccountReviewEntryPoint.welcome) {
      return const _WelcomeEntryView();
    }

    final statusAsync = ref.watch(currentMinorAccountReviewStatusProvider);

    return Scaffold(
      appBar: DiVineAppBar(title: context.l10n.minorAccountReviewTitle),
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: statusAsync.when(
              data: (status) => _LoadedView(status: status),
              loading: () =>
                  const Center(child: PartialCircleSpinner(progress: 0.33)),
              error: (error, _) {
                Log.error(
                  'Failed to load account review status: $error',
                  name: 'MinorAccountReviewScreen',
                  category: LogCategory.ui,
                );
                return _ErrorView(onRetry: () => refreshMinorAccountState(ref));
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeEntryView extends StatelessWidget {
  const _WelcomeEntryView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.minorAccountReviewWelcomePageTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
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
                _HeroCard(
                  title: l10n.minorAccountReviewWelcomeTitle,
                  body: l10n.minorAccountReviewWelcomeBody,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.minorAccountReviewChooseAgeBandTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DivineButton(
                        label: l10n.minorAccountReviewUnder13Cta,
                        onPressed: () =>
                            context.push(MinorAccountReviewUnder13Screen.path),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DivineButton(
                        label: l10n.minorAccountReviewTeenCta,
                        type: DivineButtonType.secondary,
                        onPressed: () => context.push(
                          MinorAccountReviewParentConsentScreen.path,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.minorAccountReviewLearnMoreTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                DivineButton(
                  label: l10n.minorAccountReviewKidsPolicyCta,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => _openExternalPage(
                    context,
                    AppConstants.kidsPolicyUrl,
                    'divine.video/kids',
                  ),
                ),
                const SizedBox(height: 12),
                DivineButton(
                  label: l10n.minorAccountReviewFamilyResourcesCta,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => _openExternalPage(
                    context,
                    AppConstants.familyResourcesUrl,
                    'divine.video/family',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MinorAccountReviewLoadingScreen extends StatelessWidget {
  static const routeName = 'minor-account-review-loading';
  static const path = '/account-review/checking';

  const MinorAccountReviewLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PartialCircleSpinner(progress: 0.33),
                const SizedBox(height: 20),
                Text(
                  context.l10n.minorAccountReviewCheckingStatusTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.minorAccountReviewCheckingStatusBody,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadedView extends ConsumerWidget {
  const _LoadedView({required this.status});

  final MinorAccountReviewStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reviewCase = status.currentCase;
    final title = reviewCase?.instructions.title.isNotEmpty == true
        ? reviewCase!.instructions.title
        : l10n.minorAccountReviewDefaultTitle;
    final body = reviewCase?.instructions.body.isNotEmpty == true
        ? reviewCase!.instructions.body
        : l10n.minorAccountReviewDefaultBody;
    final supportEmail = reviewCase?.supportEmail ?? AppConstants.supportEmail;
    final caseId = reviewCase?.id;
    final primaryAction = _primaryAction(reviewCase, l10n);
    final infoCard = _infoCardForCase(reviewCase, supportEmail, l10n);
    final responseClockCard = reviewCase == null
        ? null
        : _ResponseClockCard(deadline: reviewCase.responseDeadline);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: VineTheme.vineGreen.withValues(alpha: .2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: VineTheme.headlineMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.mutedText,
                ),
              ),
              if (caseId != null && caseId.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.minorAccountReviewCaseId(caseId),
                  style: VineTheme.labelMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.minorAccountReviewRestrictionsTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 12),
        ...[
          l10n.minorAccountReviewRestrictionPosting,
          l10n.minorAccountReviewRestrictionEngagement,
          l10n.minorAccountReviewRestrictionMessaging,
          l10n.minorAccountReviewRestrictionSupport,
        ].map(_RestrictionLine.new),
        const SizedBox(height: 24),
        ?responseClockCard,
        _InfoCard(
          title: l10n.minorAccountReviewContentTitle,
          body: l10n.minorAccountReviewContentBody,
        ),
        const SizedBox(height: 24),
        _InfoCard(title: infoCard.title, body: infoCard.body),
        const SizedBox(height: 24),
        _InfoCard(
          title: l10n.minorAccountReviewModerationTitle,
          body: l10n.minorAccountReviewModerationBody,
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: l10n.minorAccountReviewOpenReviewPage,
          type: DivineButtonType.secondary,
          expanded: true,
          onPressed: () => _openExternalPage(
            context,
            AppConstants.ageReviewUrl,
            'divine.video/age-review',
          ),
        ),
        const SizedBox(height: 24),
        if (primaryAction != null) ...[
          DivineButton(
            label: primaryAction.label,
            expanded: true,
            onPressed: () => primaryAction.onPressed(context),
          ),
          const SizedBox(height: 12),
        ],
        _InfoCard(
          title: l10n.minorAccountReviewAppealTitle,
          body: reviewCase?.isUnder13Path == true
              ? l10n.minorAccountReviewAppealUnder13Body
              : l10n.minorAccountReviewAppealTeenBody,
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: l10n.appealOpenSupportCenter,
          leadingIcon: DivineIconName.headphones,
          expanded: true,
          onPressed: () => context.push(SupportCenterScreen.path),
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: l10n.minorAccountReviewOpenModerationMessage,
          type: DivineButtonType.secondary,
          leadingIcon: DivineIconName.chatCircle,
          expanded: true,
          onPressed: reviewCase?.moderationConversationPubkey == null
              ? null
              : () => _openModerationConversation(context, ref, reviewCase!),
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: l10n.minorAccountReviewCheckAgain,
          type: DivineButtonType.ghost,
          expanded: true,
          onPressed: () => refreshMinorAccountState(ref),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => ref.read(authServiceProvider).signOut(),
          child: Text(
            l10n.minorAccountReviewLogOut,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  void _openModerationConversation(
    BuildContext context,
    WidgetRef ref,
    MinorReviewCase reviewCase,
  ) {
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;
    final moderationPubkey = reviewCase.moderationConversationPubkey;
    if (currentPubkey == null || moderationPubkey == null) {
      return;
    }

    final conversationId =
        reviewCase.moderationConversationId ??
        DmRepository.computeConversationId([currentPubkey, moderationPubkey]);

    context.push(
      ConversationPage.pathForId(conversationId),
      extra: [moderationPubkey],
    );
  }

  _MinorReviewInfoCardCopy _infoCardForCase(
    MinorReviewCase? reviewCase,
    String supportEmail,
    AppLocalizations l10n,
  ) {
    if (reviewCase == null) {
      return _MinorReviewInfoCardCopy(
        title: l10n.minorAccountReviewNextStepTitle,
        body: l10n.minorAccountReviewNextStepBody,
      );
    }

    if (reviewCase.isAwaitingModeratorDecision) {
      return _MinorReviewInfoCardCopy(
        title: l10n.minorAccountReviewInProgressTitle,
        body: l10n.minorAccountReviewInProgressBody,
      );
    }

    if (reviewCase.isUnder13Path) {
      return _MinorReviewInfoCardCopy(
        title: l10n.minorAccountReviewUnder13Title,
        body: l10n.minorAccountReviewUnder13Body(supportEmail),
      );
    }

    return _MinorReviewInfoCardCopy(
      title: l10n.minorAccountReviewNextStepTitle,
      body: l10n.minorAccountReviewTeenBody,
    );
  }

  _MinorReviewPrimaryAction? _primaryAction(
    MinorReviewCase? reviewCase,
    AppLocalizations l10n,
  ) {
    if (reviewCase == null || reviewCase.isAwaitingModeratorDecision) {
      return null;
    }

    // No primary action for a case with nothing left for the user to do.
    // Support Center is already offered unconditionally below, directly under
    // the reconsideration card (#8239); returning it here as well rendered the
    // same button twice — as primary above the card and again beneath it — in
    // `openReported`, `cleared`, `deniedClosed` and `unknown`.
    if (!reviewCase.needsUserAction) {
      return null;
    }

    return _MinorReviewPrimaryAction(
      label: reviewCase.isUnder13Path
          ? l10n.minorAccountReviewParentSupportInstructions
          : l10n.minorAccountReviewContinue,
      onPressed: (context) => _continueToNextStep(context, reviewCase),
    );
  }

  void _continueToNextStep(BuildContext context, MinorReviewCase reviewCase) {
    if (reviewCase.isUnder13Path) {
      context.push(MinorAccountReviewUnder13SupportScreen.path);
      return;
    }

    switch (reviewCase.allowedResolution) {
      case MinorReviewResolutionType.parentVideoOrEmail:
        context.push(MinorAccountReviewParentContactScreen.path);
      case MinorReviewResolutionType.supportEmailOnly:
        context.push(MinorAccountReviewUnder13SupportScreen.path);
      case MinorReviewResolutionType.supportReviewOnly:
      case MinorReviewResolutionType.unknown:
        context.push(SupportCenterScreen.path);
    }
  }
}

Future<void> _openExternalPage(
  BuildContext context,
  String url,
  String pageName,
) async {
  final uri = Uri.parse(url);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (launched || !context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(
      context.l10n.supportCouldNotOpenPage(pageName),
    ),
  );
}

class _MinorReviewInfoCardCopy {
  const _MinorReviewInfoCardCopy({required this.title, required this.body});

  final String title;
  final String body;
}

class _MinorReviewPrimaryAction {
  const _MinorReviewPrimaryAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final void Function(BuildContext context) onPressed;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VineTheme.vineGreen.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.headlineMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestrictionLine extends StatelessWidget {
  const _RestrictionLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: ExcludeSemantics(
              child: DivineIcon(
                icon: DivineIconName.prohibit,
                size: 16,
                color: VineTheme.vineGreen,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseClockCard extends StatelessWidget {
  const _ResponseClockCard({required this.deadline});

  final MinorReviewResponseDeadline deadline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final copy = switch (deadline.clock) {
      MinorReviewResponseClock.running => _runningCopy(context, l10n),
      MinorReviewResponseClock.paused => _ClockCopy(
        title: l10n.minorAccountReviewResponseClockPausedTitle,
        body: l10n.minorAccountReviewResponseClockPausedBody(
          deadline.remainingDaysWhenPaused!.floor(),
        ),
      ),
      MinorReviewResponseClock.expired => _ClockCopy(
        title: l10n.minorAccountReviewResponseClockExpiredTitle,
        body: l10n.minorAccountReviewResponseClockExpiredBody,
      ),
      MinorReviewResponseClock.notApplicable => null,
      MinorReviewResponseClock.unavailable => _ClockCopy(
        title: l10n.minorAccountReviewResponseClockUnavailableTitle,
        body: l10n.minorAccountReviewResponseClockUnavailableBody,
      ),
    };

    // A not-applicable clock has no copy, so the card contributes no height
    // at all — including the gap that would otherwise separate it from the
    // content card below.
    if (copy == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: _InfoCard(title: copy.title, body: copy.body),
    );
  }

  _ClockCopy _runningCopy(BuildContext context, AppLocalizations l10n) {
    final remaining = deadline.remaining!;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(deadline.deadlineAt!.toLocal());
    final body = remaining < const Duration(hours: 48)
        ? l10n.minorAccountReviewResponseClockRunningHours(
            remaining.inHours,
            date,
          )
        : l10n.minorAccountReviewResponseClockRunningDays(
            remaining.inDays,
            date,
          );
    return _ClockCopy(
      title: l10n.minorAccountReviewResponseClockRunningTitle,
      body: body,
    );
  }
}

class _ClockCopy {
  const _ClockCopy({required this.title, required this.body});

  final String title;
  final String body;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

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
          const SizedBox(height: 8),
          Text(
            body,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.minorAccountReviewErrorTitle,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.minorAccountReviewErrorBody,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          DivineButton(
            label: context.l10n.minorAccountReviewTryAgain,
            expanded: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
