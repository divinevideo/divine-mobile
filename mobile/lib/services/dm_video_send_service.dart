// ABOUTME: Orchestrates sending an encrypted video as a NIP-17 kind 15 DM:
// ABOUTME: one step encrypts and uploads the file, the next sends its metadata.

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_preview.dart';
import 'package:openvine/services/dm_video_send_cancellation.dart';
import 'package:openvine/utils/detached_future.dart';

/// Progress stages reported by [DmVideoSendService.uploadVideo] and
/// [DmVideoSendService.publishVideo].
///
/// The stages let the composer show where a send is spending its time without
/// owning the orchestration.
enum DmVideoSendPhase { encrypting, uploading, sending }

/// An encrypted video whose ciphertext is on the media server, ready to be
/// published as a kind 15 file message.
///
/// [fileMetadata] carries the decryption key and nonce, so keep this out of
/// logs and UI state. [toString] leaves them out.
@immutable
class DmVideoUpload {
  /// Creates a [DmVideoUpload].
  const DmVideoUpload({required this.fileUrl, required this.fileMetadata});

  /// Where the ciphertext was uploaded.
  final String fileUrl;

  /// The kind 15 metadata a recipient needs to fetch and decrypt [fileUrl].
  final DmFileMetadata fileMetadata;

  @override
  String toString() => 'DmVideoUpload(fileUrl: $fileUrl)';
}

/// The media server did not accept the encrypted upload.
class DmVideoUploadFailed implements Exception {
  /// Creates a [DmVideoUploadFailed] with a diagnostic [reason].
  const DmVideoUploadFailed(this.reason);

  /// Diagnostic text from the upload result.
  final String reason;

  @override
  String toString() => 'DmVideoUploadFailed: $reason';
}

/// Composes the encrypted-video DM pipeline in two steps: [uploadVideo]
/// encrypts the file and uploads the ciphertext to Blossom, then
/// [publishVideo] sends a NIP-17 kind 15 file message carrying the decryption
/// metadata. A finished upload can be published again without re-uploading.
///
/// The ciphertext temp file produced by [DmVideoEncryption] is deleted after
/// the upload settles, on both the success and failure paths. The key and
/// nonce are never logged here; they travel only inside the gift-wrapped
/// kind 15 metadata.
class DmVideoSendService {
  /// Creates a [DmVideoSendService].
  ///
  /// [encryption] defaults to a real [DmVideoEncryption] and [readPreview] to
  /// [readDmVideoPreview]; both exist so tests can inject fakes.
  DmVideoSendService({
    required DmRepository dmRepository,
    required BlossomUploadService blossom,
    DmVideoEncryption? encryption,
    DmVideoPreviewReader? readPreview,
  }) : _dmRepository = dmRepository,
       _blossom = blossom,
       _encryption = encryption ?? DmVideoEncryption(),
       _readPreview = readPreview ?? readDmVideoPreview;

  final DmRepository _dmRepository;
  final BlossomUploadService _blossom;
  final DmVideoEncryption _encryption;
  final DmVideoPreviewReader _readPreview;

  /// Encrypts [videoFile] and uploads the ciphertext, returning what
  /// [publishVideo] needs to send it.
  ///
  /// [mimeType] is the plaintext MIME type recorded in the metadata.
  /// [blurhash] is the preview the recipient's card draws, and [dimensions]
  /// the size the video displays at. When the caller passes neither, they are
  /// read from [videoFile] while the ciphertext uploads. A preview that cannot
  /// be read is left out rather than failing the upload. No thumbnail is ever
  /// attached: the thumbnail would reuse the GCM nonce, so `thumbnailUrl` is
  /// always `null` and no `thumb` tag is emitted.
  ///
  /// [onPhase], when supplied, is invoked before encryption and before the
  /// upload. It is never invoked for a stage that has not started.
  ///
  /// [onUploadProgress], when supplied, receives the ciphertext upload's
  /// completion fraction (0.0 to 1.0) as Blossom reports it.
  ///
  /// Throws:
  ///
  /// * [DmVideoUploadFailed] if the media server does not accept the upload.
  /// * [DmVideoSendCancelled] if [cancellation] ends the attempt first.
  /// * [DmVideoTooLargeException] if [videoFile] is too large to encrypt.
  @useResult
  Future<DmVideoUpload> uploadVideo({
    required File videoFile,
    required String mimeType,
    String? blurhash,
    String? dimensions,
    void Function(DmVideoSendPhase phase)? onPhase,
    void Function(double fraction)? onUploadProgress,
    DmVideoSendCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    onPhase?.call(DmVideoSendPhase.encrypting);
    final enc = await _encryption.encryptFile(videoFile);
    try {
      cancellation?.throwIfCancelled();
      // Read alongside the upload. Observe errors immediately even if an
      // interrupted upload returns before the preview settles.
      final preview =
          mimeType.startsWith('video/') &&
              blurhash == null &&
              dimensions == null
          ? _readPreview(videoFile)
          : Future.value((blurhash: blurhash, dimensions: dimensions));
      unawaited(
        preview.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      cancellation?.startUpload();
      onPhase?.call(DmVideoSendPhase.uploading);
      final uploading = _blossom.uploadEncryptedFile(
        ciphertextFile: enc.ciphertextFile,
        onProgress: cancellation == null
            ? onUploadProgress
            : (fraction) {
                if (!cancellation.isActive) return;
                cancellation.uploadProgress(fraction);
                onUploadProgress?.call(fraction);
              },
        cancelToken: cancellation?.uploadCancelToken,
        onUploadAttempt: cancellation?.startUploadAttempt,
      );
      final upload = await (cancellation?.waitFor(uploading) ?? uploading);
      cancellation?.throwIfCancelled();
      cancellation?.finishUpload();
      if (!upload.success || upload.videoId == null) {
        throw DmVideoUploadFailed(
          upload.errorMessage ?? 'Encrypted upload failed',
        );
      }

      final fileUrl =
          upload.url ??
          '${BlossomUploadService.defaultBlossomServer}/${upload.videoId}';

      final hints = await (cancellation?.waitFor(preview) ?? preview);
      return DmVideoUpload(
        fileUrl: fileUrl,
        fileMetadata: DmFileMetadata(
          fileType: mimeType,
          encryptionAlgorithm: 'aes-gcm',
          decryptionKey: enc.key,
          decryptionNonce: enc.nonce,
          fileHash: enc.ciphertextHash,
          originalFileHash: enc.plaintextHash,
          fileSize: enc.ciphertextSize,
          dimensions: hints.dimensions,
          blurhash: hints.blurhash,
          // Always null: a thumbnail would reuse the GCM nonce.
          // ignore: avoid_redundant_argument_values
          thumbnailUrl: null,
        ),
      );
    } finally {
      // Detached, never awaited: publication must not wait on file I/O.
      // Deletion stays best-effort and can never mask the upload result.
      runDetached(
        _deleteCiphertextQuietly(enc.ciphertextFile),
        'delete the video DM ciphertext file',
        logName: 'DmVideoSendService',
        category: LogCategory.video,
      );
    }
  }

  /// Sends [uploaded] to [recipientPubkey] as a kind 15 file message.
  ///
  /// The same [uploaded] can be published again after a failed publication,
  /// without encrypting or uploading the video again.
  ///
  /// [onPhase], when supplied, is invoked with [DmVideoSendPhase.sending]
  /// once publication starts. From then on [cancellation] can no longer
  /// interrupt the attempt: publication owns its delivery result.
  ///
  /// [extraTags] are forwarded to [DmRepository.sendFileMessage], e.g. the
  /// marker that identifies a Divine camera clip.
  ///
  /// Throws [DmVideoSendCancelled] if [cancellation] ended the attempt before
  /// publication started; nothing is published then.
  @useResult
  Future<NIP17SendResult> publishVideo({
    required String recipientPubkey,
    required DmVideoUpload uploaded,
    List<List<String>> extraTags = const [],
    void Function(DmVideoSendPhase phase)? onPhase,
    DmVideoSendCancellation? cancellation,
  }) async {
    cancellation?.beginPublication();
    onPhase?.call(DmVideoSendPhase.sending);
    return _dmRepository.sendFileMessage(
      recipientPubkey: recipientPubkey,
      fileUrl: uploaded.fileUrl,
      fileMetadata: uploaded.fileMetadata,
      extraTags: extraTags,
    );
  }

  /// Best-effort deletion of the ciphertext temp file.
  ///
  /// A failure to delete must not mask the send result, so filesystem errors
  /// are swallowed.
  Future<void> _deleteCiphertextQuietly(File ciphertextFile) async {
    try {
      await ciphertextFile.delete();
    } on FileSystemException {
      // Best effort: the OS temp dir will reclaim it eventually.
    }
  }
}
