// ABOUTME: Minimal wrapper utilities for Nostr key operations using nostr_sdk
// ABOUTME: Delegates to Nip19 for bech32 encoding/decoding per NIP-19

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as nostr_keys;

/// Exception thrown when encoding/decoding operations fail
class NostrEncodingException implements Exception {
  const NostrEncodingException(this.message);
  final String message;

  @override
  String toString() => 'NostrEncodingException: $message';
}

/// Utility class for Nostr key encoding operations
///
/// This is a thin wrapper around nostr_sdk's Nip19 class that provides:
/// - Type-safe decode functions (throw on wrong type)
/// - Display helpers (maskKey, isValidHexKey)
/// - Consistent error handling with NostrEncodingException
class NostrEncoding {
  /// Encode a hex public key to npub format (bech32)
  ///
  /// Takes a 64-character hex public key and returns npub1... format
  /// Example: npub1xyz...
  static String encodePublicKey(String hexPubkey) {
    if (hexPubkey.length != 64) {
      throw const NostrEncodingException(
        'Public key must be 64 hex characters',
      );
    }

    try {
      return Nip19.encodePubKey(hexPubkey);
    } catch (e) {
      throw NostrEncodingException('Failed to encode public key: $e');
    }
  }

  /// Decode an npub to hex public key
  ///
  /// Takes npub1... format and returns 64-character hex string
  static String decodePublicKey(String npub) {
    if (!npub.startsWith('npub1')) {
      throw const NostrEncodingException(
        'Invalid npub format - must start with npub1',
      );
    }

    try {
      if (!Nip19.isPubkey(npub)) {
        throw const NostrEncodingException('Invalid npub format');
      }

      final hexKey = Nip19.decode(npub);

      if (hexKey.isEmpty || hexKey.length != 64) {
        throw const NostrEncodingException(
          'Decoded public key has invalid length',
        );
      }

      return hexKey;
    } catch (e) {
      if (e is NostrEncodingException) rethrow;
      throw NostrEncodingException('Failed to decode npub: $e');
    }
  }

  /// Encode a hex private key to nsec format (bech32)
  ///
  /// Takes a 64-character hex private key and returns nsec1... format
  /// Example: nsec1xyz...
  static String encodePrivateKey(String hexPrivkey) {
    if (hexPrivkey.length != 64) {
      throw const NostrEncodingException(
        'Private key must be 64 hex characters',
      );
    }

    try {
      return Nip19.encodePrivateKey(hexPrivkey);
    } catch (e) {
      throw NostrEncodingException('Failed to encode private key: $e');
    }
  }

  /// Decode an nsec to hex private key
  ///
  /// Takes nsec1... format and returns 64-character hex string
  static String decodePrivateKey(String nsec) {
    if (!nsec.startsWith('nsec1')) {
      throw const NostrEncodingException(
        'Invalid nsec format - must start with nsec1',
      );
    }

    try {
      if (!Nip19.isPrivateKey(nsec)) {
        throw const NostrEncodingException('Invalid nsec format');
      }

      final hexKey = Nip19.decode(nsec);

      if (hexKey.isEmpty || hexKey.length != 64) {
        throw const NostrEncodingException(
          'Decoded private key has invalid length',
        );
      }

      return hexKey;
    } catch (e) {
      if (e is NostrEncodingException) rethrow;
      throw NostrEncodingException('Failed to decode nsec: $e');
    }
  }

  /// Validate if a string is a valid npub
  static bool isValidNpub(String npub) {
    return Nip19.isPubkey(npub);
  }

  /// Validate if a string is a valid nsec
  static bool isValidNsec(String nsec) {
    return Nip19.isPrivateKey(nsec);
  }

  /// Validate if a string is a valid hex key (32 bytes = 64 hex chars)
  ///
  /// Note: This is a helper not provided by Nip19
  static bool isValidHexKey(String hexKey) {
    if (hexKey.length != 64) return false;

    // Check if all characters are valid hex
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    return hexRegex.hasMatch(hexKey);
  }

  /// Generate a random private key (32 bytes in hex)
  ///
  /// Delegates to nostr_sdk's secure key generation
  static String generatePrivateKey() {
    return nostr_keys.generatePrivateKey();
  }

  /// Derive public key from private key using secp256k1
  ///
  /// Takes a hex private key and returns the corresponding hex public key
  /// Uses nostr_sdk's secure secp256k1 implementation
  static String derivePublicKey(String hexPrivkey) {
    if (!isValidHexKey(hexPrivkey)) {
      throw const NostrEncodingException('Invalid private key format');
    }

    try {
      return nostr_keys.getPublicKey(hexPrivkey.toLowerCase());
    } catch (e) {
      throw NostrEncodingException('Failed to derive public key: $e');
    }
  }

  /// Extract the key type from a bech32 encoded key
  ///
  /// Returns 'npub', 'nsec', or null if invalid
  static String? getKeyType(String bech32Key) {
    try {
      if (Nip19.isPubkey(bech32Key)) return 'npub';
      if (Nip19.isPrivateKey(bech32Key)) return 'nsec';
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mask a key for display purposes (show first 8 and last 4 characters)
  ///
  /// Example: npub1abc...xyz4 or 1234abcd...xyz4
  ///
  /// Note: This is a display helper not provided by Nip19
  static String maskKey(String key) {
    if (key.length < 12) return key;

    final start = key.substring(0, 8);
    final end = key.substring(key.length - 4);
    return '$start...$end';
  }
}
