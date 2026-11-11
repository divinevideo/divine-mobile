// ABOUTME: Normalized identity for videos shared inside DM messages.
// ABOUTME: Resolves legacy Divine URLs and structured q references consistently.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';

/// Normalized identity and routing metadata for a video shared in a DM.
@immutable
class DmVideoTarget {
  const DmVideoTarget({
    required this.stableId,
    this.authorPubkey,
    this.videoKind,
  });

  /// Stable id used by Divine video URLs. Repository lookups go through
  /// [routeId], which is this id unless the share names an author.
  final String stableId;

  /// Full author pubkey when supplied by a structured NIP-18 reference.
  final String? authorPubkey;

  /// NIP-71 video event kind when supplied by a structured reference.
  final int? videoKind;

  /// Canonical web URL for copying or sharing this video.
  String get canonicalUrl => 'https://divine.video/video/$stableId';

  /// The repository route this video resolves by.
  ///
  /// An addressable share with a known author resolves by its coordinate
  /// alone: the bare d tag names no author, and another account's video can
  /// share it (#10384).
  String get routeId => _authorScopedCoordinate ?? stableId;

  /// The author a lookup of [routeId] is held to, when [routeId] does not
  /// already name one: a regular-event share routes by its event id, which
  /// the repository also looks up as a `d` tag anyone can publish under.
  String? get routeAuthor =>
      _authorScopedCoordinate == null ? _routingAuthor : null;

  /// Repository routes tried after [routeId].
  List<String> get fallbackRouteIds {
    if (_authorScopedCoordinate != null) return const [];
    final author = _routingAuthor;
    final kind = videoKind;
    if (author == null || kind == null) return const [];
    return ['$kind:$author:$stableId'];
  }

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
          videoKind == other.videoKind;

  @override
  int get hashCode => Object.hash(stableId, authorPubkey, videoKind);
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
/// full body and a URL match that runs to its end is ignored: the URL capture
/// has no right anchor, so a cut inside the id would otherwise resolve a
/// shortened, wrong identity. See [firstCompleteDivineVideoUrlMatch].
DmVideoTarget? resolveDmVideoTarget({
  required String content,
  DmSharedVideoRef? sharedVideoRef,
  bool contentIsTruncated = false,
}) {
  final urlStableId = firstCompleteDivineVideoUrlMatch(
    content,
    contentIsTruncated: contentIsTruncated,
  )?.group(1);
  final structuredTarget = _targetFromRef(sharedVideoRef);

  if (urlStableId != null) {
    // An addressable citation of another d tag names a different video, so
    // its author must not scope this URL's lookup.
    final citesUrl =
        structuredTarget != null &&
        (sharedVideoRef?.isAddressable != true ||
            structuredTarget.stableId == urlStableId);
    return DmVideoTarget(
      stableId: urlStableId,
      authorPubkey: citesUrl ? structuredTarget.authorPubkey : null,
      videoKind: citesUrl ? structuredTarget.videoKind : null,
    );
  }

  return structuredTarget;
}

/// The first canonical Divine video URL in [content], or null when
/// [contentIsTruncated] and the match reaches the end of [content].
///
/// A match that touches the cut may be an id the display bound sliced
/// through, and `[\w-]+` cannot tell a complete id from a prefix of one, so
/// the caller keeps rendering the text and re-resolves once more is shown.
RegExpMatch? firstCompleteDivineVideoUrlMatch(
  String content, {
  required bool contentIsTruncated,
}) {
  final match = divineVideoUrlRegex.firstMatch(content);
  if (match == null) return null;
  if (contentIsTruncated && match.end == content.length) return null;
  return match;
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
