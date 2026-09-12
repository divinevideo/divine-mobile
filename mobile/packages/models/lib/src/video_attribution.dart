// ABOUTME: Data models for video attribution (collaborators and Inspired By)
// ABOUTME: InspiredByInfo captures NIP-33 'a' tag references to addressable
// ABOUTME: video events (Kind 34236)

import 'package:meta/meta.dart';

/// Information about a video that inspired the current video.
///
/// Captures a NIP-33/NIP-10 `a` tag reference to an addressable event:
/// ```dart
/// ['a', '34236:<pubkey>:<d-tag>', 'wss://relay.divine.video', 'mention']
/// ```
@immutable
class InspiredByInfo {
  /// Creates an [InspiredByInfo] from an addressable event identifier.
  ///
  /// The [addressableId] must be in the format `34236:<pubkey>:<dTag>`.
  const InspiredByInfo({required this.addressableId, this.relayUrl});

  /// Creates an [InspiredByInfo] from its JSON representation.
  factory InspiredByInfo.fromJson(Map<String, dynamic> json) => InspiredByInfo(
    addressableId: json['addressableId'] as String,
    relayUrl: json['relayUrl'] as String?,
  );

  /// The addressable event identifier in format `34236:<pubkey>:<dTag>`.
  final String addressableId;

  /// Optional relay URL hint for fetching the referenced event.
  final String? relayUrl;

  /// The pubkey of the creator whose video inspired this one.
  ///
  /// Extracted from [addressableId] (second segment after splitting by ':').
  String get creatorPubkey {
    final parts = addressableId.split(':');
    return parts.length > 1 ? parts[1] : '';
  }

  /// The `d` tag of the referenced video event.
  ///
  /// Extracted from [addressableId] (third segment after splitting by ':').
  String get dTag {
    final parts = addressableId.split(':');
    return parts.length > 2 ? parts[2] : '';
  }

  /// Serializes this [InspiredByInfo] to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'addressableId': addressableId,
    if (relayUrl != null) 'relayUrl': relayUrl,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InspiredByInfo &&
          runtimeType == other.runtimeType &&
          addressableId == other.addressableId;

  @override
  int get hashCode => addressableId.hashCode;

  @override
  String toString() => 'InspiredByInfo(addressableId: $addressableId)';
}

/// Marker on Divine inspired-by `p` tags.
///
/// Distinct from `'mention'` so the edit flow can own this tag's lifecycle
/// without touching caption-mention p-tags, and from `'collaborator'` so no
/// consumer renders the inspired-by creator as a collaborator.
const inspiredByPTagMarker = 'inspired-by';

/// Marker used on Nostr `a`/`p` tags that carry factual reused-clip credit.
const clipSourceCreditTagMarker = 'clip-source';

/// Factual provenance credit for a clip reused from a published video.
///
/// Unlike [InspiredByInfo], this can represent authorship-only provenance
/// when the source event had no addressable `d` tag.
@immutable
class ClipSourceCredit {
  const ClipSourceCredit({
    required this.authorPubkey,
    this.eventId,
    this.addressableId,
    this.relayUrl,
  });

  factory ClipSourceCredit.fromAddressableId({
    required String addressableId,
    String? relayUrl,
    String? eventId,
  }) => ClipSourceCredit(
    authorPubkey: InspiredByInfo(addressableId: addressableId).creatorPubkey,
    eventId: eventId,
    addressableId: addressableId,
    relayUrl: relayUrl,
  );

  static ClipSourceCredit? tryFromJson(Map<String, dynamic> json) {
    final authorPubkey = json['authorPubkey'];
    if (authorPubkey is! String || authorPubkey.isEmpty) return null;

    return ClipSourceCredit(
      authorPubkey: authorPubkey,
      eventId: _stringOrNull(json['eventId']),
      addressableId: _stringOrNull(json['addressableId']),
      relayUrl: _stringOrNull(json['relayUrl']),
    );
  }

  static List<ClipSourceCredit> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (credit) =>
              ClipSourceCredit.tryFromJson(Map<String, dynamic>.from(credit)),
        )
        .nonNulls
        .toList(growable: false);
  }

  static String? _stringOrNull(Object? value) => value is String ? value : null;

  final String authorPubkey;
  final String? eventId;
  final String? addressableId;
  final String? relayUrl;

  bool get hasAddressableSource =>
      addressableId != null && addressableId!.isNotEmpty;

  InspiredByInfo? get inspiredByInfo => hasAddressableSource
      ? InspiredByInfo(addressableId: addressableId!, relayUrl: relayUrl)
      : null;

  String get identityKey {
    final addressable = addressableId;
    if (addressable != null && addressable.isNotEmpty) {
      return 'a:${addressable.toLowerCase()}';
    }

    final event = eventId;
    if (event != null && event.isNotEmpty) {
      return 'e:${event.toLowerCase()}';
    }

    return 'p:${authorPubkey.toLowerCase()}';
  }

  Map<String, dynamic> toJson() => {
    'authorPubkey': authorPubkey,
    if (eventId != null) 'eventId': eventId,
    if (addressableId != null) 'addressableId': addressableId,
    if (relayUrl != null) 'relayUrl': relayUrl,
  };

  /// Equality follows [identityKey] so provenance lists can dedupe the same
  /// source even when later relay/event hints are richer.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipSourceCredit && identityKey == other.identityKey;

  @override
  int get hashCode => identityKey.hashCode;

  @override
  String toString() =>
      'ClipSourceCredit(authorPubkey: $authorPubkey, '
      'addressableId: $addressableId, eventId: $eventId)';
}
