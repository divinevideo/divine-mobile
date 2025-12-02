// ABOUTME: Riverpod provider for managing profile statistics with async loading and caching
// ABOUTME: Aggregates user video count, likes, and other metrics from Nostr events

import 'dart:async';

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/profile_stats_cache_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_stats_provider.g.dart';

/// Statistics for a user's profile
class ProfileStats {
  const ProfileStats({
    required this.videoCount,
    required this.totalLikes,
    required this.followers,
    required this.following,
    required this.totalViews,
    required this.lastUpdated,
  });
  final int videoCount;
  final int totalLikes;
  final int followers;
  final int following;
  final int totalViews; // Placeholder for future implementation
  final DateTime lastUpdated;

  ProfileStats copyWith({
    int? videoCount,
    int? totalLikes,
    int? followers,
    int? following,
    int? totalViews,
    DateTime? lastUpdated,
  }) => ProfileStats(
    videoCount: videoCount ?? this.videoCount,
    totalLikes: totalLikes ?? this.totalLikes,
    followers: followers ?? this.followers,
    following: following ?? this.following,
    totalViews: totalViews ?? this.totalViews,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );

  @override
  String toString() =>
      'ProfileStats(videos: $videoCount, likes: $totalLikes, followers: $followers, following: $following, views: $totalViews)';
}

// SQLite-based persistent cache
final _cacheService = ProfileStatsCacheService();

/// Get cached stats if available and not expired
Future<ProfileStats?> _getCachedProfileStats(String pubkey) async {
  final stats = await _cacheService.getCachedStats(pubkey);

  if (stats != null) {
    final age = DateTime.now().difference(stats.lastUpdated);
    Log.debug(
      '📱 Using cached stats for $pubkey (age: ${age.inMinutes}min)',
      name: 'ProfileStatsProvider',
      category: LogCategory.ui,
    );
  }

  return stats;
}

/// Cache stats for a user
Future<void> _cacheProfileStats(String pubkey, ProfileStats stats) async {
  await _cacheService.saveStats(pubkey, stats);
  Log.debug(
    '📱 Cached stats for $pubkey',
    name: 'ProfileStatsProvider',
    category: LogCategory.ui,
  );
}

/// Clear all cached stats
Future<void> clearAllProfileStatsCache() async {
  await _cacheService.clearAll();
  Log.debug(
    '📱️ Cleared all stats cache',
    name: 'ProfileStatsProvider',
    category: LogCategory.ui,
  );
}

/// Async provider for loading profile statistics
@riverpod
Future<ProfileStats> fetchProfileStats(Ref ref, String pubkey) async {
  // Check cache first
  final cached = await _getCachedProfileStats(pubkey);
  if (cached != null) {
    return cached;
  }

  // Get the social service from app providers
  final socialService = ref.read(socialServiceProvider);

  try {
    // Get video event service and ensure subscription exists
    final videoEventService = ref.read(videoEventServiceProvider);

    // Subscribe to user's videos to ensure _authorBuckets is populated
    // This will backfill from existing videos in other subscription types
    await videoEventService.subscribeToUserVideos(pubkey, limit: 100);

    // Get follower stats - use cache if available, otherwise fetch from network
    final followerStats = await socialService.getFollowerStats(pubkey);

    // Get videos from VideoEventService (now populated via subscription)
    final videos = videoEventService.authorVideos(pubkey);
    final videoCount = videos.length;

    // Sum up loops and likes from all user's videos
    int totalLoops = 0;
    int totalLikes = 0;

    for (final video in videos) {
      totalLoops += video.originalLoops ?? 0;
      totalLikes += video.originalLikes ?? 0;
    }

    final stats = ProfileStats(
      videoCount: videoCount,
      totalLikes: totalLikes, // Sum of all likes from user's videos
      followers: followerStats['followers'] ?? 0,
      following: followerStats['following'] ?? 0,
      totalViews: totalLoops, // Sum of all loops (views) from user's videos
      lastUpdated: DateTime.now(),
    );

    // Cache the results
    await _cacheProfileStats(pubkey, stats);

    Log.info(
      'Profile stats loaded: $videoCount videos, ${StringUtils.formatCompactNumber(totalLoops)} views, ${StringUtils.formatCompactNumber(totalLikes)} likes',
      name: 'ProfileStatsProvider',
      category: LogCategory.system,
    );

    return stats;
  } catch (e) {
    Log.error(
      'Error loading profile stats: $e',
      name: 'ProfileStatsProvider',
      category: LogCategory.ui,
    );
    rethrow;
  }
}

/// Get a formatted string for large numbers (e.g., 1234 -> "1.2k")
/// Delegates to StringUtils.formatCompactNumber for consistent formatting
String formatProfileStatsCount(int count) {
  return StringUtils.formatCompactNumber(count);
}
