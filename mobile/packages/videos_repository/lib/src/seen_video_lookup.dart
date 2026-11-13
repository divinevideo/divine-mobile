// ABOUTME: Flutter-free seen-video lookup port used by feed freshness policy.
// ABOUTME: Lets app-layer seen history decide which videos feeds still show.

import 'package:models/models.dart';

/// How long a video the viewer has seen stays out of feeds.
///
/// Matches how long the app keeps seen history, so a feed never shows a video
/// the viewer has already seen while that history remembers it. Profiles and
/// search do not apply it: a seen video is always findable there.
const Duration seenVideoExclusionWindow = Duration(days: 365);

/// Consecutive pages a feed reads past when every video on them was seen.
///
/// A viewer who has seen everything recent would otherwise walk the whole
/// feed history in one load. Hitting this budget ends the read: the viewer is
/// caught up as far as the feed is willing to look.
const int maxSeenOnlyFeedPages = 8;

/// Function signature for checking whether a video was seen recently.
typedef WasVideoSeenRecently = bool Function(String videoId, {Duration within});

/// Function signature for waiting until the lookup has loaded persisted state.
typedef InitializeSeenVideoLookup = Future<void> Function();

/// Port for app-layer seen-video persistence.
///
/// The repository package stays Flutter-free; the app injects this with its
/// persisted seen-video service implementation.
class SeenVideoLookup {
  /// Creates a lookup from a recently-seen predicate.
  const SeenVideoLookup({required this.wasSeenRecently, this.initialize});

  /// Returns whether a video ID was seen within the supplied recency window.
  final WasVideoSeenRecently wasSeenRecently;

  /// Loads any persisted seen-video state needed by [wasSeenRecently].
  final InitializeSeenVideoLookup? initialize;

  /// Waits for [initialize] when the app layer provides one.
  Future<void> ensureInitialized() => initialize?.call() ?? Future.value();
}

/// Filters out videos seen within [recencyWindow] entirely (drop, not demote).
///
/// Feeds use it so a video the viewer has already seen does not come back
/// while they browse. Returns all candidates if none were seen. By default it
/// also retains all candidates when every candidate was seen, so callers with a
/// finite candidate pool do not accidentally create an empty feed. Callers
/// that can fetch deeper may set [retainAllWhenAllSeen] to `false` and decide
/// how to recover from an empty filtered page themselves.
List<VideoEvent> filterOutRecentlySeenVideos(
  Iterable<VideoEvent> videos, {
  SeenVideoLookup? seenVideoLookup,
  Duration recencyWindow = seenVideoExclusionWindow,
  bool retainAllWhenAllSeen = true,
}) {
  final candidates = videos is List<VideoEvent> ? videos : videos.toList();
  if (seenVideoLookup == null || candidates.isEmpty) return candidates;

  final filtered = <VideoEvent>[];
  var dropped = 0;
  for (final video in candidates) {
    if (video.id.isNotEmpty &&
        seenVideoLookup.wasSeenRecently(video.id, within: recencyWindow)) {
      dropped++;
    } else {
      filtered.add(video);
    }
  }
  // If we would drop everything, return original to avoid empty feed
  // (caller can decide to deep-fetch instead).
  if (retainAllWhenAllSeen &&
      filtered.isEmpty &&
      dropped > 0 &&
      candidates.isNotEmpty) {
    return candidates;
  }
  return filtered;
}
