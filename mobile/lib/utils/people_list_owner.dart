// ABOUTME: Normalizes public authors at the people-list URL boundary.
// ABOUTME: Shares that route policy without changing profile identifier rules.

import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';

/// Returns a complete lowercase public key for a people-list author.
///
/// Uniform uppercase Bech32 is accepted; mixed case and relative `me` are not.
/// Profile and other identifier policies remain separate.
String? normalizePeopleListOwner(String identifier) {
  final lowercase = identifier.toLowerCase();
  final normalizedInput =
      (lowercase.startsWith('npub1') || lowercase.startsWith('nprofile1')) &&
          identifier == identifier.toUpperCase()
      ? lowercase
      : identifier;
  final String? owner;
  try {
    owner = normalizePublicIdentifier(normalizedInput)?.hexPubkey;
  } on FormatException {
    // Preserve the URL boundary's rejection of non-UTF-8 nprofile relay hints.
    return null;
  }
  return owner != null && NostrKeyUtils.isValidKey(owner)
      ? owner.toLowerCase()
      : null;
}
