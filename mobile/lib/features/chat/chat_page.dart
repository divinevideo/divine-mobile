// ABOUTME: Account-scoped dependency wiring for native Concord POC screens.
// ABOUTME: Reuses the active signer and disposes UI state on account changes.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/router/route_error_screen.dart';

/// Selects only channels present in the current POC catalog.
/// A missing pair opens the default; an incomplete or unknown pair is rejected.
bool selectChatRoom(ChatCubit cubit, {String? communityId, String? channelId}) {
  if (communityId == null && channelId == null) return true;
  if (!cubit.state.communities.any(
    (community) =>
        community.id == communityId && community.channels.contains(channelId),
  )) {
    return false;
  }
  cubit.selectChannel(communityId!, channelId!);
  return true;
}

class ChatPage extends ConsumerWidget {
  const ChatPage({this.communityId, this.channelId, super.key});

  final String? communityId;
  final String? channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentAuthStateProvider);
    final auth = ref.watch(authServiceProvider);
    final pubkey = auth.currentPublicKeyHex;
    final signer = auth.currentIdentity;
    if (pubkey == null || pubkey.isEmpty || signer == null) {
      return RouteErrorScreen(message: context.l10n.routeInvalidConversationId);
    }
    return BlocProvider(
      key: ValueKey((pubkey, signer, communityId, channelId)),
      create: (_) => ChatCubit(
        buildConcordRepository(
          pubkey: pubkey,
          signer: signer,
          streamPubkey: pubkey,
        ),
        pocStreamForChannel: pocStreamKeyFor,
        sealedAuthor: pubkey,
      ),
      child: _ChatSelection(communityId: communityId, channelId: channelId),
    );
  }
}

class _ChatSelection extends StatefulWidget {
  const _ChatSelection({this.communityId, this.channelId});
  final String? communityId;
  final String? channelId;

  @override
  State<_ChatSelection> createState() => _ChatSelectionState();
}

class _ChatSelectionState extends State<_ChatSelection> {
  late final bool _valid;

  @override
  void initState() {
    super.initState();
    _valid = selectChatRoom(
      context.read<ChatCubit>(),
      communityId: widget.communityId,
      channelId: widget.channelId,
    );
  }

  @override
  Widget build(BuildContext context) => _valid
      ? const ChatScreen()
      : RouteErrorScreen(message: context.l10n.routeInvalidConversationId);
}
