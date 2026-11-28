import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/blocs/drafts_library/draft_dm_share_cubit.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/draft_transfer_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/screens/inbox/new_message_sheet.dart';
import 'package:openvine/screens/inbox/widgets/dm_peer_identity.dart';
import 'package:openvine/widgets/email_confirmation/email_confirmation_gate.dart';
import 'package:openvine/widgets/email_confirmation/email_confirmation_share_prompt.dart';
import 'package:path_provider/path_provider.dart';

/// Selects one recipient, confirms what is shared, then opens the chat.
Future<void> showDraftDmShare(
  BuildContext context,
  WidgetRef ref,
  String draftId,
) async {
  if (!ensureEmailConfirmedToMessage(context)) return;

  final auth = ref.read(authServiceProvider);
  final owner = auth.currentPublicKeyHex;
  if (owner == null || ref.read(profileRepositoryProvider) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.libraryDraftShareFailed,
        error: true,
      ),
    );
    return;
  }

  bool owns(NostrSessionReadiness session) =>
      session.pubkey == owner && session.phase != NostrSessionPhase.tearingDown;
  if (!owns(ref.read(nostrSessionProvider))) return;
  var retired = false;
  final session = ref.listenManual(nostrSessionProvider, (_, next) {
    if (!owns(next)) retired = true;
  });

  bool ownsSession() =>
      context.mounted && !retired && auth.currentPublicKeyHex == owner;

  try {
    final selected = await NewMessageSheet.show(
      context,
      currentUserPubkey: owner,
      allowGroups: false,
    );
    if (!context.mounted || !ownsSession() || selected?.length != 1) return;
    final recipient = selected!.single;
    if (pubkeysEqual(owner, recipient.pubkey)) return;

    final name = dmPeerDisplayName(
      context,
      pubkeyHex: recipient.pubkey,
      isVanished: ref.read(profileVanishedProvider(recipient.pubkey)),
      moderation: ref.read(moderationPresentationProvider(recipient.pubkey)),
      profile: recipient,
    );
    final loadDraft = context.read<DraftsLibraryBloc>().loadDraftForShare;
    final sendPolicy = ref.read(dmSendPolicyProvider);
    final outbox = ref.read(videoDmOutboxProvider);
    final conversationId = await VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      enableDrag: false,
      title: Text(context.l10n.libraryDraftShareConfirm(name)),
      body: DraftDmShareConfirmation(draftId: draftId),
      contentWrapper: (sheetContext, child) {
        final route = ModalRoute.of(sheetContext);
        return BlocProvider(
          create: (_) => DraftDmShareCubit(
            senderPubkey: owner,
            recipientPubkey: recipient.pubkey,
            loadDraft: loadDraft,
            exportDraft: (draft) {
              final transfer = ref.read(draftTransferServiceProvider);
              return getTemporaryDirectory().then(
                (directory) =>
                    transfer.exportDraft(draft, temporaryDirectory: directory),
              );
            },
            readCoverBlurhash: (draft) =>
                ref.read(draftTransferServiceProvider).readCoverBlurhash(draft),
            ownsSession: () => route?.isCurrent == true && ownsSession(),
            sendPolicy: sendPolicy,
            isBlocked: (pubkey) => ref
                .read(contentBlocklistRepositoryProvider)
                .isBlocked(pubkey.toLowerCase()),
            outbox: outbox,
          ),
          child: child,
        );
      },
    );

    if (!context.mounted || !ownsSession() || conversationId == null) return;
    unawaited(
      ConversationRouteData(
        id: conversationId,
        $extra: [recipient.pubkey],
      ).push<void>(context),
    );
  } finally {
    session.close();
  }
}

@visibleForTesting
class DraftDmShareConfirmation extends StatelessWidget {
  const DraftDmShareConfirmation({required this.draftId, super.key});

  final String draftId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emailConfirmationRequired = context
        .select<EmailConfirmationCubit?, bool>(
          (cubit) => cubit?.state.isUnconfirmed ?? false,
        );

    return BlocConsumer<DraftDmShareCubit, DraftDmShareState>(
      listener: (context, state) {
        if (state == DraftDmShareState.queued ||
            state == DraftDmShareState.accountChanged) {
          if (ModalRoute.of(context)?.isCurrent != true) return;
          Navigator.of(context).pop(
            state == DraftDmShareState.queued
                ? context.read<DraftDmShareCubit>().conversationId
                : null,
          );
        }
      },
      builder: (context, state) {
        final preparing = state == DraftDmShareState.preparing;
        final error = switch (state) {
          DraftDmShareState.failed => l10n.libraryDraftShareFailed,
          DraftDmShareState.tooLarge => l10n.libraryDraftShareTooLarge,
          DraftDmShareState.blocked when !emailConfirmationRequired =>
            l10n.dmSendBlockedMessage,
          DraftDmShareState.recipientBlockedByUs => l10n.dmBlockedThreadTitle,
          DraftDmShareState.retiredRecipient =>
            l10n.dmSendBlockedRetiredMessage,
          _ => null,
        };
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.libraryDraftShareNotice,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              if (emailConfirmationRequired) ...[
                const SizedBox(height: 12),
                const EmailConfirmationSharePrompt(),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: ColoredBox(
                    color: context.vineColors.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        error,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DivineButton(
                label: preparing
                    ? l10n.dmPendingVideoPreparing
                    : l10n.libraryDraftActionShare,
                isLoading: preparing,
                onPressed: preparing || emailConfirmationRequired
                    ? null
                    : () => unawaited(
                        context.read<DraftDmShareCubit>().send(draftId),
                      ),
              ),
              const SizedBox(height: 8),
              DivineButton(
                label: l10n.commonCancel,
                type: DivineButtonType.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}
