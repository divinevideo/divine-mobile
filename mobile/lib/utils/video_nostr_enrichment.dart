import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Filter;
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

const _proofCriticalRawTagKeys = <String>{
  'verification',
  'proofmode',
  'device_attestation',
  'c2pa_manifest_id',
  'identity_binding',
  'identity_verifier',
  'identity_portable',
};

/// Bounded, time-based throttle for REST rows that still need relay
/// enrichment after a previous lookup missed.
///
/// Misses are retried after [retryDelay] rather than suppressed forever, so a
/// transient relay miss/timeout can still recover on a later feed pass.
class NostrTagEnrichmentAttemptTracker {
  NostrTagEnrichmentAttemptTracker({
    this.retryDelay = const Duration(minutes: 5),
    this.maxEntries = 500,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration retryDelay;
  final int maxEntries;
  final DateTime Function() _now;
  final _nextAttemptAtById = <String, DateTime>{};

  bool shouldAttempt(String id) {
    final retryAt = _nextAttemptAtById[id.toLowerCase()];
    return retryAt == null || !_now().isBefore(retryAt);
  }

  void recordAttemptResults({
    required Iterable<String> attemptedIds,
    required Iterable<String> enrichedIds,
  }) {
    final now = _now();
    final enriched = {for (final id in enrichedIds) id.toLowerCase()};

    enriched.forEach(_nextAttemptAtById.remove);

    for (final id in attemptedIds) {
      final key = id.toLowerCase();
      if (!enriched.contains(key)) {
        _nextAttemptAtById[key] = now.add(retryDelay);
      }
    }

    _prune(now);
  }

  @visibleForTesting
  bool isThrottling(String id) =>
      _nextAttemptAtById.containsKey(id.toLowerCase());

  void _prune(DateTime now) {
    _nextAttemptAtById.removeWhere((_, retryAt) => !now.isBefore(retryAt));
    if (_nextAttemptAtById.length <= maxEntries) return;

    final entries = _nextAttemptAtById.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final overflow = _nextAttemptAtById.length - maxEntries;
    for (final entry in entries.take(overflow)) {
      _nextAttemptAtById.remove(entry.key);
    }
  }
}

/// Returns whether a REST-sourced video should be fetched from Nostr for the
/// full event tag set.
///
/// Funnelcake has returned both very compact rows with fewer than four tags
/// and semi-compact rows with ordinary media tags (`d`, `url`, `title`,
/// thumbnail) but no proof-critical tags. The old raw tag count check missed
/// the latter, which can hide Human-Made / ProofMode badges until the backend
/// includes compact proof summaries on all feed rows.
bool needsNostrTagEnrichment(VideoEvent video) {
  if (video.rawTags.length < 4) return true;
  if (video.proofSummary != null) return false;
  if (video.hasProofMode || video.hasBasicProof) return false;

  final rawTagKeys = video.rawTags.keys.toSet();
  if (rawTagKeys.intersection(_proofCriticalRawTagKeys).isNotEmpty) {
    return false;
  }

  final hasCoreMediaTags =
      rawTagKeys.contains('d') &&
      rawTagKeys.contains('title') &&
      (rawTagKeys.contains('url') ||
          rawTagKeys.contains('thumb') ||
          rawTagKeys.contains('thumbnail'));
  return hasCoreMediaTags;
}

/// Enrich REST API videos with full Nostr event data.
///
/// REST API responses may be missing fields that are present in the raw
/// Nostr event (rawTags for ProofMode/C2PA badges, dimensions, hashtags,
/// blurhash, etc.). This function fetches the full events from Nostr relays
/// by ID and merges any missing fields into the REST API videos.
///
/// Tag merge uses [mergeVideoRawTagsPrimaryWins] so Nostr wins on metadata
/// collisions but `views` (and thus [VideoEvent.totalLoops]) takes the
/// higher parsed count — Nostr must not zero out Funnelcake aggregates (#3384).
/// Nullable engagement ints use [mergeNullableEngagementMax] for the same
/// reason as profile relay/REST merge.
Future<List<VideoEvent>> enrichVideosWithNostrTags(
  List<VideoEvent> videos, {
  required NostrClient nostrService,
  String callerName = 'VideoEnrichment',
  NostrTagEnrichmentAttemptTracker? attemptTracker,
}) async {
  if (videos.isEmpty) return videos;

  final idsToEnrich = videos
      .where(needsNostrTagEnrichment)
      .where((v) => attemptTracker?.shouldAttempt(v.id) ?? true)
      .map((v) => v.id)
      .toList();

  if (idsToEnrich.isEmpty) return videos;

  try {
    // Batch query Nostr relays for the full events
    final filter = Filter(
      ids: idsToEnrich,
      kinds: NIP71VideoKinds.getAllVideoKinds(),
      limit: idsToEnrich.length,
    );
    final nostrEvents = await nostrService
        .queryEvents([filter])
        .timeout(const Duration(seconds: 5));

    if (nostrEvents.isEmpty) {
      attemptTracker?.recordAttemptResults(
        attemptedIds: idsToEnrich,
        enrichedIds: const [],
      );
      return videos;
    }

    // Build a lookup map: event ID -> parsed VideoEvent for enrichment
    final nostrEventsMap = <String, VideoEvent>{};
    var parsedCount = 0;
    var withBlurhash = 0;
    for (final event in nostrEvents) {
      try {
        final parsed = VideoEvent.fromNostrEvent(event, permissive: true);
        parsedCount++;
        if (parsed.blurhash != null) withBlurhash++;
        if (parsed.rawTags.isNotEmpty) {
          nostrEventsMap[parsed.id] = parsed;
        }
      } catch (_) {
        // Skip events that fail to parse
      }
    }
    // One line per batch, not per event. A bug report carries only the last
    // 50 entries of any level, and a 50-video batch logging per event took
    // ~40% of that window on #8300's report — crowding out the context the
    // report was filed to capture.
    Log.info(
      'enrichVideos: parsed $parsedCount/${nostrEvents.length} Nostr events, '
      '$withBlurhash with a blurhash, ${nostrEventsMap.length} with tags',
      name: callerName,
    );

    if (nostrEventsMap.isEmpty) {
      attemptTracker?.recordAttemptResults(
        attemptedIds: idsToEnrich,
        enrichedIds: const [],
      );
      return videos;
    }

    attemptTracker?.recordAttemptResults(
      attemptedIds: idsToEnrich,
      enrichedIds: nostrEventsMap.keys,
    );

    // Merge Nostr-parsed fields into REST API videos
    return videos.map((video) {
      final parsed = nostrEventsMap[video.id];
      if (parsed != null) {
        // Check if Nostr event has original Vine metric tags

        return video.copyWith(
          // Merge: Nostr wins on key collisions for canonical event tags;
          // `views` uses the higher of REST vs Nostr so API aggregates survive
          // enrichment (#3384) — see [mergeVideoRawTagsPrimaryWins].
          rawTags: mergeVideoRawTagsPrimaryWins(parsed.rawTags, video.rawTags),
          contentWarningLabels: video.contentWarningLabels.isEmpty
              ? parsed.contentWarningLabels
              : video.contentWarningLabels,
          // Enrich with all missing fields from Nostr event
          title: video.title ?? parsed.title,
          videoUrl: video.videoUrl ?? parsed.videoUrl,
          thumbnailUrl: video.thumbnailUrl ?? parsed.thumbnailUrl,
          duration: video.duration ?? parsed.duration,
          dimensions: video.dimensions ?? parsed.dimensions,
          mimeType: video.mimeType ?? parsed.mimeType,
          sha256: video.sha256 ?? parsed.sha256,
          fileSize: video.fileSize ?? parsed.fileSize,
          hashtags: video.hashtags.isEmpty ? parsed.hashtags : video.hashtags,
          publishedAt: video.publishedAt ?? parsed.publishedAt,
          vineId: video.vineId ?? parsed.vineId,
          addressableDTag: video.addressableDTag ?? parsed.addressableDTag,
          group: video.group ?? parsed.group,
          altText: video.altText ?? parsed.altText,
          blurhash: video.blurhash ?? parsed.blurhash,
          // Original metrics: take max so a Nostr zero/static tag cannot wipe
          // Funnelcake aggregates (same rule as ProfileFeed — #3384).
          originalLoops: mergeNullableEngagementMax(
            parsed.originalLoops,
            video.originalLoops,
          ),
          originalLikes: mergeNullableEngagementMax(
            parsed.originalLikes,
            video.originalLikes,
          ),
          originalComments: mergeNullableEngagementMax(
            parsed.originalComments,
            video.originalComments,
          ),
          originalReposts: mergeNullableEngagementMax(
            parsed.originalReposts,
            video.originalReposts,
          ),
          audioEventId: video.audioEventId ?? parsed.audioEventId,
          audioEventRelay: video.audioEventRelay ?? parsed.audioEventRelay,
          collaboratorPubkeys: video.collaboratorPubkeys.isEmpty
              ? parsed.collaboratorPubkeys
              : video.collaboratorPubkeys,
          inspiredByVideo: video.inspiredByVideo ?? parsed.inspiredByVideo,
          textTrackRef: video.textTrackRef ?? parsed.textTrackRef,
          textTrackRefs: video.textTrackRefs.isNotEmpty
              ? video.textTrackRefs
              : parsed.textTrackRefs,
          textTrackContent: video.textTrackContent ?? parsed.textTrackContent,
          nostrEventTags: video.nostrEventTags.isEmpty
              ? parsed.nostrEventTags
              : video.nostrEventTags,
          nostrLikeCount: mergeNullableEngagementMax(
            parsed.nostrLikeCount,
            video.nostrLikeCount,
          ),
          nostrCommentCount: mergeNullableEngagementMax(
            parsed.nostrCommentCount,
            video.nostrCommentCount,
          ),
          nostrRepostCount: mergeNullableEngagementMax(
            parsed.nostrRepostCount,
            video.nostrRepostCount,
          ),
        );
      }
      return video;
    }).toList();
  } catch (e) {
    attemptTracker?.recordAttemptResults(
      attemptedIds: idsToEnrich,
      enrichedIds: const [],
    );
    // Non-fatal: return original videos if enrichment fails
    Log.warning(
      '$callerName: Failed to enrich with Nostr tags: $e',
      name: callerName,
      category: LogCategory.video,
    );
    return videos;
  }
}

/// Fire-and-forget enrichment that calls [onEnriched] when complete.
///
/// Returns the original [videos] immediately. Enrichment runs in the
/// background; when it finishes, [onEnriched] is called with the
/// enriched list so the caller can update its state.
///
/// [onEnriched] is NOT called when enrichment fails, when all videos
/// already have full tags (nothing to enrich), or when the relay query
/// returns no events. Callers must not rely on it firing.
List<VideoEvent> enrichVideosInBackground(
  List<VideoEvent> videos, {
  required NostrClient nostrService,
  required void Function(List<VideoEvent> enrichedVideos) onEnriched,
  String callerName = 'VideoEnrichment',
  NostrTagEnrichmentAttemptTracker? attemptTracker,
}) {
  unawaited(
    enrichVideosWithNostrTags(
      videos,
      nostrService: nostrService,
      callerName: callerName,
      attemptTracker: attemptTracker,
    ).then((enriched) {
      // Only call back if enrichment actually changed something
      if (enriched != videos) {
        onEnriched(enriched);
      }
    }),
  );
  return videos;
}
