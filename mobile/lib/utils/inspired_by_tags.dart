// ABOUTME: Shared Divine inspired-by p-tag builder and creator resolution
// ABOUTME: used by both the direct-upload and edit-video publish paths.

import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/utils/npub_hex.dart';

/// Re-exported so the app-layer tag helpers stay the one place call sites
/// reach for the marker, now that the constant lives with the models.
export 'package:models/models.dart' show inspiredByPTagMarker;

/// Default relay hint embedded in Divine inspired-by p-tags.
const String inspiredByPTagRelayHint = AppConstants.defaultRelayUrl;

/// Builds the Divine inspired-by-marked `p` tag for [pubkeyHex].
///
/// The marker must stay non-empty: funnelcake's collaborator read model
/// treats a missing p-tag marker as `'collaborator'`.
List<String> buildInspiredByPTag(String pubkeyHex, {String? relayHint}) {
  final relay = (relayHint == null || relayHint.isEmpty)
      ? inspiredByPTagRelayHint
      : relayHint;
  return ['p', pubkeyHex, relay, inspiredByPTagMarker];
}

/// Appends the NIP-27 content reference crediting the inspired-by creator.
///
/// Only the first creator can be named: the parser that reads this back is
/// anchored to a single trailing `nostr:` reference, so a second one would
/// break attribution for every reader, including us. The rest are credited by
/// the `inspired-by` p-tags instead.
String withInspiredByContentReference(String content, Iterable<String> npubs) {
  for (final npub in npubs) {
    final trimmed = npub.trim();
    if (trimmed.isEmpty) continue;
    final suffix = '\n\nInspired by nostr:$trimmed';
    return content.isEmpty ? suffix.trim() : '$content$suffix';
  }
  return content;
}

/// Builds a factual reused-clip credit `p` tag for [pubkeyHex].
List<String> buildClipSourceCreditPTag(String pubkeyHex, {String? relayHint}) {
  final relay = (relayHint == null || relayHint.isEmpty)
      ? inspiredByPTagRelayHint
      : relayHint;
  return ['p', pubkeyHex, relay, clipSourceCreditTagMarker];
}

/// Builds factual reused-clip credit `a` tags.
List<List<String>> buildClipSourceCreditATags({
  required Iterable<ClipSourceCredit> clipSourceCredits,
  String? selfPubkey,
}) {
  final self = selfPubkey?.trim().toLowerCase();
  final seen = <String>{};

  return [
    for (final credit in clipSourceCredits)
      if (credit.addressableId case final addressableId?)
        if (addressableId.isNotEmpty &&
            credit.authorPubkey.trim().toLowerCase() != self &&
            seen.add(addressableId.toLowerCase()))
          [
            'a',
            addressableId,
            credit.relayUrl ?? AppConstants.defaultRelayUrl,
            clipSourceCreditTagMarker,
          ],
  ];
}

/// Resolves the inspired-by creator hex pubkeys carried by a publish.
///
/// [addressableId] is the `34236:<pubkey>:<dTag>` coordinate of the
/// inspiring video; [npub] is the NIP-27 person reference. Both can be
/// present at publish time because the audio-reuse flow auto-populates the
/// video reference independently of the person picker, so the result can
/// contain the video's creator alongside every picked one.
///
/// Malformed coordinates and undecodable npubs are skipped rather than
/// surfaced — attribution display does not depend on this resolution, and a
/// p-tag with an invalid value must never be published. Results are
/// normalized to lowercase hex and deduplicated.
Set<String> resolveInspiredByCreatorHexes({
  String? addressableId,
  Iterable<String> npubs = const [],
}) {
  final hexes = <String>{};

  if (addressableId != null) {
    final candidate = InspiredByInfo(
      addressableId: addressableId,
    ).creatorPubkey.trim().toLowerCase();
    if (NostrHexUtils.isValidPubkey(candidate)) {
      hexes.add(candidate);
    }
  }

  for (final npub in npubs) {
    final decoded = npubToHexOrNull(npub)?.trim().toLowerCase();
    if (decoded != null && NostrHexUtils.isValidPubkey(decoded)) {
      hexes.add(decoded);
    }
  }

  return hexes;
}

/// Builds inspired-by-marked p-tags for the creator(s) referenced by a
/// publish, so they are notifiable (per NIP-27, a content mention without a
/// matching p tag does not notify).
///
/// Skips the publisher's own pubkey ([selfPubkey] — reusing your own sound
/// auto-populates the video reference with yourself) and any pubkey already
/// carried by a `p` tag in [existingTags], so collaborator, caption-mention,
/// and reply-threading tags keep the single-p-tag-per-pubkey invariant.
List<List<String>> buildInspiredByPTags({
  required List<List<String>> existingTags,
  String? addressableId,
  Iterable<String> npubs = const [],
  String? relayHint,
  String? selfPubkey,
}) {
  final hexes = resolveInspiredByCreatorHexes(
    addressableId: addressableId,
    npubs: npubs,
  );
  if (hexes.isEmpty) return const [];

  final self = selfPubkey?.trim().toLowerCase();
  final existing = {
    for (final tag in existingTags)
      if (tag.length >= 2 && tag[0] == 'p') tag[1].trim().toLowerCase(),
  };

  return [
    for (final hex in hexes)
      if (hex != self && !existing.contains(hex))
        buildInspiredByPTag(hex, relayHint: relayHint),
  ];
}

/// Builds clip-source-marked p-tags for factual reused-clip credits.
List<List<String>> buildClipSourceCreditPTags({
  required List<List<String>> existingTags,
  required Iterable<ClipSourceCredit> clipSourceCredits,
  String? selfPubkey,
}) {
  final self = selfPubkey?.trim().toLowerCase();
  final existing = {
    for (final tag in existingTags)
      if (tag.length >= 2 && tag[0] == 'p') tag[1].trim().toLowerCase(),
  };
  final seen = <String>{};

  return [
    for (final credit in clipSourceCredits)
      if (seen.add(credit.authorPubkey.trim().toLowerCase()))
        if (credit.authorPubkey.trim().toLowerCase() != self &&
            !existing.contains(credit.authorPubkey.trim().toLowerCase()) &&
            NostrHexUtils.isValidPubkey(
              credit.authorPubkey.trim().toLowerCase(),
            ))
          buildClipSourceCreditPTag(
            credit.authorPubkey.trim().toLowerCase(),
            relayHint: credit.relayUrl,
          ),
  ];
}
