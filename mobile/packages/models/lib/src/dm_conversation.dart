// ABOUTME: Domain model for a DM conversation (chat room).
// ABOUTME: Used by the DM repository and BLoC layers.

import 'package:equatable/equatable.dart';

/// A DM conversation (chat room) as defined by NIP-17.
///
/// The conversation is identified by the sorted set of participant pubkeys.
/// Stores denormalized metadata for efficient list display.
class DmConversation extends Equatable {
  DmConversation({
    required this.id,
    required List<String> participantPubkeys,
    required this.isGroup,
    required this.createdAt,
    this.lastMessageContent,
    this.lastMessageTimestamp,
    this.lastMessageSenderPubkey,
    this.subject,
    this.isRead = true,
    this.isDismissed = false,
    this.currentUserHasSent = false,
    this.dmProtocol,
  }) : participantPubkeys = List.unmodifiable(participantPubkeys);

  /// Deterministic conversation ID (SHA-256 of sorted participant pubkeys).
  final String id;

  /// Unmodifiable sorted list of participant pubkeys.
  final List<String> participantPubkeys;

  /// Whether this is a group conversation (more than 2 participants).
  final bool isGroup;

  /// Unix timestamp when the conversation was first created.
  final int createdAt;

  /// Preview text of the last message.
  final String? lastMessageContent;

  /// Unix timestamp of the last message.
  final int? lastMessageTimestamp;

  /// Pubkey of the last message sender.
  final String? lastMessageSenderPubkey;

  /// Optional conversation title (from `subject` tag).
  final String? subject;

  /// Whether the conversation has been read.
  final bool isRead;

  /// Whether this request has been put aside locally without deleting it.
  final bool isDismissed;

  /// Whether the current user has sent a message in this conversation.
  final bool currentUserHasSent;

  /// The DM protocol used for this conversation: 'nip04' or 'nip17'.
  /// Null when the protocol is unknown.
  final String? dmProtocol;

  /// The most recent timestamp for sorting: last message time, or
  /// conversation creation time if no messages exist.
  int get effectiveTimestamp => lastMessageTimestamp ?? createdAt;

  /// Creates a copy with the given fields replaced.
  ///
  /// To explicitly clear a nullable field, set the corresponding
  /// `clear*` flag to `true`.
  DmConversation copyWith({
    String? id,
    List<String>? participantPubkeys,
    bool? isGroup,
    int? createdAt,
    String? lastMessageContent,
    bool clearLastMessageContent = false,
    int? lastMessageTimestamp,
    bool clearLastMessageTimestamp = false,
    String? lastMessageSenderPubkey,
    bool clearLastMessageSenderPubkey = false,
    String? subject,
    bool clearSubject = false,
    bool? isRead,
    bool? isDismissed,
    bool? currentUserHasSent,
    String? dmProtocol,
    bool clearDmProtocol = false,
  }) {
    return DmConversation(
      id: id ?? this.id,
      participantPubkeys: participantPubkeys ?? this.participantPubkeys,
      isGroup: isGroup ?? this.isGroup,
      createdAt: createdAt ?? this.createdAt,
      lastMessageContent: clearLastMessageContent
          ? null
          : lastMessageContent ?? this.lastMessageContent,
      lastMessageTimestamp: clearLastMessageTimestamp
          ? null
          : lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageSenderPubkey: clearLastMessageSenderPubkey
          ? null
          : lastMessageSenderPubkey ?? this.lastMessageSenderPubkey,
      subject: clearSubject ? null : subject ?? this.subject,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      currentUserHasSent: currentUserHasSent ?? this.currentUserHasSent,
      dmProtocol: clearDmProtocol ? null : dmProtocol ?? this.dmProtocol,
    );
  }

  @override
  List<Object?> get props => [
    id,
    participantPubkeys,
    isGroup,
    createdAt,
    lastMessageContent,
    lastMessageTimestamp,
    lastMessageSenderPubkey,
    subject,
    isRead,
    isDismissed,
    currentUserHasSent,
    dmProtocol,
  ];
}
