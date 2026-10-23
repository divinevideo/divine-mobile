// ABOUTME: Versioned cache payload for comment-like groups.
// ABOUTME: Preserves people and raw read IDs across process restarts.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:models/models.dart';

/// Encodes comment-like membership in a versioned repository cache record.
abstract final class CommentLikeCacheCodec {
  /// Cache discriminator; legacy rows continue using their original types.
  static const type = 'commentLikeGroup';

  /// Serializes all actors and server notification IDs represented by a row.
  static String encode(ActorNotification item) => jsonEncode({
    'version': 1,
    'commentEventId': item.commentEventId,
    'actorPubkeys': item.actors.map((actor) => actor.pubkey).toList(),
    'notificationIds': {...item.notificationIds, item.id}.toList(),
    'sourceEventIds': item.sourceEventIds,
    'commentText': item.commentText,
  });

  /// Discards invalid entries individually, leaving other cache rows usable.
  static ActorNotification? decode(NotificationRow row) {
    final content = row.content;
    if (content == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      return null;
    }
    final commentId = decoded['commentEventId'];
    final commentText = decoded['commentText'];
    final pubkeys = _strings(decoded['actorPubkeys']);
    final notificationIds = _strings(decoded['notificationIds']);
    final sourceEventIds = _strings(decoded['sourceEventIds']);
    if (commentId is! String ||
        commentId.isEmpty ||
        row.targetEventId != commentId ||
        (commentText != null && commentText is! String) ||
        pubkeys == null ||
        pubkeys.isEmpty ||
        pubkeys.first != row.fromPubkey ||
        notificationIds == null ||
        !notificationIds.contains(row.id) ||
        sourceEventIds == null) {
      return null;
    }
    final actors = pubkeys
        .map(
          (pubkey) => ActorInfo(
            pubkey: pubkey,
            displayName: UserProfile.defaultDisplayNameFor(pubkey),
          ),
        )
        .toList();
    return ActorNotification(
      id: row.id,
      type: NotificationKind.likeComment,
      actor: actors.first,
      additionalActors: actors.skip(1).toList(),
      commentEventId: commentId,
      targetEventId: row.targetEventId,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        row.timestamp * 1000,
        isUtc: true,
      ).toLocal(),
      isRead: row.isRead,
      commentText: commentText as String?,
      notificationIds: notificationIds,
      sourceEventIds: sourceEventIds,
      videoAddressableId: row.videoAddressableId,
      hasCommentTarget: row.hasCommentTarget,
    );
  }

  static List<String>? _strings(Object? value) {
    if (value is! List ||
        value.any((item) => item is! String || item.isEmpty)) {
      return null;
    }
    return value.cast<String>().toSet().toList();
  }
}
