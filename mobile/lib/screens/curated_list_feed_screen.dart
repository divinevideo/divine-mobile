// ABOUTME: Screen for displaying videos from a curated NIP-51 kind 30005 list
// ABOUTME: Shows videos in a grid with tap-to-play navigation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';

class CuratedListFeedScreen extends ConsumerStatefulWidget {
  const CuratedListFeedScreen({
    required this.listId,
    required this.listName,
    super.key,
  });

  final String listId;
  final String listName;

  @override
  ConsumerState<CuratedListFeedScreen> createState() =>
      _CuratedListFeedScreenState();
}

class _CuratedListFeedScreenState extends ConsumerState<CuratedListFeedScreen> {
  int? _activeVideoIndex;

  @override
  Widget build(BuildContext context) {
    final videoIdsAsync = ref.watch(curatedListVideosProvider(widget.listId));

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: _activeVideoIndex == null
          ? AppBar(
              backgroundColor: VineTheme.cardBackground,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                widget.listName,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: videoIdsAsync.when(
        data: (videoIds) {
          if (videoIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library,
                    size: 64,
                    color: VineTheme.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No videos in this list',
                    style: TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some videos to get started',
                    style: TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          // If in video mode, show fullscreen video player
          if (_activeVideoIndex != null) {
            return _buildVideoPlayer(videoIds);
          }

          // Otherwise show grid
          return _buildVideoGrid(videoIds);
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: VineTheme.likeRed),
              const SizedBox(height: 16),
              Text(
                'Failed to load list',
                style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid(List<String> videoIds) {
    // Fetch actual video events for the IDs in the list
    final videoEventsAsync = ref.watch(videoEventsProvider);

    return videoEventsAsync.when(
      data: (allVideos) {
        // Filter to only videos that are in this list, maintaining list order
        final listVideos = <VideoEvent>[];
        for (final videoId in videoIds) {
          try {
            final video = allVideos.firstWhere((v) => v.id == videoId);
            listVideos.add(video);
          } catch (e) {
            // Video not found in cache - could fetch individually here
            Log.warning(
              'Video $videoId not found in cache',
              category: LogCategory.video,
            );
          }
        }

        if (listVideos.isEmpty) {
          return Center(
            child: Text(
              'Videos not loaded yet',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          );
        }

        return ComposableVideoGrid(
          videos: listVideos,
          onVideoTap: (videos, index) {
            Log.info(
              'Tapped video in curated list: ${videos[index].id}',
              category: LogCategory.ui,
            );
            setState(() {
              _activeVideoIndex = index;
            });
          },
          onRefresh: () async {
            // Refresh the video events
            ref.invalidate(videoEventsProvider);
            await ref.read(videoEventsProvider.future);
          },
          emptyBuilder: () => Center(
            child: Text(
              'No videos available',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
        );
      },
      loading: () =>
          Center(child: CircularProgressIndicator(color: VineTheme.vineGreen)),
      error: (error, stack) => Center(
        child: Text(
          'Error loading videos',
          style: TextStyle(color: VineTheme.likeRed),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(List<String> videoIds) {
    final videoEventsAsync = ref.watch(videoEventsProvider);

    return videoEventsAsync.when(
      data: (allVideos) {
        // Filter to videos in this list
        final listVideos = <VideoEvent>[];
        for (final videoId in videoIds) {
          try {
            final video = allVideos.firstWhere((v) => v.id == videoId);
            listVideos.add(video);
          } catch (e) {
            // Video not found
          }
        }

        if (listVideos.isEmpty || _activeVideoIndex! >= listVideos.length) {
          return Center(
            child: Text(
              'Video not available',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          );
        }

        // Use Stack with back button overlay to exit video mode
        return Stack(
          children: [
            ExploreVideoScreenPure(
              startingVideo: listVideos[_activeVideoIndex!],
              videoList: listVideos,
              contextTitle: widget.listName,
              startingIndex: _activeVideoIndex!,
              useLocalActiveState:
                  true, // Use local state since not using URL routing
            ),
            // Back button overlay to exit video mode
            Positioned(
              top: 50,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: VineTheme.whiteText,
                    ),
                  ),
                  onPressed: () {
                    // Stop all videos before switching to grid
                    disposeAllVideoControllers(ref);
                    setState(() {
                      _activeVideoIndex = null;
                    });
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () =>
          Center(child: CircularProgressIndicator(color: VineTheme.vineGreen)),
      error: (error, stack) => Center(
        child: Text(
          'Error loading videos',
          style: TextStyle(color: VineTheme.likeRed),
        ),
      ),
    );
  }
}
