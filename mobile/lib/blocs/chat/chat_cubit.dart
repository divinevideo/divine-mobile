// MPL-2.0
import 'dart:async';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/mention_resolution_service.dart';

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
    this.sending = false,
    this.loading = false,
    this.sendFailed = false,
    this.loadFailed = false,
    this.pendingIds = const [],
  });
  final List<ChatMessage> messages;
  final Map<String, Map<String, int>> reactions;
  final List<ChatCommunity> communities;
  final String selectedCommunityId;
  final String selectedChannelId;
  final String? threadRootId;
  final bool sending;
  final bool loading;
  final bool sendFailed;
  final bool loadFailed;
  final List<String> pendingIds;

  ChatState copyWith({
    List<ChatMessage>? messages,
    Map<String, Map<String, int>>? reactions,
    String? selectedCommunityId,
    String? selectedChannelId,
    String? threadRootId,
    bool clearThread = false,
    bool? sending,
    bool? loading,
    bool? sendFailed,
    bool? loadFailed,
    List<String>? pendingIds,
  }) => ChatState(
    messages: messages ?? this.messages,
    reactions: reactions ?? this.reactions,
    communities: communities,
    selectedCommunityId: selectedCommunityId ?? this.selectedCommunityId,
    selectedChannelId: selectedChannelId ?? this.selectedChannelId,
    threadRootId: clearThread ? null : (threadRootId ?? this.threadRootId),
    sending: sending ?? this.sending,
    loading: loading ?? this.loading,
    sendFailed: sendFailed ?? this.sendFailed,
    loadFailed: loadFailed ?? this.loadFailed,
    pendingIds: pendingIds ?? this.pendingIds,
  );
}

/// Cubit over [ConcordRepository]; reuses the active Divine session's
/// repository (injected), so no new login/keypair flow exists here.
class ChatCubit extends Cubit<ChatState> with CloseGuardedEmit<ChatState> {
  ChatCubit(
    this._repo, {
    this.pocStreamForChannel,
    this.sealedAuthor = '',
    this.channelIdFor,
    this.ownsRepository = false,
    this.mentionResolutionServiceOf,
  }) : super(ChatState(loading: ownsRepository));
  final ConcordRepository _repo;
  final String Function(String channel)? channelIdFor;
  final bool ownsRepository;
  final MentionResolutionService? Function()? mentionResolutionServiceOf;
  StreamSubscription<void>? _updates;
  bool _starting = false;

  Future<void> start() async {
    if (_starting || isClosed) return;
    _starting = true;
    emitIfOpen(state.copyWith(loading: true, loadFailed: false));
    _updates ??= _repo.changes.listen(
      (_) {
        refresh(now: DateTime.now().millisecondsSinceEpoch ~/ 1000);
      },
      onError: (Object error, StackTrace stack) {
        addError(error, stack);
        emitIfOpen(state.copyWith(loadFailed: true));
      },
    );
    final stream = pocStreamForChannel?.call(state.selectedChannelId);
    try {
      if (stream == null) throw StateError('missing channel key');
      await _repo.startChannel(
        channelId:
            channelIdFor?.call(state.selectedChannelId) ??
            state.selectedChannelId,
        epoch: 0,
        streamSeedHex: stream.seedHex,
        streamPubkey: stream.pubkey,
      );
      refresh(now: DateTime.now().millisecondsSinceEpoch ~/ 1000);
    } on Object catch (error, stack) {
      addError(error, stack);
      emitIfOpen(state.copyWith(loadFailed: true));
    } finally {
      _starting = false;
      emitIfOpen(state.copyWith(loading: false));
    }
  }

  @override
  Future<void> close() async {
    await _updates?.cancel();
    if (ownsRepository) await _repo.close();
    return super.close();
  }

  /// Signed-in pubkey used as sealed rumor author (session identity).
  final String sealedAuthor;

  /// Resolves only the public POC stream key. Real membership is not supported.
  final GroupKey Function(String channelId)? pocStreamForChannel;
  void refresh({required int now}) {
    final t = _repo.timeline(now: now);
    final pending = _repo.pendingIds;
    emitIfOpen(
      state.copyWith(
        messages: t.messages,
        reactions: t.reactions,
        pendingIds: pending,
        sendFailed:
            state.sendFailed &&
            !(state.pendingIds.isNotEmpty && pending.isEmpty),
      ),
    );
  }

  void selectChannel(String communityId, String channelId) {
    emitIfOpen(
      state.copyWith(
        selectedCommunityId: communityId,
        selectedChannelId: channelId,
        clearThread: true,
      ),
    );
  }

  void openThread(String rootId) =>
      emitIfOpen(state.copyWith(threadRootId: rootId));
  void closeThread() => emitIfOpen(state.copyWith(clearThread: true));

  List<ChatMessage> visibleMessages() {
    final root = state.threadRootId;
    return state.messages
        .where(
          (m) =>
              m.channelId ==
                  (channelIdFor?.call(state.selectedChannelId) ??
                      state.selectedChannelId) &&
              (root == null || m.id == root || m.threadRootId == root),
        )
        .toList();
  }

  /// Returns whether the composer text was accepted into the durable outbox.
  Future<bool> send({
    required String communityId,
    required String channelId,
    required String author,
    required String body,
    required int nowMilliseconds,
    List<MentionBinding> selectedMentions = const [],
  }) async {
    if (state.sending || state.loading || state.loadFailed || isClosed) {
      return false;
    }
    final before = _repo.pendingIds.toSet();
    final now = nowMilliseconds ~/ 1000;
    emitIfOpen(state.copyWith(sending: true, sendFailed: false));
    try {
      var preparedBody = body.trim();
      if (selectedMentions.isNotEmpty) {
        final resolver = mentionResolutionServiceOf?.call();
        if (resolver == null) {
          throw StateError('Mention resolution unavailable');
        }
        preparedBody = (await resolver.resolveTextMentions(
          rawText: body,
          selectedMentions: selectedMentions,
        )).canonicalText.trim();
      }
      if (isClosed) return false;
      final stream = pocStreamForChannel?.call(channelId);
      final effectiveAuthor = author.isNotEmpty ? author : sealedAuthor;
      if (_repo.sealedTransport != null &&
          stream != null &&
          effectiveAuthor.isNotEmpty) {
        await _repo.sendSealedMessage(
          channelId: channelIdFor?.call(channelId) ?? channelId,
          author: effectiveAuthor,
          body: preparedBody,
          createdAt: now,
          ms: nowMilliseconds % 1000,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        );
      } else {
        await _repo.send(
          communityId: communityId,
          channelId: channelId,
          author: author,
          body: preparedBody,
          createdAt: now,
        );
      }
      refresh(now: now);
      return true;
    } on Object catch (error, stack) {
      addError(error, stack);
      emitIfOpen(state.copyWith(sendFailed: true));
    } finally {
      emitIfOpen(state.copyWith(sending: false));
    }
    refresh(now: now);
    return _repo.pendingIds.any((id) => !before.contains(id));
  }

  Future<void> retry(String id) async {
    if (state.sending || state.loading || state.loadFailed || isClosed) return;
    emitIfOpen(state.copyWith(sending: true, sendFailed: false));
    try {
      await _repo.retryPending(messageId: id);
    } on Object catch (error, stack) {
      addError(error, stack);
      emitIfOpen(state.copyWith(sendFailed: true));
    } finally {
      refresh(now: DateTime.now().millisecondsSinceEpoch ~/ 1000);
      emitIfOpen(state.copyWith(sending: false));
    }
  }
}
