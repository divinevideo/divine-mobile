import 'package:equatable/equatable.dart';

/// User preferences for push notification types.
///
/// Maps to kind 3083 events per the NIP-XX push notification draft.
/// The push service uses the kinds list to filter which notification
/// types to deliver via FCM.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.likesEnabled = true,
    this.commentsEnabled = true,
    this.followsEnabled = true,
    this.mentionsEnabled = true,
    this.repostsEnabled = true,
    this.newPostsEnabled = true,
    this.campaignsEnabled = false,
  });

  /// Create preferences from a list of enabled Nostr event kinds.
  ///
  /// Kind mapping:
  /// - 7: reactions (likes)
  /// - 1: text notes (comments and mentions)
  /// - 3: contact list (follows)
  /// - 16: reposts
  /// - 34236: videos from creators the user subscribed to ("bells")
  ///
  /// Comments and mentions both use kind 1. When kind 1 is present,
  /// both are enabled. When absent, both are disabled.
  /// Known limitation: the push service filters by kind number only,
  /// so comments and mentions cannot be toggled independently.
  ///
  /// Preferences published before bells shipped carry no 34236, so
  /// [newPostsEnabled] reads back `false` for them. That is self-healing:
  /// opening the settings screen or setting the first bell republishes with
  /// 34236 included.
  factory NotificationPreferences.fromKindsList(List<int> kinds) {
    return NotificationPreferences(
      likesEnabled: kinds.contains(7),
      commentsEnabled: kinds.contains(1),
      followsEnabled: kinds.contains(3),
      mentionsEnabled: kinds.contains(1),
      repostsEnabled: kinds.contains(16),
      newPostsEnabled: kinds.contains(newPostKind),
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      likesEnabled: json['likesEnabled'] as bool? ?? true,
      commentsEnabled: json['commentsEnabled'] as bool? ?? true,
      followsEnabled: json['followsEnabled'] as bool? ?? true,
      mentionsEnabled: json['mentionsEnabled'] as bool? ?? true,
      repostsEnabled: json['repostsEnabled'] as bool? ?? true,
      newPostsEnabled: json['newPostsEnabled'] as bool? ?? true,
      campaignsEnabled: json['campaignsEnabled'] as bool? ?? false,
    );
  }

  /// Nostr kind for Divine video events, used to gate new-post pushes.
  ///
  /// Distinct from kind 1, so muting mentions does not mute new-post pushes
  /// even though video mentions also arrive on kind 34236 events.
  static const int newPostKind = 34236;

  final bool likesEnabled;
  final bool commentsEnabled;
  final bool followsEnabled;
  final bool mentionsEnabled;
  final bool repostsEnabled;

  /// Whether to receive a push when a subscribed creator posts a new video.
  final bool newPostsEnabled;

  /// Whether the user explicitly opted into engagement campaign pushes.
  final bool campaignsEnabled;

  /// Convert to the kinds list format expected by the push service.
  ///
  /// Returns deduplicated list of Nostr event kinds.
  List<int> toKindsList() {
    final kinds = <int>{};
    if (likesEnabled) kinds.add(7);
    if (commentsEnabled || mentionsEnabled) kinds.add(1);
    if (followsEnabled) kinds.add(3);
    if (repostsEnabled) kinds.add(16);
    if (newPostsEnabled) kinds.add(newPostKind);
    return kinds.toList()..sort();
  }

  Map<String, dynamic> toJson() {
    return {
      'likesEnabled': likesEnabled,
      'commentsEnabled': commentsEnabled,
      'followsEnabled': followsEnabled,
      'mentionsEnabled': mentionsEnabled,
      'repostsEnabled': repostsEnabled,
      'newPostsEnabled': newPostsEnabled,
      'campaignsEnabled': campaignsEnabled,
    };
  }

  NotificationPreferences copyWith({
    bool? likesEnabled,
    bool? commentsEnabled,
    bool? followsEnabled,
    bool? mentionsEnabled,
    bool? repostsEnabled,
    bool? newPostsEnabled,
    bool? campaignsEnabled,
  }) {
    return NotificationPreferences(
      likesEnabled: likesEnabled ?? this.likesEnabled,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      followsEnabled: followsEnabled ?? this.followsEnabled,
      mentionsEnabled: mentionsEnabled ?? this.mentionsEnabled,
      repostsEnabled: repostsEnabled ?? this.repostsEnabled,
      newPostsEnabled: newPostsEnabled ?? this.newPostsEnabled,
      campaignsEnabled: campaignsEnabled ?? this.campaignsEnabled,
    );
  }

  @override
  List<Object?> get props => [
    likesEnabled,
    commentsEnabled,
    followsEnabled,
    mentionsEnabled,
    repostsEnabled,
    newPostsEnabled,
    campaignsEnabled,
  ];
}
