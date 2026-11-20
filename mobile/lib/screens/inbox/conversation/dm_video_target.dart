// ABOUTME: Normalized identity for videos shared inside DM messages.
// ABOUTME: Resolves legacy Divine URLs and structured q references consistently.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';

/// Normalized identity and routing metadata for a video shared in a DM.
@immutable
class DmVideoTarget {
  const DmVideoTarget({
    required this.stableId,
    this.authorPubkey,
    this.videoKind,
    this.routeReference,
  });

  /// Stable id used by Divine video URLs. Repository lookups go through
  /// [routeId], which is this id unless the share is addressable and names a
  /// hex author.
  final String stableId;

  /// Author as a structured NIP-18 reference carried it, or else as the URL's
  /// `?author=` query named it. Routing uses it only when it is a hex pubkey.
  final String? authorPubkey;

  /// NIP-71 video event kind when supplied by a structured reference.
  final int? videoKind;

  /// Original NIP-19 reference, retained so strict addresses never become
  /// legacy raw coordinates while travelling through DM preview widgets.
  final String? routeReference;

  /// Canonical web URL for copying or sharing this video.
  ///
  /// Names the author when one is known, so the link opens this account's
  /// video rather than whichever account posted last under the same `d` tag
  /// (#10929).
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
  /// An addressable share with a known author resolves by its coordinate
  /// alone: the bare d tag names no author, and another account's video can
  /// share it (#10384).
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
  /// already name one: a regular-event share routes by its event id, which
  /// the repository also looks up as a `d` tag anyone can publish under.
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
/// Canonical Divine URLs remain the primary stable identity for compatibility
/// with older messages. A valid NIP-18 `q` reference contributes author/kind
/// routing metadata when it cites the URL's video (a regular-event reference,
/// or an addressable one naming the same d tag), or supplies the identity when
/// no URL is present.
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
