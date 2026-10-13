// MPL-2.0
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatCommunity {
  const ChatCommunity(this.id, this.name, this.channels);
  final String id;
  final String name;
  final List<String> channels;
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.reactions = const {},
    this.communities = const [
      ChatCommunity('community-test', 'Divine test community', [
        'general',
        'introductions',
      ]),
    ],
    this.selectedCommunityId = 'community-test',
    this.selectedChannelId = 'general',
    this.threadRootId,
    this.acceptedInvite = false,
  });
  final List<ChatMessage> messages;
  final Map<String, Map<String, int>> reactions;
  final List<ChatCommunity> communities;
  final String selectedCommunityId;
  final String selectedChannelId;
  final String? threadRootId;
  final bool acceptedInvite;

  ChatState copyWith({
    List<ChatMessage>? messages,
    Map<String, Map<String, int>>? reactions,
    String? selectedCommunityId,
    String? selectedChannelId,
    String? threadRootId,
    bool clearThread = false,
    bool? acceptedInvite,
  }) => ChatState(
    messages: messages ?? this.messages,
    reactions: reactions ?? this.reactions,
    communities: communities,
    selectedCommunityId: selectedCommunityId ?? this.selectedCommunityId,
    selectedChannelId: selectedChannelId ?? this.selectedChannelId,
    threadRootId: clearThread ? null : (threadRootId ?? this.threadRootId),
    acceptedInvite: acceptedInvite ?? this.acceptedInvite,
  );
}

/// Cubit over [ConcordRepository]; reuses the active Divine session's
/// repository (injected), so no new login/keypair flow exists here.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._repo) : super(const ChatState());
  final ConcordRepository _repo;
  void refresh({required int now}) {
    final t = _repo.timeline(now: now);
    emit(state.copyWith(messages: t.messages, reactions: t.reactions));
  }

  void selectChannel(String communityId, String channelId) {
    emit(
      state.copyWith(
        selectedCommunityId: communityId,
        selectedChannelId: channelId,
        clearThread: true,
      ),
    );
  }

  void openThread(String rootId) => emit(state.copyWith(threadRootId: rootId));
  void closeThread() => emit(state.copyWith(clearThread: true));

  Future<void> react({
    required String targetId,
    required String emoji,
    required int now,
  }) async {
    _repo.ingestControl(
      ControlEvent(
        type: ControlType.reaction,
        targetId: targetId,
        createdAt: now,
        emoji: emoji,
      ),
    );
    refresh(now: now);
  }

  List<ChatMessage> visibleMessages() {
    final root = state.threadRootId;
    if (root == null) return state.messages;
    return state.messages
        .where((m) => m.id == root || m.threadRootId == root)
        .toList();
  }

  Future<void> send({
    required String communityId,
    required String channelId,
    required String author,
    required String body,
    required int now,
  }) async {
    await _repo.send(
      communityId: communityId,
      channelId: channelId,
      author: author,
      body: body,
      createdAt: now,
    );
    refresh(now: now);
  }

  Future<void> acceptInvite(String communityId) async {
    await _repo.acceptInvite(communityId);
    emit(state.copyWith(acceptedInvite: true));
  }
}
