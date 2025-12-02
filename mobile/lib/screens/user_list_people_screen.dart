// ABOUTME: Screen for displaying people from a NIP-51 kind 30000 user list with their videos
// ABOUTME: Shows horizontal carousel of people at top, video grid below

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/services/user_list_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';

class UserListPeopleScreen extends ConsumerStatefulWidget {
  const UserListPeopleScreen({required this.userList, super.key});

  final UserList userList;

  @override
  ConsumerState<UserListPeopleScreen> createState() =>
      _UserListPeopleScreenState();
}

class _UserListPeopleScreenState extends ConsumerState<UserListPeopleScreen> {
  int? _activeVideoIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: _activeVideoIndex == null
          ? AppBar(
              backgroundColor: VineTheme.cardBackground,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userList.name,
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.userList.description != null)
                    Text(
                      widget.userList.description!,
                      style: TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            )
          : null,
      body: widget.userList.pubkeys.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group, size: 64, color: VineTheme.secondaryText),
                  const SizedBox(height: 16),
                  Text(
                    'No people in this list',
                    style: TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some people to get started',
                    style: TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _activeVideoIndex != null
          ? _buildVideoPlayer()
          : _buildListContent(),
    );
  }

  Widget _buildListContent() {
    final videosAsync = ref.watch(
      userListMemberVideosProvider(widget.userList.pubkeys),
    );

    return Column(
      children: [
        // Horizontal carousel of people in the list
        _buildPeopleCarousel(),

        // Divider
        Container(
          height: 1,
          color: VineTheme.cardBackground,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),

        // Video grid from all list members
        Expanded(
          child: videosAsync.when(
            data: (videos) {
              if (videos.isEmpty) {
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
                        'No videos yet',
                        style: TextStyle(
                          color: VineTheme.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Videos from list members will appear here',
                        style: TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ComposableVideoGrid(
                videos: videos,
                onVideoTap: (videos, index) {
                  Log.info(
                    'Tapped video in user list: ${videos[index].id}',
                    category: LogCategory.ui,
                  );
                  setState(() {
                    _activeVideoIndex = index;
                  });
                },
                onRefresh: () async {
                  // Invalidate the provider to refresh
                  ref.invalidate(
                    userListMemberVideosProvider(widget.userList.pubkeys),
                  );
                },
                emptyBuilder: () => Center(
                  child: Text(
                    'No videos available',
                    style: TextStyle(color: VineTheme.secondaryText),
                  ),
                ),
              );
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
                    'Failed to load videos',
                    style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeopleCarousel() {
    final userProfileService = ref.watch(userProfileServiceProvider);

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.userList.pubkeys.length,
        itemBuilder: (context, index) {
          final pubkey = widget.userList.pubkeys[index];

          return FutureBuilder(
            future: userProfileService.fetchProfile(pubkey),
            builder: (context, snapshot) {
              final profile = userProfileService.getCachedProfile(pubkey);

              return GestureDetector(
                onTap: () {
                  context.goProfile(pubkey);
                },
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      UserAvatar(
                        imageUrl: profile?.picture,
                        name: profile?.bestDisplayName,
                        size: 64,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile?.bestDisplayName ?? 'Loading...',
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final videosAsync = ref.watch(
      userListMemberVideosProvider(widget.userList.pubkeys),
    );

    return videosAsync.when(
      data: (videos) {
        if (videos.isEmpty || _activeVideoIndex! >= videos.length) {
          return Center(
            child: Text(
              'Video not available',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          );
        }

        return Stack(
          children: [
            ExploreVideoScreenPure(
              startingVideo: videos[_activeVideoIndex!],
              videoList: videos,
              contextTitle: widget.userList.name,
              startingIndex: _activeVideoIndex!,
              useLocalActiveState:
                  true, // Use local state since not using URL routing
            ),
            // Header bar showing list name and back button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back to grid button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.grid_view,
                            color: VineTheme.whiteText,
                            size: 20,
                          ),
                        ),
                        onPressed: () {
                          // Stop all videos before switching to grid
                          disposeAllVideoControllers(ref);
                          setState(() {
                            _activeVideoIndex = null;
                          });
                        },
                        tooltip: 'Back to grid',
                      ),
                      const SizedBox(width: 8),
                      // List name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.userList.name,
                              style: const TextStyle(
                                color: VineTheme.whiteText,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.userList.description != null)
                              Text(
                                widget.userList.description!,
                                style: TextStyle(
                                  color: VineTheme.secondaryText,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Video count indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_activeVideoIndex! + 1}/${videos.length}',
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
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
