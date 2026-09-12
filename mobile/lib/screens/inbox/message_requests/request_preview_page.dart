// ABOUTME: Page for previewing a message request before accepting/declining.
// ABOUTME: Shows sender profile, message count, and View/Decline actions.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';

/// Request preview page.
///
/// Provides [RequestPreviewCubit] for data loading and
/// [MessageRequestActionsCubit] for the decline action.
class RequestPreviewPage extends ConsumerWidget {
  const RequestPreviewPage({
    required this.conversationId,
    this.participantPubkeys = const [],
    this.subject,
    super.key,
  });

  /// Deterministic conversation ID.
  final String conversationId;

  /// Pubkeys of the other participants (excludes current user).
  ///
  /// When empty (e.g. deep link), pubkeys are loaded from the database for
  /// non-restricted users; a DM-restricted user fails closed instead (#176).
  final List<String> participantPubkeys;
  final String? subject;

  static const routeName = 'requestPreview';
  static const pathPattern = '/inbox/message-requests/:id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';
    final inviteStateStore = ref.watch(collaboratorInviteStateStoreProvider);
    final inviteResponseService = ref.watch(
      collaboratorResponseServiceProvider,
    );
    final confirmationRepository = ref.watch(
      collaboratorConfirmationRepositoryProvider,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          // Re-key on the captured auth-flippable repository, as the actions
          // cubit below already does. `load()` runs once at construction, so
          // without this the preview keeps whichever repository existed at
          // first build. The `identityKnown` repository can read local rows,
          // but the `nostrReady` replacement runs post-auth maintenance and
          // receives newly ingested rows.
          // See .claude/rules/state_management.md ("Bridging Riverpod-provided
          // dependencies into BlocProvider").
          key: ValueKey(dmRepository),
          create: (_) => RequestPreviewCubit(
            dmRepository: dmRepository,
            conversationId: conversationId,
            initialParticipantPubkeys: participantPubkeys,
            // #176 preview gate: both callbacks read live state at load time,
            // mirroring the conversation route guard.
            isDmRestricted: () => ref.read(isDmRestrictedProvider),
            isApprovedRecipient: ref
                .read(officialAccountsServiceProvider)
                .isReadableByProtectedMinor,
          )..load(),
        ),
        BlocProvider(
          // Re-key on the captured auth-flippable repository so the cubit is
          // rebuilt on account switch rather than acting on the previous
          // account's data. See
          // .claude/rules/state_management.md ("Bridging Riverpod-provided
          // dependencies into BlocProvider").
          key: ValueKey(dmRepository),
          create: (_) => MessageRequestActionsCubit(
            dmRepository: dmRepository,
          ),
        ),
        BlocProvider(
          key: ValueKey((
            inviteStateStore,
            inviteResponseService,
            confirmationRepository,
            currentPubkey,
          )),
          create: (_) => CollaboratorInviteActionsCubit(
            stateStore: inviteStateStore,
            responseService: inviteResponseService,
            currentUserPubkey: currentPubkey,
            confirmationRepository: confirmationRepository,
          ),
        ),
      ],
      child: RequestPreviewView(subject: subject),
    );
  }
}
