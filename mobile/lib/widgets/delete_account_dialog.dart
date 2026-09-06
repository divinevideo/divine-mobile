// ABOUTME: Account deletion flow: confirmation sheets, progress sheet, orchestration
// ABOUTME: Warning sheets for key removal and content deletion with confirmation

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Ask whether to remove this account's keys from the device only.
///
/// Returns true when the user confirmed. Dismissing the sheet — barrier tap
/// or swipe — counts as cancelling, so backing out is never destructive.
Future<bool> showRemoveKeysWarningSheet(BuildContext context) async {
  final confirmed = await VineBottomSheetPrompt.show<bool>(
    context: context,
    sticker: DivineStickerName.skeletonKey,
    title: context.l10n.deleteAccountRemoveKeysTitle,
    subtitle: context.l10n.deleteAccountRemoveKeysBody,
    primaryButtonText: context.l10n.deleteAccountRemoveKeysConfirm,
    primaryButtonType: DivineButtonType.error,
    onPrimaryPressed: () => Navigator.of(context).pop(true),
    secondaryButtonText: context.l10n.commonCancel,
    onSecondaryPressed: () => Navigator.of(context).pop(false),
  );
  return confirmed ?? false;
}

/// Show the confirmation sheet before deleting all content (requires typing
/// DELETE).
///
/// This sheet ensures they understand the dangerous/irreversible nature of
/// account deletion. It opens immediately and never blocks on a name-server
/// lookup: name ownership is resolved at the deletion boundary (in
/// [executeAccountDeletion]) once [onConfirm] runs, so a slow or failed lookup
/// fails the deletion closed rather than silently skipping the release.
///
/// Dismissing the sheet cancels: nothing is deleted until the token is typed
/// and the destructive button is tapped.
Future<void> showDeleteAllContentWarningSheet({
  required BuildContext context,
  required DeleteAccountConfirmation confirmation,
  required VoidCallback onConfirm,
}) async {
  // The form and the pinned footer are sibling slots of the sheet rather than
  // one subtree, so the footer learns about the typed token through this
  // notifier and reaches the form's state through the key. The controllers
  // themselves stay inside the form's State, which is what disposes them —
  // the exit animation still rebuilds the field after this future completes.
  // The notifier is safe to dispose here despite that: its only writer is the
  // field's onChanged, and the text input connection is already closed by the
  // time the route pops.
  final canConfirm = ValueNotifier<bool>(false);
  final formKey = GlobalKey<_DeleteAllContentFormState>();

  await VineBottomSheet.show<void>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: VineTheme.bottomSheetDismissFloor,
    maxChildSize: 0.95,
    // Error-coloured deliberately: this is the last gate before an
    // irreversible delete, and the red title is the destructive-action signal
    // the pre-sheet dialog carried. Reuses the header's own size and weight so
    // only the colour differs from the sheet default.
    title: Text(
      context.l10n.deleteAccountFinalConfirmationTitle,
      style: VineTheme.titleMediumFont(color: VineTheme.error),
    ),
    bottomInput: _DeleteAllContentActions(
      canConfirm: canConfirm,
      onConfirm: () => formKey.currentState?.confirm(),
    ),
    buildScrollBody: (scrollController) => _DeleteAllContentForm(
      key: formKey,
      confirmation: confirmation,
      onConfirm: onConfirm,
      canConfirm: canConfirm,
      scrollController: scrollController,
    ),
  );

  canConfirm.dispose();
}

/// Pinned footer of the delete sheet: cancel plus the destructive action.
class _DeleteAllContentActions extends StatelessWidget {
  const _DeleteAllContentActions({
    required this.canConfirm,
    required this.onConfirm,
  });

  final ValueNotifier<bool> canConfirm;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: DivineButton(
              label: l10n.commonCancel,
              type: DivineButtonType.secondary,
              onPressed: context.pop,
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: canConfirm,
              builder: (context, enabled, _) => DivineButton(
                label: l10n.deleteAccountDeleteAllContentButton,
                type: DivineButtonType.error,
                onPressed: enabled ? onConfirm : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable body of the delete sheet.
///
/// [scrollController] comes from the sheet's `DraggableScrollableSheet`, so
/// dragging the form down collapses and dismisses the sheet.
class _DeleteAllContentForm extends StatefulWidget {
  const _DeleteAllContentForm({
    required this.confirmation,
    required this.onConfirm,
    required this.canConfirm,
    required this.scrollController,
    super.key,
  });

  final DeleteAccountConfirmation confirmation;
  final void Function() onConfirm;

  /// Mirrors "the typed token matches" out to the pinned footer.
  final ValueNotifier<bool> canConfirm;
  final ScrollController scrollController;

  @override
  State<_DeleteAllContentForm> createState() => _DeleteAllContentFormState();
}

class _DeleteAllContentFormState extends State<_DeleteAllContentForm> {
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  /// Closes the sheet and runs the deletion; name ownership is resolved at the
  /// deletion boundary, not here.
  ///
  /// Called by the footer through the form's key, since the two are sibling
  /// slots of the sheet.
  void confirm() {
    // Re-derived from the controller rather than trusting the footer's
    // notifier, which only gates the button's enabled state.
    if (!widget.confirmation.matches(_confirmationController.text)) return;
    context.pop();
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.confirmation;

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          _DeleteIdentityHeader(confirmation: c),
          Text(
            l10n.deleteAccountWarningBody,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                c.isUsernameConfirmation
                    ? l10n.deleteAccountConfirmUsernamePrompt
                    : l10n.deleteAccountConfirmDeletePrompt,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              // Monospaced so the token reads as something to copy verbatim.
              Text(
                c.requiredToken,
                style: VineTheme.titleMediumFont(
                  color: VineTheme.error,
                ).copyWith(fontFamily: 'monospace'),
              ),
            ],
          ),
          DivineTextField(
            controller: _confirmationController,
            labelText: c.isUsernameConfirmation
                ? l10n.deleteAccountConfirmationHintUsername
                : l10n.deleteAccountConfirmationHint,
            filled: true,
            autocorrect: false,
            textCapitalization: c.isUsernameConfirmation
                ? TextCapitalization.none
                : TextCapitalization.characters,
            onChanged: (value) => widget.canConfirm.value = c.matches(value),
          ),
        ],
      ),
    );
  }
}

/// Identity block (avatar + name + handle/npub) for the delete sheet.
class _DeleteIdentityHeader extends StatelessWidget {
  const _DeleteIdentityHeader({required this.confirmation});

  final DeleteAccountConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    // Read as one node ("Name, handle") — a single "this account" unit.
    return MergeSemantics(
      child: Row(
        children: [
          // Avatar is decorative here — the name is shown as text beside it, so
          // exclude it from the merged node to avoid reading the name twice.
          ExcludeSemantics(
            child: UserAvatar(
              imageUrl: confirmation.avatarUrl,
              name: confirmation.displayName,
              placeholderSeed: confirmation.pubkeyHex,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  confirmation.displayName,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  confirmation.identifierLine,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress sheet content that shows deletion progress using BLoC pattern.
class _DeletionProgressSheetContent extends StatelessWidget {
  const _DeletionProgressSheetContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child:
          BlocBuilder<
            AccountDeletionProgressCubit,
            AccountDeletionProgressState
          >(
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: switch (state) {
                  AccountDeletionProgressUpdating(
                    :final current,
                    :final total,
                  ) =>
                    [
                      DivineCircularProgressIndicator(
                        value: current / total,
                        color: context.vineColors.accentPositive,
                        backgroundColor: context.vineColors.card,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.videoGridDeletingContent,
                        style: VineTheme.bodyLargeFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.deleteAccountProgressEvents(
                          current,
                          total,
                        ),
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.secondaryText,
                        ),
                      ),
                    ],
                  AccountDeletionProgressPreparing() => [
                    DivineCircularProgressIndicator(
                      color: context.vineColors.accentPositive,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.deleteAccountPreparingDeletion,
                      style: VineTheme.bodyLargeFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                  ],
                },
              );
            },
          ),
    );
  }
}

/// Execute the full account deletion flow:
/// 1. Show loading indicator with progress
/// 2. Resolve [ownedUsernameLookup]. When it finds a name, prepare a
///    recoverable @divine.video release (needs a working signer); on failure,
///    abort with nothing deleted (hard-block). Release is mandatory whenever
///    the user owns a name.
/// 3. Send NIP-62 deletion request (requires working signer)
/// 4. Submit the deletion to the coordinator, which finalizes the username and
///    Keycast account; without a username, delete Keycast directly
/// 5. Sign out and delete local keys
/// 6. Show success snackbar (router auto-redirects to /welcome)
///
/// If a later step fails after preparation, the user can restore the username.
/// The server keeps that recovery state across app restarts and reinstalls.
///
/// Aborts before any step (including the release) when [confirmedPubkey] is set
/// and no longer matches the signed-in account.
///
/// [context] - BuildContext for showing sheets
/// [deletionService] - Service to execute NIP-62 deletion
/// [authService] - Service for Keycast deletion and sign out
/// [ownedUsernameLookup] - The eventual found / confirmed-not-found / unknown
///   ownership result. Unknown and lookup failures abort before deletion.
/// [confirmedPubkey] - When set, aborts before any step if the signed-in
///   account no longer matches, binding deletion to the confirmed account
/// [screenName] - Name of the calling screen for logging
/// [onDeletionSubmitted] - Persists the attempt and vanish event before the
///   irreversible submit request, then updates it with the coordinator answer.
///   A lost response is ambiguous, so the caller must keep the user gated from
///   the receipt rather than returning to normal account use (#8583).
/// [onDeletionFlowFinished] - Releases the in-process ownership of that receipt
///   after this flow has finished submitting and cleaning up.
Future<void> executeAccountDeletion({
  required BuildContext context,
  required AccountDeletionService deletionService,
  required AuthService authService,
  required AccountDeletionRecoveryRepository deletionRecoveryRepository,
  required Future<DivineUsernameLookup> ownedUsernameLookup,
  String? confirmedPubkey,
  String screenName = 'AccountDeletion',
  Future<void> Function(AccountDeletionAttempt attempt, String vanishEventId)?
  onDeletionSubmitted,
  void Function()? onDeletionFlowFinished,
}) async {
  if (!context.mounted) return;

  // Created after the mounted gate: returning above it would leave this cubit
  // open, since only the `finally` below ever closes one.
  final cubit = AccountDeletionProgressCubit();

  // Signing out flips auth state to unauthenticated, which makes the global
  // redirect replace the whole stack with /welcome — tearing down the route
  // this was called from. Everything needed to report the outcome afterwards
  // is therefore captured here: the messenger and the view sit above the
  // Navigator and outlive the redirect, so the confirmation lands on the
  // destination instead of vanishing with the caller (#6450).
  final messenger = ScaffoldMessenger.of(context);
  final view = View.of(context);
  final textDirection = Directionality.of(context);
  // The navigator the sheet is pushed onto, resolved while the caller is
  // still mounted. `context.pop()` would resolve to the innermost navigator
  // instead, which for a shell-nested caller is not the one holding it.
  final rootNavigator = Navigator.of(context, rootNavigator: true);

  // The sheet's own route, captured so dismissal can target exactly this
  // sheet: `VineBottomSheet.show` hands back the result future, not the route.
  ModalRoute<void>? progressSheetRoute;
  // Set once the sheet has left the navigator, whoever took it down. Before
  // the sheet's first build there is no route to target, and this is then the
  // only way to tell "not shown yet" from "already gone".
  var progressSheetClosed = false;

  unawaited(
    VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
      showHeader: false,
      showDragHandle: false,
      isDismissible: false,
      enableDrag: false,
      tapOutsideToDismiss: false,
      // Pinned rather than left at VineBottomSheet's local-navigator default:
      // this blocks the UI through an irreversible delete, so it has to cover
      // shell chrome too. Both callers are root-level routes today, so it
      // changes nothing now — it keeps a future shell-nested caller from
      // leaving the bottom nav tappable mid-deletion.
      useRootNavigator: true,
      body: const _DeletionProgressSheetContent(),
      contentWrapper: (sheetContext, child) {
        progressSheetRoute = ModalRoute.of<void>(sheetContext);
        return BlocProvider.value(value: cubit, child: child);
      },
    ).whenComplete(() => progressSheetClosed = true),
  );

  // Track if the progress sheet was dismissed to avoid double-popping.
  var progressSheetDismissed = false;

  void dismissProgressSheet() {
    if (progressSheetDismissed || !rootNavigator.mounted) return;
    progressSheetDismissed = true;
    final route = progressSheetRoute;
    if (route == null) {
      // The sheet has not had its first build yet, so no frame has run since
      // it was pushed and nothing can have moved it: it is still on top —
      // unless it never made it onto the navigator, or left again before it
      // could build. Popping blindly then removes someone else's route, which
      // is the failure this whole function exists to avoid.
      if (!progressSheetClosed) rootNavigator.pop();
      return;
    }
    // Once built, dismiss by identity rather than popping whatever sits on
    // top. The sign-out redirect takes this sheet down together with the
    // route it was pushed over, and a blind pop then removes the page the
    // redirect just installed — for /welcome, the last one on the stack, so
    // the app is left with no page at all (#6450).
    if (!route.isActive) return;
    if (route.isCurrent) {
      rootNavigator.pop();
    } else {
      rootNavigator.removeRoute(route);
    }
  }

  // Speak each delete outcome so screen-reader users hear the result the
  // snackbar shows visually. Mirrors the snackbar text at every outcome site.
  void announceOutcome(String message) {
    SemanticsService.sendAnnouncement(view, message, textDirection);
  }

  // Captured before the first await so the post-sign-out catch can localize
  // without reading BuildContext across an async gap.
  final keyDeletionWarningText = context.l10n.deleteAccountKeyDeletionWarning;
  final localDataDeletionFailedText =
      context.l10n.deleteAccountLocalDataDeletionFailed;
  final accountChangedText = context.l10n.deleteAccountAccountChanged;
  final deletionUnavailableText = context.l10n.deleteAccountDeletionUnavailable;
  final reportBugText = context.l10n.supportReportBug;
  final deletionIncompleteText = context.l10n.deleteAccountDeletionIncomplete;
  final deletionNotStartedText = context.l10n.deleteAccountDeletionNotStarted;
  // Assigned at the deletion boundary once name ownership is resolved.
  String? handleLabel;
  final recoveryBodyText = context.l10n.accountDeletionRecoveryBody;
  final cancelAttemptBodyText = context.l10n.accountDeletionCancelAttemptBody;
  final restoreUsernameText = context.l10n.accountDeletionRestoreUsername;
  final cancelAttemptText = context.l10n.accountDeletionCancelAttempt;
  final usernameRestoredText = context.l10n.accountDeletionUsernameRestored;
  final attemptCancelledText = context.l10n.accountDeletionAttemptCancelled;
  final recoveryFailedText = context.l10n.accountDeletionRecoveryFailed;
  final finishingDeletionText = context.l10n.accountDeletionFinishingBody;
  final deletionSuccessText = context.l10n.deleteAccountSuccess;
  final deletionSuccessUnverifiedText =
      context.l10n.deleteAccountSuccessContentUnverified;

  AccountDeletionAttempt? deletionAttempt;
  var usernamePrepared = false;

  void showDurableDeletionOutcome(String message, {bool offerCancel = true}) {
    final attempt = deletionAttempt;
    if (!context.mounted || attempt == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        message,
        error: true,
        duration: const Duration(seconds: 12),
        actionLabel: offerCancel
            ? (usernamePrepared ? restoreUsernameText : cancelAttemptText)
            : null,
        onActionPressed: offerCancel
            ? () {
                unawaited(
                  deletionRecoveryRepository
                      .cancelAndWait(attemptId: attempt.id)
                      .then((restored) {
                        if (!context.mounted) return;
                        final succeeded =
                            restored.status ==
                            AccountDeletionAttemptStatus.cancelled;
                        final text = succeeded
                            ? (usernamePrepared
                                  ? usernameRestoredText
                                  : attemptCancelledText)
                            : (usernamePrepared
                                  ? recoveryFailedText
                                  : deletionIncompleteText);
                        ScaffoldMessenger.of(context).showSnackBar(
                          DivineSnackbarContainer.snackBar(
                            text,
                            error: !succeeded,
                          ),
                        );
                        announceOutcome(text);
                      })
                      .catchError((Object _) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          DivineSnackbarContainer.snackBar(
                            usernamePrepared
                                ? recoveryFailedText
                                : deletionIncompleteText,
                            error: true,
                          ),
                        );
                        announceOutcome(
                          usernamePrepared
                              ? recoveryFailedText
                              : deletionIncompleteText,
                        );
                      }),
                );
              }
            : null,
      ),
    );
    announceOutcome(message);
  }

  void abortPreparation(
    Object error,
    String message, {
    bool offerSupport = false,
  }) {
    Log.warning(
      'Account deletion could not be prepared ($error); aborting '
      'account deletion',
      name: screenName,
      category: LogCategory.auth,
    );
    dismissProgressSheet();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        message,
        error: true,
        duration: offerSupport ? const Duration(seconds: 12) : null,
        actionLabel: offerSupport ? reportBugText : null,
        onActionPressed: offerSupport
            ? () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                context.push(RoutePaths.supportReportBug);
              }
            : null,
      ),
    );
    announceOutcome(message);
  }

  bool stopCleanupIfAccountChanged() {
    if (confirmedPubkey == null ||
        authService.currentPublicKeyHex == confirmedPubkey) {
      return false;
    }
    Log.warning(
      'Account-bound cleanup aborted after network deletion: signed-in '
      'account changed',
      name: screenName,
      category: LogCategory.auth,
    );
    dismissProgressSheet();
    if (context.mounted) {
      showDurableDeletionOutcome(
        usernamePrepared ? recoveryBodyText : cancelAttemptBodyText,
      );
    }
    return true;
  }

  try {
    // Bind to the confirmed account: if the signed-in account changed since the
    // user confirmed, abort before releasing the name or deleting anything.
    if (confirmedPubkey != null &&
        authService.currentPublicKeyHex != confirmedPubkey) {
      Log.warning(
        'Deletion aborted: signed-in account changed since confirmation',
        name: screenName,
        category: LogCategory.auth,
      );
      dismissProgressSheet();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(accountChangedText, error: true),
        );
        announceOutcome(accountChangedText);
      }
      return;
    }

    // Pre-flight before ANY destructive step. The server-side account deletion
    // can only be authorized while the access token still carries the
    // first-party fact it was minted with, but it runs *after* the irreversible
    // NIP-62 vanish and kind-5 sweep. Without this gate a returning user has
    // their content broadcast for deletion and is then refused, leaving them
    // signed in with a live account and no way back. See #6335 / #4881.
    //
    // Refusing here costs the user a sign-in. Not refusing costs them their
    // content, permanently.
    final readiness = await authService.checkAccountDeletionReadiness();
    if (readiness == AccountDeletionReadiness.requiresReauthentication) {
      Log.warning(
        'Deletion blocked before publishing: session cannot authorize '
        'server-side account deletion',
        name: screenName,
        category: LogCategory.auth,
      );
      dismissProgressSheet();
      if (context.mounted) {
        final text = context.l10n.deleteAccountReauthRequired;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(DivineSnackbarContainer.snackBar(text, error: true));
        announceOutcome(text);
      }
      return;
    }
    if (!context.mounted) return;

    // Resolve name ownership at the deletion boundary, under the progress sheet
    // and before any destructive step. Release is mandatory, so an undetermined
    // lookup fails closed: deleting without releasing a name the user may own is
    // not acceptable. A confirmed absence proceeds with no release.
    final DivineUsernameLookup lookup;
    try {
      lookup = await ownedUsernameLookup;
    } on Object catch (error) {
      if (!context.mounted) return;
      abortPreparation(error, deletionNotStartedText);
      return;
    }
    if (!context.mounted) return;
    final String? releaseCanonical;
    switch (lookup) {
      case DivineUsernameFound(:final name, :final canonical):
        releaseCanonical = canonical;
        handleLabel = '@$name.divine.video';
      case DivineUsernameNotFound():
        releaseCanonical = null;
      case DivineUsernameUnknown():
        abortPreparation(
          StateError('Divine username ownership could not be determined'),
          deletionNotStartedText,
        );
        return;
    }

    // Create the durable coordinator attempt for every deletion. Whenever the
    // user owns a @divine.video name the repository also performs the owner-auth
    // Name Server prepare and the coordinator's verified handshake — release is
    // mandatory, so it always runs for a name-holder.
    {
      try {
        final prepared = await deletionRecoveryRepository.prepare(
          username: releaseCanonical,
        );
        if (prepared.status != AccountDeletionAttemptStatus.recoverable) {
          throw AccountDeletionRecoveryException(
            'Prepare returned ${prepared.status.name}',
            stage: AccountDeletionRecoveryStage.coordinatorAttempt,
          );
        }
        deletionAttempt = prepared;
        usernamePrepared = prepared.username != null;
        Log.info(
          'Prepared durable account deletion attempt before deletion',
          name: screenName,
          category: LogCategory.auth,
        );
      } on AccountDeletionRecoveryException catch (error) {
        // Release is mandatory, so a name-release failure fails the whole
        // deletion closed (nothing deleted). The unavailable 503 and the
        // missing-coordinator route both mean deletion is unavailable right now
        // — not something a retry fixes — so both take the unavailable copy and
        // offer the bug-report action. Once the Name Server request starts, its
        // outcome can be ambiguous and the durable attempt may need recovery,
        // so those stages must keep neutral guidance rather than claiming that
        // nothing happened. The remaining pre-name-server failures can say the
        // deletion did not start.
        final isUnavailable =
            error.stage == AccountDeletionRecoveryStage.coordinatorAttempt &&
            (error.indicatesUsernameRecoveryUnsupported ||
                error.indicatesMissingCoordinatorRoute);
        final needsNeutralRecoveryGuidance =
            error.stage == AccountDeletionRecoveryStage.usernamePreparation ||
            error.stage ==
                AccountDeletionRecoveryStage.coordinatorUsernameConfirmation;
        abortPreparation(
          error,
          isUnavailable
              ? deletionUnavailableText
              : needsNeutralRecoveryGuidance
              ? deletionIncompleteText
              : deletionNotStartedText,
          offerSupport: isUnavailable,
        );
        return;
      } on Object catch (error) {
        abortPreparation(error, deletionNotStartedText);
        return;
      }
    }

    final finalReadiness = await authService.checkAccountDeletionReadiness();
    if (finalReadiness == AccountDeletionReadiness.requiresReauthentication) {
      Log.warning(
        'Deletion blocked after username release step: session cannot authorize '
        'server-side account deletion',
        name: screenName,
        category: LogCategory.auth,
      );
      dismissProgressSheet();
      if (context.mounted) {
        showDurableDeletionOutcome(
          usernamePrepared ? recoveryBodyText : cancelAttemptBodyText,
        );
      }
      return;
    }
    if (!context.mounted) return;

    // Publish the NIP-62 deletion request (requires working signer).
    final result = await deletionService.deleteAccount(
      onProgress: cubit.updateProgress,
      expectedPubkey: confirmedPubkey,
    );

    if (result.success) {
      // The service's signer checks end when its Future completes. Re-bind at
      // the caller boundary before account-scoped cleanup, because Keycast
      // deletion and sign-out resolve the account that is active right now.
      if (stopCleanupIfAccountChanged()) return;

      final attempt = deletionAttempt;
      final eventId = result.deleteEventId;
      if (eventId == null) {
        dismissProgressSheet();
        showDurableDeletionOutcome(
          usernamePrepared ? recoveryBodyText : cancelAttemptBodyText,
        );
        return;
      }
      AccountDeletionAttempt submitted;
      try {
        await onDeletionSubmitted?.call(attempt, eventId);
      } on Object catch (error) {
        Log.error(
          'Could not persist account deletion receipt',
          name: screenName,
          category: LogCategory.auth,
          error: error,
        );
        dismissProgressSheet();
        showDurableDeletionOutcome(
          usernamePrepared ? recoveryBodyText : cancelAttemptBodyText,
        );
        return;
      }
      try {
        submitted = await deletionRecoveryRepository.submit(
          attemptId: attempt.id,
          vanishEventId: eventId,
        );
        deletionAttempt = submitted;
        await onDeletionSubmitted?.call(submitted, eventId);
        if (submitted.status != AccountDeletionAttemptStatus.processing &&
            submitted.status != AccountDeletionAttemptStatus.completed) {
          throw AccountDeletionRecoveryException(
            'Submit returned ${submitted.status.name}',
          );
        }
      } on Object catch (error) {
        Log.error(
          'Could not submit durable deletion attempt',
          name: screenName,
          category: LogCategory.auth,
          error: error,
        );
        dismissProgressSheet();
        showDurableDeletionOutcome(finishingDeletionText, offerCancel: false);
        return;
      }

      if (submitted.status == AccountDeletionAttemptStatus.processing) {
        dismissProgressSheet();
        showDurableDeletionOutcome(finishingDeletionText, offerCancel: false);
        await authService.signOut();
        return;
      }

      // Funnelcake owns Keycast deletion for every submitted attempt, with or
      // without a username. Mobile must not repeat that terminal operation.
      if (stopCleanupIfAccountChanged()) return;

      // Sign out, delete local keys, and clear local account data.
      // Router will automatically redirect to /welcome when auth state
      // becomes unauthenticated.
      // signOut may throw SecureKeyStorageException if platform key
      // deletion failed — the user IS signed out but keys may remain.
      String? keyDeletionWarning;
      String? localDataDeletionFailure;
      try {
        await authService.signOut(deleteKeys: true, deleteLocalUserData: true);
      } on SecureKeyStorageException catch (e) {
        Log.warning(
          'Key deletion failed during account deletion: $e',
          name: screenName,
          category: LogCategory.auth,
        );
        keyDeletionWarning = keyDeletionWarningText;
      } on UserDataCleanupException catch (e) {
        Log.warning(
          'Local user data cleanup failed during account deletion: $e',
          name: screenName,
          category: LogCategory.auth,
        );
        localDataDeletionFailure = localDataDeletionFailedText;
      }

      // Close loading indicator and show result snackbar. Sign-out has already
      // redirected to /welcome and taken the calling route with it, so the
      // outcome is reported through the messenger captured up front — gating
      // this on `context.mounted` left a completed deletion silent (#6450).
      dismissProgressSheet();
      // A failed or timed-out relay query may only enumerate cached or partial
      // content. A capped query or unconfirmed kind-5 batch is incomplete too.
      // Saying "deletion requests sent" would overstate any of these outcomes.
      final snackbarText =
          keyDeletionWarning ??
          localDataDeletionFailure ??
          (result.contentQueryFailed || result.contentDeletionIncomplete
              ? deletionSuccessUnverifiedText
              : deletionSuccessText);
      if (messenger.mounted) {
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            snackbarText,
            error:
                keyDeletionWarning != null || localDataDeletionFailure != null,
          ),
        );
      }
      announceOutcome(snackbarText);
    } else {
      // Content deletion (NIP-62) failed.
      Log.error(
        'Content deletion failed after preparing durable deletion for '
        '${handleLabel ?? 'an account without a handle'}',
        name: screenName,
        category: LogCategory.auth,
      );
      dismissProgressSheet();
      if (context.mounted) {
        showDurableDeletionOutcome(
          usernamePrepared ? recoveryBodyText : cancelAttemptBodyText,
        );
      }
    }
  } finally {
    onDeletionFlowFinished?.call();
    await cubit.close();

    // Ensure the progress sheet is dismissed even if an exception occurred.
    dismissProgressSheet();
  }
}

/// Cubit for managing account deletion progress state.
///
/// Used by the deletion progress dialog to display real-time
/// progress updates during the NIP-62 account deletion flow.
class AccountDeletionProgressCubit extends Cubit<AccountDeletionProgressState> {
  AccountDeletionProgressCubit()
    : super(const AccountDeletionProgressPreparing());

  /// Update the deletion progress.
  ///
  /// [current] - Number of events processed so far
  /// [total] - Total number of events to process
  void updateProgress(int current, int total) {
    emit(AccountDeletionProgressUpdating(current: current, total: total));
  }
}

/// State for the account deletion progress cubit.
sealed class AccountDeletionProgressState extends Equatable {
  const AccountDeletionProgressState();

  @override
  List<Object?> get props => [];
}

/// Initial state while preparing for deletion (fetching events).
class AccountDeletionProgressPreparing extends AccountDeletionProgressState {
  const AccountDeletionProgressPreparing();
}

/// State with active deletion progress.
class AccountDeletionProgressUpdating extends AccountDeletionProgressState {
  const AccountDeletionProgressUpdating({
    required this.current,
    required this.total,
  });

  /// Number of events processed so far.
  final int current;

  /// Total number of events to process.
  final int total;

  @override
  List<Object?> get props => [current, total];
}
