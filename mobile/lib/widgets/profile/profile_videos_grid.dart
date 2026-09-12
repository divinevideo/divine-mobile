// ABOUTME: Grid widget displaying user's videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails, handles empty state and navigation

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/grid_prefetch_mixin.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/utils/video_identity.dart';
import 'package:openvine/widgets/owner_video_actions_sheet.dart';
import 'package:openvine/widgets/profile/pending_collaborator_invite_banner_cubit.dart';
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_more_sliver.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:openvine/widgets/profile/profile_videos_grid_skeleton.dart';

/// Internal class that represents a video entry in the grid
/// It can be a video event or an uploading video
sealed class _GridVideoEntry {}

class _GridVideoEventEntry extends _GridVideoEntry {
  _GridVideoEventEntry(this.videoEvent);

  final VideoEvent videoEvent;
}

class _GridUploadingVideoEntry extends _GridVideoEntry {
  _GridUploadingVideoEntry({
    required this.draftId,
    required this.thumbnailPath,
  });

  final String draftId;
  final String? thumbnailPath;
}

/// Debug-only counter incremented at the top of every
/// [_ProfileVideosGridState.build] call. Used by tests to pin the
/// rebuild count to 1 across progress-only `BackgroundPublishBloc`
/// emissions — a regression to identity-based list equality on the
/// selector would tick this counter higher. The increment is wrapped
/// in an `assert` so it is tree-shaken out of release builds.
@visibleForTesting
int debugProfileVideosGridBuildCount = 0;

/// Equatable wrapper over the list of active uploads consumed by
/// [_ProfileVideosGridState.build]. Exists because `context.select`
/// compares its selected value with `==`, and a raw list of records falls
/// through to identity equality even when the records themselves compare
/// equal structurally. Equatable's deep `iterableEquals` gives the selector
/// the progress-insensitive comparison the optimization needs.
@visibleForTesting
class ActiveUploadsView extends Equatable {
  @visibleForTesting
  const ActiveUploadsView(this.uploads);

  // Public field uses the record type inline so the private [_ActiveUpload]
  // typedef alias doesn't leak through the public API surface
  // (avoids `library_private_types_in_public_api`).
  final List<({String draftId, String? title, String? thumbnailPath})> uploads;

  /// Projects the bloc's [BackgroundPublishState] into the shape the grid
  /// renders. Used as the selector callback in [_ProfileVideosGridState.build].
  factory ActiveUploadsView.fromState(BackgroundPublishState state) {
    return ActiveUploadsView([
      for (final upload in state.uploads)
        if (upload.result == null)
          (
            draftId: upload.draft.id,
            title: upload.draft.title,
            thumbnailPath: upload.draft.coverThumbnailPath,
          ),
    ]);
  }

  @override
  List<Object?> get props => [uploads];
}

/// Grid widget displaying user's videos on their profile
class ProfileVideosGrid extends ConsumerStatefulWidget {
  const ProfileVideosGrid({
    required this.videos,
    required this.userIdHex,
    this.isLoading = false,
    super.key,
  });

  final List<VideoEvent> videos;
  final String userIdHex;

  /// Whether videos are currently being loaded.
  final bool isLoading;

  @override
  ConsumerState<ProfileVideosGrid> createState() => _ProfileVideosGridState();
}

class _ProfileVideosGridState extends ConsumerState<ProfileVideosGrid>
    with GridPrefetchMixin, ScrollPaginationMixin {
  List<VideoEvent>? _lastPrefetchedVideos;

  late final OwnerVideoActionsCubit _ownerVideoActionsCubit;

  /// Resolved from [PrimaryScrollController] provided by [NestedScrollView].
  ScrollController? _primaryScrollController;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

  @override
  bool canLoadMore() {
    final state = context.read<ProfileFeedCubit>().state;
    return state.hasMoreContent && !state.isLoadingMore;
  }

  @override
  void onLoadMore() => _triggerLoadMore();

  @override
  void initState() {
    super.initState();
    _ownerVideoActionsCubit = OwnerVideoActionsCubit(
      contentDeletionService: () =>
          ref.read(contentDeletionServiceProvider.future),
      videoEventService: () => ref.read(videoEventServiceProvider),
      enforcementRepository: () =>
          ref.read(creatorDeleteEnforcementRepositoryProvider),
    );
    // Prefetch visible grid videos after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _prefetchIfNeeded();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.of(context);
    if (_primaryScrollController != primary) {
      if (_primaryScrollController != null) disposePagination();
      _primaryScrollController = primary;
      initPagination();
    }
  }

  @override
  void dispose() {
    _ownerVideoActionsCubit.close();
    disposePagination();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProfileVideosGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Prefetch when video list changes
    if (oldWidget.videos != widget.videos) {
      _prefetchIfNeeded();
    }
  }

  void _prefetchIfNeeded() {
    final videos = widget.videos;
    if (videos.isEmpty || videos == _lastPrefetchedVideos) return;
    _lastPrefetchedVideos = videos;
    prefetchGridVideos(videos);
  }

  void _triggerLoadMore() {
    context.read<ProfileFeedCubit>().add(const ProfileFeedLoadMoreRequested());
  }

  Future<void> _showOwnVideoActions(VideoEvent video) =>
      showOwnerVideoActionsSheet(
        context: context,
        video: video,
        cubit: _ownerVideoActionsCubit,
        onEditRequested: () => context.push(
          VideoMetadataEditScreen.pathFor(video.id),
          extra: video,
        ),
        onDeleted: () async {
          // The service marks the video locally deleted; a refresh drops the
          // tile from the grid without waiting for relay propagation.
          context.read<ProfileFeedCubit>().add(
            const ProfileFeedRefreshRequested(),
          );
        },
      );

  void _onVideoTapped(
    VideoEvent tappedVideo, {
    required int fallbackIndex,
    required List<VideoEvent> displayedVideos,
  }) {
    final currentFeedVideos = context.read<ProfileFeedCubit>().state.videos;
    final videos = currentFeedVideos.isNotEmpty
        ? currentFeedVideos
        : displayedVideos;
    final index = indexOfMatchingVideo(videos, tappedVideo);
    final resolvedIndex = index >= 0 ? index : fallbackIndex;

    // Pre-warm adjacent videos before navigation
    prefetchAroundIndex(resolvedIndex, videos);

    context.push(
      PooledFullscreenVideoFeedScreen.pathForVideoId(tappedVideo.id),
      extra: ProfilePooledFullscreenVideoFeedArgs(
        userIdHex: widget.userIdHex,
        initialIndex: resolvedIndex,
        seedVideos: videos,
        initialVideoId: tappedVideo.id,
        initialStableId: tappedVideo.stableId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugProfileVideosGridBuildCount++;
      return true;
    }(), 'debug build counter must not throw');
    final authService = ref.read(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnProfile =
        currentUserPubkey != null && currentUserPubkey == widget.userIdHex;

    // Subscribe to the *shape* of the active upload list (id + title +
    // thumbnailPath per upload). Progress is intentionally excluded so that
    // per-tick progress emissions don't rebuild the grid — each upload
    // tile subscribes to its own progress in [_VideoGridUploadingTile].
    //
    // The selector returns [ActiveUploadsView] (Equatable) rather than a raw
    // [List]: `context.select` compares its result with `==`, and `List`
    // equality is identity-based — without the wrapper, a freshly-built list
    // every tick would defeat the optimization regardless of record equality
    // inside it.
    final activeUploads = isOwnProfile
        ? context
              .select<BackgroundPublishBloc, ActiveUploadsView>(
                (bloc) => ActiveUploadsView.fromState(bloc.state),
              )
              .uploads
        : const <({String draftId, String? title, String? thumbnailPath})>[];

    // De-duplicate relay-delivered videos against active uploads.
    //
    // When a video is published, the relay may deliver it to the profile
    // feed before the [BackgroundPublishBloc] removes the upload from its
    // state. This causes a brief visual duplicate: the upload tile and
    // the published video tile appear side-by-side.
    //
    // To prevent this we filter relay videos by:
    //  1. Only inspecting videos created within the last 5 minutes —
    //     older videos cannot be duplicates of an in-progress upload.
    //  2. Matching by title against the active upload drafts.
    //  3. Removing only the *first* match per title so that legitimate
    //     older videos with the same title are not hidden.
    final now = DateTime.now();
    final matchedTitles = <String>{};
    final filteredVideos = isOwnProfile
        ? widget.videos.where((video) {
            // Step 1: Skip de-duplication for videos older than 5 minutes.
            final videoTime = DateTime.fromMillisecondsSinceEpoch(
              video.createdAt * 1000,
            );
            if (now.difference(videoTime).inMinutes > 5) return true;

            // Step 2: Check if this video's title matches an active upload
            // that hasn't been matched yet.
            final isDuplicate =
                !matchedTitles.contains(video.title) &&
                activeUploads.any((upload) => upload.title == video.title);

            // Step 3: Mark the title as matched so only the first duplicate
            // per upload is filtered out.
            if (isDuplicate) {
              if (video.title case final title?) {
                matchedTitles.add(title);
              }
              return false;
            }
            return true;
          }).toList()
        : widget.videos;

    final allVideos = [
      ...activeUploads.map(
        (upload) => _GridUploadingVideoEntry(
          draftId: upload.draftId,
          thumbnailPath: upload.thumbnailPath,
        ),
      ),
      ...filteredVideos.map(_GridVideoEventEntry.new),
    ];

    if (allVideos.isEmpty) {
      if (widget.isLoading) {
        return const ProfileVideosGridSkeleton();
      }
      return ProfileTabEmptyState(
        title: context.l10n.profileNoVideosTitle,
        subtitle: isOwnProfile
            ? context.l10n.profileNoVideosOwnSubtitle
            : context.l10n.profileNoVideosOtherSubtitle,
      );
    }

    // Count uploading videos to offset indices for published videos
    final uploadingCount = activeUploads.length;

    final isLoadingMore = context.watch<ProfileFeedCubit>().state.isLoadingMore;
    final pendingInviteGroups = isOwnProfile
        ? ref
              .watch(pendingCollaboratorInviteGroupsProvider)
              .maybeWhen(
                data: (groups) => groups,
                orElse: () => const <PendingCollaboratorInviteGroup>[],
              )
        : const <PendingCollaboratorInviteGroup>[];

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        if (pendingInviteGroups.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (final group in pendingInviteGroups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PendingCollaboratorInviteBanner(group: group),
                    ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(context).bottom,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final videoEntry = allVideos[index];
              return switch (videoEntry) {
                final _GridUploadingVideoEntry uploadEntry =>
                  _VideoGridUploadingTile(
                    draftId: uploadEntry.draftId,
                    thumbnailPath: uploadEntry.thumbnailPath,
                  ),
                final _GridVideoEventEntry eventEntry => _VideoGridTile(
                  videoEvent: eventEntry.videoEvent,
                  userIdHex: widget.userIdHex,
                  index: index,
                  onLongPress:
                      currentUserPubkey != null &&
                          currentUserPubkey == eventEntry.videoEvent.pubkey
                      ? () => _showOwnVideoActions(eventEntry.videoEvent)
                      : null,
                  onTap: () {
                    // Adjust index to account for uploading videos at the top
                    final publishedIndex = index - uploadingCount;
                    if (publishedIndex >= 0) {
                      final displayedVideos = filteredVideos;
                      _onVideoTapped(
                        eventEntry.videoEvent,
                        fallbackIndex: publishedIndex,
                        displayedVideos: displayedVideos,
                      );
                    }
                  },
                ),
              };
            }, childCount: allVideos.length),
          ),
        ),
        if (isLoadingMore) const ProfileTabLoadingMoreSliver(),
      ],
    );
  }
}

class _VideoGridUploadingTile extends StatelessWidget {
  const _VideoGridUploadingTile({
    required this.draftId,
    required this.thumbnailPath,
  });

  final String draftId;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    // Subscribe to this specific upload's progress so the tile rebuilds on
    // every progress tick without the surrounding grid having to.
    //
    // Fallback returns 1.0 (not 0): this branch is reached only after the
    // bloc removes the upload from state on [PublishSuccess]. If the tile
    // renders one frame before the parent grid prunes it, animating the
    // spinner forward to full is correct; animating backward to empty
    // would briefly snap the spinner across a 200ms animation.
    final progress = context.select<BackgroundPublishBloc, double>((bloc) {
      for (final upload in bloc.state.uploads) {
        if (upload.draft.id == draftId) return upload.progress;
      }
      return 1.0;
    });
    final path = thumbnailPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (path != null)
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ProfileTabThumbnailPlaceholder(),
            )
          else
            const ProfileTabThumbnailPlaceholder(),
          const ColoredBox(color: Color(0x66000000)),
          Center(child: PartialCircleSpinner(progress: progress)),
        ],
      ),
    );
  }
}

/// Individual video tile in the grid
class _VideoGridTile extends StatelessWidget {
  const _VideoGridTile({
    required this.videoEvent,
    required this.userIdHex,
    required this.index,
    required this.onTap,
    this.onLongPress,
  });

  final VideoEvent videoEvent;
  final String userIdHex;
  final int index;
  final VoidCallback onTap;

  /// Opens the own-video actions sheet; null on other users' profiles.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'video_thumbnail_$index',
    label: context.l10n.profileVideoThumbnailLabel(index + 1),
    button: true,
    onLongPress: onLongPress,
    onLongPressHint: onLongPress == null
        ? null
        : context.l10n.videoGridOptionsTitle,
    child: GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.vineColors.card),
          child: ProfileTabThumbnail(
            thumbnailUrl: videoEvent.thumbnailUrl,
            blurhash: videoEvent.blurhash,
          ),
        ),
      ),
    ),
  );
}

class _PendingCollaboratorInviteBanner extends ConsumerWidget {
  const _PendingCollaboratorInviteBanner({required this.group});

  final PendingCollaboratorInviteGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = this.group;
    final title = group.title?.trim();
    return BlocProvider(
      key: ValueKey(ref.watch(collaboratorInviteRecoveryRepositoryProvider)),
      create: (_) => PendingCollaboratorInviteBannerCubit(
        ref.read(collaboratorInviteRecoveryRepositoryProvider),
      ),
      child:
          BlocListener<
            PendingCollaboratorInviteBannerCubit,
            PendingCollaboratorInviteBannerState
          >(
            listenWhen: (previous, current) =>
                previous.feedback != current.feedback &&
                current.feedback !=
                    PendingCollaboratorInviteBannerFeedback.none,
            listener: (context, state) {
              final messenger = ScaffoldMessenger.maybeOf(context);
              if (messenger == null) return;
              final l10n = context.l10n;
              final message = switch (state.feedback) {
                PendingCollaboratorInviteBannerFeedback.retryUnavailable =>
                  l10n.profileCollaboratorInviteRetryUnavailable,
                PendingCollaboratorInviteBannerFeedback.retryCompleted =>
                  state.remainingInviteCount == 0 &&
                          state.blockedInviteCount > 0
                      ? l10n.profileCollaboratorInviteBlockedResult(
                          state.blockedInviteCount,
                        )
                      : l10n.profileCollaboratorInviteRetryResult(
                          state.remainingInviteCount,
                        ),
                PendingCollaboratorInviteBannerFeedback.none => null,
              };
              if (message == null) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(message),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child:
                BlocBuilder<
                  PendingCollaboratorInviteBannerCubit,
                  PendingCollaboratorInviteBannerState
                >(
                  builder: (context, state) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.vineColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(
                          _PendingInviteBannerTokens.borderRadius,
                        ),
                        border: Border.all(
                          color: context.vineColors.outlineMuted,
                          width: _PendingInviteBannerTokens.borderWidth,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          _PendingInviteBannerTokens.padding,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: _PendingInviteBannerTokens.iconTopPadding,
                              ),
                              child: ExcludeSemantics(
                                child: DivineIcon(
                                  icon: DivineIconName.envelopeSimple,
                                  color: context.vineColors.accentPositive,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: _PendingInviteBannerTokens.contentSpacing,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n
                                        .profileCollaboratorInvitePendingHeadline(
                                          group.inviteCount,
                                        ),
                                    style: VineTheme.titleMediumFont(
                                      color: context.vineColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        _PendingInviteBannerTokens.textSpacing,
                                  ),
                                  Text(
                                    title == null || title.isEmpty
                                        ? context
                                              .l10n
                                              .profileCollaboratorInvitePendingDetail
                                        : context.l10n
                                              .profileCollaboratorInvitePendingDetailWithTitle(
                                                title,
                                              ),
                                    style: VineTheme.bodySmallFont(
                                      color:
                                          context.vineColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              width: _PendingInviteBannerTokens.contentSpacing,
                            ),
                            DivineButton(
                              label: state.isRetrying
                                  ? context
                                        .l10n
                                        .profileCollaboratorInviteRetryingAction
                                  : context
                                        .l10n
                                        .profileCollaboratorInviteRetryAction,
                              size: DivineButtonSize.small,
                              onPressed: state.isRetrying
                                  ? null
                                  : () {
                                      context
                                          .read<
                                            PendingCollaboratorInviteBannerCubit
                                          >()
                                          .retry(group);
                                    },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
    );
  }
}

abstract final class _PendingInviteBannerTokens {
  static const double borderRadius = 18;
  static const double borderWidth = 1.5;
  static const double padding = 14;
  static const double iconTopPadding = 2;
  static const double contentSpacing = 12;
  static const double textSpacing = 4;
}
