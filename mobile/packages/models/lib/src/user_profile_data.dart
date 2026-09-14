// ABOUTME: Typed sub-models for the Funnelcake user profile API response.
// ABOUTME: Replaces the loosely-typed Map<String, dynamic> shapes previously
// ABOUTME: returned by getUserProfile and getBulkProfiles.

import 'package:meta/meta.dart';

// ---------------------------------------------------------------------------
// Shared numeric parse helpers used by all sub-models below.
// ---------------------------------------------------------------------------

/// Parses [value] as an [int], accepting int, num, or String representations.
/// Returns 0 for null or unrecognised types.
int parseIntSafe(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Parses [value] as a [double], accepting double, num, or String
/// representations. Returns 0 for null or unrecognised types.
double parseDoubleSafe(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

// ---------------------------------------------------------------------------
// Sub-models
// ---------------------------------------------------------------------------

/// Core profile metadata fields from the Funnelcake `/api/users/:pubkey`
/// response — the `profile` sub-object.
@immutable
class UserProfileData {
  const UserProfileData({
    required this.pubkey,
    this.name,
    this.displayName,
    this.about,
    this.picture,
    this.banner,
    this.website,
    this.nip05,
    this.lud16,
    this.createdAt,
  });

  factory UserProfileData.fromJson(String pubkey, Map<String, dynamic> json) {
    return UserProfileData(
      pubkey: pubkey,
      name: _absentIfEmpty(json['name']),
      displayName: _absentIfEmpty(json['display_name']),
      about: _absentIfEmpty(json['about']),
      picture: _absentIfEmpty(json['picture']),
      banner: _absentIfEmpty(json['banner']),
      website: _absentIfEmpty(json['website']),
      nip05: _absentIfEmpty(json['nip05']),
      lud16: _absentIfEmpty(json['lud16']),
      createdAt: switch (json['profile_updated']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
    );
  }

  /// Reads a Funnelcake profile string field, mapping `''` to `null`.
  ///
  /// Funnelcake's profile response models every metadata field as a
  /// non-nullable Rust `String`, so a Kind 0 key that simply does not exist is
  /// serialized as `''`. Keeping that `''` would make an absent field
  /// indistinguishable from a deliberately-blank one, and downstream that is
  /// destructive rather than cosmetic: `UserProfile.fromUserProfileFound`
  /// admits every non-null field into `rawData`, so the REST-derived profile
  /// out-counts the real Kind 0 and wins `_resolvePublishSeed`'s richness
  /// comparison — after which the publish path's `isNotEmpty` guards delete the
  /// fields that were only ever `''` placeholders.
  static String? _absentIfEmpty(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  final String pubkey;
  final String? name;
  final String? displayName;
  final String? about;
  final String? picture;
  final String? banner;
  final String? website;
  final String? nip05;
  final String? lud16;

  /// The original Nostr Kind 0 event `created_at`, taken from Funnelcake's
  /// `profile.profile_updated` field.
  ///
  /// Funnelcake derives this directly from the indexed Kind 0 event timestamp
  /// (newest-wins), so it is a trustworthy original event time rather than a
  /// service/cache write time. `null` when the API response omits it or the
  /// value cannot be parsed. Used by `UserProfile.fromUserProfileFound` to
  /// drive newest-wins cache merges instead of a synthetic `DateTime.now()`.
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileData &&
        other.pubkey == pubkey &&
        other.name == name &&
        other.displayName == displayName &&
        other.about == about &&
        other.picture == picture &&
        other.banner == banner &&
        other.website == website &&
        other.nip05 == nip05 &&
        other.lud16 == lud16 &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    pubkey,
    name,
    displayName,
    about,
    picture,
    banner,
    website,
    nip05,
    lud16,
    createdAt,
  );

  @override
  String toString() =>
      'UserProfileData(pubkey: $pubkey, name: $name, '
      'displayName: $displayName)';
}

/// Social graph counts (follower/following) from the `social` sub-object.
@immutable
class ProfileSocialData {
  const ProfileSocialData({
    required this.followerCount,
    required this.followingCount,
  });

  factory ProfileSocialData.fromJson(Map<String, dynamic> json) {
    return ProfileSocialData(
      followerCount: parseIntSafe(json['follower_count']),
      followingCount: parseIntSafe(json['following_count']),
    );
  }

  final int followerCount;
  final int followingCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileSocialData &&
        other.followerCount == followerCount &&
        other.followingCount == followingCount;
  }

  @override
  int get hashCode => Object.hash(followerCount, followingCount);

  @override
  String toString() =>
      'ProfileSocialData(followerCount: $followerCount, '
      'followingCount: $followingCount)';
}

/// Content statistics from the `stats` sub-object.
@immutable
class ProfileStatsData {
  const ProfileStatsData({
    required this.videoCount,
    required this.reactionCount,
    this.verticalVideos = 0,
  });

  factory ProfileStatsData.fromJson(Map<String, dynamic> json) {
    return ProfileStatsData(
      videoCount: parseIntSafe(json['video_count']),
      reactionCount: parseIntSafe(json['reaction_count']),
      verticalVideos: parseIntSafe(json['vertical_videos']),
    );
  }

  /// Every video the author has posted, whatever its orientation.
  ///
  /// Divine only ever renders the vertical ones, so prefer
  /// [verticalVideos] for anything a viewer can count on screen.
  final int videoCount;

  final int reactionCount;

  /// The subset of [videoCount] that Divine can show.
  final int verticalVideos;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileStatsData &&
        other.videoCount == videoCount &&
        other.reactionCount == reactionCount &&
        other.verticalVideos == verticalVideos;
  }

  @override
  int get hashCode => Object.hash(videoCount, reactionCount, verticalVideos);

  @override
  String toString() =>
      'ProfileStatsData(videoCount: $videoCount, '
      'reactionCount: $reactionCount, '
      'verticalVideos: $verticalVideos)';
}

/// Engagement totals from the `engagement` sub-object.
@immutable
class ProfileEngagementData {
  const ProfileEngagementData({
    required this.totalReactions,
    required this.totalLoops,
    required this.totalViews,
  });

  factory ProfileEngagementData.fromJson(Map<String, dynamic> json) {
    return ProfileEngagementData(
      totalReactions: parseIntSafe(json['total_reactions']),
      totalLoops: parseDoubleSafe(json['total_loops']),
      totalViews: parseIntSafe(json['total_views']),
    );
  }

  final int totalReactions;
  final double totalLoops;
  final int totalViews;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileEngagementData &&
        other.totalReactions == totalReactions &&
        other.totalLoops == totalLoops &&
        other.totalViews == totalViews;
  }

  @override
  int get hashCode => Object.hash(totalReactions, totalLoops, totalViews);

  @override
  String toString() =>
      'ProfileEngagementData(totalReactions: $totalReactions, '
      'totalLoops: $totalLoops, totalViews: $totalViews)';
}
