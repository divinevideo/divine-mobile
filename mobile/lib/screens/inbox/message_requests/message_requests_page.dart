// ABOUTME: Page for the message requests inbox.
// ABOUTME: Provides MessageRequestActionsCubit and ConversationListBloc
// ABOUTME: for the message requests list view.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_view.dart';

/// Message Requests inbox page.
///
/// Provides [ConversationListBloc] (for the request list) and
/// [MessageRequestActionsCubit] (for bulk actions) to the widget tree.
class MessageRequestsPage extends ConsumerWidget {
  const MessageRequestsPage({super.key});

  static const routeName = 'messageRequests';
  static const String path = RoutePaths.messageRequests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final protectedMinorInboxGate = ref.watch(protectedMinorInboxGateProvider);

    return MultiBlocProvider(
      // Re-key on the captured dependencies' identities so the blocs are
      // rebuilt bound to fresh instances when `dmRepositoryProvider` (keepAlive
      // but rebuilt as the nostr session advances / on account switch) hands
      // over a new DmRepository — otherwise a keyless BlocProvider strands the
      // list on an orphaned repo whose userPubkeyStream never fires and the
      // requests list spins forever. See .claude/rules/state_management.md
      // ("Bridging Riverpod-provided dependencies into BlocProvider").
      key: ValueKey((
        dmRepository,
        followRepository,
        blocklistRepository,
        protectedMinorInboxGate,
      )),
      providers: [
        BlocProvider(
          create: (_) => ConversationListBloc(
            dmRepository: dmRepository,
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
            protectedMinorInboxGate: protectedMinorInboxGate,
            // Same support-row wiring as InboxPage (#6283). Without it this
            // bloc leaves the moderation thread in `requestConversations`
            // while the inbox lifts it into the pinned row — so the same
            // thread is reachable from both surfaces, the inbox's request
            // banner counts one fewer than this page lists, and "mark all
            // read" / "remove all" sweep a conversation the user is not
            // looking at.
            supportRowPubkey: kModerationPubkeyHex,
            moderationAccount: isModerationAccount,
            retiredModerationAccount: isRetiredModerationAccount,
          )..add(const ConversationListStarted()),
        ),
        BlocProvider(
          create: (_) => MessageRequestActionsCubit(dmRepository: dmRepository),
        ),
      ],
      child: const MessageRequestsView(),
    );
  }
}
