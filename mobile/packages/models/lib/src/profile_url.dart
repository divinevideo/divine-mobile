/// Builds a shareable profile URL from a verified NIP-05 and an npub.
///
/// Pass `UserProfile.displayNip05` (`@alice.divine.video`), not the raw
/// claim: legacy `alice@divine.video` and `alice@openvine.co` claims carry
/// their subdomain only in that normalized form. The short `@alice` handle
/// has no domain at all.
///
/// Returns the Divine subdomain URL, or the npub profile URL as a fallback.
String buildProfileUrl(String? nip05, String npub) {
  if (nip05 != null && nip05.isNotEmpty) {
    // NIP-05 format: `_@username.divine.video` or `user@domain.com`
    final atIndex = nip05.indexOf('@');
    if (atIndex != -1) {
      final domain = nip05.substring(atIndex + 1);
      if (domain.endsWith('.divine.video')) {
        return 'https://$domain';
      }
    }
  }
  return 'https://divine.video/profile/$npub';
}
