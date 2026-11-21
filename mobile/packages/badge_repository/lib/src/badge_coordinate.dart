// ABOUTME: Badge definition addressing — coordinate parsing, naddr encoding,
// ABOUTME: identifier slugs, and recipient input resolution.

import 'package:meta/meta.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

final RegExp _hexKey = RegExp(r'^[0-9a-f]{64}$');
final RegExp _nonSlugCharacters = RegExp('[^a-z0-9]+');
final RegExp _slugEdgeDashes = RegExp(r'^-+|-+$');
final RegExp _recipientSeparators = RegExp(r'[\s,;]+');

/// The address of a NIP-58 badge definition: `30009:<pubkey>:<identifier>`.
///
/// Badge definitions are addressable events, so awards and profile badge
/// lists reference them by this coordinate rather than by event id.
@immutable
class BadgeCoordinate {
  /// Creates a coordinate from its already-validated parts.
  const BadgeCoordinate({required this.pubkey, required this.identifier});

  /// Parses a raw `30009:<pubkey>:<identifier>` coordinate.
  ///
  /// Returns null for any other kind, a malformed pubkey, or an empty
  /// identifier. Identifiers may themselves contain `:`.
  static BadgeCoordinate? parse(String value) {
    final parts = value.split(':');
    if (parts.length < 3) return null;
    if (int.tryParse(parts[0]) != EventKind.badgeDefinition) return null;

    final pubkey = parts[1];
    final identifier = parts.sublist(2).join(':');
    if (!isBadgePubkey(pubkey) || identifier.isEmpty) return null;
    return BadgeCoordinate(pubkey: pubkey, identifier: identifier);
  }

  /// Decodes a NIP-19 `naddr1…` badge reference.
  ///
  /// Returns null when the reference is not an `naddr`, does not decode, or
  /// addresses a kind other than a badge definition.
  static BadgeCoordinate? fromNaddr(String value) {
    final trimmed = _stripNostrScheme(value);
    if (!NIP19Tlv.isNaddr(trimmed)) return null;

    final decoded = NIP19Tlv.decodeNaddr(trimmed);
    if (decoded == null || decoded.kind != EventKind.badgeDefinition) {
      return null;
    }
    if (!isBadgePubkey(decoded.author) || decoded.id.isEmpty) return null;
    return BadgeCoordinate(pubkey: decoded.author, identifier: decoded.id);
  }

  /// Parses either encoding: an `naddr1…` reference or a raw coordinate.
  static BadgeCoordinate? tryParse(String value) {
    return fromNaddr(value) ?? parse(value);
  }

  /// Pubkey of the badge's issuer, hex encoded.
  final String pubkey;

  /// The definition's `d` tag.
  final String identifier;

  /// The raw coordinate, as it appears in `a` tags.
  String get value => '${EventKind.badgeDefinition}:$pubkey:$identifier';

  /// Encodes this coordinate as a shareable NIP-19 `naddr1…` reference.
  String toNaddr({List<String> relays = const []}) {
    return NIP19Tlv.encodeNaddr(
      Naddr(
        id: identifier,
        author: pubkey,
        kind: EventKind.badgeDefinition,
        relays: relays.isEmpty ? null : relays,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BadgeCoordinate &&
      other.pubkey == pubkey &&
      other.identifier == identifier;

  @override
  int get hashCode => Object.hash(pubkey, identifier);

  @override
  String toString() => value;
}

/// Whether [value] is a hex-encoded Nostr public key.
bool isBadgePubkey(String value) => _hexKey.hasMatch(value);

/// Derives a badge identifier (the `d` tag) from a display [name].
///
/// Matches the web badge client so a badge created on either surface lands
/// on the same coordinate: lowercase, non-alphanumerics collapsed to a
/// single dash, no leading or trailing dash. Returns an empty string when
/// [name] carries no alphanumerics at all.
String deriveBadgeIdentifier(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(_nonSlugCharacters, '-')
    .replaceAll(_slugEdgeDashes, '');

/// Resolves one recipient token to a hex pubkey, or null when it is not a key.
///
/// Accepts hex keys, `npub1…`, and `nprofile1…`, each with an optional
/// `nostr:` scheme prefix.
String? badgeRecipientPubkey(String value) {
  final trimmed = _stripNostrScheme(value);
  if (isBadgePubkey(trimmed)) return trimmed;

  if (NIP19Tlv.isNprofile(trimmed)) {
    final decoded = NIP19Tlv.decodeNprofile(trimmed);
    if (decoded == null || !isBadgePubkey(decoded.pubkey)) return null;
    return decoded.pubkey;
  }

  if (Nip19.isPubkey(trimmed)) {
    final decoded = Nip19.decode(trimmed);
    return isBadgePubkey(decoded) ? decoded : null;
  }

  return null;
}

/// Resolves a free-text recipient field into unique hex pubkeys.
///
/// Tokens are separated by whitespace, commas, or semicolons; tokens that do
/// not resolve to a key are dropped, and order of first appearance is kept.
List<String> parseBadgeRecipients(String value) {
  final pubkeys = <String>{};
  for (final token in value.split(_recipientSeparators)) {
    final pubkey = badgeRecipientPubkey(token);
    if (pubkey != null) pubkeys.add(pubkey);
  }
  return List<String>.unmodifiable(pubkeys);
}

String _stripNostrScheme(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('nostr:')) return trimmed;
  return trimmed.substring('nostr:'.length).trim();
}
