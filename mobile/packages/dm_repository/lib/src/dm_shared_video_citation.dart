// ABOUTME: Builds + parses the NIP-18 `q` citation for a video shared in a DM.
// ABOUTME: Encodes naddr (addressable 34236) / nevent (regular 22) per NIP-19.
// ABOUTME: Also reads divine-web's legacy `r` + `a` share shape (#6224).

import 'package:dm_repository/src/collaborator_invite_recovery.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';

/// Shared-video citation constants.
abstract class DmShareConstants {
  /// Relay hint used when the video carries no known source relay.
  static const String defaultRelayHint = 'wss://relay.divine.video';
}

final RegExp _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

bool _isHex64(String value) => _hex64.hasMatch(value);

/// The machine-readable + human-readable halves of a video citation inside a
/// NIP-17 kind-14 rumor: the NIP-18 `q` tag and the NIP-21 `nostr:` URI.
class DmSharedVideoCitation {
  /// Creates a citation from a prebuilt [qTag] and [nostrUri].
  const DmSharedVideoCitation({required this.qTag, required this.nostrUri});

  /// The `["q", "<coordinate-or-id>", "<relay>", "<author?>"]` tag.
  final List<String> qTag;

  /// The `nostr:naddr1…` / `nostr:nevent1…` URI for the message content.
  final String nostrUri;

  /// Builds a citation for a video, choosing `naddr` (addressable) vs `nevent`
  /// (regular) by [videoKind]. Returns `null` when the inputs can't form a
  /// valid reference (so the caller can fall back to a plain-text share).
  ///
  /// - Addressable (34236/34235): `q = ["q", "<kind>:<author>:<d>", relay]`
  ///   with NO 4th element (the pubkey is already in the coordinate).
  /// - Regular (22): `q = ["q", "<event-id>", relay, "<author>"]`.
  ///
  /// An addressable video with no `d` tag has no coordinate, so it is cited by
  /// [eventId] in the regular form instead.
  static DmSharedVideoCitation? build({
    required int videoKind,
    required String authorPubkey,
    required String relayHint,
    String? dTag,
    String? eventId,
  }) {
    if (!_isHex64(authorPubkey)) return null;
    final relay = relayHint.isNotEmpty
        ? relayHint
        : DmShareConstants.defaultRelayHint;

    final isAddressable =
        videoKind == NIP71VideoKinds.addressableShortVideo ||
        videoKind == NIP71VideoKinds.addressableNormalVideo;

    if (isAddressable && dTag != null && dTag.isNotEmpty) {
      final coordinate = '$videoKind:$authorPubkey:$dTag';
      final naddr = NIP19Tlv.encodeNaddr(
        Naddr(id: dTag, author: authorPubkey, kind: videoKind, relays: [relay]),
      );
      return DmSharedVideoCitation(
        qTag: ['q', coordinate, relay],
        nostrUri: 'nostr:$naddr',
      );
    }

    if (eventId == null || !_isHex64(eventId)) return null;
    final nevent = NIP19Tlv.encodeNevent(
      Nevent(id: eventId, author: authorPubkey, relays: [relay]),
    );
    return DmSharedVideoCitation(
      qTag: ['q', eventId, relay, authorPubkey],
      nostrUri: 'nostr:$nevent',
    );
  }

  /// Parses a kind-14 rumor's [tags] into a [DmSharedVideoRef]. Total —
  /// returns `null` for absent/malformed tags so a plain message degrades
  /// gracefully.
  ///
  /// Tries the canonical NIP-18 `q` citation first, then falls back to the
  /// legacy divine-web share shape (see [_parseLegacyWebShare]).
  static DmSharedVideoRef? parse(List<List<String>> tags) =>
      _parseQTag(tags) ?? _parseLegacyWebShare(tags);

  /// Parses the first `q` tag into a [DmSharedVideoRef].
  static DmSharedVideoRef? _parseQTag(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length < 2 || tag[0] != 'q') continue;
      final value = tag[1];
      if (value.isEmpty) continue;
      final relayHint = tag.length >= 3 && tag[2].isNotEmpty ? tag[2] : null;
      final explicitAuthor = tag.length >= 4 && tag[3].isNotEmpty
          ? tag[3]
          : null;

      // Addressable coordinate: "<kind>:<author>:<d>".
      final coordParts = value.split(':');
      final coordinateKind = int.tryParse(coordParts.first);
      final isSupportedAddressableKind =
          coordinateKind == DmSharedVideoKind.addressableShortVideo.kind ||
          coordinateKind == DmSharedVideoKind.addressableNormalVideo.kind;
      if (coordParts.length >= 3 && isSupportedAddressableKind) {
        return DmSharedVideoRef(
          coordinateOrId: value,
          videoKind: DmSharedVideoKind.fromKind(coordinateKind!),
          relayHint: relayHint,
          authorPubkey: coordParts[1].isNotEmpty
              ? coordParts[1]
              : explicitAuthor,
        );
      }

      // Regular video event id (64-hex). Require the author slot used by our
      // NIP-19 `nevent` share shape so ordinary note `q` tags do not masquerade
      // as saveable Divine videos.
      if (_isHex64(value) &&
          explicitAuthor != null &&
          _isHex64(explicitAuthor)) {
        return DmSharedVideoRef(
          coordinateOrId: value,
          videoKind: DmSharedVideoKind.shortVideo,
          relayHint: relayHint,
          authorPubkey: explicitAuthor,
        );
      }
    }
    return null;
  }

  /// Parses divine-web's legacy share shape: `['r', <canonical url>]` plus
  /// `['a', '<kind>:<author>:<d>']` (#6224).
  ///
  /// divine-web emitted this from 2026-03-09 until its DM share path was
  /// removed on 2026-08-04, and never wrote the URL into the rumor content —
  /// so without this fallback those messages render as plain text, or as an
  /// empty bubble when the sender attached the share with no comment.
  ///
  /// Two tags are deliberately NOT accepted:
  ///
  /// - **`e`**, because NIP-17 reserves it for the reply parent and
  ///   `DmRepository` already assigns any `e` tag to `replyToId`. Treating it
  ///   as a citation would render a compact quoted preview instead of a share
  ///   card and leave the video actions disabled. divine-web only ever shared
  ///   kind 34236, so its `e` branch was effectively unreachable anyway.
  /// - **A bare `a` with no companion `r`**, because Divine's own
  ///   collaborator-invite DM also carries an addressable video coordinate.
  static DmSharedVideoRef? _parseLegacyWebShare(List<List<String>> tags) {
    if (_hasCollaboratorInviteMarker(tags)) return null;

    // divine-web wrote `r` first and unconditionally on every share, and no
    // Divine DM producer emits an `r` tag otherwise — so requiring a canonical
    // divine.video URL is what makes the `a` fallback unambiguous.
    if (!_hasDivineVideoUrlTag(tags)) return null;

    for (final tag in tags) {
      if (tag.length < 2 || tag[0] != 'a') continue;
      final coordinate = tag[1];
      final parts = coordinate.split(':');
      if (parts.length < 3) continue;

      final kind = int.tryParse(parts.first);
      if (kind != DmSharedVideoKind.addressableShortVideo.kind &&
          kind != DmSharedVideoKind.addressableNormalVideo.kind) {
        continue;
      }

      // divine-web built the coordinate from unvalidated URL query params, so
      // guard both segments rather than trusting the wire.
      final author = parts[1];
      if (!_isHex64(author)) continue;
      if (parts.sublist(2).join(':').isEmpty) continue;

      return DmSharedVideoRef(
        coordinateOrId: coordinate,
        videoKind: DmSharedVideoKind.fromKind(kind!),
        relayHint: tag.length >= 3 && tag[2].isNotEmpty ? tag[2] : null,
        authorPubkey: author,
      );
    }
    return null;
  }

  /// Whether [tags] carry the `['divine', 'collab-invite']` marker that
  /// identifies a collaborator invite rather than a shared video.
  static bool _hasCollaboratorInviteMarker(List<List<String>> tags) => tags.any(
    (tag) =>
        tag.length >= 2 &&
        tag[0] == CollaboratorInviteTags.markerName &&
        tag[1] == CollaboratorInviteTags.markerValue,
  );

  /// Whether [tags] carry an `r` tag that *starts with* a divine.video share
  /// URL.
  ///
  /// Anchored at the start so a URL merely embedded in some other string
  /// (`https://elsewhere.example/?next=<share url>`) cannot satisfy the gate.
  /// Not anchored at the end: divine-web interpolated the video's `d` tag into
  /// the path without percent-encoding, so a legitimate share can carry a
  /// trailing `.`, `?`, `#`, or `/` that a full-string match would reject.
  static bool _hasDivineVideoUrlTag(List<List<String>> tags) => tags.any(
    (tag) =>
        tag.length >= 2 &&
        tag[0] == 'r' &&
        divineVideoUrlRegex.matchAsPrefix(tag[1]) != null,
  );
}
