import 'package:nostr_sdk/event_kind.dart';

/// Addressable event identifier (NIP-01).
///
/// Addressable events are identified by `kind:pubkey:d-tag` format.
/// Used for parameterized replaceable events (kinds 30000-39999).
class AId {
  /// Creates an addressable event identifier.
  const AId({required this.kind, required this.pubkey, required this.dTag});

  /// The event kind.
  final int kind;

  /// The author's public key.
  final String pubkey;

  /// The d-tag value (may contain colons).
  final String dTag;

  /// Parses an addressable ID from string format `kind:pubkey:d-tag`.
  ///
  /// Handles d-tags that contain colons by joining all parts after the pubkey.
  /// Returns null if the format is invalid (less than 3 parts or invalid kind).
  static AId? fromString(String text) {
    final parts = text.split(':');
    if (parts.length < 3) return null;

    final kind = int.tryParse(parts[0]);
    if (kind == null) return null;

    final pubkey = parts[1];
    // Handle d-tags with colons by joining remaining parts
    final dTag = parts.sublist(2).join(':');

    return AId(kind: kind, pubkey: pubkey, dTag: dTag);
  }

  /// Converts this identifier to string format `kind:pubkey:d-tag`.
  String toAString() => '$kind:$pubkey:$dTag';

  @override
  String toString() => toAString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AId &&
          kind == other.kind &&
          pubkey == other.pubkey &&
          dTag == other.dTag;

  @override
  int get hashCode => Object.hash(kind, pubkey, dTag);
}

/// The `34236:` coordinate Divine wrote for a Kind 34235 [coordinate].
///
/// Until #10776 Divine built every video coordinate under kind 34236, so the
/// likes and reposts it published for a Kind 34235 video, and the rows it
/// stored for them, carry this key. Returns null for any other coordinate.
String? legacyVideoCoordinateFor(String coordinate) {
  final aid = AId.fromString(coordinate);
  if (aid == null || aid.kind != EventKind.videoHorizontal) return null;
  return AId(
    kind: EventKind.videoVertical,
    pubkey: aid.pubkey,
    dTag: aid.dTag,
  ).toAString();
}
