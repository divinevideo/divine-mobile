// ABOUTME: Account-scoped dependency wiring for native Concord POC screens.
// ABOUTME: Reuses the active signer and disposes UI state on account changes.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_mention_providers.dart';
import 'package:openvine/features/chat/chat_mention_repository.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/features/chat/concord_store.dart';
import 'package:openvine/features/chat/room_activity_provider.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
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
  const ChatPage({
    this.communityId,
    this.channelId,
    this.repositoryBuilder,
    super.key,
  });

  final String? communityId;
  final String? channelId;

  /// Test seam: builds an isolated repository the cubit owns, skipping the
  /// shared room session and read tracking.
  final ConcordRepositoryBuilder? repositoryBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentAuthStateProvider);
    final auth = ref.watch(authServiceProvider);
    final pubkey = auth.currentPublicKeyHex;
    final signer = auth.currentIdentity;
    // The route redirect only runs on entry. Watching the same two gates here
    // closes a room that is already open when the flag or the account's
    // messaging restriction changes underneath it.
    final enabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.concordChat),
    );
    final restricted = ref.watch(isDmRestrictedProvider);
    if (!enabled ||
        restricted ||
        !auth.isAuthenticated ||
        pubkey == null ||
        pubkey.isEmpty ||
        signer == null) {
      return RouteErrorScreen(message: context.l10n.routeInvalidConversationId);
    }
    final shared = repositoryBuilder == null
        ? ref.watch(roomActivityRepositoryProvider)
        : null;
    if (repositoryBuilder == null && shared == null) {
      return RouteErrorScreen(message: context.l10n.routeInvalidConversationId);
    }
    final channel = channelId ?? pocChatDefaultChannel;
    // repositoryFor throws for a room outside the catalog and runs before
    // selectChatRoom could reject the URL, so validate the room here.
    if (!const ChatState().communities.any(
          (community) =>
              community.id == (communityId ?? pocChatCommunityId) &&
              community.channels.contains(channel),
        ) ||
        (communityId == null) != (channelId == null)) {
      return RouteErrorScreen(message: context.l10n.routeInvalidConversationId);
    }
    final effectiveChannel = pocChannelIdFor(channel);
    final database = shared == null ? ref.watch(databaseProvider) : null;
    return BlocProvider(
      key: ValueKey((pubkey, signer, communityId, channelId, shared)),
      create: (_) => ChatCubit(
        shared?.repositoryFor(effectiveChannel) ??
            repositoryBuilder!(
              pubkey: pubkey,
              signer: signer,
              store: DriftConcordStore(
                dao: database!.concordStoreDao,
                account: pubkey,
                scope: '$concordRelayUrl/${channelId ?? pocChatDefaultChannel}',
              ),
            ),
        pocStreamForChannel: pocStreamKeyFor,
        sealedAuthor: pubkey,
        channelIdFor: pocChannelIdFor,
        ownsRepository: shared == null,
        initialize: shared == null
            ? null
            : () => shared.ensureStarted(effectiveChannel),
        onRead: shared == null
            ? null
            : (messages) => shared.markRead(effectiveChannel, messages),
        // Read when the room opens, not captured, and again after each
        // enrollment: a source rebuilt meanwhile knows only the rooms it
        // loaded from storage.
        onRoomOpened: (channel) async {
          ChatMentionRepository? enrolled;
          while (context.mounted) {
            final mentions = ref.read(chatMentionRepositoryProvider);
            if (mentions == null || identical(mentions, enrolled)) return;
            await mentions.enroll(channel);
            enrolled = mentions;
          }
        },
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
    if (_valid) unawaited(context.read<ChatCubit>().start());
  }

  @override
  Widget build(BuildContext context) => _valid
      ? const ChatScreen()
      : RouteErrorScreen(message: context.l10n.routeInvalidConversationId);
}
