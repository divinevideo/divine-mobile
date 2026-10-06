import 'package:equatable/equatable.dart';
import 'package:openvine/models/live/live_chat_message.dart';

enum LiveChatStatus { initial, loading, ready, failure }

class LiveChatState extends Equatable {
  const LiveChatState({
    this.status = LiveChatStatus.initial,
    this.sessionAddress,
    this.messages = const <LiveChatMessage>[],
    this.isSending = false,
    this.errorMessage,
  });

  final LiveChatStatus status;
  final String? sessionAddress;
  final List<LiveChatMessage> messages;
  final bool isSending;
  final String? errorMessage;

  LiveChatState copyWith({
    LiveChatStatus? status,
    String? sessionAddress,
    bool clearSessionAddress = false,
    List<LiveChatMessage>? messages,
    bool? isSending,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return LiveChatState(
      status: status ?? this.status,
      sessionAddress: clearSessionAddress
          ? null
          : (sessionAddress ?? this.sessionAddress),
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    sessionAddress,
    messages,
    isSending,
    errorMessage,
  ];
}
