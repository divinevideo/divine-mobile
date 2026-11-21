// ABOUTME: One post's performance as the creator analytics screens show it.
// ABOUTME: Built from a single VideoEvent's view and engagement counts.

import 'package:models/models.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';

class VideoPerformance {
  const VideoPerformance({
    required this.video,
    required this.views,
    required this.uniqueViewers,
    required this.hasEngagementData,
    required this.likes,
    required this.comments,
    required this.reposts,
    required this.interactions,
    required this.engagementRate,
    required this.displayTitle,
  });

  factory VideoPerformance.fromVideo(
    VideoEvent video, {
    bool hasEngagementData = true,
  }) {
    final likes = liveLikeCountSeed(video) ?? 0;
    final comments = liveCommentCountSeed(video) ?? 0;
    final reposts = liveRepostCountSeed(video) ?? 0;
    final views = extractVideoViews(video);
    final uniqueViewers = extractUniqueViewers(video);
    final interactions = likes + comments + reposts;
    final engagementRate = (views != null && views > 0)
        ? interactions / views
        : null;
    final displayTitle = video.title?.trim().isNotEmpty == true
        ? video.title!.trim()
        : video.id;

    return VideoPerformance(
      video: video,
      views: views,
      uniqueViewers: uniqueViewers,
      hasEngagementData: hasEngagementData,
      likes: likes,
      comments: comments,
      reposts: reposts,
      interactions: interactions,
      engagementRate: engagementRate,
      displayTitle: displayTitle,
    );
  }

  final VideoEvent video;
  final int? views;
  final int? uniqueViewers;
  final bool hasEngagementData;
  final int likes;
  final int comments;
  final int reposts;
  final int interactions;
  final double? engagementRate;
  final String displayTitle;
}
