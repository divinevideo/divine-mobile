import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/live_chat/live_chat_event.dart';
import 'package:openvine/blocs/live_chat/live_chat_state.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/repositories/live_chat_repository.dart';

export 'package:openvine/blocs/live_chat/live_chat_event.dart';
export 'package:openvine/blocs/live_chat/live_chat_state.dart';

class LiveChatBloc extends Bloc<LiveChatEvent, LiveChatState> {
  LiveChatBloc({
    required LiveChatRepository liveChatRepository,
  }) : _liveChatRepository = liveChatRepository,
       super(const LiveChatState()) {
    on<LiveChatStarted>(_onStarted);
    on<LiveChatMessagesUpdated>(_onMessagesUpdated);
    on<LiveChatMessageSendRequested>(
      _onMessageSendRequested,
      transformer: droppable(),
    );
    on<LiveChatSubscriptionFailed>(_onSubscriptionFailed);
  }

  final LiveChatRepository _liveChatRepository;

  StreamSubscription<List<LiveChatMessage>>? _messagesSubscription;

  Future<void> _onStarted(
    LiveChatStarted event,
    Emitter<LiveChatState> emit,
  ) async {
    await _messagesSubscription?.cancel();
    if (isClosed) return;
    final sessionAddress = event.sessionAddress;

    emit(
      state.copyWith(
        status: LiveChatStatus.loading,
        sessionAddress: sessionAddress,
        messages: const <LiveChatMessage>[],
        isSending: false,
        clearError: true,
      ),
    );

    _messagesSubscription = _liveChatRepository
        .watchChatMessages(sessionAddress: sessionAddress)
        .listen(
          (messages) => addIfOpen(
            LiveChatMessagesUpdated(
              sessionAddress: sessionAddress,
              messages: messages,
            ),
          ),
          onError: (Object error, StackTrace _) {
            addIfOpen(
              LiveChatSubscriptionFailed(
                sessionAddress: sessionAddress,
                error: error,
              ),
            );
          },
        );
  }

  void _onMessagesUpdated(
    LiveChatMessagesUpdated event,
    Emitter<LiveChatState> emit,
  ) {
    if (event.sessionAddress != state.sessionAddress) {
      return;
    }

    emit(
      state.copyWith(
        status: LiveChatStatus.ready,
        messages: event.messages,
        isSending: false,
        clearError: true,
      ),
    );
  }

  Future<void> _onMessageSendRequested(
    LiveChatMessageSendRequested event,
    Emitter<LiveChatState> emit,
  ) async {
    final sessionAddress = state.sessionAddress;
    final trimmedContent = event.content.trim();
    if (sessionAddress == null || trimmedContent.isEmpty) {
      return;
    }

    emit(
      state.copyWith(
        isSending: true,
        clearError: true,
      ),
    );

    try {
      final publishedMessage = await _liveChatRepository.publishMessage(
        sessionAddress: sessionAddress,
        content: trimmedContent,
      );
      final nextMessages = publishedMessage == null
          ? state.messages
          : _mergedMessages(state.messages, publishedMessage);
      emit(
        state.copyWith(
          status: LiveChatStatus.ready,
          messages: nextMessages,
          isSending: false,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          isSending: false,
          error: LiveChatError.sendFailed,
        ),
      );
    }
  }

  void _onSubscriptionFailed(
    LiveChatSubscriptionFailed event,
    Emitter<LiveChatState> emit,
  ) {
    if (event.sessionAddress != state.sessionAddress) {
      return;
    }

    addError(event.error);
    emit(
      state.copyWith(
        status: LiveChatStatus.failure,
        isSending: false,
        error: LiveChatError.loadFailed,
      ),
    );
  }

  @override
  Future<void> close() async {
    // Close event dispatch before awaiting cancellation, so a restart cannot
    // install a new subscription while teardown is waiting on the old one.
    final closing = super.close();
    await _messagesSubscription?.cancel();
    return closing;
  }

  List<LiveChatMessage> _mergedMessages(
    List<LiveChatMessage> existingMessages,
    LiveChatMessage nextMessage,
  ) {
    final byId = <String, LiveChatMessage>{
      for (final message in existingMessages) message.id: message,
      nextMessage.id: nextMessage,
    };
    final merged = byId.values.toList(growable: false)
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return merged;
  }
}
