import 'package:models/models.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

extension UserProfileUtils on UserProfile {
  /// Get the best available display name
  String get bestDisplayName {
    if (displayName?.isNotEmpty == true) return displayName!;
    if (name?.isNotEmpty == true) return name!;
    // Fallback to truncated npub (e.g., "npub1abc...xyz")
    return truncatedNpub;
  }

  /// Get npub encoding of pubkey
  String get npub {
    try {
      return NostrKeyUtils.encodePubKey(pubkey);
    } catch (e) {
      // Fallback to shortened pubkey if encoding fails
      return shortPubkey;
    }
  }

  /// Get truncated npub for display (e.g., "npub1abc...xyz")
  String get truncatedNpub {
    try {
      final fullNpub = NostrKeyUtils.encodePubKey(pubkey);
      if (fullNpub.length <= 16) return fullNpub;
      // Show first 10 chars + "..." + last 6 chars (npub1abc...xyz format)
      return '${fullNpub.substring(0, 10)}...${fullNpub.substring(fullNpub.length - 6)}';
    } catch (e) {
      // Fallback to shortened hex pubkey if encoding fails
      if (pubkey.length <= 16) return pubkey;
      return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 6)}';
    }
  }
}
