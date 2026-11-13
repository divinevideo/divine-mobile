// ABOUTME: Regex + helpers for building and extracting divine.video URLs.
// ABOUTME: Shared by the share builders, the conversation bubble, the
// ABOUTME: long-press handler, and the DM shared-video citation parser.

import 'package:models/src/nostr_hex_utils.dart';

/// Query parameter that names the author of a `/video/<id>` share link.
///
/// A video's `d` tag is not unique across accounts (a Divine upload's is the
/// file's sha256), so a link that names only the `d` tag can open another
/// account's video. Clients that read this parameter hold the lookup to that
/// author; older clients ignore it and resolve the `d` tag as before.
const divineVideoAuthorQueryParameter = 'author';

/// Detects the canonical share-link shape
/// (`https://divine.video/video/<id>`, optionally `?author=<hex pubkey>`).
///
/// Group 1 is the id: hex event IDs (64 chars) and d-tags (UUIDs,
/// alphanumeric strings). Only word characters and hyphens are matched so
/// trailing punctuation (`.`, `,`, `)`) is excluded. Group 2 is the author's
/// hex pubkey when the link carries one; any other query string is excluded
/// from the match.
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

/// The canonical share link for the video whose route id is [stableId].
///
/// Appends the `author` query when [authorPubkey] is a hex pubkey, so the
/// link resolves to that author's video rather than to whichever account
/// last posted under the same `d` tag. [stableId] is interpolated as given;
/// a caller holding an id that may need escaping encodes it first.
String divineVideoShareUrl(String stableId, {String? authorPubkey}) =>
    divineVideoUrlWithAuthor(
      'https://divine.video/video/$stableId',
      authorPubkey,
    );

/// [videoUrl] with the `author` query appended when [authorPubkey] is a hex
/// pubkey, or [videoUrl] unchanged otherwise.
String divineVideoUrlWithAuthor(String videoUrl, String? authorPubkey) {
  if (!NostrHexUtils.isValidPubkey(authorPubkey)) return videoUrl;
  return '$videoUrl?$divineVideoAuthorQueryParameter='
      '${authorPubkey!.toLowerCase()}';
}
