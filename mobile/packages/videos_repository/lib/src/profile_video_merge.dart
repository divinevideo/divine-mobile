// ABOUTME: Cross-source merge policy for author/profile feeds (#3384).
// ABOUTME: Canonical owner of the REST-count-wins / max-merge rules so the
// ABOUTME: repository's author-feed composition and the app-layer profile
// ABOUTME: code share one implementation.

import 'dart:math' as math;

import 'package:models/models.dart';
import 'package:videos_repository/src/video_merge_helpers.dart';

/// Canonical dedup key for an addressable profile/author video.
///
/// Keys on `pubkey:stableId` (lowercased) so the same addressable video from
/// the REST source and the relay/Nostr source collapses to one entry.
String canonicalProfileFeedVideoKey(VideoEvent video) =>
    '${video.pubkey}:${video.stableId}'.toLowerCase();

/// Merges two [VideoEvent]s for the same addressable video, applying the
/// #3384 REST-count-wins / max-merge policy.
///
/// The "primary" copy is the newer one (greater `createdAt`; ties broken by the
/// smaller `id`). Metadata scalars take primary-wins (`primary ?? secondary`);
/// list fields take primary-if-non-empty; every engagement counter takes the
/// per-counter max ([mergeNullableEngagementMax]); raw tags merge primary-wins
/// except `views` and `unique_viewers`, which take the higher parsed count
/// ([mergeVideoRawTagsPrimaryWins]). When neither copy carries a `publishedAt`,
/// the merged `createdAt`/`timestamp` preserve the older value so re-merging is
/// stable.
VideoEvent mergeProfileFeedVideos(VideoEvent existing, VideoEvent incoming) {
  final incomingIsNewer =
      incoming.createdAt > existing.createdAt ||
      (incoming.createdAt == existing.createdAt &&
          incoming.id.compareTo(existing.id) < 0);
  final primary = incomingIsNewer ? incoming : existing;
  final secondary = incomingIsNewer ? existing : incoming;

  final primaryHasPublishedAt =
      primary.publishedAt != null && primary.publishedAt!.isNotEmpty;
  final secondaryHasPublishedAt =
      secondary.publishedAt != null && secondary.publishedAt!.isNotEmpty;
  final preserveOriginalTimestamp =
      !primaryHasPublishedAt && !secondaryHasPublishedAt;

  return primary.copyWith(
    createdAt: preserveOriginalTimestamp
        ? math.min(primary.createdAt, secondary.createdAt)
        : primary.createdAt,
    timestamp: preserveOriginalTimestamp
        ? (primary.timestamp.isBefore(secondary.timestamp)
              ? primary.timestamp
              : secondary.timestamp)
        : primary.timestamp,
    publishedAt: primaryHasPublishedAt
        ? primary.publishedAt
        : secondary.publishedAt,
    rawTags: mergeVideoRawTagsPrimaryWins(primary.rawTags, secondary.rawTags),
    contentWarningLabels: primary.contentWarningLabels.isNotEmpty
        ? primary.contentWarningLabels
        : secondary.contentWarningLabels,
    title: primary.title ?? secondary.title,
    videoUrl: primary.videoUrl ?? secondary.videoUrl,
    thumbnailUrl: primary.thumbnailUrl ?? secondary.thumbnailUrl,
    duration: primary.duration ?? secondary.duration,
    dimensions: primary.dimensions ?? secondary.dimensions,
    mimeType: primary.mimeType ?? secondary.mimeType,
    sha256: primary.sha256 ?? secondary.sha256,
    fileSize: primary.fileSize ?? secondary.fileSize,
    hashtags: primary.hashtags.isNotEmpty
        ? primary.hashtags
        : secondary.hashtags,
    vineId: primary.vineId ?? secondary.vineId,
    addressableDTag: primary.addressableDTag ?? secondary.addressableDTag,
    group: primary.group ?? secondary.group,
    altText: primary.altText ?? secondary.altText,
    blurhash: primary.blurhash ?? secondary.blurhash,
    originalLoops: mergeNullableEngagementMax(
      primary.originalLoops,
      secondary.originalLoops,
    ),
    originalLikes: mergeNullableEngagementMax(
      primary.originalLikes,
      secondary.originalLikes,
    ),
    originalComments: mergeNullableEngagementMax(
      primary.originalComments,
      secondary.originalComments,
    ),
    originalReposts: mergeNullableEngagementMax(
      primary.originalReposts,
      secondary.originalReposts,
    ),
    audioEventId: primary.audioEventId ?? secondary.audioEventId,
    audioEventRelay: primary.audioEventRelay ?? secondary.audioEventRelay,
    collaboratorPubkeys: primary.collaboratorPubkeys.isNotEmpty
        ? primary.collaboratorPubkeys
        : secondary.collaboratorPubkeys,
    inspiredByVideo: primary.inspiredByVideo ?? secondary.inspiredByVideo,
    textTrackRef: primary.textTrackRef ?? secondary.textTrackRef,
    textTrackLang: primary.textTrackLang ?? secondary.textTrackLang,
    textTrackRefs: primary.textTrackRefs.isNotEmpty
        ? primary.textTrackRefs
        : secondary.textTrackRefs,
    textTrackContent:
        primary.textTrackContent ??
        ((primary.textTrackRef?.isNotEmpty ?? false) ||
                primary.textTrackRefs.isNotEmpty
            ? null
            : secondary.textTrackContent),
    nostrEventTags: primary.nostrEventTags.isNotEmpty
        ? primary.nostrEventTags
        : secondary.nostrEventTags,
    authorName: primary.authorName ?? secondary.authorName,
    authorAvatar: primary.authorAvatar ?? secondary.authorAvatar,
    nostrLikeCount: mergeNullableEngagementMax(
      primary.nostrLikeCount,
      secondary.nostrLikeCount,
    ),
    nostrCommentCount: mergeNullableEngagementMax(
      primary.nostrCommentCount,
      secondary.nostrCommentCount,
    ),
    nostrRepostCount: mergeNullableEngagementMax(
      primary.nostrRepostCount,
      secondary.nostrRepostCount,
    ),
  );
}

/// Dedup-merges [current] and [incoming] into one list, applying
/// [mergeProfileFeedVideos] when both carry the same addressable video, then
/// sorts newest-first by published/created time (ties broken by `id`).
///
/// Does NOT apply NIP-09 tombstone filtering — that is a session-scoped,
/// relay-source concern owned by the app layer (the profile cubit), kept out
/// of this Flutter-free package.
List<VideoEvent> mergeProfileFeedVideoLists(
  List<VideoEvent> current,
  List<VideoEvent> incoming,
) {
  final byKey = <String, VideoEvent>{};

  for (final video in current) {
    byKey[canonicalProfileFeedVideoKey(video)] = video;
  }

  for (final video in incoming) {
    final key = canonicalProfileFeedVideoKey(video);
    final existing = byKey[key];
    byKey[key] = existing == null
        ? video
        : mergeProfileFeedVideos(existing, video);
  }

  return byKey.values.toList()..sort(compareProfileFeedVideos);
}

/// Newest-first comparator for profile feed videos: orders by the published
/// timestamp (falling back to `createdAt`), with ties broken by ascending `id`.
int compareProfileFeedVideos(VideoEvent a, VideoEvent b) {
  final timestampComparison = _publishedSortKey(
    b,
  ).compareTo(_publishedSortKey(a));
  if (timestampComparison != 0) return timestampComparison;
  return a.id.compareTo(b.id);
}

int _publishedSortKey(VideoEvent video) {
  final publishedAt = video.publishedAt;
  if (publishedAt != null && publishedAt.isNotEmpty) {
    final parsed = int.tryParse(publishedAt);
    if (parsed != null) return parsed;
  }
  return video.createdAt;
}
