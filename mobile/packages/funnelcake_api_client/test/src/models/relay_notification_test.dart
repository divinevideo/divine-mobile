import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('RelayNotification', () {
    group('fromJson', () {
      test('parses valid notification JSON', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'content': '+',
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.id, equals('notif_123'));
        expect(notification.sourcePubkey, equals('aabbccdd' * 8));
        expect(notification.sourceEventId, equals('11223344' * 8));
        expect(notification.sourceKind, equals(7));
        expect(notification.referencedEventId, equals('55667788' * 8));
        expect(notification.notificationType, equals('reaction'));
        expect(notification.read, isFalse);
        expect(notification.content, equals('+'));
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.referencedEventId, isNull);
        expect(notification.referencedEventKind, isNull);
        expect(notification.content, isNull);
        expect(notification.isReferencedVideo, isFalse);
        expect(notification.referencedVideoTitle, isNull);
      });

      test('parses referenced_event_kind', () {
        final notification = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_event_kind': 16,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        });

        expect(notification.referencedEventKind, equals(16));
      });

      test('flags video target when referenced_video is populated', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_video': {
            'title': 'My funny vine',
            'thumbnail': 'https://example.com/thumb.jpg',
          },
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.isReferencedVideo, isTrue);
        expect(notification.referencedVideoTitle, equals('My funny vine'));
      });

      test('reports non-video target when referenced_video is absent (like '
          'on a comment)', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.isReferencedVideo, isFalse);
        expect(notification.referencedVideoTitle, isNull);
      });

      test(
        'falls back to referenced_event_title when referenced_video is null',
        () {
          final json = {
            'id': 'notif_123',
            'source_pubkey': 'aabbccdd' * 8,
            'source_event_id': '11223344' * 8,
            'source_kind': 7,
            'referenced_event_id': '55667788' * 8,
            'referenced_event_title': 'Top-level title',
            'notification_type': 'reaction',
            'created_at': 1712345678,
            'read': false,
          };

          final notification = RelayNotification.fromJson(json);

          expect(notification.isReferencedVideo, isFalse);
          expect(notification.referencedVideoTitle, equals('Top-level title'));
        },
      );

      test('parses d_tag from referenced_video.d_tag', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_video': {
            'title': 'My vine',
            'thumbnail': 'https://example.com/thumb.jpg',
            'd_tag': 'vine-stable-id',
          },
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.referencedDTag, equals('vine-stable-id'));
        expect(
          notification.referencedVideoThumbnail,
          equals('https://example.com/thumb.jpg'),
        );
      });

      test('falls back to top-level referenced_d_tag when '
          'referenced_video is absent', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_d_tag': 'top-level-dtag',
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.referencedDTag, equals('top-level-dtag'));
        expect(notification.isReferencedVideo, isFalse);
      });

      test(
        'prefers referenced_video.d_tag over top-level referenced_d_tag',
        () {
          final json = {
            'id': 'notif_123',
            'source_pubkey': 'aabbccdd' * 8,
            'source_event_id': '11223344' * 8,
            'source_kind': 7,
            'referenced_event_id': '55667788' * 8,
            'referenced_video': {'title': 'My vine', 'd_tag': 'nested-dtag'},
            'referenced_d_tag': 'top-level-dtag',
            'notification_type': 'reaction',
            'created_at': 1712345678,
            'read': false,
          };

          final notification = RelayNotification.fromJson(json);

          expect(notification.referencedDTag, equals('nested-dtag'));
        },
      );

      test('treats empty referenced_d_tag as null', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_d_tag': '',
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.referencedDTag, isNull);
      });

      test('parses list_add list context', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 30005,
          'referenced_event_id': '55667788' * 8,
          'notification_type': 'list_add',
          'created_at': 1712345678,
          'read': false,
          'list_title': 'Literature',
          'list_coordinate': '30005:${'aabbccdd' * 8}:literature',
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.listTitle, equals('Literature'));
        expect(
          notification.listCoordinate,
          equals('30005:${'aabbccdd' * 8}:literature'),
        );
      });

      test('treats absent and empty list_add context as null', () {
        final absent = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 30005,
          'notification_type': 'list_add',
          'created_at': 1712345678,
          'read': false,
        });
        final empty = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 30005,
          'notification_type': 'list_add',
          'created_at': 1712345678,
          'read': false,
          'list_title': '',
          'list_coordinate': '',
        });

        expect(absent.listTitle, isNull);
        expect(absent.listCoordinate, isNull);
        expect(empty.listTitle, isNull);
        expect(empty.listCoordinate, isNull);
      });

      test('parses thumbnail from referenced_video.thumbnail', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_video': {
            'thumbnail': 'https://cdn.example.com/thumb.jpg',
          },
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(
          notification.referencedVideoThumbnail,
          equals('https://cdn.example.com/thumb.jpg'),
        );
      });

      test('falls back to referenced_event_thumbnail when '
          'referenced_video is absent', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_event_thumbnail': 'https://cdn.example.com/fallback.jpg',
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(
          notification.referencedVideoThumbnail,
          equals('https://cdn.example.com/fallback.jpg'),
        );
        expect(notification.isReferencedVideo, isFalse);
      });

      test('treats empty referenced_video.thumbnail as null thumbnail', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_video': {'thumbnail': ''},
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.referencedVideoThumbnail, isNull);
      });

      test('treats empty referenced_video.title as null title', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_video': {'title': ''},
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.isReferencedVideo, isTrue);
        expect(notification.referencedVideoTitle, isNull);
      });

      test('handles missing fields with defaults', () {
        final notification = RelayNotification.fromJson(<String, dynamic>{});

        expect(notification.id, equals(''));
        expect(notification.sourcePubkey, equals(''));
        expect(notification.sourceEventId, equals(''));
        expect(notification.sourceKind, equals(0));
        expect(notification.notificationType, equals(''));
        expect(notification.read, isFalse);
      });

      test('converts created_at unix seconds to DateTime', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(
          notification.createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(1712345678 * 1000)),
        );
      });

      test('prefers source_created_at over notification row created_at', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 1111,
          'notification_type': 'comment',
          'source_created_at': 1712000000,
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(
          notification.createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(1712000000 * 1000)),
        );
      });

      test('parses integer read flags from notifications API', () {
        final unreadJson = {
          'id': 'notif_unread',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 1111,
          'notification_type': 'comment',
          'created_at': 1712345678,
          'read': 0,
        };
        final readJson = {...unreadJson, 'id': 'notif_read', 'read': 1};

        expect(RelayNotification.fromJson(unreadJson).read, isFalse);
        expect(RelayNotification.fromJson(readJson).read, isTrue);
      });

      test('parses staging NIP-22 comment anchor fields', () {
        final json = {
          'id': '',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 1111,
          'referenced_event_id': '',
          'notification_type': 'mention',
          'created_at': 1712345678,
          'read': false,
          'content': 'Fake staging comment from Codex',
          'referenced_event_title': 'Codex staging comment notification test',
          'target_comment_id': '11223344' * 8,
          'root_event_id': '55667788' * 8,
          'root_event_kind': 34236,
          'root_d_tag': 'root-d-tag',
          'root_addressable_id': '34236:${'aabbccdd' * 8}:root-d-tag',
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.referencedEventId, equals(''));
        expect(notification.rootEventId, equals('55667788' * 8));
        expect(notification.rootEventKind, equals(34236));
        expect(notification.rootDTag, equals('root-d-tag'));
        expect(
          notification.rootAddressableId,
          equals('34236:${'aabbccdd' * 8}:root-d-tag'),
        );
        expect(notification.targetCommentId, equals('11223344' * 8));
        expect(
          notification.referencedVideoTitle,
          equals('Codex staging comment notification test'),
        );
      });

      test('parses comment_content as the liked comment body', () {
        // A reaction on a comment: `content` is the reaction emoji, and
        // `comment_content` carries the body of the comment that was
        // liked — the only context a "liked your comment" row can show.
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'content': '+',
          'target_comment_id': '55667788' * 8,
          'comment_content': 'this vine still holds up',
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.content, equals('+'));
        expect(
          notification.commentContent,
          equals('this vine still holds up'),
        );
      });

      test('treats empty comment_content as null', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'comment_content': '',
        };

        expect(RelayNotification.fromJson(json).commentContent, isNull);
      });

      test('leaves comment_content null when the server omits it', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        expect(RelayNotification.fromJson(json).commentContent, isNull);
      });

      test('treats empty root coordinate fields as null', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 1111,
          'notification_type': 'mention',
          'created_at': 1712345678,
          'read': false,
          'root_event_id': '',
          'root_event_kind': '',
          'root_d_tag': '',
          'root_addressable_id': '',
          'target_comment_id': '',
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.rootEventId, isNull);
        expect(notification.rootEventKind, isNull);
        expect(notification.rootDTag, isNull);
        expect(notification.rootAddressableId, isNull);
        expect(notification.targetCommentId, isNull);
      });

      test('parses root_event_pubkey (root video author)', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'root_event_pubkey': 'deadbeef' * 8,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.rootEventPubkey, equals('deadbeef' * 8));
      });

      test('lowercases root_event_pubkey', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'root_event_pubkey': 'DEADBEEF' * 8,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.rootEventPubkey, equals('deadbeef' * 8));
      });

      test('parses root_addressable_id', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'root_addressable_id': '34236:${'deadbeef' * 8}:root-d-tag',
        };

        final notification = RelayNotification.fromJson(json);

        expect(
          notification.rootAddressableId,
          equals('34236:${'deadbeef' * 8}:root-d-tag'),
        );
      });

      test('treats empty or absent root_event_pubkey as null', () {
        final absent = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        });
        final empty = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'root_event_pubkey': '',
        });

        expect(absent.rootEventPubkey, isNull);
        expect(empty.rootEventPubkey, isNull);
      });

      test('treats empty or absent root_addressable_id as null', () {
        final absent = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        });
        final empty = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'root_addressable_id': '',
        });

        expect(absent.rootAddressableId, isNull);
        expect(empty.rootAddressableId, isNull);
      });
    });

    group('dedupeKey', () {
      test('uses id when present', () {
        final notification = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        });

        expect(notification.dedupeKey, equals('notif_123'));
      });

      test('falls back to sourceEventId when id is empty', () {
        final notification = RelayNotification.fromJson({
          'id': '',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        });

        expect(notification.dedupeKey, equals('11223344' * 8));
      });
    });
  });
}
