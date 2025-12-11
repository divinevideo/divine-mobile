// ABOUTME: NostrSigner implementation that bridges AuthService's SecureKeyContainer
// ABOUTME: Provides secure event signing and encryption using the auth service's keys

import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/unified_logger.dart';

/// NostrSigner implementation that uses SecureKeyContainer from AuthService
///
/// This bridges the gap between NostrClient's signer requirement and
/// AuthService's secure key management. All cryptographic operations
/// are performed through the SecureKeyContainer's secure access methods.
class AuthServiceSigner implements NostrSigner {
  /// Creates an AuthServiceSigner with the given secure key container
  AuthServiceSigner(this._keyContainer);

  final SecureKeyContainer _keyContainer;

  @override
  Future<String?> getPublicKey() async {
    return _keyContainer.publicKeyHex;
  }

  @override
  Future<Event?> signEvent(Event event) async {
    try {
      return _keyContainer.withPrivateKey<Event>((privateKeyHex) {
        event.sign(privateKeyHex);
        return event;
      });
    } on Exception catch (e) {
      Log.error(
        'Failed to sign event: $e',
        name: 'AuthServiceSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<Map?> getRelays() async {
    // AuthService doesn't manage relay preferences
    return null;
  }

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async {
    try {
      return _keyContainer.withPrivateKey<String?>((privateKeyHex) {
        final agreement = NIP04.getAgreement(privateKeyHex);
        return NIP04.encrypt(plaintext, agreement, pubkey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-04 encryption failed: $e',
        name: 'AuthServiceSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async {
    try {
      return _keyContainer.withPrivateKey<String?>((privateKeyHex) {
        final agreement = NIP04.getAgreement(privateKeyHex);
        return NIP04.decrypt(ciphertext, agreement, pubkey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-04 decryption failed: $e',
        name: 'AuthServiceSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    try {
      return _keyContainer.withPrivateKey<Future<String?>>(
        (privateKeyHex) async {
          final conversationKey = NIP44V2.shareSecret(privateKeyHex, pubkey);
          return NIP44V2.encrypt(plaintext, conversationKey);
        },
      );
    } on Exception catch (e) {
      Log.error(
        'NIP-44 encryption failed: $e',
        name: 'AuthServiceSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    try {
      return _keyContainer.withPrivateKey<Future<String?>>(
        (privateKeyHex) async {
          final sealKey = NIP44V2.shareSecret(privateKeyHex, pubkey);
          return NIP44V2.decrypt(ciphertext, sealKey);
        },
      );
    } on Exception catch (e) {
      Log.error(
        'NIP-44 decryption failed: $e',
        name: 'AuthServiceSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  void close() {
    // Key container is managed by AuthService, not disposed here
  }
}
