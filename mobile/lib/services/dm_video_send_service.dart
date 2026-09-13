// ABOUTME: Orchestrates sending an encrypted video as a NIP-17 kind 15 DM.
// ABOUTME: Encrypts the file, uploads the ciphertext, and sends the metadata.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_encryption.dart';

/// Composes the encrypted-video DM pipeline:
/// encrypt the file, upload the ciphertext to Blossom, then send a NIP-17
/// kind 15 file message carrying the decryption metadata.
///
/// The ciphertext temp file produced by [DmVideoEncryption] is deleted after
/// the upload settles, on both the success and failure paths. The key and
/// nonce are never logged here; they travel only inside the gift-wrapped
/// kind 15 metadata.
class DmVideoSendService {
  /// Creates a [DmVideoSendService].
  ///
  /// [encryption] defaults to a real [DmVideoEncryption] and exists so tests
  /// can inject a fake.
  DmVideoSendService({
    required DmRepository dmRepository,
    required BlossomUploadService blossom,
    DmVideoEncryption? encryption,
  }) : _dmRepository = dmRepository,
       _blossom = blossom,
       _encryption = encryption ?? DmVideoEncryption();

  final DmRepository _dmRepository;
  final BlossomUploadService _blossom;
  final DmVideoEncryption _encryption;

  /// Encrypts [videoFile], uploads the ciphertext, and sends it as a kind 15
  /// file message to [recipientPubkey].
  ///
  /// [mimeType] is the plaintext MIME type recorded in the metadata.
  /// [blurhash] and [dimensions] are optional display hints. No thumbnail is
  /// ever attached: the thumbnail would reuse the GCM nonce, so
  /// `thumbnailUrl` is always `null` and no `thumb` tag is emitted.
  ///
  /// Returns an upload failure result if the encryption upload does not
  /// succeed, without calling [DmRepository.sendFileMessage].
  @useResult
  Future<NIP17SendResult> sendVideo({
    required String recipientPubkey,
    required File videoFile,
    required String mimeType,
    String? blurhash,
    String? dimensions,
  }) async {
    final enc = await _encryption.encryptFile(videoFile);
    try {
      final upload = await _blossom.uploadEncryptedFile(
        ciphertextFile: enc.ciphertextFile,
      );
      if (!upload.success || upload.videoId == null) {
        return NIP17SendResult.failure(
          upload.errorMessage ?? 'Encrypted upload failed',
        );
      }

      final fileUrl =
          upload.url ??
          '${BlossomUploadService.defaultBlossomServer}/${upload.videoId}';

      return await _dmRepository.sendFileMessage(
        recipientPubkey: recipientPubkey,
        fileUrl: fileUrl,
        fileMetadata: DmFileMetadata(
          fileType: mimeType,
          encryptionAlgorithm: 'aes-gcm',
          decryptionKey: enc.key,
          decryptionNonce: enc.nonce,
          fileHash: enc.ciphertextHash,
          originalFileHash: enc.plaintextHash,
          fileSize: enc.ciphertextSize,
          dimensions: dimensions,
          blurhash: blurhash,
          // Always null: a thumbnail would reuse the GCM nonce.
          // ignore: avoid_redundant_argument_values
          thumbnailUrl: null,
        ),
      );
    } finally {
      await _deleteCiphertextQuietly(enc.ciphertextFile);
    }
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
