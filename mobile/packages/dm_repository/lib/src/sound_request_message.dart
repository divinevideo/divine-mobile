// ABOUTME: Versioned sound request and fulfillment metadata in NIP-17 DMs.
// ABOUTME: Validates ownership independently of readable fallback text.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// The application's role in the request flow.
enum SoundRequestMessageKind {
  /// A viewer asks the creator to enable reuse.
  request,

  /// The creator announces the sound is available.
  ready,
}

/// Validated metadata from a one-to-one sound request exchange.
class SoundRequestMessage extends Equatable {
  /// Creates validated message metadata.
  const SoundRequestMessage({
    required this.kind,
    required this.messageId,
    required this.senderPubkey,
    required this.recipientPubkey,
    required this.videoAddress,
    required this.creatorPubkey,
    this.requestId,
    this.audioEventId,
  });

  /// Whether the message requests or fulfills a sound.
  final SoundRequestMessageKind kind;

  /// Full rumor ID of this message.
  final String messageId;

  /// Authenticated message author.
  final String senderPubkey;

  /// Other participant in the one-to-one exchange.
  final String recipientPubkey;

  /// Full source video coordinate.
  final String videoAddress;

  /// Signing owner encoded in the video coordinate.
  final String creatorPubkey;

  /// Original request rumor ID on a fulfillment reply.
  final String? requestId;

  /// Published sound event ID on a fulfillment reply.
  final String? audioEventId;
  @override
  List<Object?> get props => [
    kind,
    messageId,
    senderPubkey,
    recipientPubkey,
    videoAddress,
    creatorPubkey,
    requestId,
    audioEventId,
  ];
}

/// Returns the signing owner of a supported source coordinate.
String? soundRequestCreator(String address) {
  final parts = address.split(':');
  if (parts.length < 3 ||
      !['34236', '34235'].contains(parts[0]) ||
      !NostrHexUtils.isValidPubkey(parts[1]) ||
      parts.sublist(2).join(':').isEmpty) {
    return null;
  }
  return parts[1];
}

/// Builds versioned application tags for a sound request.
List<List<String>> soundRequestTags({
  required String videoAddress,
  String relayHint = '',
}) => [
  ['divine', 'sound-request', '1'],
  ['a', videoAddress, relayHint, 'root'],
];

/// Builds a reply with distinct request and audio references.
List<List<String>> soundReadyTags({
  required String videoAddress,
  required String requestId,
  required String audioEventId,
  String relayHint = '',
  String audioRelayHint = '',
}) => [
  ['divine', 'sound-ready', '1'],
  ['a', videoAddress, relayHint, 'root'],
  ['e', requestId, '', 'reply'],
  ['e', audioEventId, audioRelayHint, 'audio'],
];

/// Validates participant topology and creator ownership of application tags.
SoundRequestMessage? parseSoundRequestMessage(
  DmMessage message, {
  required String ownerPubkey,
  required bool isGroup,
}) {
  if (isGroup ||
      message.messageKind != 14 ||
      !NostrHexUtils.isValidPubkey(ownerPubkey) ||
      !NostrHexUtils.isValidPubkey(message.senderPubkey) ||
      !NostrHexUtils.isValidEventId(message.id)) {
    return null;
  }
  final tags = message.tags;
  final markers = tags.where((t) => t.isNotEmpty && t[0] == 'divine').toList();
  if (markers.length != 1 ||
      markers.single.length != 3 ||
      markers.single[2] != '1') {
    return null;
  }
  final kind = switch (markers.single[1]) {
    'sound-request' => SoundRequestMessageKind.request,
    'sound-ready' => SoundRequestMessageKind.ready,
    _ => null,
  };
  if (kind == null) {
    return null;
  }
  final addresses = tags.where((t) => t.isNotEmpty && t[0] == 'a').toList();
  if (addresses.length != 1 ||
      addresses.single.length != 4 ||
      addresses.single[3] != 'root') {
    return null;
  }
  final address = addresses.single[1];
  final creator = soundRequestCreator(address);
  if (creator == null) {
    return null;
  }
  final recipients = tags
      .where((t) => t.length >= 2 && t[0] == 'p')
      .map((t) => t[1])
      .where((p) => p != message.senderPubkey)
      .toSet();
  if (recipients.length != 1 ||
      !NostrHexUtils.isValidPubkey(recipients.single)) {
    return null;
  }
  final recipient = recipients.single;
  final pair = [recipient, message.senderPubkey]..sort();
  final conversation = sha256.convert(utf8.encode(pair.join(':'))).toString();
  if (!pair.contains(ownerPubkey) || message.conversationId != conversation) {
    return null;
  }
  String? requestId;
  String? audioId;
  if (kind == SoundRequestMessageKind.request) {
    if (recipient != creator || message.senderPubkey == creator) {
      return null;
    }
  } else {
    if (message.senderPubkey != creator) {
      return null;
    }
    final references = tags.where((t) => t.isNotEmpty && t[0] == 'e').toList();
    final replies = references
        .where((t) => t.length == 4 && t[3] == 'reply')
        .toList();
    final sounds = references
        .where((t) => t.length == 4 && t[3] == 'audio')
        .toList();
    if (replies.length != 1 || sounds.length != 1 || references.length != 2) {
      return null;
    }
    requestId = replies.single[1];
    audioId = sounds.single[1];
    if (!NostrHexUtils.isValidEventId(requestId) ||
        !NostrHexUtils.isValidEventId(audioId)) {
      return null;
    }
  }
  return SoundRequestMessage(
    kind: kind,
    messageId: message.id,
    senderPubkey: message.senderPubkey,
    recipientPubkey: recipient,
    videoAddress: address,
    creatorPubkey: creator,
    requestId: requestId,
    audioEventId: audioId,
  );
}
