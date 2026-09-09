// ABOUTME: Owns per-author video buckets and memoized sorted profile views.
// ABOUTME: Keeps profile feed reads identity-stable until an author's bucket changes.

import 'package:models/models.dart';

/// Combines the cached and the incoming version of the same video.
typedef VideoMerge = VideoEvent Function(
  VideoEvent existing,
  VideoEvent updated,
);

/// Reports how many videos [AuthorVideoBuckets.removeWhere] dropped from one
/// author's bucket.
typedef BucketRemoved = void Function(String authorPubkey, int removedCount);

/// Per-author video buckets behind a memoized newest-first view.
///
/// Every mutating method invalidates the cached view for the author it
/// touched, so [videosFor] keeps returning the same list instance until that
/// author's bucket actually changes. Profile feeds read on every app-wide
/// `VideoEventService` notification, so a read must not sort or allocate.
class AuthorVideoBuckets {
  final Map<String, List<VideoEvent>> _buckets = {};
  final Map<String, List<VideoEvent>> _sortedViews = {};

  /// Whether a bucket exists for [authorPubkey], even when it holds no videos.
  bool contains(String authorPubkey) => _buckets.containsKey(authorPubkey);

  /// Replaces [authorPubkey]'s bucket with a copy of [videos].
  void seed(String authorPubkey, List<VideoEvent> videos) {
    _buckets[authorPubkey] = List.of(videos);
    _invalidate(authorPubkey);
  }

  /// Lazily yields [authorPubkey]'s videos in bucket order.
  ///
  /// Use this for membership checks; [videosFor] is the ordered read.
  Iterable<VideoEvent> videosForAuthorUnsorted(String authorPubkey) sync* {
    final videos = _buckets[authorPubkey];
    if (videos != null) yield* videos;
  }

  /// Lazily yields every cached video across all authors, in no useful order.
  Iterable<VideoEvent> get allVideos sync* {
    for (final videos in _buckets.values) {
      yield* videos;
    }
  }

  /// Returns [authorPubkey]'s videos newest first, as an unmodifiable list.
  ///
  /// The same instance comes back on every call until that author's bucket
  /// changes, so `identical` comparisons upstream stay meaningful. An author
  /// with no videos always yields the canonical empty list.
  List<VideoEvent> videosFor(String authorPubkey) {
    final bucket = _buckets[authorPubkey];
    if (bucket == null || bucket.isEmpty) return const [];

    return _sortedViews.putIfAbsent(authorPubkey, () {
      final sorted = List<VideoEvent>.from(bucket)..sort(_newestFirstThenId);
      return List<VideoEvent>.unmodifiable(sorted);
    });
  }

  /// Adds the [candidates] whose (case-insensitive) event id is not cached yet.
  ///
  /// Creates the bucket when it is missing. Returns how many were added.
  int backfillUniqueById(String authorPubkey, Iterable<VideoEvent> candidates) {
    final bucket = _buckets.putIfAbsent(authorPubkey, () => []);
    final seenBucketIds = {for (final video in bucket) video.id.toLowerCase()};
    var added = 0;

    for (final video in candidates) {
      if (seenBucketIds.add(video.id.toLowerCase())) {
        bucket.add(video);
        added++;
      }
    }

    if (added > 0) _invalidate(authorPubkey);
    return added;
  }

  /// Swaps the cached video with event id [videoId] for [updated].
  ///
  /// Returns whether a match was found.
  bool replaceById(String authorPubkey, String videoId, VideoEvent updated) {
    final bucket = _buckets[authorPubkey];
    if (bucket == null) return false;

    final index = bucket.indexWhere((video) => video.id == videoId);
    if (index == -1) return false;

    bucket[index] = updated;
    _invalidate(authorPubkey);
    return true;
  }

  /// Caches [video], deduplicating addressable (NIP-71) events by
  /// `(pubkey, vineId)` because each edit mints a new event id.
  ///
  /// An existing entry is overwritten only by a newer `createdAt`. New videos
  /// go to the front unless [isHistorical]. Creates the bucket when it is
  /// missing. Returns whether this added a video rather than updating one.
  bool addOrUpdateByVine(
    VideoEvent video, {
    required String authorPubkey,
    required bool isHistorical,
  }) {
    final bucket = _buckets.putIfAbsent(authorPubkey, () => []);
    final existingIndex = bucket.indexWhere(
      (existing) =>
          existing.vineId == video.vineId && existing.pubkey == video.pubkey,
    );

    if (existingIndex != -1) {
      if (video.createdAt > bucket[existingIndex].createdAt) {
        bucket[existingIndex] = video;
        _invalidate(authorPubkey);
      }
      return false;
    }

    if (isHistorical) {
      bucket.add(video);
    } else {
      bucket.insert(0, video);
    }
    _invalidate(authorPubkey);
    return true;
  }

  /// Merges [updated] into the cached video with the same `stableId` and
  /// `pubkey`, using [merge] to combine the two versions.
  ///
  /// Returns whether a match was found.
  bool replaceByStableId(
    String authorPubkey,
    VideoEvent updated, {
    required VideoMerge merge,
  }) {
    final bucket = _buckets[authorPubkey];
    if (bucket == null) return false;

    final index = bucket.indexWhere(
      (existing) =>
          existing.stableId == updated.stableId &&
          existing.pubkey == updated.pubkey,
    );
    if (index == -1) return false;

    bucket[index] = merge(bucket[index], updated);
    _invalidate(authorPubkey);
    return true;
  }

  /// Drops every video matching [shouldRemove] from every author's bucket.
  ///
  /// [onBucketRemoved] fires once per author that actually lost videos.
  /// Returns the total number removed.
  int removeWhere(
    bool Function(VideoEvent video) shouldRemove, {
    BucketRemoved? onBucketRemoved,
  }) {
    var removedTotal = 0;
    for (final entry in _buckets.entries) {
      final initialLength = entry.value.length;
      entry.value.removeWhere(shouldRemove);
      final removed = initialLength - entry.value.length;
      if (removed > 0) {
        removedTotal += removed;
        _invalidate(entry.key);
        onBucketRemoved?.call(entry.key, removed);
      }
    }
    return removedTotal;
  }

  void _invalidate(String authorPubkey) {
    _sortedViews.remove(authorPubkey);
  }
}

/// Newest first, breaking `createdAt` ties on descending event id.
///
/// The tie-break is what makes the memoized view reproducible: `List.sort` is
/// not stable, so videos sharing a second would otherwise land in an arbitrary
/// order that changes every time the view is rebuilt.
int _newestFirstThenId(VideoEvent a, VideoEvent b) {
  final createdAt = b.createdAt.compareTo(a.createdAt);
  if (createdAt != 0) return createdAt;
  return b.id.compareTo(a.id);
}
