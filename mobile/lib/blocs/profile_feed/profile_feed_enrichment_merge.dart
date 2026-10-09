// ABOUTME: Nostr-enrichment merge policy for the profile/author feed (#3705).
// ABOUTME: Merges REST and Nostr metadata without clobbering newer relay events.

import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

/// Merges enriched copies over [sourceKeys] against [current]. A strictly newer
/// raw Nostr event supplies edit-sensitive metadata; otherwise current state
/// remains primary so relay updates that arrived during enrichment survive.
///
/// [removeTombstones] drops NIP-09-deleted events; it is injected because
/// tombstone state is a session-scoped, `VideoEventService`-owned concern that
/// this Flutter-free merge must not depend on directly.
List<VideoEvent> mergeProfileFeedEnrichment({
  required List<VideoEvent> current,
  required Set<String> sourceKeys,
  required List<VideoEvent> incoming,
  required List<VideoEvent> Function(List<VideoEvent>) removeTombstones,
}) {
  if (sourceKeys.isEmpty) {
    return removeTombstones(mergeProfileFeedVideoLists(current, incoming));
  }
  final currentByKey = {
    for (final video in current)
      if (sourceKeys.contains(canonicalProfileFeedVideoKey(video)))
        canonicalProfileFeedVideoKey(video): video,
  };
  final keepFromCurrent = current
      .where((v) => !sourceKeys.contains(canonicalProfileFeedVideoKey(v)))
      .toList();
  final mergedSource = incoming
      .map((video) {
        final currentVideo = currentByKey[canonicalProfileFeedVideoKey(video)];
        return currentVideo == null
            ? null
            : _mergeEnrichmentIntoCurrent(currentVideo, video);
      })
      .nonNulls
      .toList();
  return removeTombstones(
    mergeProfileFeedVideoLists(keepFromCurrent, mergedSource),
  );
}

VideoEvent _mergeEnrichmentIntoCurrent(
  VideoEvent current,
  VideoEvent enriched,
) {
  final enrichedIsNewer =
      current.eventCreatedAt != null &&
      enriched.eventCreatedAt != null &&
      enriched.eventCreatedAt! > current.eventCreatedAt!;
  final primary = enrichedIsNewer ? enriched : current;
  final secondary = enrichedIsNewer ? current : enriched;

  return primary.copyWith(
    publishedAt:
        (primary.publishedAt != null && primary.publishedAt!.isNotEmpty)
        ? primary.publishedAt
        : secondary.publishedAt,
    rawTags: mergeVideoRawTagsPrimaryWins(primary.rawTags, secondary.rawTags),
    contentWarningLabels: primary.contentWarningLabels.isNotEmpty
        ? primary.contentWarningLabels
        : secondary.contentWarningLabels,
    categories: primary.categories.isNotEmpty
        ? primary.categories
        : secondary.categories,
    moderationLabels: primary.moderationLabels.isNotEmpty
        ? primary.moderationLabels
        : secondary.moderationLabels,
    proofSummary: primary.proofSummary ?? secondary.proofSummary,
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
