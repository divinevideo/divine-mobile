// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SocialState _$SocialStateFromJson(Map<String, dynamic> json) => _SocialState(
  likedEventIds:
      (json['likedEventIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  likeCounts:
      (json['likeCounts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  likeEventIdToReactionId:
      (json['likeEventIdToReactionId'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  commentCounts:
      (json['commentCounts'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  repostedEventIds:
      (json['repostedEventIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  repostEventIdToRepostId:
      (json['repostEventIdToRepostId'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  followingPubkeys:
      (json['followingPubkeys'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  followerStats:
      (json['followerStats'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, Map<String, int>.from(e as Map)),
      ) ??
      const {},
  currentUserContactListEvent: json['currentUserContactListEvent'] == null
      ? null
      : Event.fromJson(
          json['currentUserContactListEvent'] as Map<String, dynamic>,
        ),
  isLoading: json['isLoading'] as bool? ?? false,
  isInitialized: json['isInitialized'] as bool? ?? false,
  error: json['error'] as String?,
  likesInProgress:
      (json['likesInProgress'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  repostsInProgress:
      (json['repostsInProgress'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  followsInProgress:
      (json['followsInProgress'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
);

Map<String, dynamic> _$SocialStateToJson(_SocialState instance) =>
    <String, dynamic>{
      'likedEventIds': instance.likedEventIds.toList(),
      'likeCounts': instance.likeCounts,
      'likeEventIdToReactionId': instance.likeEventIdToReactionId,
      'commentCounts': instance.commentCounts,
      'repostedEventIds': instance.repostedEventIds.toList(),
      'repostEventIdToRepostId': instance.repostEventIdToRepostId,
      'followingPubkeys': instance.followingPubkeys,
      'followerStats': instance.followerStats,
      'currentUserContactListEvent': instance.currentUserContactListEvent,
      'isLoading': instance.isLoading,
      'isInitialized': instance.isInitialized,
      'error': instance.error,
      'likesInProgress': instance.likesInProgress.toList(),
      'repostsInProgress': instance.repostsInProgress.toList(),
      'followsInProgress': instance.followsInProgress.toList(),
    };
