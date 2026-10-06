import 'package:equatable/equatable.dart';
import 'package:openvine/models/live/live_chat_message.dart';

sealed class LiveChatEvent extends Equatable {
  const LiveChatEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LiveChatStarted extends LiveChatEvent {
  const LiveChatStarted({required this.sessionAddress});

  final String sessionAddress;

  @override
  List<Object?> get props => <Object?>[sessionAddress];
}

class LiveChatMessageSendRequested extends LiveChatEvent {
  const LiveChatMessageSendRequested(this.content);

  final String content;

  @override
  List<Object?> get props => <Object?>[content];
}

class LiveChatMessagesUpdated extends LiveChatEvent {
  const LiveChatMessagesUpdated({
    required this.sessionAddress,
    required this.messages,
  });

  final String sessionAddress;
  final List<LiveChatMessage> messages;

  @override
  List<Object?> get props => <Object?>[sessionAddress, messages];
}

class LiveChatSubscriptionFailed extends LiveChatEvent {
  const LiveChatSubscriptionFailed({
    required this.sessionAddress,
    required this.error,
  });

  final String sessionAddress;
  final Object error;

  @override
  List<Object?> get props => <Object?>[sessionAddress, error];
}
