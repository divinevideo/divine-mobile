// ABOUTME: Account-scoped dependency wiring for native Concord POC screens.
// ABOUTME: Reuses the active signer and disposes UI state on account changes.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/blocs/mention_search/mention_search_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/features/chat/concord_session.dart';
import 'package:openvine/features/chat/concord_store.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/services/mention_resolution_service.dart';

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
    this.repositoryBuilder = buildConcordRepository,
    super.key,
  });

  final String? communityId;
  final String? channelId;
  final ConcordRepositoryBuilder repositoryBuilder;

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
    final database = ref.watch(databaseProvider);
    return BlocProvider(
      key: ValueKey((pubkey, signer, communityId, channelId)),
      create: (_) => ChatCubit(
        repositoryBuilder(
          pubkey: pubkey,
          signer: signer,
          store: DriftConcordStore(
            dao: database.concordStoreDao,
            account: pubkey,
            scope: '$concordRelayUrl/${channelId ?? 'general'}',
          ),
        ),
        pocStreamForChannel: pocStreamKeyFor,
        sealedAuthor: pubkey,
        channelIdFor: pocChannelIdFor,
        ownsRepository: true,
        mentionResolutionServiceOf: () {
          final profiles = ref.read(profileRepositoryProvider);
          return profiles == null
              ? null
              : MentionResolutionService(
                  profileRepository: profiles,
                );
        },
      ),
      child: BlocProvider(
        create: (chatContext) => MentionSearchCubit(
          profileRepositoryOf: () => ref.read(profileRepositoryProvider),
          candidatePubkeys: () => [
            ...chatContext.read<ChatCubit>().visibleMessages().map(
              (message) => message.author,
            ),
            ...ref.read(followRepositoryProvider).followingPubkeys,
          ],
        ),
        child: _ChatSelection(communityId: communityId, channelId: channelId),
      ),
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
