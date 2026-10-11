import 'package:equatable/equatable.dart';
import 'package:openvine/models/live/live_chat_message.dart';

enum LiveChatStatus { initial, loading, ready, failure }

enum LiveChatError { loadFailed, sendFailed }

class LiveChatState extends Equatable {
  const LiveChatState({
    this.status = LiveChatStatus.initial,
    this.sessionAddress,
    this.messages = const <LiveChatMessage>[],
    this.isSending = false,
    this.error,
  });

  final LiveChatStatus status;
  final String? sessionAddress;
  final List<LiveChatMessage> messages;
  final bool isSending;
  final LiveChatError? error;

  LiveChatState copyWith({
    LiveChatStatus? status,
    String? sessionAddress,
    bool clearSessionAddress = false,
    List<LiveChatMessage>? messages,
    bool? isSending,
    LiveChatError? error,
    bool clearError = false,
  }) {
    return LiveChatState(
      status: status ?? this.status,
      sessionAddress: clearSessionAddress
          ? null
          : (sessionAddress ?? this.sessionAddress),
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    sessionAddress,
    messages,
    isSending,
    error,
  ];
}
