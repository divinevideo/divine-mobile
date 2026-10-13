// MPL-2.0
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatState {
  const ChatState({this.messages = const [], this.reactions = const {}});
  final List<ChatMessage> messages;
  final Map<String, Map<String, int>> reactions;
}

/// Cubit over [ConcordRepository]; reuses the active Divine session's
/// repository (injected), so no new login/keypair flow exists here.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._repo) : super(const ChatState());
  final ConcordRepository _repo;
  void refresh({required int now}) {
    final t = _repo.timeline(now: now);
    emit(ChatState(messages: t.messages, reactions: t.reactions));
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

  Future<void> acceptInvite(String communityId) =>
      _repo.acceptInvite(communityId);
}
