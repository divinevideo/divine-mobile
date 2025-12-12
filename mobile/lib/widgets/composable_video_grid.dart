// ABOUTME: Composable video grid widget with automatic broken video filtering
// ABOUTME: Reusable component for Explore, Hashtag, and Search screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Composable video grid that automatically filters broken videos
/// and provides consistent styling across Explore, Hashtag, and Search screens
class ComposableVideoGrid extends ConsumerWidget {
  const ComposableVideoGrid({
    super.key,
    required this.videos,
    required this.onVideoTap,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.72,
    this.thumbnailAspectRatio = 1.0,
    this.padding,
    this.emptyBuilder,
    this.onRefresh,
  });

  final List<VideoEvent> videos;
  final Function(List<VideoEvent> videos, int index) onVideoTap;
  final int crossAxisCount;
  final double childAspectRatio;
  final double thumbnailAspectRatio;
  final EdgeInsets? padding;
  final Widget Function()? emptyBuilder;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch broken video tracker asynchronously
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

    return brokenTrackerAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: VineTheme.vineGreen)),
      error: (error, stack) {
        // Fallback: show all videos if tracker fails
        return _buildGrid(context, ref, videos);
      },
      data: (tracker) {
        // Filter out broken videos
        final filteredVideos = videos
            .where((video) => !tracker.isVideoBroken(video.id))
            .toList();

        if (filteredVideos.isEmpty && emptyBuilder != null) {
          return emptyBuilder!();
        }

        return _buildGrid(context, ref, filteredVideos);
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    List<VideoEvent> videosToShow,
  ) {
    if (videosToShow.isEmpty && emptyBuilder != null) {
      return emptyBuilder!();
    }

    // Responsive column count: 3 for tablets/desktop (width >= 600), 2 for phones
    final screenWidth = MediaQuery.of(context).size.width;
    final responsiveCrossAxisCount = screenWidth >= 600 ? 3 : crossAxisCount;

    final gridView = GridView.builder(
      padding: padding ?? const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveCrossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: videosToShow.length,
      itemBuilder: (context, index) {
        final video = videosToShow[index];
        return _buildVideoTile(context, ref, video, index, videosToShow);
      },
    );

    // Wrap with RefreshIndicator if onRefresh is provided
    if (onRefresh != null) {
      return RefreshIndicator(
        semanticsLabel: 'searching for more videos',
        onRefresh: onRefresh!,
        child: gridView,
      );
    }

    return gridView;
  }

  Widget _buildVideoTile(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
    int index,
    List<VideoEvent> displayedVideos,
  ) {
    return GestureDetector(
      onTap: () => onVideoTap(displayedVideos, index),
      onLongPress: () => _showVideoContextMenu(context, ref, video),
      child: Container(
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Column(
            children: [
              // Video thumbnail with play overlay
              AspectRatio(
                aspectRatio: thumbnailAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: VineTheme.cardBackground,
                      child: video.thumbnailUrl != null
                          ? VideoThumbnailWidget(
                              video: video,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(0),
                            )
                          : Container(
                              color: VineTheme.cardBackground,
                              child: Icon(
                                Icons.videocam,
                                size: 40,
                                color: VineTheme.secondaryText,
                              ),
                            ),
                    ),
                    // Play button overlay
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VineTheme.darkOverlay,
                          shape: BoxShape.circle,
                        ),
                        child: Semantics(
                          identifier: 'play_button',
                          child: Icon(
                            Icons.play_arrow,
                            size: 24,
                            color: VineTheme.whiteText,
                            semanticLabel: 'Play video',
                          ),
                        ),
                      ),
                    ),
                    // Duration badge if available
                    if (video.duration != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: VineTheme.darkOverlay,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${video.duration}s',
                            style: TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Video info - wrapped in Expanded to fill remaining space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CreatorName(pubkey: video.pubkey),
                      const SizedBox(height: 1),
                      // Title or content
                      Flexible(
                        child: Text(
                          video.title ?? video.content,
                          style: TextStyle(
                            color: VineTheme.primaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Stats row - watch social provider for current metrics
                      Consumer(
                        builder: (context, ref, _) {
                          final socialState = ref.watch(socialProvider);
                          final newLikeCount =
                              socialState.likeCounts[video.id] ?? 0;
                          final totalLikes =
                              newLikeCount + (video.originalLikes ?? 0);

                          return Row(
                            children: [
                              Icon(
                                Icons.favorite,
                                size: 10,
                                color: VineTheme.likeRed,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                StringUtils.formatCompactNumber(totalLikes),
                                style: TextStyle(
                                  color: VineTheme.secondaryText,
                                  fontSize: 9,
                                ),
                              ),
                              if (video.originalLoops != null) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.repeat,
                                  size: 10,
                                  color: VineTheme.secondaryText,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  StringUtils.formatCompactNumber(
                                    video.originalLoops!,
                                  ),
                                  style: TextStyle(
                                    color: VineTheme.secondaryText,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show context menu for long press on video tiles
  void _showVideoContextMenu(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
  ) {
    // Check if user owns this video
    final nostrService = ref.read(nostrServiceProvider);
    final userPubkey = nostrService.publicKey;
    final isOwnVideo = userPubkey != null && userPubkey == video.pubkey;

    // Only show context menu for own videos
    if (!isOwnVideo) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.backgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.more_vert, color: VineTheme.whiteText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Video Options',
                      style: TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.close, color: VineTheme.secondaryText),
                  ),
                ],
              ),
            ),

            // Edit option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: VineTheme.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit, color: VineTheme.vineGreen, size: 20),
              ),
              title: Text(
                'Edit Video',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Update title, description, and hashtags',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
              ),
              onTap: () {
                context.pop();
                showEditDialogForVideo(context, video);
              },
            ),

            // Delete option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: VineTheme.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
              title: Text(
                'Delete Video',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Permanently remove this content',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
              ),
              onTap: () {
                context.pop();
                _showDeleteConfirmation(context, ref, video);
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          'Delete Video',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this video?',
              style: TextStyle(color: VineTheme.whiteText),
            ),
            SizedBox(height: 12),
            Text(
              'This will send a delete request (NIP-09) to all relays. Some relays may still retain the content.',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deleteVideo(context, ref, video);
    }
  }

  /// Delete video using ContentDeletionService
  Future<void> _deleteVideo(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
  ) async {
    try {
      final deletionService = await ref.read(
        contentDeletionServiceProvider.future,
      );

      // Show loading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Deleting content...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final result = await deletionService.quickDelete(
        video: video,
        reason: DeleteReason.personalChoice,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.success
                        ? 'Delete request sent successfully'
                        : 'Failed to delete content: ${result.error}',
                  ),
                ),
              ],
            ),
            backgroundColor: result.success ? VineTheme.vineGreen : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _CreatorName extends ConsumerWidget {
  const _CreatorName({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileReactiveProvider(pubkey));

    final displayName = switch (profileAsync) {
      AsyncData(:final value) when value != null => value.bestDisplayName,
      AsyncData() || AsyncError() => 'Unknown',
      AsyncLoading() => 'Loading...',
    };

    return Text(
      displayName,
      style: TextStyle(
        color: VineTheme.secondaryText,
        fontSize: 10,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
