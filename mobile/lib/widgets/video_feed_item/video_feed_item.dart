// ABOUTME: Video feed item using individual controller architecture
// ABOUTME: Each video gets its own controller with automatic lifecycle management via Riverpod autoDispose
// ABOUTME: SCOPE: Non-feed detail use cases only (e.g. debug screens).
// ABOUTME: Feed surfaces must use PooledFullscreenVideoFeedScreen / FeedVideos instead.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/constants/og_beta_testers.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/community_content_label_provider.dart';
import 'package:openvine/providers/og_viner_cache_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/og_beta_badge.dart';
import 'package:openvine/widgets/og_viner_badge.dart';
import 'package:openvine/widgets/profile_badge_explanation_sheet.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/collaborator_avatar_row.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/inspired_by_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/list_attribution_chip.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart';
import 'package:openvine/widgets/video_feed_item/video_card_meta.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';
import 'package:openvine/widgets/video_reply_parent_link.dart';
import 'package:unified_logger/unified_logger.dart';

/// Size of the avatar block: the avatar plus the sliver of overflow the follow
/// badge has always drawn into. Also the height the author text is centred
/// against, so raising it to a 48dp target cannot shift it off the avatar.
const double _avatarClusterSize = 58;

class VideoOverlayPreviewData {
  const VideoOverlayPreviewData({
    required this.pubkey,
    required this.title,
    required this.description,
  });

  final String pubkey;
  final String title;
  final String description;
}

/// Video overlay actions widget with working functionality
class VideoOverlayActions extends ConsumerWidget {
  const VideoOverlayActions({
    required this.video,
    required this.isVisible,
    required this.isActive,
    super.key,
    this.subtitleLayer,
    this.hasBottomNavigation = true,
    this.contextTitle,
    this.isFullscreen = false,
    this.listSources,
    this.showListAttribution = false,
    this.isPreviewMode = false,
    this.showBottomGradient = true,
    this.showTopGradient = false,
    this.topOffset = 8.0,
    this.onInteracted,
  }) : previewData = null;

  const VideoOverlayActions.preview({
    required this.previewData,
    required this.isVisible,
    required this.isActive,
    super.key,
    this.subtitleLayer,
    this.hasBottomNavigation = true,
    this.contextTitle,
    this.isFullscreen = false,
    this.listSources,
    this.showListAttribution = false,
    this.isPreviewMode = true,
    this.showBottomGradient = true,
    this.showTopGradient = false,
    this.topOffset = 8.0,
    this.onInteracted,
  }) : video = null;

  final Widget? subtitleLayer;
  final VideoEvent? video;
  final VideoOverlayPreviewData? previewData;
  final bool isVisible;
  final bool isActive;
  final bool hasBottomNavigation;
  final String? contextTitle;
  final bool isFullscreen;
  final double topOffset;

  /// Displays the overlay in preview mode during video creation.
  /// When true, users can preview how their video will appear to other users
  /// before publishing.
  final bool isPreviewMode;

  /// Set of curated list IDs this video is from (for list attribution display).
  final Set<String>? listSources;

  /// Whether to show the list attribution chip below the author info.
  final bool showListAttribution;

  /// Whether to render the bottom darkening gradient behind the caption
  /// block. Disabled in preview / editor flows that have their own chrome.
  final bool showBottomGradient;

  /// Whether to render a symmetric top darkening gradient behind the
  /// app bar region. Useful on fullscreen overlays so the white title
  /// and back/More buttons stay readable over light video frames.
  /// Defaults to `false` — opt in per surface so the home feed (which
  /// doesn't have a transparent AppBar over the video) is unaffected.
  final bool showTopGradient;

  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVisible) return const SizedBox();
    final video = this.video;
    final previewData = this.previewData;
    final authorPubkey = previewData?.pubkey ?? video!.pubkey;
    // Watched purely for its invalidation. AuthService is not a ChangeNotifier
    // and authServiceProvider hands back a stable singleton, so watching it
    // (with or without select) never rebuilds on sign-in or account switch —
    // a card mounted while signed out would keep hiding its owner's counts.
    ref.watch(currentAuthStateProvider);
    final currentUserPubkey = ref.read(authServiceProvider).currentPublicKeyHex;
    final isOwnVideo =
        video != null &&
        currentUserPubkey != null &&
        currentUserPubkey == video.pubkey;
    final trimmedTitle = previewData != null
        ? UserProfile.sanitizeDisplayName(previewData.title).trim()
        : video?.displayTitle?.trim();
    final titleText = trimmedTitle == null || trimmedTitle.isEmpty
        ? null
        : trimmedTitle;
    final descriptionText = previewData != null
        ? UserProfile.sanitizeDisplayName(previewData.description).trim()
        : video!.displayContent.trim();

    // Check if there's meaningful text content to display
    final hasTextContent =
        descriptionText.isNotEmpty || (titleText?.isNotEmpty ?? false);

    // Shared by the title and the description, and on the description it is
    // attached twice: once to the semantics node that carries the label, once
    // to the detector that takes the real pointer.
    final openMetadata = video == null
        ? null
        : () {
            onInteracted?.call();
            MetadataExpandedSheet.show(context, video);
          };

    // In fullscreen mode, ensure badges clear the status bar icons
    // (battery, wifi, clock). viewPaddingOf may return 0 if a parent
    // widget (Scaffold, SafeArea) has already consumed the safe area.
    // Use the window's actual padding as a fallback minimum.
    final viewPaddingTop = MediaQuery.viewPaddingOf(context).top;
    final safeAreaTop = isFullscreen
        ? (viewPaddingTop > 0
              ? viewPaddingTop
              : MediaQuery.paddingOf(context).top > 0
              ? MediaQuery.paddingOf(context).top
              : 54.0) // Fallback for Dynamic Island iPhones
        : viewPaddingTop;

    // In fullscreen mode, match the home feed overlay's baseline:
    // 20 px above the safe-area bottom, with the action column flush to the
    // author row instead of 6 px below it. Other consumers
    // (video metadata preview, video editor preview) keep the legacy
    // 14 px offset and the `-6` action-column adjustment so their layouts
    // are unaffected.
    final bottomOffset = isFullscreen
        ? 20.0 + MediaQuery.viewPaddingOf(context).bottom
        : 14.0 + MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        // Top gradient overlay — sits behind the (transparent) app
        // bar so the white title / back button / More popover stay
        // readable over light video frames. Lives inside the body's
        // Stack so it overlays the video, NOT the app bar (Scaffold
        // paints the app bar above the body) and is wrapped in
        // [IgnorePointer] so tapping the gradient region falls
        // through to the video (or, in the top strip, to the
        // already-z-above app bar's controls).
        if (showTopGradient)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          VineTheme.backgroundColor.withValues(alpha: 0.35),
                          VineTheme.backgroundColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Bottom gradient overlay (sits below UI elements, only overlays video)
        if (showBottomGradient)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: FractionallySizedBox(
                widthFactor: 1.0,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height / 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          VineTheme.backgroundColor.withValues(alpha: 0.0),
                          VineTheme.backgroundColor.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Content warning badge below back button area
        if (video != null &&
            video.hasContentWarning &&
            !shouldShowContentWarningOverlay(
              contentWarningLabels: video.contentWarningLabels,
              warnLabels: video.warnLabels,
            ))
          PositionedDirectional(
            top: safeAreaTop + topOffset + 56,
            start: 16,
            child: GestureDetector(
              onTap: () => _showContentWarningDetails(
                context,
                ref,
                video.contentWarningLabels,
                isActive,
              ),
              child: _ContentWarningBadge(labels: video.contentWarningLabels),
            ),
          ),
        // Author info and video description overlay at bottom left.
        Positioned(
          bottom: bottomOffset,
          left: 16,
          right: 80, // Leave space for action buttons
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ?subtitleLayer,

                // Repost banner (if video is a repost)
                if (video != null &&
                    video.isRepost &&
                    video.reposterPubkey != null) ...[
                  VideoRepostHeader(reposterPubkey: video.reposterPubkey!),
                  const SizedBox(height: 8),
                ],
                // Author avatar and info row
                Consumer(
                  builder: (context, ref, _) {
                    final profile = ref
                        .watch(userProfileReactiveProvider(authorPubkey))
                        .value;
                    // Use embedded author data from REST API as fallback
                    // This avoids WebSocket profile fetches for videos
                    // that already have author_name/author_avatar embedded
                    final avatarUrl = profile?.picture ?? video?.authorAvatar;
                    final displayName =
                        profile?.bestDisplayName ??
                        video?.displayAuthorName ??
                        UserProfile.generatedNameFor(authorPubkey);
                    final isOgViner = ref.watch(
                      ogVinerCacheServiceProvider.select(
                        (service) => service.isOgViner(authorPubkey),
                      ),
                    );
                    final showCheckmark = shouldShowSpecialProfileCheckmark(
                      authorPubkey,
                    );
                    // The beta chit yields to both the checkmark and the OG
                    // Viner chit, so a name never carries two of them. The
                    // Viner rosters are disjoint by construction; many team
                    // accounts also appear on the beta roster.
                    final isOgBetaTester =
                        !isOgViner &&
                        !showCheckmark &&
                        isOgBetaTesterPubkey(authorPubkey);

                    void navigateToProfile() {
                      onInteracted?.call();
                      Log.info(
                        '👤 User tapped profile: videoId=${video?.id ?? "preview"}, authorPubkey=${pubkeyForLogs(authorPubkey)}',
                        name: 'VideoFeedItem',
                        category: LogCategory.ui,
                      );
                      final npub = normalizeToNpub(authorPubkey);
                      if (npub != null) {
                        context.push(OtherProfileScreen.pathForNpub(npub));
                      }
                    }

                    return Row(
                      children: [
                        // Avatar with follow button overlay
                        SizedBox(
                          width: _avatarClusterSize,
                          height: _avatarClusterSize,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Avatar (tappable to go to profile)
                              UserAvatar(
                                imageUrl: avatarUrl,
                                name: displayName,
                                size: 48,
                                semanticLabel:
                                    context.l10n.videoAuthorAvatarSemanticLabel,
                                onTap: navigateToProfile,
                              ),
                              // Follow button positioned at bottom-right of avatar
                              if (video != null)
                                PositionedDirectional(
                                  start: 31,
                                  top: 31,
                                  child: VideoFollowButton(
                                    pubkey: authorPubkey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // User name and loop count (tappable to go to profile)
                        Expanded(
                          child: Align(
                            // Aligned OUTSIDE the detector so the target hugs
                            // the author content. Inside it, the detector
                            // filled the whole Expanded, and an opaque hit box
                            // that wide swallowed the empty video to the right
                            // of a short name — taking double-tap-to-like and
                            // press-and-hold-to-peek with it.
                            alignment: AlignmentDirectional.centerStart,
                            child: GestureDetector(
                              // Opaque, so the target is tappable across its
                              // full height rather than only on the painted
                              // glyphs: deferring to the child leaves the 58dp
                              // node it advertises just 20dp of real target.
                              behavior: HitTestBehavior.opaque,
                              onTap: navigateToProfile,
                              // The name + meta column is intrinsically 44dp,
                              // which failed androidTapTargetGuideline (48) on
                              // device. Constrained to the avatar block and
                              // centred, so the text sits where it always has
                              // while the target clears 48dp. minHeight, not a
                              // fixed height, so it still grows with the system
                              // font scale (.claude/rules/accessibility.md);
                              // minWidth covers a display name too short to
                              // reach the minimum on its own.
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: kMinInteractiveDimension,
                                  minHeight: _avatarClusterSize,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      // Hugs the name and its badges, so the
                                      // detector above can hug in turn.
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Semantics(
                                            identifier: 'video_author_name',
                                            container: true,
                                            explicitChildNodes: true,
                                            label: context.l10n
                                                .videoAuthorSemanticLabel(
                                                  displayName,
                                                ),
                                            child: DivineHeartText(
                                              displayName,
                                              style: VineTheme.titleSmallFont(
                                                color: VineTheme.whiteText,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        if (showCheckmark)
                                          const SpecialProfileCheckmark(),
                                        if (isOgViner) const OgVinerBadge(),
                                        if (isOgBetaTester)
                                          OgBetaBadge(
                                            onTap: () =>
                                                showProfileBadgeExplanationSheet(
                                                  context,
                                                  ProfileBadgeExplanationType
                                                      .ogBetaTester,
                                                ),
                                          ),
                                      ],
                                    ),
                                    _VideoCardMetaLine(
                                      meta: resolveVideoCardMeta(
                                        video: video,
                                        isOwnVideo: isOwnVideo,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                // List attribution chip (shown when video is from subscribed curated list)
                if (video != null &&
                    showListAttribution &&
                    listSources != null &&
                    listSources!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final curatedListState = ref.watch(
                        curatedListsStateProvider,
                      );
                      final curatedListService = curatedListState.whenOrNull(
                        data: (_) => ref
                            .read(curatedListsStateProvider.notifier)
                            .service,
                      );

                      return ListAttributionChip(
                        listIds: listSources!,
                        listLookup: (listId) =>
                            curatedListService?.getListById(listId),
                        onListTap: (listId, listName) {
                          final list = curatedListService?.getListById(listId);
                          context.push(
                            CuratedListFeedScreen.pathForId(listId),
                            extra: CuratedListRouteExtra(
                              listName: listName,
                              videoIds: list?.videoEventIds,
                              authorPubkey: list?.pubkey,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
                // Video title and description (caption block).
                // Title and description render independently when present.
                if (hasTextContent) ...[
                  const SizedBox(
                    height: 2,
                  ), // 2px + 10px from avatar container = 12px total
                  // Title (when present)
                  if (titleText != null)
                    Semantics(
                      identifier: SemanticIds.videoTitle,
                      container: true,
                      explicitChildNodes: true,
                      button: true,
                      label: context.l10n.videoOverlayOpenMetadataFromTitle,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: openMetadata,
                        child: DivineHeartText(
                          titleText,
                          style: VineTheme.labelMediumFont(
                            color: VineTheme.whiteText,
                          ).copyWith(shadows: VineTheme.buttonShadows),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  // 4 px gap between title and description when both
                  // are present (matches the Figma caption spacing).
                  if (titleText != null && descriptionText.isNotEmpty)
                    const SizedBox(height: 4),
                  // Description (only when actual content exists — the
                  // title has its own row above, so no fallback here).
                  if (descriptionText.isNotEmpty)
                    Semantics(
                      identifier: 'video_description',
                      container: true,
                      explicitChildNodes: true,
                      button: true,
                      label:
                          context.l10n.videoOverlayOpenMetadataFromDescription,
                      // The action belongs on the node that carries the label.
                      // On the detector below it landed on an anonymous child:
                      // `LinkifiedText` splits into several spans once the text
                      // holds a hashtag, mention or URL, and then nothing merges
                      // up to name the tappable node. Plain text merges and
                      // passes, so this was data-dependent, not layout-dependent.
                      onTap: openMetadata,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Excluded so it cannot re-create the anonymous node
                        // the annotation above exists to name.
                        excludeFromSemantics: true,
                        onTap: openMetadata,
                        child: LinkifiedText(
                          text: descriptionText,
                          style: VineTheme.bodySmallFont(
                            color: VineTheme.whiteText,
                          ).copyWith(shadows: VineTheme.buttonShadows),
                          linkStyle: VineTheme.bodySmallFont(
                            color: VineTheme.whiteText,
                          ).copyWith(shadows: VineTheme.buttonShadows),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  // Collaborator avatar row (if video has collaborators)
                  if (video != null && video.hasCollaborators) ...[
                    const SizedBox(height: 4),
                    CollaboratorAvatarRow(video: video),
                  ],
                  if (video != null && video.isVideoReply) ...[
                    const SizedBox(height: 4),
                    VideoReplyParentLink(
                      video: video,
                      variant: VideoReplyParentLinkVariant.overlay,
                      onInteracted: onInteracted,
                    ),
                  ],
                  // Inspired-by attribution row (if video credits another creator)
                  if (video != null && video.hasInspiredBy) ...[
                    const SizedBox(height: 4),
                    InspiredByAttributionRow(video: video, isActive: isActive),
                  ],
                ],
                // Audio attribution row (all videos)
                const SizedBox(height: 4),
                if (video != null) AudioAttributionRow(video: video),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // Action buttons at bottom right.
        // In fullscreen mode the right inset tightens to 12 px to match
        // the trailing inset on the fullscreen app bar's More popover.
        // Other consumers (video metadata preview, video editor preview)
        // keep the legacy 16 px so their layouts are unaffected.
        PositionedDirectional(
          bottom: isFullscreen ? bottomOffset : bottomOffset - 6,
          end: isFullscreen ? 12 : 16,
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: false, // Action buttons SHOULD receive taps
              child: video == null
                  ? _PreviewOverlayActionColumn(onInteracted: onInteracted)
                  : VideoOverlayActionColumn(
                      video: video,
                      isFullscreen: isFullscreen,
                      isPreviewMode: isPreviewMode,
                      onInteracted: onInteracted,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showContentWarningDetails(
    BuildContext context,
    WidgetRef ref,
    List<String> labels,
    bool isActive,
  ) async {
    await context.showVideoPausingDialog<void>(
      builder: (context) => _ContentWarningDetailsSheet(labels: labels),
    );
  }
}

/// The line under a video card's author name: post date, loop count, or both.
///
/// Renders nothing when neither is available, rather than an empty row.
class _VideoCardMetaLine extends StatelessWidget {
  const _VideoCardMetaLine({required this.meta});

  final VideoCardMeta meta;

  @override
  Widget build(BuildContext context) {
    if (meta.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final loopCount = meta.loopCount;
    final timestamp = meta.timestamp;

    final parts = <String>[
      if (timestamp != null)
        LocalizedTimeFormatter.formatPostAge(
          l10n,
          timestamp,
          locale: Localizations.localeOf(context).toString(),
        ),
      if (loopCount != null)
        l10n.videoFeedLoopCountLine(
          StringUtils.formatCompactNumber(loopCount),
          loopCount,
        ),
    ];

    return Text(
      parts.join(' · '),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 20 / 14,
        // Sits on the video next to the white author name.
        color: VineTheme.onSurfaceVariant,
      ),
    );
  }
}

class _PreviewOverlayActionColumn extends StatelessWidget {
  const _PreviewOverlayActionColumn({this.onInteracted});

  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 20,
      children: [
        LikeActionButton.preview(onInteracted: onInteracted),
        CommentActionButton.preview(onInteracted: onInteracted),
        RepostActionButton.preview(onInteracted: onInteracted),
        VideoActionButton(
          icon: .shareFatDuo,
          semanticIdentifier: SemanticIds.shareButton,
          semanticLabel: context.l10n.shareVideoLabel,
          labelWhenZero: context.l10n.videoActionShareLabel,
          onPressed: onInteracted,
        ),
        VideoActionButton(
          icon: DivineIconName.flag,
          semanticIdentifier: 'report_button',
          semanticLabel: context.l10n.videoActionReport,
          labelWhenZero: context.l10n.videoActionReportLabel,
          onPressed: onInteracted,
        ),
        VideoActionButton(
          icon: DivineIconName.info,
          semanticIdentifier: 'more_button',
          semanticLabel: context.l10n.videoActionMoreOptions,
          caption: context.l10n.videoActionAboutLabel,
          onPressed: onInteracted,
        ),
      ],
    );
  }
}

class VideoOverlayActionColumn extends ConsumerWidget {
  const VideoOverlayActionColumn({
    required this.video,
    super.key,
    this.isPreviewMode = false,
    this.isFullscreen = false,
    this.onInteracted,
  });

  final VideoEvent video;
  final bool isPreviewMode;
  final bool isFullscreen;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Owners get an [EditActionButton] at the top of the column (above
    // Like) and the [ReportActionButton] is suppressed — you can't report
    // your own video, so the slot is reused for Edit instead. The gate
    // resolves to false for non-owners and during preview, leaving the
    // column unchanged.
    final currentUserPubkey = ref
        .watch(authServiceProvider)
        .currentPublicKeyHex;
    final isOwnVideo =
        currentUserPubkey != null && currentUserPubkey == video.pubkey;
    final showEditButton = !isPreviewMode && isOwnVideo;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: overlayActionColumnTextScaleLimit,
      child: Column(
        spacing: 20,
        children: [
          if (showEditButton)
            EditActionButton(video: video, onInteracted: onInteracted),
          LikeActionButton(
            video: video,
            isPreviewMode: isPreviewMode,
            isOwnVideo: isOwnVideo,
            onInteracted: onInteracted,
          ),
          CommentActionButton(
            video: video,
            isPreviewMode: isPreviewMode,
            onInteracted: onInteracted,
          ),
          RepostActionButton(
            video: video,
            isPreviewMode: isPreviewMode,
            isOwnVideo: isOwnVideo,
            onInteracted: onInteracted,
          ),
          ShareActionButton(video: video, onInteracted: onInteracted),
          if (!isOwnVideo) ...[
            ReportActionButton(video: video, onInteracted: onInteracted),
            // Gate the slot itself so a build that cannot offer the action
            // inserts no child into Column(spacing: 20) — a hidden
            // SizedBox.shrink would still add a permanent gap between Report
            // and More. The gate covers the kill-switch *and* repository /
            // pubkey readiness; the button keeps the same checks defensively.
            if (ref.watch(helpClassifyActionAvailableProvider))
              HelpClassifyActionButton(
                video: video,
                onInteracted: onInteracted,
              ),
          ],
          MoreActionButton(video: video, onInteracted: onInteracted),
        ],
      ),
    );
  }
}

/// Repost header banner showing who reposted the video.
class VideoRepostHeader extends ConsumerWidget {
  const VideoRepostHeader({required this.reposterPubkey, super.key});

  final String reposterPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reposterProfile = ref
        .watch(userProfileReactiveProvider(reposterPubkey))
        .value;

    final displayName =
        reposterProfile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(reposterPubkey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DivineIcon(
            icon: DivineIconName.repeat,
            color: VineTheme.vineGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$displayName reposted',
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small badge shown on videos that have NIP-32 content-warning self-labels.
class _ContentWarningBadge extends StatelessWidget {
  const _ContentWarningBadge({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: VineTheme.contentWarningAmber.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DivineIcon(
            icon: DivineIconName.warning,
            color: VineTheme.contentWarningAmber,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            labels.length == 1
                ? _humanize(context, labels.first)
                : context.l10n.contentWarningLabel,
            style: const TextStyle(
              color: VineTheme.contentWarningAmber,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Convert a NIP-32 label value to a localized human-readable string.
  static String _humanize(BuildContext context, String label) =>
      humanizeContentLabel(context, label);

  /// Return a localized description for a NIP-32 content-warning label.
  static String _describe(BuildContext context, String label) {
    final l10n = context.l10n;
    switch (label) {
      case 'nudity':
        return l10n.contentWarningDescNudity;
      case 'sexual':
        return l10n.contentWarningDescSexual;
      case 'porn':
        return l10n.contentWarningDescPorn;
      case 'graphic-media':
        return l10n.contentWarningDescGraphicMedia;
      case 'violence':
        return l10n.contentWarningDescViolence;
      case 'self-harm':
        return l10n.contentWarningDescSelfHarm;
      case 'drugs':
        return l10n.contentWarningDescDrugs;
      case 'alcohol':
        return l10n.contentWarningDescAlcohol;
      case 'tobacco':
        return l10n.contentWarningDescTobacco;
      case 'gambling':
        return l10n.contentWarningDescGambling;
      case 'profanity':
        return l10n.contentWarningDescProfanity;
      case 'flashing-lights':
        return l10n.contentWarningDescFlashingLights;
      case 'ai-generated':
        return l10n.contentWarningDescAiGenerated;
      case 'spoiler':
        return l10n.contentWarningDescSpoiler;
      case 'content-warning':
        return l10n.contentWarningDescContentWarning;
      default:
        return l10n.contentWarningDescDefault;
    }
  }
}

/// Bottom sheet showing content warning label details with descriptions.
class _ContentWarningDetailsSheet extends StatelessWidget {
  const _ContentWarningDetailsSheet({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.vineColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const DivineIcon(
                  icon: DivineIconName.warning,
                  color: VineTheme.contentWarningAmber,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.contentWarningDetailsTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.contentWarningDetailsSubtitle,
              style: TextStyle(
                color: context.vineColors.secondaryText,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            // Label list
            ...labels.map(
              (label) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: const BoxDecoration(
                        color: VineTheme.contentWarningAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _ContentWarningBadge._humanize(context, label),
                            style: TextStyle(
                              color: context.vineColors.primaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _ContentWarningBadge._describe(context, label),
                            style: TextStyle(
                              color: context.vineColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: context.vineColors.outline),
            const SizedBox(height: 8),
            // Manage content filters button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/content-filters');
                },
                icon: DivineIcon(
                  icon: DivineIconName.slidersHorizontal,
                  size: 18,
                  color: context.vineColors.accentPositive,
                ),
                label: Text(
                  context.l10n.contentWarningManageFilters,
                  style: TextStyle(
                    color: context.vineColors.accentPositive,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
