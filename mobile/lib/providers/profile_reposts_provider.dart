// ABOUTME: Provider for fetching videos that a user has reposted
// ABOUTME: Filters profile feed events to show only reposts by the specified user

import 'package:models/models.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_reposts_provider.g.dart';

/// Provider that returns only the videos a user has reposted
///
/// Watches the profile feed provider and filters for videos where:
/// - isRepost == true
/// - reposterPubkey == userIdHex
@riverpod
Future<List<VideoEvent>> profileReposts(Ref ref, String userIdHex) async {
  // Watch the full profile feed (which includes reposts since we enabled includeReposts)
  final profileFeed = await ref.watch(profileFeedProvider(userIdHex).future);

  // Filter for only reposts by this specific user
  final reposts = profileFeed.videos
      .where((video) => video.isRepost && video.reposterPubkey == userIdHex)
      .toList();

  return reposts;
}
