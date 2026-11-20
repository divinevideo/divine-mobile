// ABOUTME: Builds divine.video video links (NIP-19 naddr/nevent, or the
// ABOUTME: legacy ?author= form) and extracts them from text.

import 'dart:convert';

import 'package:models/src/nip71_video_kinds.dart';
import 'package:models/src/nostr_hex_utils.dart';
import 'package:models/src/video_event.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';

/// Query parameter that names the author of a `/video/<id>` share link.
///
/// A video's `d` tag is not unique across accounts (a Divine upload's is the
/// file's sha256), so a link that names only the `d` tag can open another
/// account's video. Clients that read this parameter hold the lookup to that
/// author; older clients ignore it and resolve the `d` tag as before. Only
/// legacy links carry it; an `naddr` embeds the author.
const divineVideoAuthorQueryParameter = 'author';

/// Detects a divine.video video link (`https://divine.video/video/<id>`,
/// optionally `?author=<hex pubkey>` on a legacy link).
///
/// Group 1 is the id: an `naddr1`/`nevent1` reference, a 64-char hex event
/// ID, or a legacy d tag (UUIDs, alphanumeric strings). Only word characters
/// and hyphens are matched so trailing punctuation (`.`, `,`, `)`) is
/// excluded. Group 2 is the author's hex pubkey when the link carries one;
/// any other query string is excluded from the match.
final divineVideoUrlRegex = RegExp(
  r'https?://(?:www\.)?divine\.video/video/([\w-]+)'
  r'(?:\?author=([0-9a-fA-F]{64})(?![0-9a-zA-Z]))?',
  caseSensitive: false,
);

/// Matches a line whose entire content is a canonical divine.video share URL.
final divineVideoUrlLineRegex = RegExp(
  r'^https?://(?:www\.)?divine\.video/video/[\w-]+'
  r'(?:\?author=[0-9a-fA-F]{64})?$',
  caseSensitive: false,
);

/// The divine.video link for a video, as an `naddr` or `nevent` reference.
///
/// [stableId] is the real `d` tag for an addressable [kind], or the event ID
/// for a regular one. A null [kind] (the event kind is unknown), a non-hex
/// [authorPubkey] for an addressable kind, or a `d` tag over NIP-19's
/// 255-byte entry limit falls back to the legacy `/video/<id>?author=<hex>`
/// link. That path encodes [stableId] itself, so pass it unencoded.
String divineVideoShareUrl(
  String stableId, {
  required int? kind,
  String? authorPubkey,
}) {
  final author = NostrHexUtils.isValidPubkey(authorPubkey)
      ? authorPubkey!.toLowerCase()
      : null;
  if (kind != null &&
      NIP71VideoKinds.isAddressableVideoKind(kind) &&
      author != null &&
      utf8.encode(stableId).length <= 255) {
    final reference = NIP19Tlv.encodeNaddr(
      Naddr(id: stableId, author: author, kind: kind),
    );
    return 'https://divine.video/video/$reference';
  }
  if ((kind == NIP71VideoKinds.shortVideo ||
          kind == NIP71VideoKinds.normalVideo) &&
      NostrHexUtils.isValidEventId(stableId)) {
    final reference = NIP19Tlv.encodeNevent(
      Nevent(id: stableId.toLowerCase()),
    );
    return 'https://divine.video/video/$reference';
  }
  return divineVideoUrlWithAuthor(
    'https://divine.video/video/${Uri.encodeComponent(stableId)}',
    author,
  );
}

/// [videoUrl] with the `author` query appended when [authorPubkey] is a hex
/// pubkey, or [videoUrl] unchanged otherwise.
String divineVideoUrlWithAuthor(String videoUrl, String? authorPubkey) {
  if (!NostrHexUtils.isValidPubkey(authorPubkey)) return videoUrl;
  return '$videoUrl?$divineVideoAuthorQueryParameter='
      '${authorPubkey!.toLowerCase()}';
}

/// Builds a standard share reference without mistaking an event-ID fallback
/// in `vineId` for a real addressable identifier.
String divineVideoShareUrlForEvent(VideoEvent video) {
  final identity = divineVideoShareIdentity(video);
  return divineVideoShareUrl(
    identity.dTag ?? video.id,
    authorPubkey: video.pubkey,
    kind: identity.dTag == null ? NIP71VideoKinds.shortVideo : identity.kind,
  );
}

/// The protocol identity the URL and DM citation builders share.
///
/// A null `dTag` means the `d` tag is missing, empty or too long to encode, so
/// callers cite the event id; `kind` stays the event's kind even then (see
/// [divineVideoShareUrlForEvent]).
({int kind, String? dTag}) divineVideoShareIdentity(VideoEvent video) {
  final dTag = video.addressableDTag ?? video.rawTags['d'];
  final kind =
      video.eventKind ??
      (dTag != null
          ? NIP71VideoKinds.addressableShortVideo
          : NIP71VideoKinds.shortVideo);
  final addressable =
      NIP71VideoKinds.isAddressableVideoKind(kind) &&
      dTag != null &&
      dTag.isNotEmpty &&
      utf8.encode(dTag).length <= 255;
  return (kind: kind, dTag: addressable ? dTag : null);
}
