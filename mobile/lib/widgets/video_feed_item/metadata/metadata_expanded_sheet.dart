// ABOUTME: Expanded video metadata bottom sheet opened by the info button.
// ABOUTME: Header (date + title + badges + description + tags), stats,
// ABOUTME: actions, creator, collaborators, inspired by, remixes, reposted by,
// ABOUTME: sounds, links, verification. Actions run through the shared video
// ABOUTME: actions blocs.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_loops/video_loops_cubit.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/sticker_responses_filter_provider.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/proofmode_helpers.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/video_feed_item/actions/owner_video_actions_setup.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_feedback.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_actions_scope.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_actions_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_badges_row.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_links_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_remixes_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_sounds_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_stats_row.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_tags_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_user_chips.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_verification_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_remixes_cubit.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_reposters_cubit.dart';
import 'package:openvine/widgets/video_reply_parent_link.dart';
import 'package:time_formatter/time_formatter.dart';

/// Expanded metadata bottom sheet for a video.
///
/// Opened by the three-dot "more" button on the video overlay action column.
/// Uses [showVideoPausingVineBottomSheet] with `showHeader: false` so the
/// title scrolls with the content rather than being pinned in a header bar.
///
/// Metadata is read from [VideoEvent] and the existing
/// [VideoInteractionsBloc] in the widget tree. The action row, Remix
/// included, runs through a [VideoContentActionsBloc], plus an
/// [OwnerVideoActionsCubit] when the viewer owns the video, both created by
/// [show].
///
/// Matches Figma node `15675:27353` ("metadata-expanded").
class MetadataExpandedSheet extends StatelessWidget {
  @visibleForTesting
  const MetadataExpandedSheet({required this.video, super.key});

  final VideoEvent video;

  /// Opens the metadata sheet for the given [video].
  ///
  /// Captures the [VideoInteractionsBloc] from the caller's [context] and
  /// re-provides it inside the modal, since [showModalBottomSheet] creates
  /// a separate widget tree without access to the video feed's providers.
  ///
  /// Creates a [VideoRepostersCubit] to fetch reposter pubkeys from the
  /// relay, and a [VideoRemixesCubit] to read the videos that use a clip of
  /// [video], through the viewer's [stickerResponsesFilterProvider] as the
  /// sheet opens. Both are scoped to the modal and auto-closed on dismiss.
  ///
  /// Creates the [VideoContentActionsBloc] the action row runs through, and
  /// an [OwnerVideoActionsCubit] when the signed-in viewer owns
  /// [video].
  /// Ownership, and whether [video] is a remix of one of the viewer's videos,
  /// are decided once here, so the actions offered and their cubit cannot
  /// disagree if auth changes while the sheet is open.
  static Future<void> show(BuildContext context, VideoEvent video) {
    final interactionsBloc = context.read<VideoInteractionsBloc>();
    final loopCounts = context.read<VideoLoopsCubit?>();
    final container = ProviderScope.containerOf(context, listen: false);
    final repostsRepository = container.read(repostsRepositoryProvider);
    final videoResponsesRepository = container.read(
      videoResponsesRepositoryProvider,
    );
    final remixesFilter = container.read(stickerResponsesFilterProvider);
    final viewerPubkey = signedInViewerPubkey(container);
    final isOwnVideo = isVideoByViewer(video, viewerPubkey);
    final isRemixOfViewers = isRemixOfViewersVideo(video, viewerPubkey);

    return context.showVideoPausingVineBottomSheet<void>(
      showHeader: false,
      initialChildSize: 0.7,
      buildScrollBody: (scrollController) => MultiBlocProvider(
        providers: [
          BlocProvider<VideoInteractionsBloc>.value(value: interactionsBloc),
          if (loopCounts != null)
            BlocProvider<VideoLoopsCubit>.value(value: loopCounts),
          BlocProvider<VideoRepostersCubit>(
            create: (_) => VideoRepostersCubit(
              repostsRepository: repostsRepository,
              videoId: video.id,
              addressableId: video.addressableId,
            ),
          ),
          BlocProvider<VideoRemixesCubit>(
            create: (_) => VideoRemixesCubit(
              videoResponsesRepository: videoResponsesRepository,
              addressableId: video.addressableId,
              filter: remixesFilter,
            ),
          ),
          if (isOwnVideo)
            BlocProvider<OwnerVideoActionsCubit>(
              create: (_) => createOwnerVideoActionsCubit(container),
            ),
        ],
        child: VideoContentActionsScope(
          video: video,
          child: VideoContentActionsFeedbackListener(
            keepBookmarkResultsOpen: true,
            child: _MetadataContent(
              video: video,
              scrollController: scrollController,
              isOwnVideo: isOwnVideo,
              isRemixOfViewersVideo: isRemixOfViewers,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _MetadataContent(video: video);
  }
}

/// Scrollable content for the metadata sheet.
///
/// When used inside [MetadataExpandedSheet.show], receives a
/// [scrollController] from [VineBottomSheet]'s [DraggableScrollableSheet].
/// When used directly in tests, scrolls freely without a controller.
class _MetadataContent extends StatelessWidget {
  const _MetadataContent({
    required this.video,
    this.scrollController,
    this.isOwnVideo = false,
    this.isRemixOfViewersVideo = false,
  });

  final VideoEvent video;
  final ScrollController? scrollController;
  final bool isOwnVideo;
  final bool isRemixOfViewersVideo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      children: [
        _OverviewSection(video: video),
        VideoReplyParentLink(
          video: video,
          variant: VideoReplyParentLinkVariant.metadata,
        ),
        MetadataStatsRow(video: video),
        MetadataActionsSection(
          video: video,
          isOwnVideo: isOwnVideo,
          isRemixOfViewersVideo: isRemixOfViewersVideo,
        ),
        MetadataCreatorSection(pubkey: video.pubkey),
        MetadataCollaboratorsSection(video: video),
        MetadataInspiredBySection(video: video),
        MetadataRemixesSection(video: video),
        MetadataRepostedBySection(video: video),
        MetadataSoundsSection(video: video),
        MetadataLinksSection(video: video),
        MetadataVerificationSection(video: video),
      ],
    );
  }
}

/// First content section: posted date, title, badges, description, tags.
///
/// Mirrors the Figma frame hierarchy (`15675:27356`):
/// - Outer column with 16 px gap between date, title cluster, and tags.
/// - Inner title cluster (8 px gap): title, badges row, description.
/// - When enabled, the date renders independently of title/description so
///   classic Vine archives without captions still show their original
///   publish year.
///
/// The separator line between the sheet's drag-handle chrome and this
/// section comes from `VineBottomSheet` itself when `showHeaderDivider`
/// is true; this widget contributes only the scroll-body content.
///
/// The visible date drops the localized "Posted on" prefix to match
/// the Figma copy; the prefix lives on the [Semantics] label so
/// screen readers still announce it.
///
/// The date is shown only when the viewer asked for publish dates
/// ([StatsVisibilityPreferences.showPublishedDate], off by default).
class _OverviewSection extends ConsumerWidget {
  const _OverviewSection({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsVisibility = ref.watch(statsVisibilityPreferencesProvider);

    return ListenableBuilder(
      listenable: statsVisibility,
      builder: (context, _) {
        final l10n = context.l10n;
        final title = video.captionTitle;
        final description = video.chipCaptionDescription;

        final formattedDate =
            !statsVisibility.showPublishedDate || video.hasUnknownOriginalDate
            ? null
            : TimeFormatter.formatLongDate(
                int.tryParse(video.publishedAt ?? '') ?? video.createdAt,
                locale: Localizations.localeOf(context).toString(),
              );
        final semanticDate = formattedDate == null
            ? null
            : l10n.metadataPostedDateSemantics(formattedDate);

        final hasTitle = title != null && title.isNotEmpty;
        final hasDescription = description.isNotEmpty;
        final hasBadges =
            video.isClassicVine ||
            video.shouldShowProofModeBadge ||
            video.shouldShowNotDivineBadge;
        final hasTags =
            video.categories.isNotEmpty || video.displayableHashtags.isNotEmpty;

        final titleCluster = <Widget>[
          if (hasTitle)
            LinkifiedText(
              text: title,
              style: VineTheme.headlineSmallFont(
                color: context.vineColors.primaryText,
              ),
              linkStyle:
                  VineTheme.headlineSmallFont(
                    color: context.vineColors.link,
                  ).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: context.vineColors.link,
                  ),
              mentionStyle:
                  VineTheme.headlineSmallFont(
                    color: context.vineColors.link,
                  ).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: context.vineColors.link,
                  ),
              mentionProfilePubkeys: video.mentionedPubkeys,
              dismissModalBeforeNavigation: true,
            ),
          if (hasBadges) MetadataBadgesRow(video: video),
          if (hasDescription)
            LinkifiedText(
              text: description,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.onSurfaceVariant,
              ),
              mentionProfilePubkeys: video.mentionedPubkeys,
              dismissModalBeforeNavigation: true,
            ),
        ];

        // ⚠ LOAD-BEARING bottom padding. 16 px (vs 20 px on top) only
        // when tags are present — compensates for the hashtag chips' 4 px
        // invisible tap-target padding below the last visible chip row so
        // the section's visible bottom gap stays 20 px. One of three
        // constants that conspire to keep the visible chip 40 dp tall
        // while giving every tap target 48 dp; see the full dependency
        // map in `MetadataTagsSection.build`
        // (`metadata_tags_section.dart`). Changing this requires the
        // other two as well.
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, hasTags ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (formattedDate != null)
                Semantics(
                  label: semanticDate,
                  child: ExcludeSemantics(
                    child: Text(
                      formattedDate,
                      style: VineTheme.labelSmallFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              if (formattedDate != null && titleCluster.isNotEmpty) ...[
                const SizedBox(height: 16),
              ],
              if (titleCluster.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: titleCluster,
                ),
              // ⚠ LOAD-BEARING 12 px (NOT 16). When content precedes the chip row,
              // the first chip row's 4 px invisible top padding stacks on this to
              // produce a visible 16 px gap. Sibling of the bottom-padding tweak
              // above; see `MetadataTagsSection` for the full dependency map.
              if (hasTags) ...[
                if (formattedDate != null || titleCluster.isNotEmpty)
                  const SizedBox(height: 12),
                MetadataTagsSection(video: video),
              ],
            ],
          ),
        );
      },
    );
  }
}
