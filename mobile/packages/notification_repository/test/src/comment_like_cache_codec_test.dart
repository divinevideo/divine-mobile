// ABOUTME: Rejects corrupted grouped-comment cache entries.
// ABOUTME: Keeps malformed cached groups from breaking feed hydration.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:notification_repository/src/comment_like_cache_codec.dart';
import 'package:test/test.dart';

void main() {
  final pubkey = 'a' * 64;
  Map<String, Object?> payload() => {
    'version': 1,
    'commentEventId': 'c' * 64,
    'actorPubkeys': [pubkey, 'b' * 64, pubkey],
    'notificationIds': ['like-1', 'like-2', 'like-1'],
    'sourceEventIds': ['d' * 64, 'e' * 64],
    'commentText': 'same comment',
  };
  NotificationRow row(String content) => NotificationRow(
    id: 'like-1',
    type: CommentLikeCacheCodec.type,
    fromPubkey: pubkey,
    timestamp: 1700000000,
    targetEventId: 'c' * 64,
    hasCommentTarget: true,
    isRead: false,
    cachedAt: DateTime(2026),
    content: content,
  );

  group(CommentLikeCacheCodec, () {
    group('decode', () {
      test('deduplicates cache membership while preserving order', () {
        final group = CommentLikeCacheCodec.decode(row(jsonEncode(payload())))!;
        expect(group.actors.map((actor) => actor.pubkey), [pubkey, 'b' * 64]);
        expect(group.notificationIds, ['like-1', 'like-2']);
      });

      test('invalid payloads are skipped instead of breaking hydration', () {
        final invalid = [
          '{broken',
          'null',
          '[]',
          for (final change in <Map<String, Object?>>[
            {'version': 2},
            {'commentEventId': ''},
            {'actorPubkeys': <String>[]},
            {
              'actorPubkeys': [pubkey, 42],
            },
            {
              'notificationIds': ['unrelated'],
            },
            {'sourceEventIds': 'invalid'},
            {'commentText': 42},
          ])
            jsonEncode({...payload(), ...change}),
        ];
        for (final content in invalid) {
          expect(CommentLikeCacheCodec.decode(row(content)), isNull);
        }
      });
    });
  });
}
