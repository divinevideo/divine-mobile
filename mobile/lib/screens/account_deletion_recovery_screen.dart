// ABOUTME: Full-screen recovery gate for interrupted account deletion.
// ABOUTME: Bridges app dependencies into the recovery Cubit and renders state.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/account_deletion_recovery_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/router/route_paths.dart';

class AccountDeletionRecoveryScreen extends ConsumerWidget {
  const AccountDeletionRecoveryScreen({super.key});

  static const String path = RoutePaths.accountDeletionRecovery;
  static const String routeName = 'account-deletion-recovery';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountDeletionRecoveryRepositoryProvider);
    final authService = ref.watch(authServiceProvider);
    ref.watch(currentAuthRpcCapabilityProvider);
    final signerReadiness = authService.signerReadiness;
    final receipt = ref.watch(currentSubmittedAccountDeletionAttemptProvider);
    final submittedMonitor = ref.watch(
      submittedAccountDeletionMonitorProvider,
    );

    if (receipt?.submissionOwnedLocally ?? false) {
      return const _SubmissionInFlightRecoveryView();
    }

    if (receipt != null && submittedMonitor != null) {
      return BlocProvider<AccountDeletionRecoveryCubit>.value(
        value: submittedMonitor,
        child: const AccountDeletionRecoveryView(),
      );
    }

    return BlocProvider<AccountDeletionRecoveryCubit>(
      key: ValueKey((
        repository,
        authService,
        signerReadiness,
      )),
      create: (_) {
        final expectedPubkeyHex = authService.currentPublicKeyHex;
        final cubit = AccountDeletionRecoveryCubit(
          repository: repository,
          authService: authService,
          onAttemptResolved: () async {
            await ref
                .read(submittedAccountDeletionAttemptProvider.notifier)
                .clear(expectedPubkeyHex: expectedPubkeyHex);
            ref.invalidate(currentAccountDeletionAttemptProvider);
          },
          onAttemptUpdated: (attempt) => ref
              .read(submittedAccountDeletionAttemptProvider.notifier)
              .updateAttempt(attempt),
        );
        // A seed, not a dependency: the attempt the router gated on, which is
        // the one this process committed when the signer is already gone. The
        // cubit owns the attempt from here, so a later emission must not
        // re-create it.
        final knownAttempt = ref
            .read(currentAccountDeletionAttemptProvider)
            .value;
        switch (signerReadiness) {
          case SignerReadiness.ready:
            if (knownAttempt != null) {
              unawaited(cubit.resume(knownAttempt));
            } else {
              unawaited(cubit.load());
            }
          case SignerReadiness.unavailable:
            unawaited(cubit.signerUnavailable(attempt: knownAttempt));
          case SignerReadiness.pending:
            break;
        }
        return cubit;
      },
      child: const AccountDeletionRecoveryView(),
    );
  }
}

class _SubmissionInFlightRecoveryView extends StatelessWidget {
  const _SubmissionInFlightRecoveryView();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: Text(context.l10n.accountDeletionRecoveryTitle),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _PassiveRecoveryContent(
          body: context.l10n.accountDeletionFinishingBody,
        ),
      ),
    ),
  );
}

class AccountDeletionRecoveryView extends StatelessWidget {
  @visibleForTesting
  const AccountDeletionRecoveryView({super.key});

  @override
  Widget build(BuildContext context) {
    final hasConfirmedDeletionAttempt = context.select(
      (AccountDeletionRecoveryCubit cubit) => cubit.state.attempt != null,
    );
    return BlocListener<
      AccountDeletionRecoveryCubit,
      AccountDeletionRecoveryState
    >(
      listenWhen: (previous, current) =>
          previous.status != AccountDeletionRecoveryStatus.resolved &&
          current.status == AccountDeletionRecoveryStatus.resolved,
      listener: (context, _) => context.go(RoutePaths.videoFeedForIndex(0)),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            hasConfirmedDeletionAttempt
                ? context.l10n.accountDeletionRecoveryTitle
                : context.l10n.minorAccountReviewCheckingStatusTitle,
          ),
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _RecoveryStateContent(),
          ),
        ),
      ),
    );
  }
}

class _RecoveryStateContent extends StatelessWidget {
  const _RecoveryStateContent();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AccountDeletionRecoveryCubit>().state;
    final cubit = context.read<AccountDeletionRecoveryCubit>();
    return switch (state.status) {
      AccountDeletionRecoveryStatus.initial ||
      AccountDeletionRecoveryStatus.loading => _LoadingRecoveryContent(
        onSignOut: cubit.signOut,
      ),
      AccountDeletionRecoveryStatus.completingLocally ||
      AccountDeletionRecoveryStatus.signingOut ||
      AccountDeletionRecoveryStatus.resolved => const Center(
        child: DivineCircularProgressIndicator(),
      ),
      AccountDeletionRecoveryStatus.confirmingSubmission =>
        state.pollingPaused
            ? _RecoveryContent(
                body: context.l10n.accountDeletionFinishingBody,
                actionLabel: context.l10n.supportContactSupport,
                onPressed: () => context.push(RoutePaths.supportCenter),
                secondaryActionLabel: context.l10n.authUseAnotherAccount,
                onSecondaryPressed: () => _switchAccount(context, cubit),
              )
            : _PassiveRecoveryContent(
                body: context.l10n.accountDeletionFinishingBody,
              ),
      AccountDeletionRecoveryStatus.loadFailed => _RecoveryContent(
        body: state.failure == AccountDeletionRecoveryFailure.signerUnavailable
            ? context.l10n.authSessionExpired
            : context.l10n.authUnexpectedError,
        actionLabel: context.l10n.commonRetry,
        onPressed: cubit.retry,
        secondaryActionLabel: context.l10n.accountDeletionSignOut,
        onSecondaryPressed: cubit.signOut,
      ),
      AccountDeletionRecoveryStatus.signOutFailed => _RecoveryContent(
        body: context.l10n.authUnexpectedError,
        actionLabel: context.l10n.accountDeletionSignOut,
        onPressed: cubit.signOut,
      ),
      AccountDeletionRecoveryStatus.restorable => _RestorableContent(
        state: state,
      ),
      AccountDeletionRecoveryStatus.cancelInFlight => _RecoveryContent(
        body: context.l10n.accountDeletionCancellingBody,
        actionLabel: context.l10n.commonRetry,
        onPressed: cubit.retry,
      ),
      AccountDeletionRecoveryStatus.processing =>
        state.pollingPaused
            ? _RecoveryContent(
                body: context.l10n.accountDeletionFinishingBody,
                actionLabel: context.l10n.supportContactSupport,
                onPressed: () => context.push(RoutePaths.supportCenter),
                secondaryActionLabel: context.l10n.authUseAnotherAccount,
                onSecondaryPressed: () => _switchAccount(context, cubit),
              )
            : _RecoveryContent(
                body: context.l10n.accountDeletionFinishingBody,
                actionLabel: context.l10n.authUseAnotherAccount,
                onPressed: () => _switchAccount(context, cubit),
              ),
      AccountDeletionRecoveryStatus.completed => _RecoveryContent(
        body: context.l10n.deleteAccountSuccess,
        actionLabel: context.l10n.commonClose,
        onPressed: cubit.acknowledgeCompletion,
      ),
      AccountDeletionRecoveryStatus.cleanupFailed => _RecoveryContent(
        body: state.failure == AccountDeletionRecoveryFailure.keychainCleanup
            ? context.l10n.deleteAccountKeyDeletionWarning
            : state.failure == AccountDeletionRecoveryFailure.receiptClear
            ? context.l10n.authUnexpectedError
            : context.l10n.deleteAccountLocalDataDeletionFailed,
        actionLabel: context.l10n.commonRetry,
        onPressed: cubit.completeLocalCleanup,
      ),
      AccountDeletionRecoveryStatus.terminalFailure => _RecoveryContent(
        body: _failureBody(context, state.attempt?.failureCode),
        actionLabel: context.l10n.supportContactSupport,
        onPressed: () => context.push(RoutePaths.supportCenter),
        secondaryActionLabel: context.l10n.accountDeletionSignOut,
        onSecondaryPressed: cubit.signOut,
      ),
    };
  }
}

Future<void> _switchAccount(
  BuildContext context,
  AccountDeletionRecoveryCubit cubit,
) async {
  final signedOut = await cubit.switchAccount();
  if (signedOut && context.mounted) context.go(RoutePaths.welcome);
}

class _PassiveRecoveryContent extends StatelessWidget {
  const _PassiveRecoveryContent({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 24,
    children: [
      const Center(child: DivineCircularProgressIndicator()),
      Text(
        body,
        textAlign: TextAlign.center,
        style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
      ),
    ],
  );
}

class _LoadingRecoveryContent extends StatelessWidget {
  const _LoadingRecoveryContent({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        const Center(child: DivineCircularProgressIndicator()),
        DivineButton(
          label: context.l10n.accountDeletionSignOut,
          type: DivineButtonType.secondary,
          onPressed: onSignOut,
        ),
      ],
    );
  }
}

class _RestorableContent extends StatelessWidget {
  const _RestorableContent({required this.state});

  final AccountDeletionRecoveryState state;

  @override
  Widget build(BuildContext context) {
    final attempt = state.attempt!;
    final hasUsername = attempt.username != null;
    return _RecoveryContent(
      body: switch (state.failure) {
        AccountDeletionRecoveryFailure.usernameRestore =>
          context.l10n.accountDeletionRecoveryFailed,
        AccountDeletionRecoveryFailure.statusLookup =>
          context.l10n.accountDeletionRecoveryStatusFailed,
        _ =>
          hasUsername
              ? _usernameRecoveryBody(context, attempt)
              : context.l10n.accountDeletionCancelAttemptBody,
      },
      actionLabel: hasUsername
          ? context.l10n.accountDeletionRestoreUsername
          : context.l10n.accountDeletionCancelAttempt,
      onPressed: context.read<AccountDeletionRecoveryCubit>().cancel,
    );
  }
}

String _usernameRecoveryBody(
  BuildContext context,
  AccountDeletionAttempt attempt,
) {
  final expiresAt = attempt.usernameExpiresAt;
  if (expiresAt == null) return context.l10n.accountDeletionRecoveryBody;
  final expiryDate = MaterialLocalizations.of(context).formatFullDate(
    DateTime.fromMillisecondsSinceEpoch(
      expiresAt * Duration.millisecondsPerSecond,
    ).toLocal(),
  );
  return context.l10n.accountDeletionRecoveryBodyWithExpiry(expiryDate);
}

String _failureBody(
  BuildContext context,
  String? failureCode,
) => switch (failureCode) {
  'username_attempt_expired' => context.l10n.deleteAccountDeletionIncomplete,
  'keycast_deletion_failed' => context.l10n.deleteAccountServerDeletionFailed,
  _ => context.l10n.accountDeletionTerminalFailureBody,
};

class _RecoveryContent extends StatelessWidget {
  const _RecoveryContent({
    required this.body,
    required this.actionLabel,
    required this.onPressed,
    this.secondaryActionLabel,
    this.onSecondaryPressed,
  });

  final String body;
  final String actionLabel;
  final VoidCallback? onPressed;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        const DivineIcon(icon: DivineIconName.userCircle, size: 64),
        Text(
          body,
          textAlign: TextAlign.center,
          style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
        ),
        DivineButton(
          label: actionLabel,
          onPressed: onPressed,
          leadingIcon: DivineIconName.arrowCounterClockwise,
        ),
        if (secondaryActionLabel != null)
          DivineButton(
            label: secondaryActionLabel!,
            type: DivineButtonType.secondary,
            onPressed: onSecondaryPressed,
          ),
      ],
    );
  }
}
