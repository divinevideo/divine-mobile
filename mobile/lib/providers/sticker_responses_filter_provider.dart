// ABOUTME: The filter an Add yours or replies sticker's responses pass through:
// ABOUTME: the same blocks, mutes, deletions and content filters as the feeds.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/sticker_responses/sticker_responses_cubit.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_providers.dart';

/// Filters the responses an Add yours or replies sticker shows, and the feed
/// it opens, the way the feeds filter: blocks and mutes either way, deleted
/// videos, and the viewer's content filters. Each response that stays carries
/// the content warnings the viewer's settings call for, so the sticker blurs
/// it and the feed shows its warning.
///
/// Rebuilt whenever one of those policies changes, like
/// [curatedListThumbnailFilterProvider], so a sticker already on screen reads
/// its responses again under the new policy.
final stickerResponsesFilterProvider = Provider<StickerResponsesFilter>((ref) {
  ref
    ..watch(currentAuthStateProvider)
    ..watch(blocklistVersionProvider)
    ..watch(contentFilterVersionProvider)
    ..watch(divineHostFilterVersionProvider)
    ..watch(videoProvenanceFilterVersionProvider)
    ..watch(adultContentVerificationVersionProvider)
    ..watch(videoDeletionVersionProvider);
  final videoService = ref.watch(videoEventServiceProvider);
  final videos = ref.watch(videosRepositoryProvider);
  // Feed shape decides what a feed discovers, not what a sticker shows.
  return (responses) => videos.applyContentPreferences([
    for (final response in responses)
      if (!videoService.shouldHideVideo(response)) response,
  ], includeFeedShape: false);
});
