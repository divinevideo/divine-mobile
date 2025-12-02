// ABOUTME: Parser for converting Nostr events into NotificationModel instances
// ABOUTME: Pure business logic without external dependencies for easy testing

import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/notification_helpers.dart';

/// Parses Nostr events into notification models
/// This class contains pure business logic and has no external dependencies
class NotificationEventParser {
  /// Parse a reaction (like) event into a notification
  /// Returns null if the event is not a valid like or missing required data
  NotificationModel? parseReactionEvent(
    Event event, {
    required UserProfile? actorProfile,
    required VideoEvent? videoEvent,
  }) {
    // Check if this is a like (+ reaction)
    if (event.content != '+') return null;

    // Get the video that was liked
    final videoEventId = extractVideoEventId(event);
    if (videoEventId == null) return null;

    // Resolve actor name
    final actorName = resolveActorName(actorProfile);

    return NotificationModel(
      id: event.id,
      type: NotificationType.like,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName liked your video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      targetEventId: videoEventId,
      targetVideoUrl: videoEvent?.videoUrl,
      targetVideoThumbnail: videoEvent?.thumbnailUrl,
    );
  }

  /// Parse a comment event into a notification
  /// Returns null if the event is missing required data
  NotificationModel? parseCommentEvent(
    Event event, {
    required UserProfile? actorProfile,
    required VideoEvent? videoEvent,
  }) {
    // Check if this is a reply to a video
    final videoEventId = extractVideoEventId(event);
    if (videoEventId == null) return null;

    // Resolve actor name
    final actorName = resolveActorName(actorProfile);

    return NotificationModel(
      id: event.id,
      type: NotificationType.comment,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName commented on your video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      targetEventId: videoEventId,
      targetVideoUrl: videoEvent?.videoUrl,
      targetVideoThumbnail: videoEvent?.thumbnailUrl,
      metadata: {'comment': event.content},
    );
  }

  /// Parse a follow event into a notification
  NotificationModel parseFollowEvent(
    Event event, {
    required UserProfile? actorProfile,
  }) {
    // Resolve actor name
    final actorName = resolveActorName(actorProfile);

    return NotificationModel(
      id: event.id,
      type: NotificationType.follow,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName started following you',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
    );
  }

  /// Parse a mention event into a notification
  NotificationModel parseMentionEvent(
    Event event, {
    required UserProfile? actorProfile,
  }) {
    // Resolve actor name
    final actorName = resolveActorName(actorProfile);

    return NotificationModel(
      id: event.id,
      type: NotificationType.mention,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName mentioned you',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      metadata: {'text': event.content},
    );
  }

  /// Parse a repost event into a notification
  /// Returns null if the event is missing required data
  NotificationModel? parseRepostEvent(
    Event event, {
    required UserProfile? actorProfile,
    required VideoEvent? videoEvent,
  }) {
    // Get the video that was reposted
    final videoEventId = extractVideoEventId(event);
    if (videoEventId == null) return null;

    // Resolve actor name
    final actorName = resolveActorName(actorProfile);

    return NotificationModel(
      id: event.id,
      type: NotificationType.repost,
      actorPubkey: event.pubkey,
      actorName: actorName,
      actorPictureUrl: actorProfile?.picture,
      message: '$actorName reposted your video',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      targetEventId: videoEventId,
      targetVideoUrl: videoEvent?.videoUrl,
      targetVideoThumbnail: videoEvent?.thumbnailUrl,
    );
  }
}
