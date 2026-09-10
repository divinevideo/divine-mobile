// ABOUTME: BuildContext extensions for common navigation patterns
// ABOUTME: Provides type-safe, reusable navigation helpers

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

/// Extension on BuildContext for common navigation patterns
extension NavExtensions on BuildContext {
  /// Navigate to another user's profile (fullscreen, no bottom nav).
  ///
  /// Converts the hex pubkey to npub format and pushes the fullscreen profile.
  /// Use this for tapping profiles from mentions, search, feeds, etc.
  /// The user can navigate back to the previous screen.
  void pushOtherProfile(String hexPubkey) {
    final npub = NostrKeyUtils.encodePubKey(hexPubkey);
    push(OtherProfileScreen.pathForNpub(npub));
  }

  /// Navigate to another user's profile using go (replaces stack).
  ///
  /// Converts the hex pubkey to npub format and goes to the fullscreen profile.
  /// Use this when you want the profile to become the new root.
  void goOtherProfile(String hexPubkey) {
    final npub = NostrKeyUtils.encodePubKey(hexPubkey);
    go(OtherProfileScreen.pathForNpub(npub));
  }
}
