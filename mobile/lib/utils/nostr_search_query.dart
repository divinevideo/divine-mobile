// ABOUTME: Classifies a search query as a Nostr identifier and decides what
// ABOUTME: to open, reusing the NIP-19 decoders the app already ships.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:videos_repository/videos_repository.dart';

/// A search query that names a Nostr entity rather than free text.
///
/// Returned by [resolveNostrSearchTarget] only for a *complete* identifier:
/// a full 64-character hex value, a whole `npub1` / `nprofile1` bech32 string,
/// or a decodable `note1` / `nevent1` / `naddr1` / `kind:pubkey:d-tag`
/// coordinate. Partial prefixes return null so search-as-you-type never
/// resolves half an identifier.
sealed class NostrSearchTarget {
  const NostrSearchTarget();
}

/// `npub1` or `nprofile1`: a public key with no event attached.
final class NostrProfileTarget extends NostrSearchTarget {
  const NostrProfileTarget(this.hexPubkey);

  final String hexPubkey;
}

/// `note1`, `nevent1`, `naddr1`, or a raw NIP-33 coordinate: an events-known
/// video reference. [routeId] is the original query, kept so the `/video`
/// route and [VideoRouteRef.parse] decode it exactly once on the far side.
final class NostrVideoTarget extends NostrSearchTarget {
  const NostrVideoTarget(this.routeId);

  final String routeId;
}

/// A bare 64-character hex string, which is a valid public key *and* a valid
/// event id at the same time. Hex carries no type tag, so only a lookup can
/// say which the value actually names.
final class NostrAmbiguousTarget extends NostrSearchTarget {
  const NostrAmbiguousTarget(this.hex);

  final String hex;
}

/// What the caller should open, or null when nothing matched.
sealed class NostrIdOpenAction {
  const NostrIdOpenAction();
}

/// Open the profile for [npub].
final class OpenProfileAction extends NostrIdOpenAction {
  const OpenProfileAction(this.npub);

  final String npub;
}

/// Open the video addressed by [routeId] (`/video/<routeId>`).
final class OpenVideoAction extends NostrIdOpenAction {
  const OpenVideoAction(this.routeId);

  final String routeId;
}

/// Classifies [rawQuery] as a Nostr identifier.
///
/// Order matters: the bech32/coordinate event forms are tested first, because
/// a bare hex value would otherwise be claimed by the public-key decoder.
/// Returns null for anything that is not a complete identifier, including an
/// `naddr1` that encodes a non-video kind and a `note1` whose payload is not
/// a 32-byte id.
NostrSearchTarget? resolveNostrSearchTarget(String rawQuery) {
  final query = rawQuery.trim();
  if (query.isEmpty) return null;

  final lower = query.toLowerCase();

  // Event forms that are never a pubkey.
  if (lower.startsWith('note1') ||
      lower.startsWith('nevent1') ||
      lower.startsWith('naddr1')) {
    return VideoRouteRef.parse(query) == null ? null : NostrVideoTarget(query);
  }

  // Raw NIP-33 coordinate "kind:pubkey:d-tag", gated to video kinds so a
  // long-form or list coordinate stays a text search. AId.fromString accepts
  // any middle part, so the pubkey is checked here; otherwise text such as
  // "21:30:00" would open a video.
  final coordinate = AId.fromString(query);
  if (coordinate != null &&
      NIP71VideoKinds.isAcceptableVideoKind(coordinate.kind) &&
      NostrHexUtils.isValidPubkey(coordinate.pubkey)) {
    return NostrVideoTarget(query);
  }

  // Bare 64-hex is valid as both a pubkey and an event id.
  if (NostrHexUtils.isValidEventId(query)) {
    return NostrAmbiguousTarget(lower);
  }

  // npub1 / nprofile1. The decoder returns an empty string rather than null
  // for a truncated bech32 payload, so the decoded value is re-validated
  // here — otherwise a half-typed npub would classify as a real profile.
  final profile = normalizePublicIdentifier(query);
  if (profile != null && NostrHexUtils.isValidPubkey(profile.hexPubkey)) {
    return NostrProfileTarget(profile.hexPubkey);
  }

  return null;
}

/// Turns a query into the entity to open, resolving a bare hex query against
/// both the profile and video sources because hex alone cannot say which it is.
class NostrIdSearchResolver {
  const NostrIdSearchResolver({
    required this.profileExists,
    required this.videoExists,
  });

  /// Whether a profile is known for [hexPubkey].
  final Future<bool> Function(String hexPubkey) profileExists;

  /// Whether a video is known for [routeId].
  final Future<bool> Function(String routeId) videoExists;

  /// Resolves [rawQuery], or null when it names nothing openable.
  ///
  /// `npub1` / `nprofile1` and the event forms open without a lookup — the
  /// destination screen owns "does this exist". A bare hex string is looked up
  /// against both sources; the video wins when both somehow resolve, since a
  /// pasted event id is the common case and a hex value cannot be two things.
  Future<NostrIdOpenAction?> resolve(String rawQuery) async {
    final target = resolveNostrSearchTarget(rawQuery);
    switch (target) {
      case null:
        return null;
      case NostrProfileTarget(:final hexPubkey):
        final npub = normalizeToNpub(hexPubkey);
        return npub == null ? null : OpenProfileAction(npub);
      case NostrVideoTarget(:final routeId):
        return OpenVideoAction(routeId);
      case NostrAmbiguousTarget(:final hex):
        final hits = await Future.wait([
          _orFalse(() => videoExists(hex)),
          _orFalse(() => profileExists(hex)),
        ]);
        if (hits[0]) return OpenVideoAction(hex);
        if (hits[1]) {
          final npub = normalizeToNpub(hex);
          if (npub != null) return OpenProfileAction(npub);
        }
        return null;
    }
  }

  Future<bool> _orFalse(Future<bool> Function() lookup) async {
    try {
      return await lookup();
    } on Exception {
      return false;
    }
  }
}
