// ABOUTME: Pure reconstruction and attestation for #8407 — rebuilding a group
// ABOUTME: conversation from the rumor tags left on its re-parented messages.

import 'dart:convert';

/// The facts one stored message contributes to rebuilding a destroyed room.
///
/// Deliberately a plain value type rather than a Drift row: the reconstruction
/// rules below are the part worth testing, and they need no database.
class RecoveryMessageFacts {
  /// Creates the facts for one message.
  const RecoveryMessageFacts({
    required this.id,
    required this.senderPubkey,
    required this.participants,
    this.replyToId,
    this.subject,
    this.createdAt = 0,
  });

  /// Rumor id of the message.
  final String id;

  /// Author of the message.
  final String senderPubkey;

  /// The room this message names — see [reconstructParticipants].
  final Set<String> participants;

  /// Rumor id this message replies to, if any.
  final String? replyToId;

  /// NIP-17 `subject` carried by this message, if any.
  final String? subject;

  /// Rumor `created_at`, used to pick the newest subject and preview.
  final int createdAt;
}

/// The participant set a single message says its room has.
///
/// NIP-17: *"The set of `pubkey` + `p` tags defines a chat room."* Both halves
/// are required — `buildGroupRumor` deliberately omits the sender's own pubkey
/// from the `p` tags (matching Amethyst), so the tags alone are always missing
/// exactly one member: the peer on a received row, us on a sent one.
///
/// Returns an empty set when [tagsJson] is null or unparseable. Callers read
/// the raw column rather than a parsed model precisely so those two cases stay
/// distinguishable from "tags present but no `p` entries".
Set<String> reconstructParticipants(String? tagsJson, String senderPubkey) {
  return {..._pTagsOf(tagsJson), senderPubkey};
}

Set<String> _pTagsOf(String? tagsJson) {
  if (tagsJson == null || tagsJson.isEmpty) return const {};
  final Object? decoded;
  try {
    decoded = jsonDecode(tagsJson);
  } on FormatException {
    return const {};
  }
  if (decoded is! List) return const {};
  return {
    for (final tag in decoded)
      if (tag is List && tag.length >= 2 && tag[0] == 'p' && tag[1] is String)
        tag[1] as String,
  };
}

/// A stable key for a participant set.
///
/// Dart `Set` has no value equality, so a `Set<Set<String>>` never dedupes two
/// equal participant sets and a `Map<Set<String>, …>` never finds one again.
/// Every grouping in this file keys on the sorted join instead.
String canonicalParticipantKey(Iterable<String> participants) =>
    (participants.toSet().toList()..sort()).join(',');

/// Groups [messages] by the room each one names.
///
/// Keyed by [canonicalParticipantKey]; values keep arrival order.
Map<String, List<RecoveryMessageFacts>> bucketByRoom(
  Iterable<RecoveryMessageFacts> messages,
) {
  final buckets = <String, List<RecoveryMessageFacts>>{};
  for (final message in messages) {
    if (message.participants.isEmpty) continue;
    buckets
        .putIfAbsent(
          canonicalParticipantKey(message.participants),
          () => <RecoveryMessageFacts>[],
        )
        .add(message);
  }
  return buckets;
}

/// Whether [bucket] is positively attested as a real group rather than a 1:1 a
/// non-compliant client widened with a mention.
///
/// There is no *total* discriminator. A real group whose extra member never
/// sent anything is byte-identical on disk to a mention-inflated 1:1, so the
/// sender-count rule proposed in the never-merged #5478 cannot separate them
/// and neither can participant-set consistency. This returns `false` for those,
/// leaving them exactly as they are — recovering them would resurrect the
/// duplicate-conversation bug (#2740) that the destructive pass was written to
/// fix.
///
/// For a room without prior attestation, the required high-confidence signal is
/// **two or more distinct senders inside this exact room**. One mention names a
/// third party; it does not make them speak. Independent mentions by any two
/// senders can still produce the same bytes as a real room, so this is
/// deliberately conservative rather than conclusive.
///
/// A single-sender room without prior attestation is **deliberately skipped**,
/// even though some of those are real groups whose other members stayed quiet.
/// That case is indistinguishable from a mention-widened 1:1 (see above), and
/// this pass does not guess: a wrong restore is a user-visible phantom
/// conversation, whereas a skip leaves the thread exactly as the user already
/// sees it.
///
/// The reply-mention shape is kept as an additional **veto**, not as a grant.
/// #2740 records the real-world cause as "NIP-10 reply mentions", and a reply
/// carries an `e` tag; a message that widens the room *and* replies into a
/// strictly smaller one is a mention. It costs nothing to honour that even when
/// the sender count already said yes.
/// This veto applies to the whole bucket, so one such mention leaves even an
/// otherwise genuine room untouched rather than risking a destructive move.
///
/// [roomsByMessageId] must resolve reply parents across the *whole* source
/// conversation, not just this bucket — a mention-reply's parent lives in the
/// narrower room by definition.
/// Set [requireMultipleSenders] to false only when another source conversation
/// already attested this exact room; the reply-mention veto still applies.
bool isAttestedGroup(
  List<RecoveryMessageFacts> bucket,
  Map<String, Set<String>> roomsByMessageId, {
  bool requireMultipleSenders = true,
}) {
  if (bucket.isEmpty) return false;
  if (requireMultipleSenders &&
      bucket.map((m) => m.senderPubkey).toSet().length < 2) {
    return false;
  }
  return !bucket.any((m) => _repliesIntoASmallerRoom(m, roomsByMessageId));
}

bool _repliesIntoASmallerRoom(
  RecoveryMessageFacts message,
  Map<String, Set<String>> roomsByMessageId,
) {
  final parentId = message.replyToId;
  if (parentId == null) return false;
  final parentRoom = roomsByMessageId[parentId];
  if (parentRoom == null) return false;
  return isMentionOfWiderRoom(parentRoom, message.participants);
}

/// Whether a reply naming [room] answers a message held in [parentRoom], a
/// strictly smaller room that [room] fully contains.
///
/// That is the shape of a NIP-10 reply mention (#2740): the reply widens the
/// conversation it answers by tagging a third party, and does not start a
/// room. Shared by the receive path and the recovery pass so the two cannot
/// disagree about what a mention is.
bool isMentionOfWiderRoom(Set<String> parentRoom, Set<String> room) =>
    parentRoom.length < room.length && parentRoom.every(room.contains);

/// The newest `subject` in [bucket], or null if none carries one.
///
/// NIP-17: *"There is no need to send `subject` in every message. The newest
/// `subject` in the chat room is the subject of the conversation."*
String? newestSubject(List<RecoveryMessageFacts> bucket) {
  RecoveryMessageFacts? newest;
  for (final message in bucket) {
    final subject = message.subject;
    if (subject == null || subject.isEmpty) continue;
    if (newest == null || message.createdAt >= newest.createdAt) {
      newest = message;
    }
  }
  return newest?.subject;
}
