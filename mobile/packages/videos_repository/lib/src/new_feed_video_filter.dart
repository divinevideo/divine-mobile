import 'package:models/models.dart';

/// Maximum videos from one creator in a displayed New feed window.
const newFeedVideosPerCreator = 2;

/// Keeps the first [newFeedVideosPerCreator] videos per public key,
/// preserving source order.
///
/// Apply after visibility filtering and deduplication, across the complete
/// displayed window rather than independently to each fetched page. Repository
/// pages and pagination cursors remain unfiltered.
List<VideoEvent> filterNewFeedVideos(Iterable<VideoEvent> videos) {
  final counts = <String, int>{};
  return videos.where((video) {
    final count = counts[video.pubkey] ?? 0;
    if (count >= newFeedVideosPerCreator) return false;
    counts[video.pubkey] = count + 1;
    return true;
  }).toList();
}
