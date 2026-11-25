// ABOUTME: Normalized identity for videos shared inside DM messages.
// ABOUTME: Resolves NIP-19 and legacy Divine URLs and structured q references.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';

/// Matches a single line whose entire content is a straight-quoted
/// string — the shape `VideoSharingService` uses to embed the title in
/// the share-message body (`"<title>"`). The bubble drops this line so
/// the title isn't duplicated alongside the overlay-footer rendering.
final dmVideoQuotedTitleLine = RegExp(r'^".*"$');

/// Matches a line that is just a NIP-21 `nostr:` citation (or bare entity).
/// The share body carries a `nostr:naddr…`/`nevent…` reference for other
/// clients to resolve, but in-app it duplicates the tappable video card, so
/// the bubble drops it rather than rendering a redundant "View video" link.
final dmVideoCitationLine = RegExp(
  r'^(?:nostr:)?(?:naddr|nevent|note|npub|nprofile)1[0-9a-z]+$',
  caseSensitive: false,
);

/// Normalized identity and routing metadata for a video shared in a DM.
@immutable
class DmVideoTarget {
  const DmVideoTarget({
    required this.stableId,
    this.authorPubkey,
    this.videoKind,
    this.routeReference,
  });

  /// The video's `d` tag, or the event id of a regular event. Repository
  /// lookups go through [routeId].
  final String stableId;

  /// Author named by the URL's `naddr`/`nevent`, else by a citing NIP-18
  /// reference, else by the URL's `?author=` query. Routing uses it only when
  /// it is a hex pubkey.
  final String? authorPubkey;

  /// NIP-71 video event kind, from the URL's `naddr` or a structured
  /// reference; an `nevent` URL is taken as kind 22.
  final int? videoKind;

  /// The URL's `naddr`/`nevent`, re-encoded from its decoded fields, kept so
  /// routing stays exact: an `naddr` never degrades to a raw coordinate that
  /// matches any kind, nor an `nevent` to a bare id also looked up as a `d`
  /// tag.
  final String? routeReference;

  /// Canonical web URL for copying or sharing this video.
  ///
  /// Echoes [routeReference] when the message carried one, and encodes a
  /// regular event as an `nevent`. Any other share keeps the legacy link,
  /// which names the author when one is known so it opens this account's video
  /// rather than whichever account posted last under the same `d` tag
  /// (#10929). An addressable share stays legacy because a raw coordinate's
  /// kind may be the 34236 alias Divine once used for kind 34235 videos, and an
  /// `naddr` of the wrong kind resolves to nothing.
  String get canonicalUrl {
    final reference = routeReference;
    if (reference != null) return 'https://divine.video/video/$reference';
    return divineVideoShareUrl(
      stableId,
      authorPubkey: _routingAuthor,
      kind:
          videoKind != null &&
              !NIP71VideoKinds.isAddressableVideoKind(videoKind!)
          ? videoKind
          : null,
    );
  }

  /// The repository route this video resolves by.
  ///
  /// A NIP-19 reference routes as itself, and a regular event with a hex id
  /// as an `nevent`, so neither is also looked up as a `d` tag. An addressable
  /// share with a known author resolves by its coordinate alone: the bare d
  /// tag names no author, and another account's video can share it (#10384).
  String get routeId {
    final reference = routeReference;
    if (reference != null) return reference;
    final coordinate = _authorScopedCoordinate;
    if (coordinate != null) return coordinate;
    if (videoKind != null &&
        !NIP71VideoKinds.isAddressableVideoKind(videoKind!) &&
        NostrHexUtils.isValidEventId(stableId)) {
      return NIP19Tlv.encodeNevent(Nevent(id: stableId));
    }
    return stableId;
  }

  /// The author a lookup of [routeId] is held to, when [routeId] does not
  /// already name one: a bare hex or d-tag route is also looked up as a `d`
  /// tag anyone can publish under.
  String? get routeAuthor =>
      _authorScopedCoordinate == null ? _routingAuthor : null;

  String? get _authorScopedCoordinate {
    final author = _routingAuthor;
    final kind = videoKind;
    if (author == null || kind == null) return null;
    if (!NIP71VideoKinds.isAddressableVideoKind(kind)) return null;
    return '$kind:$author:$stableId';
  }

  /// [authorPubkey] when it is a hex pubkey. Another client's npub or
  /// truncated key cannot scope a lookup, so routing treats it as absent.
  String? get _routingAuthor {
    final author = authorPubkey;
    if (!NostrHexUtils.isValidPubkey(author)) return null;
    return author!.toLowerCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DmVideoTarget &&
          stableId == other.stableId &&
          authorPubkey == other.authorPubkey &&
          videoKind == other.videoKind &&
          routeReference == other.routeReference;

  @override
  int get hashCode =>
      Object.hash(stableId, authorPubkey, videoKind, routeReference);
}

/// Resolves the video represented by a DM's plaintext and structured citation.
///
/// A Divine URL in the text is the primary identity. An `naddr` or `nevent`
/// URL carries its own identity and overrides the citation; one that does not
/// decode to a video resolves to null rather than to a `d`-tag lookup. For a
/// legacy URL, a valid NIP-18 `q` reference contributes its author when it
/// cites the URL's video (a regular-event reference, or an addressable one
/// naming the same d tag), and its kind only when it cites the URL's own id.
/// With no URL, the reference supplies the identity.
///
/// When [contentIsTruncated] is true, [content] is a bounded prefix of the
/// full body and a URL match that runs to its end, or into a cut author query,
/// is ignored: the URL capture has no right anchor, so a cut inside the id
/// would otherwise resolve a shortened, wrong identity. See
/// [firstCompleteDivineVideoUrlMatch].
DmVideoTarget? resolveDmVideoTarget({
  required String content,
  DmSharedVideoRef? sharedVideoRef,
  bool contentIsTruncated = false,
}) {
  final urlMatch = firstCompleteDivineVideoUrlMatch(
    content,
    contentIsTruncated: contentIsTruncated,
  );
  final urlStableId = urlMatch?.group(1);
  final structuredTarget = _targetFromRef(sharedVideoRef);

  if (urlStableId != null) {
    // A NIP-19 reference is re-encoded from what this decoder read, so the
    // copied link names the video the card previews: decoders disagree on a
    // reference that repeats a field.
    final lower = urlStableId.toLowerCase();
    if (lower.startsWith('naddr1')) {
      final address = NIP19Tlv.decodeNaddr(urlStableId);
      if (address == null ||
          !NostrHexUtils.isValidPubkey(address.author) ||
          !NIP71VideoKinds.isAddressableVideoKind(address.kind)) {
        return null;
      }
      return DmVideoTarget(
        stableId: address.id,
        routeReference: NIP19Tlv.encodeNaddr(
          Naddr(
            id: address.id,
            author: address.author,
            kind: address.kind,
            relays: address.relays,
          ),
        ),
        authorPubkey: address.author,
        videoKind: address.kind,
      );
    }
    if (lower.startsWith('nevent1')) {
      final event = NIP19Tlv.decodeNevent(urlStableId);
      if (event == null || !NostrHexUtils.isValidEventId(event.id)) return null;
      final author = NostrHexUtils.isValidPubkey(event.author)
          ? event.author
          : null;
      return DmVideoTarget(
        stableId: event.id,
        routeReference: NIP19Tlv.encodeNevent(
          Nevent(id: event.id, relays: event.relays, author: author),
        ),
        authorPubkey:
            author ??
            (structuredTarget?.stableId == event.id &&
                    sharedVideoRef?.isAddressable == false
                ? structuredTarget?.authorPubkey
                : null),
        videoKind: NIP71VideoKinds.shortVideo,
      );
    }
    final citesSameId = structuredTarget?.stableId == urlStableId;
    // An addressable citation of another d tag names a different video, so
    // its author must not scope this URL's lookup.
    final citesUrl =
        structuredTarget != null &&
        (sharedVideoRef?.isAddressable != true || citesSameId);
    // The URL's own `?author=` scopes it when no citation does.
    final urlAuthor = urlMatch?.group(2);
    return DmVideoTarget(
      stableId: urlStableId,
      authorPubkey: citesUrl
          ? structuredTarget.authorPubkey ?? urlAuthor
          : urlAuthor,
      // A regular citation of another id says nothing about the URL's id,
      // which may be a hex d tag: routing it as an exact event would lose it.
      videoKind: citesSameId ? structuredTarget!.videoKind : null,
    );
  }

  return structuredTarget;
}

/// The first canonical Divine video URL in [content], or null when
/// [contentIsTruncated] and the match reaches the end of [content], or only
/// an `?author=` query the cut sliced through follows it.
///
/// A match that touches the cut may be an id the display bound sliced
/// through, and `[\w-]+` cannot tell a complete id from a prefix of one, so
/// the caller keeps rendering the text and re-resolves once more is shown.
/// A cut author query leaves the id intact, but resolving it then would drop
/// the author the link names (#10929).
RegExpMatch? firstCompleteDivineVideoUrlMatch(
  String content, {
  required bool contentIsTruncated,
}) {
  final match = divineVideoUrlRegex.firstMatch(content);
  if (match == null) return null;
  if (contentIsTruncated && _mayBeCutQuery(content.substring(match.end))) {
    return null;
  }
  return match;
}

final _partialPubkey = RegExp(r'^[0-9a-f]{1,63}$');

/// Whether [rest], everything after a URL match, could be the start of an
/// author query the cut sliced through. Empty [rest] is a cut at the id.
bool _mayBeCutQuery(String rest) {
  const query = '?$divineVideoAuthorQueryParameter=';
  final lower = rest.toLowerCase();
  if (lower.length <= query.length) return query.startsWith(lower);
  return lower.startsWith(query) &&
      _partialPubkey.hasMatch(lower.substring(query.length));
}

DmVideoTarget? _targetFromRef(DmSharedVideoRef? ref) {
  if (ref == null) return null;
  if (!ref.isAddressable) {
    return DmVideoTarget(
      stableId: ref.coordinateOrId,
      authorPubkey: ref.authorPubkey,
      videoKind: ref.videoKind.kind,
    );
  }

  final parts = ref.coordinateOrId.split(':');
  if (parts.length < 3) return null;
  final kind = int.tryParse(parts.first);
  final author = parts[1].isNotEmpty ? parts[1] : ref.authorPubkey;
  final stableId = ref.dTag;
  if (kind == null || stableId == null) return null;

  return DmVideoTarget(
    stableId: stableId,
    authorPubkey: author,
    videoKind: kind,
  );
}
