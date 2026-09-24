// ABOUTME: Encrypts DM video files with AES-256-GCM before Blossom upload.
// ABOUTME: Reports separate ciphertext and plaintext hashes for the Kind 15 event.

import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:nostr_sdk/nip17/file_encryption.dart';
import 'package:path_provider/path_provider.dart';

/// Largest plaintext video accepted for an encrypted video DM.
///
/// The whole file is held in memory for AES-GCM on both the send and receive
/// side, so the ceiling bounds peak memory as well as upload cost.
const int dmVideoMaxPlaintextBytes = 100 * 1024 * 1024;

/// Largest ciphertext blob a receiver will download: the plaintext ceiling
/// plus the 16-byte GCM tag appended by [FileEncryption].
const int dmVideoMaxCiphertextBytes = dmVideoMaxPlaintextBytes + 16;

/// Thrown by [DmVideoEncryption.encryptFile] when the file exceeds
/// [dmVideoMaxPlaintextBytes].
class DmVideoTooLargeException implements Exception {
  /// Creates a [DmVideoTooLargeException] for a file of [sizeBytes].
  const DmVideoTooLargeException(this.sizeBytes);

  /// Size of the rejected file in bytes.
  final int sizeBytes;

  @override
  String toString() =>
      'DmVideoTooLargeException: $sizeBytes bytes exceeds '
      '$dmVideoMaxPlaintextBytes';
}

/// Result of encrypting a video file for an encrypted video DM.
///
/// Carries the on-disk ciphertext plus the key/nonce needed by the recipient.
/// The key and nonce must only travel inside the NIP-59 gift-wrapped Kind 15
/// event, never in logs or the public Blossom request.
class EncryptedVideoFile {
  /// Creates an [EncryptedVideoFile].
  const EncryptedVideoFile({
    required this.ciphertextFile,
    required this.key,
    required this.nonce,
    required this.ciphertextHash,
    required this.plaintextHash,
    required this.ciphertextSize,
  });

  /// Temp file containing `ciphertext || GCM tag`.
  final File ciphertextFile;

  /// AES-256 key as a hex string (64 chars).
  final String key;

  /// GCM nonce as a hex string (24 chars).
  final String nonce;

  /// SHA-256 of the ciphertext blob (hex).
  final String ciphertextHash;

  /// SHA-256 of the original plaintext (hex).
  final String plaintextHash;

  /// Size of the ciphertext blob in bytes.
  final int ciphertextSize;
}

/// Encrypts video files for encrypted DMs and decrypts them on receipt.
class DmVideoEncryption {
  /// Creates a [DmVideoEncryption].
  DmVideoEncryption();

  final FileEncryption _fileEncryption = FileEncryption();

  /// Encrypts [plaintextFile] with AES-256-GCM.
  ///
  /// Generates a fresh random 256-bit key and 96-bit nonce for every call and
  /// writes `ciphertext || GCM tag` to a temp file named by its own hash. The
  /// plaintext is never written to disk.
  ///
  /// Throws a [DmVideoTooLargeException] before reading the file when it is
  /// larger than [dmVideoMaxPlaintextBytes].
  Future<EncryptedVideoFile> encryptFile(File plaintextFile) async {
    final size = await plaintextFile.length();
    if (size > dmVideoMaxPlaintextBytes) {
      throw DmVideoTooLargeException(size);
    }
    final plaintext = await plaintextFile.readAsBytes();
    final plaintextHash = HashUtil.sha256Hash(plaintext);

    final result = await _fileEncryption.encrypt(plaintext);
    final ciphertextHash = HashUtil.sha256Hash(result.ciphertext);

    final tempDir = await getTemporaryDirectory();
    final ciphertextFile = File('${tempDir.path}/$ciphertextHash');
    await ciphertextFile.writeAsBytes(result.ciphertext);

    return EncryptedVideoFile(
      ciphertextFile: ciphertextFile,
      key: result.key,
      nonce: result.nonce,
      ciphertextHash: ciphertextHash,
      plaintextHash: plaintextHash,
      ciphertextSize: result.ciphertext.length,
    );
  }

  /// Decrypts a `ciphertext || GCM tag` blob using the sender's key/nonce.
  ///
  /// Throws [SecretBoxAuthenticationError] when the ciphertext, key, or nonce
  /// do not authenticate.
  Future<Uint8List> decryptBytes({
    required Uint8List ciphertext,
    required String key,
    required String nonce,
  }) {
    return _fileEncryption.decrypt(
      ciphertext: ciphertext,
      hexKey: key,
      hexNonce: nonce,
    );
  }
}
