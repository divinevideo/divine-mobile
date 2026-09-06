// ABOUTME: View for the message requests inbox list.
// ABOUTME: Shows all pending message requests with bulk actions via "..." menu.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_bulk_actions_sheet.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_tile.dart';
import 'package:openvine/screens/inbox/widgets/restore_paused_banner.dart';

/// View for the message requests inbox.
///
/// Displays a scrollable list of message request conversations with
/// an app bar containing a back button, title, and bulk actions menu.
class MessageRequestsView extends ConsumerWidget {
  const MessageRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: context.l10n.inboxMessageRequestsTitle,
        showBackButton: true,
        onBackPressed: context.pop,
        actions: [
          DiVineAppBarAction(
            icon: SvgIconSource(DivineIconName.dotsThree.assetPath),
            onPressed: () => _showBulkActions(context),
            semanticLabel: context.l10n.profileMoreSemanticLabel,
          ),
        ],
      ),
      body: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VineTheme.bottomSheetBorderRadius),
        ),
        child: ColoredBox(
          color: context.vineColors.surfaceContainerHigh,
          child: _RequestList(currentPubkey: currentPubkey),
        ),
      ),
    );
  }

  Future<void> _showBulkActions(BuildContext context) async {
    final result = await RequestBulkActionsSheet.show(context);
    if (result == null || !context.mounted) return;

    final requests = context
        .read<ConversationListBloc>()
        .state
        .requestConversations;
    final ids = requests.map((c) => c.id).toList();

    if (!context.mounted) return;
    final actionsCubit = context.read<MessageRequestActionsCubit>();

    switch (result) {
      case RequestBulkAction.markAllRead:
        await actionsCubit.markAllRequestsAsRead(ids);
      case RequestBulkAction.removeAll:
        final messenger = ScaffoldMessenger.of(context);
        final withheldText =
            context.l10n.messageRequestModerationNoticeCannotBeRemoved;
        final errorText = context.l10n.commonSomethingWentWrong;
        // Whole list, not ids: the repository decides what "all requests"
        // excludes, so a Divine moderation notice cannot be swept away by a
        // gesture aimed at spam (#6971). Keeping the policy there means every
        // removal caller inherits it.
        final outcome = await actionsCubit.removeAllRequests(requests);
        if (context.mounted) context.pop();
        // Silence reads as a broken button: a list holding nothing but a
        // notice removes nothing and emits nothing, so without this the tap
        // looks like it missed (#8347). The strings and messenger are captured
        // before the await because the pop can retire this context.
        //
        // A failure outranks the withheld notice: the removal is transactional,
        // so a throw left every row in place and naming the notice would blame
        // the guard for a sweep that did nothing.
        if (outcome.failed) {
          messenger.showSnackBar(
            DivineSnackbarContainer.snackBar(errorText, error: true),
          );
        } else if (outcome.withheld) {
          messenger.showSnackBar(
            DivineSnackbarContainer.snackBar(withheldText),
          );
        }
    }
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.currentPubkey});

  final String currentPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationListBloc, ConversationListState>(
      buildWhen: (prev, curr) =>
          prev.requestConversations != curr.requestConversations ||
          prev.requestsWithheld != curr.requestsWithheld ||
          prev.isRestoringHistory != curr.isRestoringHistory ||
          prev.status != curr.status,
      builder: (context, state) {
        if (state.status == ConversationListStatus.initial ||
            state.status == ConversationListStatus.loading) {
          return Center(
            child: CircularProgressIndicator(
              color: context.vineColors.accentPositive,
            ),
          );
        }

        final requests = state.requestConversations;
        if (requests.isEmpty) {
          if (state.requestsWithheld && state.isRestoringHistory) {
            return Center(
              child: Semantics(
                label: context.l10n.inboxRestoringMessages,
                child: CircularProgressIndicator(
                  color: context.vineColors.accentPositive,
                ),
              ),
            );
          }

          if (state.requestsWithheld) {
            return Align(
              alignment: Alignment.topCenter,
              child: RestorePausedBanner(
                onRetry: () => context.read<ConversationListBloc>().add(
                  const ConversationListRestoreRetryRequested(),
                ),
              ),
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                context.l10n.inboxMessageRequestsEmpty,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return RequestTile(
              conversation: request,
              currentUserPubkey: currentPubkey,
              onTap: () => _onRequestTapped(context, request),
            );
          },
        );
      },
    );
  }

  void _onRequestTapped(BuildContext context, DmConversation conversation) {
    final otherPubkeys = dmConversationPeerPubkeys(
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: currentPubkey,
    );

    final extra = conversation.subject == null
        ? otherPubkeys
        : {
            'participantPubkeys': otherPubkeys,
            'subject': conversation.subject,
          };

    context.pushNamed(
      RequestPreviewPage.routeName,
      pathParameters: {'id': conversation.id},
      extra: extra,
    );
  }
}
