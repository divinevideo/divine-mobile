// ABOUTME: Reads the newest revision of a video before a republish replaces it,
// ABOUTME: so the replacement is built from what the relays hold now (#11250).

import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart'
    show
        LatestVideoRevisionAbsent,
        LatestVideoRevisionFound,
        LatestVideoRevisionUnknown,
        VideosRepository;

/// The newest signed revision [repository] reads at [video]'s address.
/// Returns null when the repository is unavailable, the read does not settle
/// with a revision, or the opened revision wins under NIP-01 ordering when
/// its Nostr timestamp is known. The reason is logged under [logName].
///
/// A video's copy in hand can be older than the relays' newest revision, and
/// a replacement built from it deletes whatever only the newer one carried.
///
/// Throws [ArgumentError] when [video] is not an addressable video.
Future<Event?> newestVideoRevision(
  VideosRepository? repository,
  VideoEvent video, {
  required String logName,
}) async {
  final kind = video.eventKind ?? NIP71VideoKinds.addressableShortVideo;
  final address =
      video.addressableId ?? '$kind:${video.pubkey}:${video.stableId}';
  if (repository == null) {
    Log.warning(
      'Not republishing $address: no repository to read its newest revision',
      name: logName,
      category: LogCategory.video,
    );
    return null;
  }
  switch (await repository.fetchLatestVideoRevision(address)) {
    case LatestVideoRevisionFound(:final event):
      // A healthy relay can still hold an older revision, for example when
      // Funnelcake indexed a publish that has not reached this relay yet.
      // Compare only a known Nostr timestamp, since createdAt may be the
      // video's display date on an older cache row.
      final openedCreatedAt = video.eventCreatedAt;
      if (openedCreatedAt == null ||
          event.createdAt > openedCreatedAt ||
          (event.createdAt == openedCreatedAt &&
              event.id.compareTo(video.id) <= 0)) {
        return event;
      }
      Log.warning(
        'Not republishing $address: the relay revision predates the opened one',
        name: logName,
        category: LogCategory.video,
      );
      return null;
    case LatestVideoRevisionUnknown():
      Log.warning(
        'Not republishing $address: a relay did not answer in full',
        name: logName,
        category: LogCategory.video,
      );
      return null;
    case LatestVideoRevisionAbsent():
      Log.warning(
        'Not republishing $address: no signed revision was returned',
        name: logName,
        category: LogCategory.video,
      );
      return null;
  }
}
