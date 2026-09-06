// ABOUTME: Shared entry point that opens the account deletion flow
// ABOUTME: Called by every screen that offers deletion so the gates cannot drift

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/owned_divine_username_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/widgets/modal_progress_overlay.dart';

/// How long to wait for the profile behind the confirmation gate.
///
/// Cache-first, so this is usually instant. A miss degrades to npub + DELETE
/// rather than hanging the tap.
const Duration _profileResolveTimeout = Duration(seconds: 3);

/// Open the account deletion flow: resolve the identity to confirm against,
/// show the type-to-confirm gate, then run the deletion.
///
/// Every entry point calls this rather than rebuilding the sequence, so the
/// confirmation gate, the mandatory username release and the step ordering
/// cannot drift between screens. [screenName] only labels the logs.
///
/// Returns without doing anything when no account is signed in.
Future<void> startAccountDeletionFlow({
  required BuildContext context,
  required WidgetRef ref,
  required String screenName,
}) async {
  final deletionService = ref.read(accountDeletionServiceProvider);
  final authService = ref.read(authServiceProvider);
  final deletionRecoveryRepository = ref.read(
    accountDeletionRecoveryRepositoryProvider,
  );
  final pubkey = authService.currentPublicKeyHex;
  if (pubkey == null || pubkey.isEmpty) return;
  final pendingDeletion = ref.read(submittedAccountDeletionAttemptProvider);
  if (pendingDeletion != null && pendingDeletion.pubkeyHex != pubkey) {
    final monitor = ref.read(submittedAccountDeletionMonitorProvider);
    if (monitor?.state.pollingPaused ?? false) {
      unawaited(monitor!.resume(pendingDeletion.attempt));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.accountDeletionOtherAccountPending),
        action: SnackBarAction(
          label: context.l10n.supportContactSupport,
          onPressed: () => context.push(RoutePaths.supportCenter),
        ),
      ),
    );
    return;
  }

  // Kick off the owned-name lookup but do not await it here: the dialog opens
  // immediately and the future is resolved at the deletion boundary, where an
  // undetermined result fails the deletion closed. A slow name-server call
  // never blocks the tap.
  final ownedUsernameLookup = ref.read(ownedDivineUsernameProvider.future);

  final overlay = ModalProgressOverlay.show(context);
  UserProfile? profile;
  try {
    profile = await ref
        .read(fetchUserProfileProvider(pubkey).future)
        .timeout(_profileResolveTimeout, onTimeout: () => null);
  } catch (_) {
    profile = null;
  } finally {
    overlay.dismiss();
  }
  if (!context.mounted) return;

  // The gate anchors on the shown profile identity (displayNip05) to confirm
  // *which account* is being erased — deliberately distinct from the release
  // target (the owned @divine.video handle). The two can differ for an
  // external-NIP-05 user who also owns a divine username; that divergence is
  // intended, not a mismatch to reconcile.
  final confirmation = DeleteAccountConfirmation(
    pubkeyHex: pubkey,
    displayName:
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey),
    avatarUrl: profile?.picture,
    handle: profile?.displayNip05,
  );

  await showDeleteAllContentWarningSheet(
    context: context,
    confirmation: confirmation,
    onConfirm: () async {
      await executeAccountDeletion(
        context: context,
        deletionService: deletionService,
        authService: authService,
        deletionRecoveryRepository: deletionRecoveryRepository,
        ownedUsernameLookup: ownedUsernameLookup,
        confirmedPubkey: pubkey,
        screenName: screenName,
        // The gate reads this record instead of refetching: the coordinator
        // deletes the Keycast user right after accepting, and a lookup signed
        // through that signer fails, which used to leave the user signed in on
        // the settings screen (#8583).
        onDeletionSubmitted: (attempt, vanishEventId) async {
          await ref
              .read(submittedAccountDeletionAttemptProvider.notifier)
              .record(
                pubkeyHex: pubkey,
                attempt: attempt,
                vanishEventId: vanishEventId,
              );
          final owner = ref.read(submittedAccountDeletionMonitorProvider);
          if (owner == null) {
            throw StateError('Could not start account deletion recovery');
          }
          await owner.resume(attempt, signOutWhenProcessing: false);
          final submittedStatus = owner.state.attempt?.status;
          if (submittedStatus != AccountDeletionAttemptStatus.processing &&
              submittedStatus != AccountDeletionAttemptStatus.completed) {
            throw const AccountDeletionRecoveryException(
              'Could not submit durable deletion attempt',
            );
          }
        },
      );
      ref.invalidate(currentAccountDeletionAttemptProvider);
    },
  );
}
