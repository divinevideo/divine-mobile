// ABOUTME: Parsed `/video/:id` route reference shared by every video route.
// ABOUTME: Decodes hex ids, NIP-19 note/nevent/naddr and raw coordinates.

import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// A `/video/:id` route reference, decoded into the identifiers the data
/// layer can actually address a video by.
///
/// The same identifier space serves the detail route and its engagement
/// sub-routes, and a shared link may carry any of the accepted forms: a
/// 64-character hex event id, a NIP-19 `note1` / `nevent1` / `naddr1`, a raw
/// NIP-33 `kind:pubkey:d-tag` coordinate, or a first-party stable id. Callers
/// must decode before querying, because the first-party API resolves a hex id
/// or a d-tag but 404s on a bech32 string.
class VideoRouteRef {
  /// Creates a reference from already-decoded identifiers.
  const VideoRouteRef({
    this.eventId,
    this.addressableId,
    this.addressablePubkey,
    this.stableId,
  });

  /// The 64-character hex event id, when the reference names a concrete event.
  ///
  /// Null for an `naddr1` or a raw coordinate: an addressable event is
  /// identified by its coordinate, and any one version's id is incidental.
  final String? eventId;

  /// The NIP-33 `kind:pubkey:d-tag` coordinate, when the reference is
  /// addressable.
  final String? addressableId;

  /// The author of [addressableId], when the reference is addressable.
  final String? addressablePubkey;

  /// The first-party stable id — the video's `d` tag.
  ///
  /// The first-party API resolves this like an event id, which is what makes
  /// an `naddr1` addressable without a prior coordinate lookup.
  final String? stableId;

  /// Decodes a raw `/video/:id` path segment, or null when it is empty.
  ///
  /// Accepts a hex event id, a NIP-19 `note1` / `nevent1` / `naddr1`, a raw
  /// NIP-33 coordinate, or a first-party stable id, and returns null for a
  /// bech32 string that does not decode.
  static VideoRouteRef? parse(String routeId) {
    final trimmed = routeId.trim();
    if (trimmed.isEmpty) return null;

    if (NostrHexUtils.isValidEventId(trimmed)) {
      return VideoRouteRef(
        eventId: trimmed.toLowerCase(),
        stableId: trimmed,
      );
    }

    if (Nip19.isNoteId(trimmed)) {
      final eventId = Nip19.decode(trimmed);
      return eventId.isEmpty ? null : VideoRouteRef(eventId: eventId);
    }

    if (NIP19Tlv.isNevent(trimmed)) {
      // decodeNevent runs its TLV loop outside any try/catch, unlike
      // decodeNaddr. A string whose bech32 checksum is valid but whose TLV
      // payload is malformed reaches getInt32 on a short kind entry or
      // utf8.decode on invalid bytes, and throws. This parse runs inside a
      // go_router builder, where a throw escapes as Flutter's ErrorWidget
      // rather than the route error screen — errorBuilder only covers
      // route-matching failures.
      try {
        final decoded = NIP19Tlv.decodeNevent(trimmed);
        return decoded == null ? null : VideoRouteRef(eventId: decoded.id);
      } on Object catch (_) {
        return null;
      }
    }

    if (NIP19Tlv.isNaddr(trimmed)) {
      final decoded = NIP19Tlv.decodeNaddr(trimmed);
      if (decoded == null) return null;
      return VideoRouteRef(
        addressableId: AId(
          kind: decoded.kind,
          pubkey: decoded.author,
          dTag: decoded.id,
        ).toAString(),
        addressablePubkey: decoded.author,
        stableId: decoded.id,
      );
    }

    // Raw NIP-33 addressable coordinate: "kind:pubkey:d-tag"
    // Produced by VideoNotification.videoAddressableId for stable notification
    // navigation and by DM share-card fallbacks, which can reference any
    // acceptable NIP-71 kind (e.g. 34235). Accepts the same kinds as the
    // naddr branch above; the 34236-only isVideoKind check would let a
    // 34235 coordinate fall through to an unmatched d-tag lookup.
    final aid = AId.fromString(trimmed);
    if (aid != null && NIP71VideoKinds.isAcceptableVideoKind(aid.kind)) {
      return VideoRouteRef(
        addressableId: trimmed,
        addressablePubkey: aid.pubkey,
        stableId: aid.dTag,
      );
    }

    return VideoRouteRef(stableId: trimmed);
  }

  /// The identifier to address this video by in first-party REST calls.
  ///
  /// Prefers the event id, falling back to the stable id / d-tag, which the
  /// API resolves for addressable events that carry no event id of their own
  /// (an `naddr1`). Null when neither is known.
  String? get lookupId {
    final id = eventId;
    if (id != null && id.isNotEmpty) return id;
    final stable = stableId;
    if (stable != null && stable.isNotEmpty) return stable;
    return null;
  }
}
