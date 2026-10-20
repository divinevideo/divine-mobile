/// Builds a shareable profile URL from a full NIP-05 identifier and npub.
///
/// Callers must verify the identifier before passing it. Display-only handles
/// such as `@username` do not contain enough information to build a URL.
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
