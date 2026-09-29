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
    this.hasKnownTotalViews = true,
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

  /// The author's lifetime loop total across all videos.
  ///
  /// This is archived Vine loops plus Divine-era views, summed by
  /// `ProfileRepository` from funnelcake's `engagement.archived_loops` and
  /// `engagement.total_views`. Until funnelcake reports `archived_loops`, a
  /// fetched value is Divine-era views only, though it never lowers a cached
  /// archived total such as the classic Vine seed's. A surface that needs the
  /// archival-only per-video figure must read the event tags instead.
  final int totalViews;

  /// Whether [totalViews] came from a source that supplied a value.
  ///
  /// A missing total is kept as zero for compatibility with existing profile
  /// consumers, but the video card must not render it as a genuine zero.
  final bool hasKnownTotalViews;

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
    bool? hasKnownTotalViews,
    DateTime? lastUpdated,
  }) {
    return ProfileStats(
      pubkey: pubkey ?? this.pubkey,
      videoCount: videoCount ?? this.videoCount,
      totalLikes: totalLikes ?? this.totalLikes,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      totalViews: totalViews ?? this.totalViews,
      hasKnownTotalViews: hasKnownTotalViews ?? this.hasKnownTotalViews,
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
        other.hasKnownTotalViews == hasKnownTotalViews &&
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
    hasKnownTotalViews,
    lastUpdated,
  );

  @override
  String toString() =>
      'ProfileStats(pubkey: $pubkey, videos: $videoCount, '
      'likes: $totalLikes, followers: $followers, '
      'following: $following, views: $totalViews)';
}
