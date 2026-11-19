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

/// The newest revision [repository] reads at [video]'s address, or null when
/// a relay did not answer in full or none holds a revision there. Either way
/// the reason is logged under [logName].
///
/// A video's copy in hand can be older than the relays' newest revision, and
/// a replacement built from it deletes whatever only the newer one carried.
///
/// Throws [ArgumentError] when [video] is not an addressable video.
Future<Event?> newestVideoRevision(
  VideosRepository repository,
  VideoEvent video, {
  required String logName,
}) async {
  final kind = video.eventKind ?? NIP71VideoKinds.addressableShortVideo;
  final address = '$kind:${video.pubkey}:${video.stableId}';
  switch (await repository.fetchLatestVideoRevision(address)) {
    case LatestVideoRevisionFound(:final event):
      return event;
    case LatestVideoRevisionUnknown():
      Log.warning(
        'Not republishing $address: a relay did not answer in full',
        name: logName,
        category: LogCategory.video,
      );
      return null;
    case LatestVideoRevisionAbsent():
      Log.warning(
        'Not republishing $address: no relay holds a revision of it',
        name: logName,
        category: LogCategory.video,
      );
      return null;
  }
}
