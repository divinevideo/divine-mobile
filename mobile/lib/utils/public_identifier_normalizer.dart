// ABOUTME: Normalizes all public identifier formats to hex pubkey
// ABOUTME: Handles npub, nprofile, hex, and special 'me' identifier universally

import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

/// Normalized result containing hex pubkey and optional relay hints
class NormalizedPublicIdentifier {
  const NormalizedPublicIdentifier({
    required this.hexPubkey,
    this.relayHints = const [],
    this.isCurrentUser = false,
  });

  final String hexPubkey;
  final List<String> relayHints;
  final bool isCurrentUser;
}

/// Normalize any public identifier format to hex pubkey
///
/// Accepts:
/// - 'me' (special identifier for current user - requires currentUserHex)
/// - npub (bech32 encoded pubkey)
/// - nprofile (bech32 encoded pubkey with relay hints)
/// - hex (64-char hex pubkey)
///
/// Returns null if the identifier is invalid or cannot be decoded
NormalizedPublicIdentifier? normalizePublicIdentifier(
  String identifier, {
  String? currentUserHex,
}) {
  if (identifier.isEmpty) return null;

  // Handle special 'me' identifier
  if (identifier == 'me') {
    if (currentUserHex == null || currentUserHex.isEmpty) return null;
    return NormalizedPublicIdentifier(
      hexPubkey: currentUserHex,
      isCurrentUser: true,
    );
  }

  // Try hex format first (most common internally)
  if (NostrKeyUtils.isValidKey(identifier)) {
    // Canonicalize casing: consumers compare this hex against the signed-in
    // pubkey and key providers with it, so an uppercase deep-link segment must
    // not read as a different identity than its lowercase form.
    return NormalizedPublicIdentifier(hexPubkey: identifier.toLowerCase());
  }

  // Try npub format. The decoder returns an empty string for a failed
  // checksum and does not check that the payload is a 32-byte key.
  if (identifier.startsWith('npub1')) {
    final hexKey = NostrKeyUtils.decode(identifier);
    if (!NostrKeyUtils.isValidKey(hexKey)) return null;
    return NormalizedPublicIdentifier(hexPubkey: hexKey);
  }

  // Try nprofile format
  if (identifier.startsWith('nprofile1')) {
    final decoded = NIP19Tlv.decodeNprofile(identifier);
    final pubkey = decoded?.pubkey;
    if (pubkey == null || pubkey.isEmpty || pubkey.length != 64) return null;
    return NormalizedPublicIdentifier(
      hexPubkey: pubkey,
      relayHints: decoded?.relays ?? const [],
    );
  }

  return null;
}

/// Normalize to hex pubkey only (simpler version)
///
/// Returns null if invalid
String? normalizeToHex(String identifier, {String? currentUserHex}) {
  return normalizePublicIdentifier(
    identifier,
    currentUserHex: currentUserHex,
  )?.hexPubkey;
}

/// Returns [identifiers] without values that resolve to [excludedIdentifier].
///
/// Surviving values retain their original representation. Invalid values are
/// preserved so callers can apply their own boundary-validation policy.
Set<String> withoutPublicIdentifier(
  Iterable<String> identifiers,
  String excludedIdentifier,
) {
  final excludedHex = normalizeToHex(excludedIdentifier);
  if (excludedHex == null) return identifiers.toSet();

  return identifiers
      .where((identifier) => normalizeToHex(identifier) != excludedHex)
      .toSet();
}

/// Normalize to npub format
///
/// Returns null if invalid
String? normalizeToNpub(String identifier, {String? currentUserHex}) {
  final normalized = normalizePublicIdentifier(
    identifier,
    currentUserHex: currentUserHex,
  );
  if (normalized == null) return null;

  try {
    return NostrKeyUtils.encodePubKey(normalized.hexPubkey);
  } catch (e) {
    return null;
  }
}
