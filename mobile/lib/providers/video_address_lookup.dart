// ABOUTME: Looks up the coordinate of the addressable video each event id is
// ABOUTME: a version of, for bookmarks and lists saved before #7135.

import 'package:videos_repository/videos_repository.dart';

/// Maps each of [eventIds] to the `kind:pubkey:d-tag` coordinate of the video
/// it is a version of, as [videosRepository] finds them.
///
/// Ids that are not addressable videos, or that cannot be found, are left
/// out. Bookmarks and curated lists use it to recognise an item saved as the
/// event id of an older version as the video it was edited into (#7135).
Future<Map<String, String>> lookUpVideoAddresses(
  VideosRepository videosRepository,
  List<String> eventIds,
) async {
  final videos = await videosRepository.getVideosByIds(
    eventIds,
    hydrateBulkStats: false,
    includeFeedShape: false,
  );
  return {for (final video in videos) video.id: ?video.addressableId};
}
