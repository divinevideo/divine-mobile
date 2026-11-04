// ABOUTME: Domain model for a decrypted NIP-17 direct message.
// ABOUTME: Supports both Kind 14 (text) and Kind 15 (file) messages.

import 'package:equatable/equatable.dart';
import 'package:models/src/dm_shared_video_ref.dart';

/// Delivery state of an own-message "Delete for everyone" request.
enum DmRetractionStatus {
  /// No deletion is in progress.
  none,

  /// Delivery has not yet been confirmed for every recipient.
  pending,

  /// Delivery was refused for at least one recipient, or its automatic
  /// retries ran out without every recipient confirming it (#10012). Either
  /// way the sender can try again.
  failed,
}

/// A decrypted NIP-17 direct message.
///
/// Represents a single message in a conversation after the three-layer
/// gift-wrap decryption (kind 1059 → kind 13 → kind 14/15).
///
/// For text messages (kind 14), [content] holds the plaintext.
/// For file messages (kind 15), [content] holds the encrypted file URL
/// and file metadata is in the [fileMetadata] field.
class DmMessage extends Equatable {
  const DmMessage({
    required this.id,
    required this.conversationId,
    required this.senderPubkey,
    required this.content,
    required this.createdAt,
    required this.giftWrapId,
    this.messageKind = 14,
    this.replyToId,
    this.subject,
    this.tags = const [],
    this.fileMetadata,
    this.sharedVideoRef,
    this.sendBatchId,
    this.retractionStatus = DmRetractionStatus.none,
  });

  /// The rumor event ID (kind 14 or 15).
  final String id;

  /// Deterministic conversation ID (SHA-256 of sorted participant pubkeys).
  final String conversationId;

  /// Sender's public key.
  final String senderPubkey;

  /// For kind 14: decrypted plaintext content.
  /// For kind 15: the encrypted file URL.
  final String content;

  /// Message creation timestamp (Unix seconds).
  final int createdAt;

  /// The gift-wrap event ID (kind 1059) used for deduplication.
  final String giftWrapId;

  /// The inner event kind (14 = text, 15 = file).
  final int messageKind;

  /// Optional parent message ID for threaded replies.
  final String? replyToId;

  /// Optional conversation subject/title.
  final String? subject;

  /// Tags from the decrypted NIP-17 rumor event.
  final List<List<String>> tags;

  /// File metadata for kind 15 messages. Null for kind 14.
  final DmFileMetadata? fileMetadata;

  /// Structured reference to a video event cited via a NIP-18 `q` tag, or via
  /// divine-web's legacy `r` + `a` share tags (#6224).
  ///
  /// Non-null when this message shares a video (e.g. a reel shared into the
  /// DM); lets the UI render a deterministic video card. Null for ordinary
  /// messages and for shares that carry only a URL and no event identity.
  final DmSharedVideoRef? sharedVideoRef;

  /// Durable, collision-proof id of the send invocation. Non-null for the
  /// sender's own persisted 1:1 message and for the single message representing
  /// a group fan-out. A self-wrap received on another device preserves it;
  /// peer-authored and legacy messages leave it null. The conversation state
  /// additionally uses a group message's value to collapse its per-recipient
  /// bubbles and aggregate their delivery status.
  final String? sendBatchId;

  /// Delivery state for this sender-authored message's retraction.
  ///
  /// Pending and failed retractions remain recognizable in the sender's
  /// thread with subdued styling and a compact status affordance. Only a
  /// retraction confirmed for every recipient disappears (#8201).
  final DmRetractionStatus retractionStatus;

  /// Whether this is a file message (kind 15).
  bool get isFileMessage => messageKind == 15;

  /// Whether this message carries a structured shared-video reference.
  bool get hasSharedVideo => sharedVideoRef != null;

  /// Whether the sender marked this message sensitive: a NIP-36
  /// `content-warning` tag, with or without a reason, or a NIP-32 `l` label
  /// in the `content-warning` namespace. An `L` tag alone only names the
  /// namespace and labels nothing.
  bool get isMarkedSensitive => tags.any(
    (tag) =>
        (tag.isNotEmpty && tag.first == _contentWarning) ||
        (tag.length >= 3 && tag.first == 'l' && tag[2] == _contentWarning),
  );

  static const _contentWarning = 'content-warning';

  /// The name of the tag a private answer to a question sticker carries:
  /// `["divine:question", <question>, <video event id>]`.
  static const String questionTagName = 'divine:question';

  List<String>? get _questionTag => tags
      .where((tag) => tag.length >= 2 && tag.first == questionTagName)
      .firstOrNull;

  /// The question this message answers, when it is a private answer to a
  /// question sticker on a video; `null` for any other message.
  String? get answeredQuestion {
    final question = _questionTag?[1].trim();
    return question == null || question.isEmpty ? null : question;
  }

  /// The event id of the video whose question sticker this message answers,
  /// when it names one.
  String? get answeredVideoId => _questionTag?.elementAtOrNull(2);

  /// Whether this message was sent by the given pubkey.
  bool isSentBy(String pubkey) => senderPubkey == pubkey;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderPubkey,
    content,
    createdAt,
    giftWrapId,
    messageKind,
    replyToId,
    subject,
    tags,
    fileMetadata,
    sharedVideoRef,
    sendBatchId,
    retractionStatus,
  ];
}

/// Metadata for a Kind 15 encrypted file message.
///
/// Contains the decryption parameters and file information needed to
/// download, decrypt, and display an encrypted file attachment.
class DmFileMetadata extends Equatable {
  const DmFileMetadata({
    required this.fileType,
    required this.encryptionAlgorithm,
    required this.decryptionKey,
    required this.decryptionNonce,
    required this.fileHash,
    this.originalFileHash,
    this.fileSize,
    this.dimensions,
    this.blurhash,
    this.thumbnailUrl,
  });

  /// MIME type of the file before encryption (e.g. `image/jpeg`).
  final String fileType;

  /// Encryption algorithm used (e.g. `aes-gcm`).
  final String encryptionAlgorithm;

  /// Hex-encoded AES key for decryption.
  final String decryptionKey;

  /// Hex-encoded nonce/IV for decryption.
  final String decryptionNonce;

  /// SHA-256 hex hash of the encrypted file (for integrity verification).
  final String fileHash;

  /// SHA-256 hex hash of the original file before encryption.
  final String? originalFileHash;

  /// Size of the encrypted file in bytes.
  final int? fileSize;

  /// Dimensions in `<width>x<height>` format (for images/video).
  final String? dimensions;

  /// BlurHash string for image preview while loading.
  final String? blurhash;

  /// URL of an encrypted thumbnail (same key/nonce).
  final String? thumbnailUrl;

  /// Whether this is an image file.
  bool get isImage => fileType.startsWith('image/');

  /// Whether this is a video file.
  bool get isVideo => fileType.startsWith('video/');

  /// Whether this is an audio file.
  bool get isAudio => fileType.startsWith('audio/');

  @override
  List<Object?> get props => [
    fileType,
    encryptionAlgorithm,
    decryptionKey,
    decryptionNonce,
    fileHash,
    originalFileHash,
    fileSize,
    dimensions,
    blurhash,
    thumbnailUrl,
  ];
}
