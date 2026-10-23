// ABOUTME: In-app-only decision for notification avatar-stack taps.
// ABOUTME: Keeps avatar affordances separate from row/push notification taps.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart'
    show VideoEngagementType;

/// Destination for tapping the avatar stack on a rendered notification row.
///
/// Unlike [NotificationTapTarget], this contract is only for the in-app avatar
/// affordance. Push/local payloads do not have an avatar stack.
sealed class AvatarStackTapTarget extends Equatable {
  const AvatarStackTapTarget();
}

/// Open the full video engagement list behind a grouped like/repost row.
class OpenEngagementListTarget extends AvatarStackTapTarget {
  const OpenEngagementListTarget({
    required this.eventId,
    required this.type,
    this.addressableId,
  });

  /// Hex id of the target video event.
  final String eventId;

  /// Optional `kind:pubkey:d-tag` for addressable video events.
  final String? addressableId;

  /// Whether to open likers or reposters.
  final VideoEngagementType type;

  @override
  List<Object?> get props => [eventId, addressableId, type];
}

/// Open the actor profile represented by the avatar.
class OpenActorProfileTarget extends AvatarStackTapTarget {
  const OpenActorProfileTarget(this.pubkey);

  /// Hex pubkey of the actor whose profile should open.
  final String pubkey;

  @override
  List<Object?> get props => [pubkey];
}

/// Resolves the avatar-stack tap target for [notification].
///
/// Grouped video likes/reposts open their engagement list. Single-actor rows
/// and all non-engagement notification kinds keep the historical behavior:
/// open the visible actor's profile.
AvatarStackTapTarget? resolveAvatarStackTapTarget(
  NotificationItem notification,
) {
  return switch (notification) {
    VideoNotification(
      type: NotificationKind.like,
      totalCount: > 1,
      :final videoEventId,
      :final videoAddressableId,
    ) =>
      OpenEngagementListTarget(
        eventId: videoEventId,
        addressableId: videoAddressableId,
        type: VideoEngagementType.likers,
      ),
    VideoNotification(
      type: NotificationKind.repost,
      totalCount: > 1,
      :final videoEventId,
      :final videoAddressableId,
    ) =>
      OpenEngagementListTarget(
        eventId: videoEventId,
        addressableId: videoAddressableId,
        type: VideoEngagementType.reposters,
      ),
    VideoNotification(:final actors) when actors.isNotEmpty =>
      OpenActorProfileTarget(actors.first.pubkey),
    ActorNotification(:final actor) => OpenActorProfileTarget(actor.pubkey),
    VideoNotification() || AnnouncementNotification() => null,
  };
}
