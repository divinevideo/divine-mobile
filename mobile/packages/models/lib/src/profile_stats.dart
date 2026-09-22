import 'package:meta/meta.dart';

/// Aggregated statistics for a user profile.
///
/// Contains video count, engagement metrics, and social counts
/// sourced from the local Drift cache.
@immutable
class ProfileStats {
  /// Creates a new [ProfileStats] instance.
  const ProfileStats({
    required this.pubkey,
    this.videoCount = 0,
    this.totalLikes = 0,
    this.followers,
    this.following,
    this.totalViews = 0,
    this.lastUpdated,
  });

  /// The user's public key (hex format).
  final String pubkey;

  /// Number of published videos.
  final int videoCount;

  /// Total likes across all videos.
  final int totalLikes;

  /// Number of followers, or `null` when no follower count has been cached
  /// yet.
  ///
  /// Follower and following counts are owned by `FollowRepository`, which
  /// writes them independently of the rest of this row. `null` means "not
  /// known yet" and must not be rendered as zero — callers should show a
  /// loading affordance instead.
  final int? followers;

  /// Number of accounts this user follows, or `null` when no following count
  /// has been cached yet. See [followers].
  final int? following;

  /// Total views across all videos.
  ///
  /// This is the author's aggregate engagement figure, not an archival-only
  /// count: `ProfileRepository` fills it from funnelcake's `engagement` total,
  /// falling back to the loop total, so a classic Vine's archived loops and a
  /// live Divine video's loops land in the same number. A surface that needs
  /// the archival-only per-video figure must read the event tags instead.
  final int totalViews;

  /// When these stats were last cached.
  final DateTime? lastUpdated;

  /// Creates a copy with the given fields replaced.
  ProfileStats copyWith({
    String? pubkey,
    int? videoCount,
    int? totalLikes,
    int? followers,
    int? following,
    int? totalViews,
    DateTime? lastUpdated,
  }) {
    return ProfileStats(
      pubkey: pubkey ?? this.pubkey,
      videoCount: videoCount ?? this.videoCount,
      totalLikes: totalLikes ?? this.totalLikes,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      totalViews: totalViews ?? this.totalViews,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileStats &&
        other.pubkey == pubkey &&
        other.videoCount == videoCount &&
        other.totalLikes == totalLikes &&
        other.followers == followers &&
        other.following == following &&
        other.totalViews == totalViews &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => Object.hash(
    pubkey,
    videoCount,
    totalLikes,
    followers,
    following,
    totalViews,
    lastUpdated,
  );

  @override
  String toString() =>
      'ProfileStats(pubkey: $pubkey, videos: $videoCount, '
      'likes: $totalLikes, followers: $followers, '
      'following: $following, views: $totalViews)';
}
