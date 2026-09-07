// ABOUTME: NostrSigner implementation backed by a local SecureKeyContainer
// ABOUTME: Provides secure event signing and encryption using locally stored keys

import 'dart:typed_data';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:crypto/crypto.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';

const _canonicalPayloadAux =
    '00000000000000000000000000000000'
    '00000000000000000000000000000000';

/// A local signer had the capability to perform an operation, attempted it,
/// and failed.
///
/// This is distinct from a nullable signer result: `null` means the signer
/// does not support the requested capability. Callers that compose local and
/// remote signers may catch this exception to choose an explicit fallback.
class LocalSignerOperationException implements Exception {
  /// Creates a typed local-operation failure while preserving its [cause].
  const LocalSignerOperationException(this.operation, this.cause);

  /// The operation that failed, without any key or payload data.
  final LocalSignerOperation operation;

  /// The original failure.
  final Object cause;

  @override
  String toString() =>
      'LocalSignerOperationException(${operation.name}): ${cause.runtimeType}';
}

/// Operations that a [LocalKeySigner] can attempt and fail.
enum LocalSignerOperation {
  /// Deterministic signature over an arbitrary canonical payload.
  signCanonicalPayload,

  /// Nostr event signing.
  signEvent,

  /// NIP-04 encryption.
  nip04Encrypt,

  /// NIP-04 decryption.
  nip04Decrypt,

  /// NIP-44 encryption.
  nip44Encrypt,

  /// NIP-44 decryption.
  nip44Decrypt,
}

/// NostrSigner implementation backed by a local [SecureKeyContainer].
///
/// Used internally by [LocalNostrIdentity] and [KeycastNostrIdentity]'s
/// local signing optimization. Not used directly by consumers.
class LocalKeySigner implements IsolateDecryptSigner {
  /// Creates a [LocalKeySigner] with the given key container.
  ///
  /// The container is required. "No identity yet" is not this type's job —
  /// that state belongs to [UnauthenticatedSigner], which throws rather
  /// than returning null. Because this signer supports every operation it
  /// exposes, an attempted operation either succeeds or throws
  /// [LocalSignerOperationException]. Unexpected Dart [Error]s propagate so
  /// programming-invariant failures remain visible and reportable.
  LocalKeySigner(this._keyContainer);

  final SecureKeyContainer _keyContainer;

  /// Returns the current public key for creator-bound signing flows.
  Future<String> currentPubkey() async {
    return _keyContainer.publicKeyHex;
  }

  /// Whether this signer can expose its private key bytes to a
  /// [compute()] isolate for batch decryption. True only for local
  /// signers that already keep the key in memory.
  @override
  bool get canDecryptInIsolate => _keyContainer.hasPrivateKey;

  /// Runs [operation] with the raw private key hex. Mirrors
  /// [SecureKeyContainer.withPrivateKey] but scoped to this signer so
  /// callers never need to reach into the container directly.
  @override
  T withPrivateKeyHex<T>(T Function(String hex) operation) {
    return _keyContainer.withPrivateKey(operation);
  }

  @override
  Future<String> getPublicKey() async {
    return _keyContainer.publicKeyHex;
  }

  /// Signs an arbitrary canonical payload by first hashing it with SHA-256.
  ///
  /// Uses deterministic auxiliary data so repeated signing of the same payload
  /// produces the same signature, which keeps creator-binding assertions stable.
  ///
  /// Throws [LocalSignerOperationException] if the signing attempt fails.
  Future<String> signCanonicalPayload(Uint8List payload) async {
    try {
      final digest = sha256.convert(payload).toString();
      return _keyContainer.withPrivateKey<String>((privateKeyHex) {
        return schnorr.sign(privateKeyHex, digest, _canonicalPayloadAux);
      });
    } on LocalSignerOperationException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      _throwOperationFailure(.signCanonicalPayload, error, stackTrace);
    }
  }

  /// Throws [LocalSignerOperationException] if the signing attempt fails.
  @override
  Future<Event> signEvent(Event event) async {
    try {
      return _keyContainer.withPrivateKey<Event>((privateKeyHex) {
        event.sign(privateKeyHex);
        return event;
      });
    } on LocalSignerOperationException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      _throwOperationFailure(.signEvent, error, stackTrace);
    }
  }

  @override
  Future<Map?> getRelays() async => null;

  /// Throws [LocalSignerOperationException] if encryption fails.
  @override
  Future<String> encrypt(String pubkey, String plaintext) async {
    try {
      return _keyContainer.withPrivateKey<String>((privateKeyHex) {
        _validatePeerPubkey(pubkey, operation: .nip04Encrypt);
        final agreement = NIP04.getAgreement(privateKeyHex);
        return NIP04.encrypt(plaintext, agreement, pubkey);
      });
    } on LocalSignerOperationException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      _throwOperationFailure(.nip04Encrypt, error, stackTrace);
    }
  }

  /// Throws [LocalSignerOperationException] if decryption fails.
  @override
  Future<String> decrypt(String pubkey, String ciphertext) async {
    try {
      return _keyContainer.withPrivateKey<String>((privateKeyHex) {
        _validatePeerPubkey(pubkey, operation: .nip04Decrypt);
        final agreement = NIP04.getAgreement(privateKeyHex);
        return NIP04.decrypt(ciphertext, agreement, pubkey);
      });
    } on LocalSignerOperationException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      _throwOperationFailure(.nip04Decrypt, error, stackTrace);
    }
  }

  /// Throws [LocalSignerOperationException] if encryption fails.
  @override
  Future<String> nip44Encrypt(String pubkey, String plaintext) async {
    try {
      // Keep the async cipher outside the private-key scope and await it inside
      // this try so failures retain their typed boundary (#7332).
      final conversationKey = _keyContainer.withPrivateKey<Uint8List>(
        (privateKeyHex) {
          _validatePeerPubkey(pubkey, operation: .nip44Encrypt);
          return NIP44V2.shareSecret(privateKeyHex, pubkey);
        },
      );
      return await NIP44V2.encrypt(plaintext, conversationKey);
    } on LocalSignerOperationException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      _throwOperationFailure(.nip44Encrypt, error, stackTrace);
    }
  }

  /// Throws [LocalSignerOperationException] if decryption fails.
  @override
  Future<String> nip44Decrypt(String pubkey, String ciphertext) async {
    try {
      final sealKey = _keyContainer.withPrivateKey<Uint8List>(
        (privateKeyHex) {
          _validatePeerPubkey(pubkey, operation: .nip44Decrypt);
          return NIP44V2.shareSecret(privateKeyHex, pubkey);
        },
      );
      return await NIP44V2.decrypt(ciphertext, sealKey);
    } on LocalSignerOperationException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      _throwOperationFailure(.nip44Decrypt, error, stackTrace);
    }
  }

  @override
  void close() {
    // Key container is managed by AuthService, not disposed here
  }

  void _validatePeerPubkey(
    String pubkey, {
    required LocalSignerOperation operation,
  }) {
    try {
      if (!keyIsValid(pubkey)) {
        throw const FormatException('Peer public key must be 32-byte hex');
      }
      NIP04.liftX(BigInt.parse(pubkey, radix: 16));
    } on Object catch (error, stackTrace) {
      // This catch is deliberately scoped to peer-key validation. The crypto
      // package exposes an invalid curve point as a raw Dart Error; translate
      // that untrusted-input outcome here without hiding Errors from the
      // signing or cipher operations themselves.
      _throwOperationFailure(operation, error, stackTrace);
    }
  }

  Never _throwOperationFailure(
    LocalSignerOperation operation,
    Object error,
    StackTrace stackTrace,
  ) {
    Log.error(
      'Local signer operation failed',
      name: 'LocalKeySigner',
      category: LogCategory.relay,
      error: error,
      stackTrace: stackTrace,
    );
    Error.throwWithStackTrace(
      LocalSignerOperationException(operation, error),
      stackTrace,
    );
  }
}
