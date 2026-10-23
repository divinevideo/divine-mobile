// ABOUTME: AES-GCM file encryption/decryption for NIP-17 Kind 15 file messages.
// ABOUTME: Encrypts files client-side before upload and decrypts after download.

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Metadata produced by encrypting a file for a Kind 15 message.
class EncryptedFileResult {
  const EncryptedFileResult({
    required this.ciphertext,
    required this.key,
    required this.nonce,
  });

  /// The encrypted file bytes (ciphertext + GCM authentication tag).
  final Uint8List ciphertext;

  /// The AES-256 key used for encryption (32 bytes, hex-encoded for tags).
  final String key;

  /// The GCM nonce/IV used for encryption (12 bytes, hex-encoded for tags).
  final String nonce;
}

/// AES-GCM file encryption for NIP-17 Kind 15 file messages.
///
/// Files are encrypted with AES-256-GCM before upload. The decryption key
/// and nonce are included in the Kind 15 event tags (which are themselves
/// encrypted via NIP-59 gift wrapping).
///
/// Flow:
/// 1. Sender: [encrypt] plaintext → upload ciphertext → Kind 15 event
/// 2. Receiver: download ciphertext → [decrypt] → plaintext
class FileEncryption {
  FileEncryption({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  final AesGcm _algorithm;

  /// Encrypts file bytes with AES-256-GCM.
  ///
  /// Generates a random 256-bit key and 96-bit nonce.
  /// Returns the ciphertext and the key/nonce as hex strings
  /// (for inclusion in Kind 15 event tags).
  Future<EncryptedFileResult> encrypt(Uint8List plaintext) async {
    final secretKey = await _algorithm.newSecretKey();
    final nonce = _algorithm.newNonce();

    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Combine ciphertext + MAC (GCM tag) into a single blob for upload.
    // The MAC is appended by the cryptography package in secretBox.
    final ciphertextWithMac = Uint8List.fromList(
      secretBox.cipherText + secretBox.mac.bytes,
    );

    final keyBytes = await secretKey.extractBytes();

    return EncryptedFileResult(
      ciphertext: ciphertextWithMac,
      key: _bytesToHex(Uint8List.fromList(keyBytes)),
      nonce: _bytesToHex(Uint8List.fromList(nonce)),
    );
  }

  /// Decrypts file bytes with AES-256-GCM.
  ///
  /// [ciphertext] is the encrypted blob (ciphertext + 16-byte GCM tag).
  /// [hexKey] is the 32-byte key as a hex string (from `decryption-key` tag).
  /// [hexNonce] is the 12-byte nonce as a hex string (from `decryption-nonce` tag).
  ///
  /// Throws [SecretBoxAuthenticationError] if the ciphertext has been tampered
  /// with or the key/nonce are incorrect, and an [ArgumentError] if the key or
  /// nonce is not hex of the right size or the ciphertext is shorter than its
  /// tag. No error quotes the key or nonce.
  Future<Uint8List> decrypt({
    required Uint8List ciphertext,
    required String hexKey,
    required String hexNonce,
  }) async {
    final keyBytes = _hexToBytes(hexKey);
    final nonceBytes = _hexToBytes(hexNonce);

    if (keyBytes.length != 32) {
      throw ArgumentError('hexKey must be 32 bytes (64 hex digits)');
    }
    if (nonceBytes.length != 12) {
      throw ArgumentError('hexNonce must be 12 bytes (24 hex digits)');
    }

    // Split ciphertext into body + 16-byte GCM authentication tag, as views:
    // a received video can be 100 MB, and a copy of each part doubles that.
    const macLength = 16;
    if (ciphertext.length < macLength) {
      throw ArgumentError.value(
        ciphertext.length,
        'ciphertext.length',
        'too short to contain GCM tag',
      );
    }

    final body = Uint8List.sublistView(
      ciphertext,
      0,
      ciphertext.length - macLength,
    );
    final mac = Mac(
      Uint8List.sublistView(ciphertext, ciphertext.length - macLength),
    );

    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(body, nonce: nonceBytes, mac: mac);

    final decrypted = await _algorithm.decrypt(secretBox, secretKey: secretKey);

    return decrypted is Uint8List ? decrypted : Uint8List.fromList(decrypted);
  }

  static String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static final RegExp _hexDigits = RegExp(r'^[0-9a-fA-F]*$');

  /// Decodes [hex], which may be a key or a nonce, so no error quotes it.
  static Uint8List _hexToBytes(String hex) {
    if (hex.length.isOdd || !_hexDigits.hasMatch(hex)) {
      throw ArgumentError('hex must be an even number of hex digits');
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
