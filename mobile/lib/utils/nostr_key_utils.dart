// ABOUTME: Utility functions for Nostr key encoding and masking
// ABOUTME: Centralized functions for encoding pubkeys to npub format and masking keys for display

import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nip19/nip19.dart';

/// Utility class for Nostr key operations
class NostrKeyUtils {
  NostrKeyUtils._(); // Private constructor to prevent instantiation

  /// Encode a hex public key to npub format (bech32 encoded)
  ///
  /// Wraps Nip19.encodePubKey for consistent usage across the codebase
  static String encodePubKey(String hexPubkey) {
    return Nip19.encodePubKey(hexPubkey);
  }

  /// Decode a bech32 encoded key (npub, nsec, nprofile, etc.) to hex format
  ///
  /// Wraps Nip19.decode for consistent usage across the codebase
  static String decode(String bech32Key) {
    return Nip19.decode(bech32Key);
  }

  /// Check if a key is a valid 32-byte hexadecimal string
  ///
  /// Wraps keyIsValid from nostr_sdk for consistent usage across the codebase
  static bool isValidKey(String key) {
    return keyIsValid(key);
  }

  /// Mask a key for display purposes (show first 8 and last 4 characters)
  ///
  /// Useful for logging and UI display where full keys should not be shown
  static String maskKey(String key) {
    if (key.length < 12) return key;
    final start = key.substring(0, 8);
    final end = key.substring(key.length - 4);
    return '$start...$end';
  }

  /// Check if nsec is valid by attempting to decode it
  ///
  /// Returns true if the nsec can be successfully decoded, false otherwise
  static bool isValidNsec(String nsec) {
    try {
      Nip19.decode(nsec);
      return true;
    } catch (_) {
      return false;
    }
  }
}
