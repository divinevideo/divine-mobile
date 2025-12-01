// ABOUTME: Social state model for managing likes, follows, reposts and social metrics
// ABOUTME: Used by Riverpod SocialProvider to manage reactive social interaction state

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nostr_sdk/event.dart';

part 'social_state.freezed.dart';
part 'social_state.g.dart';

@freezed
sealed class SocialState with _$SocialState {
  const factory SocialState({
    // Like-related state
    @Default({}) Set<String> likedEventIds,
    @Default({})
    Map<String, int>
    likeCounts, // NEW likes from Nostr only (add to originalLikes for total)
    @Default({}) Map<String, String> likeEventIdToReactionId,

    // Repost-related state
    @Default({}) Set<String> repostedEventIds,
    @Default({}) Map<String, String> repostEventIdToRepostId,

    // Follow-related state
    @Default([]) List<String> followingPubkeys,
    @Default({}) Map<String, Map<String, int>> followerStats,
    Event? currentUserContactListEvent,

    // Loading and error state
    @Default(false) bool isLoading,
    @Default(false) bool isInitialized,
    String? error,

    // Operation-specific loading states
    @Default({}) Set<String> likesInProgress,
    @Default({}) Set<String> repostsInProgress,
    @Default({}) Set<String> followsInProgress,
  }) = _SocialState;

  factory SocialState.fromJson(Map<String, dynamic> json) =>
      _$SocialStateFromJson(json);

  const SocialState._();

  /// Create initial state
  static final SocialState initial = SocialState();

  /// Check if user has liked an event
  bool isLiked(String eventId) => likedEventIds.contains(eventId);

  /// Check if user has reposted an event
  bool hasReposted(String eventId) => repostedEventIds.contains(eventId);

  /// Check if user is following another user
  bool isFollowing(String pubkey) => followingPubkeys.contains(pubkey);

  /// Check if a like operation is in progress
  bool isLikeInProgress(String eventId) => likesInProgress.contains(eventId);

  /// Check if a repost operation is in progress
  bool isRepostInProgress(String eventId) =>
      repostsInProgress.contains(eventId);

  /// Check if a follow operation is in progress
  bool isFollowInProgress(String pubkey) => followsInProgress.contains(pubkey);
}
