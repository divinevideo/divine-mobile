// ABOUTME: Outgoing video DM models: an entry's phase, failure and progress,
// ABOUTME: and how a send request ended, shared by the outbox, bloc and UI.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/dm_video_encryption.dart';

/// Size limit for a picked video, in whole megabytes, for display copy.
const int videoDmMaxMegabytes = dmVideoMaxPlaintextBytes ~/ (1024 * 1024);

/// Where an [OutgoingVideoDm] is in its send.
enum OutgoingVideoDmPhase {
  /// Waiting for the sends ahead of it.
  queued,

  /// A library clip's C2PA credential is being checked.
  checking,

  /// The plaintext file is being encrypted for upload.
  encrypting,

  /// The ciphertext is being uploaded to Blossom.
  uploading,

  /// The kind 15 file message is being published to relays.
  publishing,

  /// The recipient gift wrap reached a relay.
  sent,

  /// The send ended without delivering; see [OutgoingVideoDm.failure].
  failed,
}

/// Why an [OutgoingVideoDm] ended [OutgoingVideoDmPhase.failed].
enum OutgoingVideoDmFailure {
  /// The file exceeds [dmVideoMaxPlaintextBytes]; nothing was uploaded.
  tooLarge,

  /// A library clip failed its C2PA camera-capture check and is not an
  /// archived Vine, so it was not sent.
  clipNotVerified,

  /// The send did not complete. Retrying redoes the whole pipeline.
  failed,
}

/// How a finished send request ended.
enum VideoDmOutcomeStatus {
  /// Everything in the request went out.
  sent,

  /// The file was too large to send.
  tooLarge,

  /// A library clip failed its C2PA camera-capture check.
  clipNotVerified,

  /// The send did not complete.
  failed,
}

/// One outgoing video DM, from the moment it is requested until its message
/// row is on screen or it is removed.
class OutgoingVideoDm extends Equatable {
  /// Creates an [OutgoingVideoDm].
  const OutgoingVideoDm({
    required this.id,
    required this.conversationId,
    required this.recipientPubkey,
    required this.localPath,
    required this.requestedAt,
    this.clip,
    this.batchId,
    this.frame,
    this.phase = OutgoingVideoDmPhase.queued,
    this.uploadProgress,
    this.failure,
    this.rumorEventId,
  });

  /// Local id, stable for the entry's life.
  final String id;

  /// The conversation the video is sent in.
  final String conversationId;

  /// Hex public key of the recipient.
  final String recipientPubkey;

  /// The picked or library file being sent.
  final String localPath;

  /// The library clip being sent; null for a gallery video.
  final DivineVideoClip? clip;

  /// Shared by the clips of one multi-clip pick; null for a single video.
  final String? batchId;

  /// When the send was requested.
  final DateTime requestedAt;

  /// JPEG bytes of the card frame; null until read, or if it cannot be.
  final Uint8List? frame;

  /// Where the send is.
  final OutgoingVideoDmPhase phase;

  /// Upload completion fraction (0.0 to 1.0); set only while uploading.
  final double? uploadProgress;

  /// Why the send failed; set only when [phase] is failed.
  final OutgoingVideoDmFailure? failure;

  /// The id of the sent message's row; set when [phase] is sent.
  final String? rumorEventId;

  /// Whether retrying could succeed: a too-large file or a rejected clip
  /// would fail again the same way.
  bool get canRetry =>
      phase == OutgoingVideoDmPhase.failed &&
      failure == OutgoingVideoDmFailure.failed;

  /// Returns a copy with the given fields replaced. Nullable fields take a
  /// getter so they can be cleared: `uploadProgress: () => null`.
  OutgoingVideoDm copyWith({
    OutgoingVideoDmPhase? phase,
    Uint8List? Function()? frame,
    double? Function()? uploadProgress,
    OutgoingVideoDmFailure? Function()? failure,
    String? Function()? rumorEventId,
  }) => OutgoingVideoDm(
    id: id,
    conversationId: conversationId,
    recipientPubkey: recipientPubkey,
    localPath: localPath,
    clip: clip,
    batchId: batchId,
    requestedAt: requestedAt,
    frame: frame != null ? frame() : this.frame,
    phase: phase ?? this.phase,
    uploadProgress: uploadProgress != null
        ? uploadProgress()
        : this.uploadProgress,
    failure: failure != null ? failure() : this.failure,
    rumorEventId: rumorEventId != null ? rumorEventId() : this.rumorEventId,
  );

  @override
  List<Object?> get props => [
    id,
    conversationId,
    recipientPubkey,
    localPath,
    clip,
    batchId,
    requestedAt,
    frame,
    phase,
    uploadProgress,
    failure,
    rumorEventId,
  ];
}

/// How one send request (a single video, or a whole clip batch) ended.
class VideoDmSendOutcome extends Equatable {
  /// Creates a [VideoDmSendOutcome].
  const VideoDmSendOutcome({
    required this.status,
    required this.sentCount,
    required this.total,
  });

  /// The terminal status: [VideoDmOutcomeStatus.sent] when everything went
  /// out.
  final VideoDmOutcomeStatus status;

  /// How many videos were delivered before the request ended.
  final int sentCount;

  /// How many videos the request held.
  final int total;

  /// Whether some, but not all, videos went out.
  bool get isPartial => sentCount > 0 && sentCount < total;

  @override
  List<Object?> get props => [status, sentCount, total];
}
