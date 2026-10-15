// ABOUTME: Visible, per-thread read, dismissal, and local removal controls.
// ABOUTME: Shares the same repository-backed actions as the inbox list.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';

/// Actions for one person's conversation, available without accepting a request.
class ConversationTriageBar extends ConsumerWidget {
  const ConversationTriageBar({
    required this.conversationId,
    this.showRemove = true,
    this.participantPubkeys = const [],
    super.key,
  });

  final String conversationId;
  final bool showRemove;
  final List<String> participantPubkeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(dmRepositoryProvider);
    final blocklist = ref.watch(contentBlocklistRepositoryProvider);
    final owner = ref.watch(authServiceProvider).currentPublicKeyHex ?? '';
    return BlocProvider(
      key: ValueKey((conversationId, repository, blocklist, owner)),
      create: (_) => ConversationActionsCubit(
        dmRepository: repository,
        contentBlocklistRepository: blocklist,
        currentUserPubkey: owner,
      ),
      child: _TriageActions(
        conversationId: conversationId,
        showRemove: showRemove,
        participantPubkeys: participantPubkeys,
      ),
    );
  }
}

class _TriageActions extends StatelessWidget {
  const _TriageActions({
    required this.conversationId,
    required this.showRemove,
    required this.participantPubkeys,
  });

  final String conversationId;
  final bool showRemove;
  final List<String> participantPubkeys;

  @override
  Widget build(BuildContext context) {
    final processing = context.select(
      (ConversationActionsCubit cubit) =>
          cubit.state.status == ConversationActionsStatus.processing,
    );
    final cubit = context.read<ConversationActionsCubit>();
    final canDismiss =
        participantPubkeys.isNotEmpty &&
        !cubit.isThreadProtected(participantPubkeys);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          DivineButton(
            label: context.l10n.inboxThreadMarkRead,
            type: DivineButtonType.secondary,
            size: DivineButtonSize.small,
            leadingIcon: DivineIconName.checks,
            onPressed: processing
                ? null
                : () async {
                    final success = await cubit.markAsRead(conversationId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      DivineSnackbarContainer.snackBar(
                        success
                            ? context.l10n.inboxThreadMarkedRead
                            : context.l10n.commonSomethingWentWrong,
                        error: !success,
                      ),
                    );
                  },
          ),
          if (canDismiss)
            DivineButton(
              label: context.l10n.inboxRequestDismiss,
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              onPressed: processing
                  ? null
                  : () async {
                      final success = await cubit.setDismissed(
                        conversationId,
                        dismissed: true,
                      );
                      if (!context.mounted) return;
                      if (success) {
                        context.safePop(fallback: InboxPage.path);
                      } else {
                        _showError(context);
                      }
                    },
            ),
          if (showRemove && canDismiss)
            DivineButton(
              label: context.l10n.inboxRemoveConfirmConfirm,
              type: DivineButtonType.link,
              size: DivineButtonSize.small,
              onPressed: processing ? null : () => _remove(context, cubit),
            ),
        ],
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    ConversationActionsCubit cubit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.inboxRemoveConfirmTitle),
        content: Text(
          participantPubkeys.length > 1
              ? context.l10n.inboxRemoveConfirmBodyGroup
              : context.l10n.inboxRemoveConfirmBodyVanishedAccount,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.inboxRemoveConfirmConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted || cubit.isClosed) return;
    final result = await cubit.removeConversation(conversationId);
    if (!context.mounted) return;
    switch (result) {
      case RemoveConversationOutcome.removed:
        context.safePop(fallback: InboxPage.path);
      case RemoveConversationOutcome.refused:
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.messageRequestModerationNoticeCannotBeRemoved,
          ),
        );
      case RemoveConversationOutcome.failed:
        _showError(context);
    }
  }

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.commonSomethingWentWrong,
        error: true,
      ),
    );
  }
}
