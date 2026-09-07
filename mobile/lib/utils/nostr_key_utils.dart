// ABOUTME: Utility functions for Nostr key encoding and UI-side shortening
// ABOUTME: Centralized functions for encoding pubkeys to npub format and
// ABOUTME: shortening them for UI display (never for logs — see AGENTS.md)

import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nip19/hrps.dart';
import 'package:nostr_sdk/nip19/nip19.dart';

/// Utility class for Nostr key operations.
///
/// The shortening helpers here are for UI display only. Logs, analytics and
/// debug output carry the full identifier — see the Nostr rule in AGENTS.md
/// and the guard in scripts/check_nostr_id_log_truncation.sh.
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

  /// Whether [nsec] is a bech32 `nsec1…` string carrying a 32-byte key.
  ///
  /// False when the prefix is absent or belongs to another HRP that merely
  /// starts with `nsec`, when the bech32 is malformed, or when the decoded
  /// payload is not a 32-byte hex key.
  static bool isValidNsec(String nsec) =>
      nsec.startsWith('${Hrps.privateKey}1') && isValidKey(Nip19.decode(nsec));

  /// The full npub for [hexPubkey], or the hex itself when it cannot be
  /// encoded.
  ///
  /// For UI that shows a key as an identifier of last resort. Never truncates:
  /// the caller's `maxLines` / `TextOverflow.ellipsis` decides how much fits,
  /// so a copied or read value is always the exact identifier.
  static String npubOrHex(String hexPubkey) {
    try {
      return encodePubKey(hexPubkey);
    } on Exception {
      return hexPubkey;
    }
  }

  /// Create a truncated npub for display (e.g., "npub1abc...xyz")
  ///
  /// Converts a hex pubkey to npub format and truncates for UI display.
  /// Shows first 10 characters + "..." + last 6 characters.
  /// Use this when displaying usernames for users without a Kind 0 profile.
  static String truncateNpub(String hexPubkey) {
    try {
      final fullNpub = encodePubKey(hexPubkey);
      if (fullNpub.length <= 16) return fullNpub;
      return '${fullNpub.substring(0, 10)}...${fullNpub.substring(fullNpub.length - 6)}';
    } catch (e) {
      // Fallback to shortened hex pubkey if encoding fails
      if (hexPubkey.length <= 16) return hexPubkey;
      return '${hexPubkey.substring(0, 8)}...${hexPubkey.substring(hexPubkey.length - 6)}';
    }
  }
}
