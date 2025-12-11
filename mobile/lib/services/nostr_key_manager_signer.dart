// ABOUTME: NostrSigner implementation that bridges NostrKeyManager to NostrClient
// ABOUTME: Provides event signing using NostrKeyManager's key storage

import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/unified_logger.dart';

/// NostrSigner implementation that uses NostrKeyManager for key operations
///
/// This bridges the gap between NostrClient's signer requirement and
/// NostrKeyManager's key management. Used when creating NostrClient
/// from the factory with a NostrKeyManager.
class NostrKeyManagerSigner implements NostrSigner {
  /// Creates a NostrKeyManagerSigner with the given key manager
  NostrKeyManagerSigner(this._keyManager);

  final NostrKeyManager _keyManager;

  @override
  Future<String?> getPublicKey() async {
    return _keyManager.publicKey;
  }

  @override
  Future<Event?> signEvent(Event event) async {
    try {
      final privateKey = _keyManager.privateKey;
      if (privateKey == null) {
        Log.error(
          'Cannot sign event: no private key available',
          name: 'NostrKeyManagerSigner',
          category: LogCategory.relay,
        );
        return null;
      }
      event.sign(privateKey);
      return event;
    } on Exception catch (e) {
      Log.error(
        'Failed to sign event: $e',
        name: 'NostrKeyManagerSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<Map?> getRelays() async {
    // KeyManager doesn't manage relay preferences
    return null;
  }

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async {
    try {
      final privateKey = _keyManager.privateKey;
      if (privateKey == null) {
        Log.error(
          'Cannot encrypt: no private key available',
          name: 'NostrKeyManagerSigner',
          category: LogCategory.relay,
        );
        return null;
      }
      final agreement = NIP04.getAgreement(privateKey);
      return NIP04.encrypt(plaintext, agreement, pubkey);
    } on Exception catch (e) {
      Log.error(
        'NIP-04 encryption failed: $e',
        name: 'NostrKeyManagerSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async {
    try {
      final privateKey = _keyManager.privateKey;
      if (privateKey == null) {
        Log.error(
          'Cannot decrypt: no private key available',
          name: 'NostrKeyManagerSigner',
          category: LogCategory.relay,
        );
        return null;
      }
      final agreement = NIP04.getAgreement(privateKey);
      return NIP04.decrypt(ciphertext, agreement, pubkey);
    } on Exception catch (e) {
      Log.error(
        'NIP-04 decryption failed: $e',
        name: 'NostrKeyManagerSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    try {
      final privateKey = _keyManager.privateKey;
      if (privateKey == null) {
        Log.error(
          'Cannot encrypt: no private key available',
          name: 'NostrKeyManagerSigner',
          category: LogCategory.relay,
        );
        return null;
      }
      final conversationKey = NIP44V2.shareSecret(privateKey, pubkey);
      return NIP44V2.encrypt(plaintext, conversationKey);
    } on Exception catch (e) {
      Log.error(
        'NIP-44 encryption failed: $e',
        name: 'NostrKeyManagerSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    try {
      final privateKey = _keyManager.privateKey;
      if (privateKey == null) {
        Log.error(
          'Cannot decrypt: no private key available',
          name: 'NostrKeyManagerSigner',
          category: LogCategory.relay,
        );
        return null;
      }
      final sealKey = NIP44V2.shareSecret(privateKey, pubkey);
      return NIP44V2.decrypt(ciphertext, sealKey);
    } on Exception catch (e) {
      Log.error(
        'NIP-44 decryption failed: $e',
        name: 'NostrKeyManagerSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  void close() {
    // Key manager is managed externally, not disposed here
  }
}
