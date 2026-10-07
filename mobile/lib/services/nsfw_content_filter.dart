// ABOUTME: Creates a VideoEventFilter for NSFW content filtering.
// ABOUTME: Bridges app-level ContentFilterService to repository-level filter.

import 'package:models/models.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/effective_content_labels.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:videos_repository/videos_repository.dart';

/// Creates a [VideoContentFilter] that filters NSFW content based on
/// per-category preferences from [contentFilterService].
///
/// Returns `true` (filter out) if any content label on the video maps to
/// [ContentFilterPreference.hide] in the user's preferences.
///
/// By default, adult categories (nudity, sexual, porn) are set to [hide],
/// so NSFW content is filtered unless the user explicitly changes preferences.
///
/// This allows the [VideosRepository] to filter NSFW content without
/// depending directly on app-level services.
VideoContentFilter createNsfwFilter(
  ContentFilterService contentFilterService, {
  ModerationLabelService? moderationLabelService,
  String? Function()? viewerPubkey,
}) {
  return (VideoEvent video) {
    final sources = _getContentLabelSources(
      video,
      moderationLabelService: moderationLabelService,
    );
    final decision = resolveEffectiveContentFilterDecision(
      sources: sources,
      moderationLabels: video.moderationLabels,
      contentFilterService: contentFilterService,
      isOwner: contentOwnerMatches(video.pubkey, viewerPubkey?.call()),
    );
    return decision.preference == ContentFilterPreference.hide;
  };
}

/// Creates a [VideoWarningLabelsResolver] that returns matched labels whose
/// preference is [ContentFilterPreference.warn].
VideoWarningLabelsResolver createNsfwWarnLabels(
  ContentFilterService contentFilterService, {
  ModerationLabelService? moderationLabelService,
  String? Function()? viewerPubkey,
}) {
  return (VideoEvent video) {
    final sources = _getContentLabelSources(
      video,
      moderationLabelService: moderationLabelService,
    );
    return resolveEffectiveContentFilterDecision(
      sources: sources,
      moderationLabels: video.moderationLabels,
      contentFilterService: contentFilterService,
      isOwner: contentOwnerMatches(video.pubkey, viewerPubkey?.call()),
    ).warnLabels;
  };
}

/// Extracts content label values from a [VideoEvent].
///
/// Uses creator self-labels, trusted kind-1985 labels, and hashtag fallbacks.
EffectiveContentLabelSources _getContentLabelSources(
  VideoEvent video, {
  ModerationLabelService? moderationLabelService,
}) {
  final sources = resolveEffectiveContentLabelSources(
    video,
    moderationLabelService: moderationLabelService,
  );
  final labels = [...sources.creator, ...sources.trusted];

  // If content-warning labels exist but none are recognized categories,
  // treat as nudity (conservative default). The fallback follows whoever
  // supplied the unrecognized labels, so a trusted labeler's label still hides
  // the creator's own video.
  if (labels.isNotEmpty &&
      labels.every((l) => ContentLabel.fromValue(l) == null)) {
    return (
      creator: [...sources.creator, if (sources.creator.isNotEmpty) 'nudity'],
      trusted: [...sources.trusted, if (sources.trusted.isNotEmpty) 'nudity'],
    );
  }
  return sources;
}
