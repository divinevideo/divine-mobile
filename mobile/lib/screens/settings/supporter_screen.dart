// ABOUTME: Settings screen for the Divine supporter subscription.
// ABOUTME: Signal-style: optional monthly support, nothing gated, recognition only.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/supporter/supporter_cubit.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/settings/settings_screen.dart';

class SupporterScreen extends ConsumerWidget {
  static const routeName = 'supporter';
  static const subpath = 'supporter';
  static const path = '/settings/supporter';

  const SupporterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(supporterRepositoryProvider);
    final analytics = ref.watch(analyticsEventSinkProvider);
    return BlocProvider(
      create: (_) => SupporterCubit(
        repository: repository,
        trackEvent: (event) => analytics.logEvent(
          name: event,
          parameters: const {},
        ),
      ),
      child: const SupporterScreenView(),
    );
  }
}

class SupporterScreenView extends StatefulWidget {
  const SupporterScreenView({super.key});

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
                  if (state.status == SupporterStatus.pending ||
                      state.status == SupporterStatus.confirming)
                    _PurchaseStatusNote(status: state.status),
                  if (state.isSupporter)
                    const _ActiveBadge()
                  else if (state.status != SupporterStatus.pending &&
                      state.status != SupporterStatus.confirming &&
                      state.hasTiers)
                    _TierList(state: state)
                  else if (state.status != SupporterStatus.pending &&
                      state.status != SupporterStatus.confirming)
                    _UnavailableNote(loading: state.isBusy),
                  const SizedBox(height: 16),
                  if (!state.isSupporter) _RestoreButton(state: state),
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
          context.l10n.supporterHeroBody,
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
    return Text(
      status == SupporterStatus.pending
          ? context.l10n.supporterPurchasePending
          : context.l10n.supporterPurchaseConfirming,
      style: Theme.of(context).textTheme.bodyLarge,
      textAlign: TextAlign.center,
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
              label: context.l10n.supporterTierMonthlyLabel(
                tier.title,
                tier.price,
              ),
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

class _RestoreButton extends StatelessWidget {
  const _RestoreButton({required this.state});

  final SupporterState state;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      type: DivineButtonType.link,
      onPressed: state.isBusy
          ? null
          : () => context.read<SupporterCubit>().restore(),
      label: context.l10n.supporterRestorePurchases,
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
      context.l10n.supporterDisclaimer,
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }
}
