// ABOUTME: Picks the revision a video republish is built from: the newest
// ABOUTME: one read, or the signed opened copy when that read falls short.

import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_sdk/event.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart'
    show
        LatestVideoRevision,
        LatestVideoRevisionAbsent,
        LatestVideoRevisionFound,
        LatestVideoRevisionUnknown,
        VideoRevisionFloor;

/// The newest signed revision of [video] to build a republish from, or null
/// when there is none to trust. The reason is logged under [logName].
///
/// Returns what [readRevision] reads at [video]'s address unless it predates
/// the opened revision under NIP-01 ordering, or unless the read returned
/// nothing and did not complete. The opened revision is passed as the read's
/// floor when its timestamp is known, so a REST answer older than it, for
/// example when the API has not yet indexed this device's own latest
/// publish, sends the read on to the relays. When the revision read still
/// predates the opened one, or nothing was read, the signed copy of the
/// opened revision that [cachedEvent] holds is used instead, when it is at
/// the same address and validly signed. Returns null when the video has
/// no unambiguous address, the reader is unavailable, the read found the
/// address empty, the revision read has conflicting `d` tags, or neither
/// revision can be used.
///
/// A video's copy in hand can be older than the newest revision, and a
/// replacement built from it deletes whatever only the newer one carried.
Future<Event?> newestVideoRevision(
  Future<LatestVideoRevision> Function(
    String addressableId, {
    VideoRevisionFloor? notOlderThan,
  })?
  readRevision,
  VideoEvent video, {
  required String logName,
  Event? Function(String eventId)? cachedEvent,
}) async {
  final address = video.addressableId;
  if (address == null || _hasConflictingIdentifiers(video.nostrEventTags)) {
    Log.warning(
      'Not republishing video ${video.id}: no unambiguous video address',
      name: logName,
      category: LogCategory.video,
    );
    return null;
  }
  if (readRevision == null) {
    Log.warning(
      'Not republishing $address: no reader for its newest revision',
      name: logName,
      category: LogCategory.video,
    );
    return null;
  }
  // Compare only a known Nostr timestamp, since createdAt may be the video's
  // display date on an older cache row.
  final openedCreatedAt = video.eventCreatedAt;
  final floor = openedCreatedAt == null
      ? null
      : (createdAt: openedCreatedAt, id: video.id);
  switch (await readRevision(address, notOlderThan: floor)) {
    case LatestVideoRevisionFound(:final event):
      if (_hasConflictingIdentifiers(event.tags)) {
        Log.warning(
          'Not republishing $address: the newest revision ${event.id} has '
          'conflicting d tags',
          name: logName,
          category: LogCategory.video,
        );
        return null;
      }

      // The revision read can still be older than the opened one, for
      // example when neither Funnelcake nor any relay that answered has this
      // device's own latest publish yet.
      if (openedCreatedAt == null ||
          event.createdAt > openedCreatedAt ||
          (event.createdAt == openedCreatedAt &&
              event.id.compareTo(video.id) <= 0)) {
        Log.info(
          'Republishing $address from its newest revision ${event.id}',
          name: logName,
          category: LogCategory.video,
        );
        return event;
      }
      return _openedRevision(
        video,
        address,
        cachedEvent,
        logName: logName,
        why: 'the revision read, ${event.id}, predates the opened one',
      );
    case LatestVideoRevisionUnknown():
      return _openedRevision(
        video,
        address,
        cachedEvent,
        logName: logName,
        why: 'no revision was read and the relay read did not complete',
      );
    case LatestVideoRevisionAbsent():
      Log.warning(
        'Not republishing $address: no signed revision was returned',
        name: logName,
        category: LogCategory.video,
      );
      return null;
  }
}

/// The signed copy of the opened [video] that [cachedEvent] holds, when it
/// is that exact event at [address]; otherwise null. [why] says why the
/// opened revision is wanted.
Event? _openedRevision(
  VideoEvent video,
  String address,
  Event? Function(String eventId)? cachedEvent, {
  required String logName,
  required String why,
}) {
  final held = cachedEvent?.call(video.id);
  final refusal = switch (held) {
    null => 'no copy of the opened revision ${video.id} is held',
    _ when held.id != video.id =>
      'the held copy ${held.id} is not the opened revision ${video.id}',
    _
        when '${held.kind}:${held.pubkey}:${held.dTagValue}' != address ||
            _hasConflictingIdentifiers(held.tags) =>
      'the held copy of ${video.id} is not at exactly this address',
    _ when !held.isValid =>
      'the held copy of ${video.id} has content its id does not cover',
    _ when !(held.hasVerifiedSignature || held.isSigned) =>
      'the held copy of ${video.id} is not validly signed',
    _ => null,
  };
  if (held == null || refusal != null) {
    Log.warning(
      'Not republishing $address: $why, and ${refusal ?? 'no copy is held'}',
      name: logName,
      category: LogCategory.video,
    );
    return null;
  }
  Log.info(
    'Republishing $address from the opened revision ${video.id}: $why',
    name: logName,
    category: LogCategory.video,
  );
  return held;
}

// Model parsing and relay lookup can select different values from these tags.
bool _hasConflictingIdentifiers(List<List<String>> tags) {
  final identifiers = tags
      .where((tag) => tag.firstOrNull == 'd')
      .map((tag) => tag.length > 1 ? tag[1] : '')
      .toSet();
  return identifiers.length > 1;
}
