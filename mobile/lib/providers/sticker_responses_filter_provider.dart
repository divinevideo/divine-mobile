// ABOUTME: The filter an Add yours or replies sticker's responses pass through,
// ABOUTME: as the feeds filter, and the warnings on a creator's own replies.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/sticker_responses/sticker_responses_cubit.dart';
import 'package:openvine/blocs/video_replies/video_replies_cubit.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/nsfw_content_filter.dart';

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

/// Puts on each of a creator's video replies the warnings their content
/// settings call for, leaving none out: their replies page lists every reply
/// so they can hide it, and blurs one the settings warn about or would hide.
///
/// Rebuilt when the account or its content settings change.
final repliesWarningsProvider = Provider<RepliesWarnings>((ref) {
  ref
    ..watch(currentAuthStateProvider)
    ..watch(contentFilterVersionProvider);
  final authService = ref.watch(authServiceProvider);
  final labels = createNsfwReviewLabels(
    ref.watch(contentFilterServiceProvider),
    moderationLabelService: ref.watch(moderationLabelServiceProvider),
    viewerPubkey: () => authService.currentPublicKeyHex,
  );
  return (replies) => [
    for (final reply in replies) reply.copyWith(warnLabels: labels(reply)),
  ];
});

/// Whether the creator's content settings would hide a reply. Their replies
/// page still lists it, blurred, so they can hide it, but never plays it:
/// some of those categories are locked to hide for every account, and others
/// until the account is verified as an adult.
///
/// Rebuilt when the account, its content settings or its adult verification
/// change.
final repliesHiddenBySettingsProvider = Provider<bool Function(VideoEvent)>((
  ref,
) {
  ref
    ..watch(currentAuthStateProvider)
    ..watch(contentFilterVersionProvider)
    ..watch(adultContentVerificationVersionProvider);
  final authService = ref.watch(authServiceProvider);
  return createNsfwFilter(
    ref.watch(contentFilterServiceProvider),
    moderationLabelService: ref.watch(moderationLabelServiceProvider),
    viewerPubkey: () => authService.currentPublicKeyHex,
  );
});
