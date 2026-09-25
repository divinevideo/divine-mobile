// ABOUTME: Settings screen for the Divine supporter subscription.
// ABOUTME: Acknowledges membership, manages recognition, and explains verification eligibility.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/verify/verify_screen.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class SupporterScreen extends ConsumerWidget {
  static const routeName = 'supporter';
  static const subpath = 'supporter';
  static const path = '/settings/supporter';

  const SupporterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(supporterRepositoryProvider);
    final analytics = ref.watch(analyticsEventSinkProvider);
    final storeBillingAvailable = ref.watch(
      supporterStoreBillingAvailableProvider,
    );
    return BlocProvider(
      key: ValueKey((repository, analytics)),
      create: (_) => SupporterCubit(
        repository: repository,
        trackEvent: (event) =>
            analytics.logEvent(name: event, parameters: const {}),
      ),
      child: SupporterScreenView(storeBillingAvailable: storeBillingAvailable),
    );
  }
}

class SupporterScreenView extends StatefulWidget {
  const SupporterScreenView({this.storeBillingAvailable = true, super.key});

  /// Whether a store can bill this build. When false, plans and restore are
  /// replaced by a note, because no checkout can succeed here.
  final bool storeBillingAvailable;

  @override
  State<SupporterScreenView> createState() => _SupporterScreenViewState();
}

class _SupporterScreenViewState extends State<SupporterScreenView> {
  @override
  void initState() {
    super.initState();
    // Start the cubit's entitlement listener now that the BlocProvider above
    // has created the cubit.
    context.read<SupporterCubit>().start();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupporterCubit, SupporterState>(
      builder: (context, state) {
        final showPurchaseStatus =
            state.status == SupporterStatus.purchasing ||
            state.status == SupporterStatus.pending ||
            state.status == SupporterStatus.confirming;
        return Scaffold(
          appBar: DiVineAppBar(
            title: context.l10n.supporterTitle,
            showBackButton: true,
            // safePop: this screen has a registered path, so the back stack
            // can be empty on a cold entry and a raw pop would throw GoError.
            onBackPressed: () => context.safePop(fallback: SettingsScreen.path),
          ),
          backgroundColor: context.vineColors.surface,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Hero(state: state),
                  const SizedBox(height: 24),
                  if (showPurchaseStatus)
                    _PurchaseStatusNote(status: state.status),
                  if (state.isSupporter)
                    const _ActiveBadge()
                  else if (!widget.storeBillingAvailable)
                    const _NonStoreBuildNote()
                  else if (state.hasTiers)
                    _TierList(state: state)
                  else if (!showPurchaseStatus)
                    _UnavailableNote(loading: state.isBusy),
                  if (state.isSupporter) ...[
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      title: Text(context.l10n.supporterPublicRecognition),
                      subtitle: Text(
                        context.l10n.supporterPublicRecognitionBody,
                      ),
                      value: state.snapshot?.haloVisible ?? false,
                      onChanged:
                          state.snapshot == null || state.savingRecognition
                          ? null
                          : context.read<SupporterCubit>().setPublicRecognition,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    state.isSupporter
                        ? context.l10n.supporterVerificationEligible
                        : context.l10n.supporterVerificationJoin,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.supporterVerificationBody,
                    textAlign: TextAlign.center,
                  ),
                  if (state.isSupporter)
                    DivineButton(
                      label: context.l10n.supporterExploreVerification,
                      type: DivineButtonType.link,
                      onPressed: () => context.push(VerifyPage.path),
                    ),
                  const SizedBox(height: 16),
                  if (!state.isSupporter && widget.storeBillingAvailable)
                    _RestoreButton(state: state),
                  if (!state.isSupporter && state.hasTiers)
                    const _SubscriptionTerms(),
                  if (state.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _FailureBanner(
                        failure: state.failure!,
                        onDismiss: () =>
                            context.read<SupporterCubit>().dismissError(),
                      ),
                    ),
                  const SizedBox(height: 32),
                  _Disclaimer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.state});

  final SupporterState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DivineIcon(
          icon: DivineIconName.heart,
          color: VineTheme.accentOrange,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.supporterHeroTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.supporterMembershipBody,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.accentOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const DivineIcon(
            icon: DivineIconName.heart,
            color: VineTheme.accentOrange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.supporterActiveBadge,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseStatusNote extends StatelessWidget {
  const _PurchaseStatusNote({required this.status});

  final SupporterStatus status;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      SupporterStatus.purchasing => context.l10n.supporterPreparingCheckout,
      SupporterStatus.pending => context.l10n.supporterPurchasePending,
      _ => context.l10n.supporterPurchaseConfirming,
    };
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          if (status == SupporterStatus.purchasing) ...[
            const DivineCircularProgressIndicator(),
            const SizedBox(height: 12),
          ],
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TierList extends StatelessWidget {
  const _TierList({required this.state});

  final SupporterState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final tier in state.tiers)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DivineButton(
              label: _tierLabel(context, tier),
              onPressed: state.isBusy
                  ? null
                  : () => context.read<SupporterCubit>().subscribe(
                      tier.productId,
                    ),
            ),
          ),
      ],
    );
  }
}

/// Names the billing period only when the tier carries one, so a plan is
/// never shown as "/ month" when it renews yearly.
String _tierLabel(BuildContext context, SupporterTier tier) {
  final l10n = context.l10n;
  return switch (tier.billingPeriod) {
    SupporterBillingPeriod.monthly => l10n.supporterTierMonthlyLabel(
      tier.title,
      tier.price,
    ),
    SupporterBillingPeriod.annual => l10n.supporterTierAnnualLabel(
      tier.title,
      tier.price,
    ),
    null => l10n.supporterTierLabel(tier.title, tier.price),
  };
}

class _UnavailableNote extends StatelessWidget {
  const _UnavailableNote({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Text(
      loading
          ? context.l10n.supporterStoreChecking
          : context.l10n.supporterUnavailable,
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }
}

class _NonStoreBuildNote extends StatelessWidget {
  const _NonStoreBuildNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.supporterStoreNotInThisBuild,
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }
}

class _RestoreButton extends StatelessWidget {
  const _RestoreButton({required this.state});

  final SupporterState state;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      type: DivineButtonType.link,
      isLoading: state.status == SupporterStatus.restoring,
      onPressed: state.isBusy
          ? null
          : () => context.read<SupporterCubit>().restore(),
      label: context.l10n.supporterRestorePurchases,
    );
  }
}

/// Links App Store Review requires beside auto-renewing subscription offers.
abstract class SupporterLegalLinks {
  /// Apple's standard EULA, which covers the App Store subscriptions.
  static const appleStandardEula =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const divineTerms = 'https://divine.video/terms';
  static const privacyPolicy = 'https://divine.video/privacy';

  /// The Terms of Use that govern a purchase on the current platform.
  static String get termsOfUse => switch (defaultTargetPlatform) {
    _ when kIsWeb => divineTerms,
    TargetPlatform.iOS || TargetPlatform.macOS => appleStandardEula,
    _ => divineTerms,
  };
}

class _SubscriptionTerms extends StatelessWidget {
  const _SubscriptionTerms();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Text(
            l10n.supporterAutoRenewNotice,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              DivineButton(
                type: DivineButtonType.link,
                label: l10n.supporterTermsOfUse,
                onPressed: () => _openLegalPage(
                  context,
                  SupporterLegalLinks.termsOfUse,
                  l10n.supporterTermsOfUse,
                ),
              ),
              DivineButton(
                type: DivineButtonType.link,
                label: l10n.legalPrivacyPolicy,
                onPressed: () => _openLegalPage(
                  context,
                  SupporterLegalLinks.privacyPolicy,
                  l10n.legalPrivacyPolicy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _openLegalPage(
  BuildContext context,
  String url,
  String pageName,
) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    Log.error(
      'Failed to open $url: $e',
      name: 'SupporterScreen',
      category: LogCategory.ui,
    );
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.legalCouldNotOpenPage(pageName),
        error: true,
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure, required this.onDismiss});

  final SupporterFailure failure;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const DivineIcon(
          icon: DivineIconName.warning,
          color: VineTheme.accentOrange,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(_message(context, failure))),
        DivineIconButton(
          icon: DivineIconName.x,
          type: DivineIconButtonType.ghostSecondary,
          onPressed: onDismiss,
          semanticLabel: context.l10n.supporterDismissError,
        ),
      ],
    );
  }

  String _message(BuildContext context, SupporterFailure failure) {
    final l10n = context.l10n;
    switch (failure) {
      case SupporterFailure.storeUnavailable:
        return l10n.supporterErrorStoreUnavailable;
      case SupporterFailure.purchaseFailed:
        return l10n.supporterErrorPurchaseFailed;
      case SupporterFailure.purchasePending:
        return l10n.supporterErrorPurchasePending;
      case SupporterFailure.restoreFailed:
        return l10n.supporterErrorRestoreFailed;
      case SupporterFailure.ownershipConflict:
        return l10n.supporterErrorOwnershipConflict;
      case SupporterFailure.verificationUnavailable:
        return l10n.supporterErrorVerificationUnavailable;
      case SupporterFailure.unknown:
        return l10n.supporterErrorUnknown;
    }
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.supporterRecognitionDisclaimer,
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }
}
