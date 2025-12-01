// ABOUTME: Navigation utilities for launching contextual video feeds
// ABOUTME: Handles navigation from explore screen to feed with specific starting points and filters

import 'package:flutter/material.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/screens/video_feed_screen.dart';

class FeedNavigation {
  /// Navigate to feed starting with a specific video from editor's picks
  static void goToEditorsPicks(BuildContext context, VideoEvent startingVideo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoFeedScreen(
          startingVideo: startingVideo,
          context: FeedContext.editorsPicks,
        ),
      ),
    );
  }

  /// Navigate to feed starting with a specific video from a hashtag
  static void goToHashtagFeed(
    BuildContext context,
    VideoEvent startingVideo,
    String hashtag,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoFeedScreen(
          startingVideo: startingVideo,
          context: FeedContext.hashtag,
          contextValue: hashtag,
        ),
      ),
    );
  }

  /// Navigate to feed starting with a specific video from trending
  static void goToTrendingFeed(BuildContext context, VideoEvent startingVideo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoFeedScreen(
          startingVideo: startingVideo,
          context: FeedContext.trending,
        ),
      ),
    );
  }

  /// Navigate to feed starting with a specific video from user profile
  static void goToUserFeed(
    BuildContext context,
    VideoEvent startingVideo,
    String userPubkey,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoFeedScreen(
          startingVideo: startingVideo,
          context: FeedContext.userProfile,
          contextValue: userPubkey,
        ),
      ),
    );
  }

  /// Navigate to general feed starting with a specific video
  static void goToGeneralFeed(BuildContext context, VideoEvent startingVideo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoFeedScreen(
          startingVideo: startingVideo,
          context: FeedContext.general,
        ),
      ),
    );
  }

  /// Navigate to main feed tab (for bottom navigation)
  static void goToMainFeed(BuildContext context, {VideoEvent? startingVideo}) {
    // Find the MainNavigationScreen and switch to feed tab
    // This preserves the bottom navigation instead of pushing a full-screen view
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == Navigator.defaultRouteName || route.isFirst,
    );

    if (startingVideo != null) {
      // TODO: Need to communicate the starting video to the feed tab
      // For now, just navigate to feed tab - this needs MainNavigationScreen enhancement
    }
  }
}
