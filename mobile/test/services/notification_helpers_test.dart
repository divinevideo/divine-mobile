// ABOUTME: Tests for notification payload helper functions.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/notification_helpers.dart';

void main() {
  group('parseAddressableId', () {
    test('parses valid addressable ID into components', () {
      final result = parseAddressableId('34236:abc123pubkey:my-video-id');

      expect(result, isNotNull);
      expect(result!.kind, equals(34236));
      expect(result.pubkey, equals('abc123pubkey'));
      expect(result.dTag, equals('my-video-id'));
    });

    test('handles d-tag containing colons', () {
      final result = parseAddressableId('34236:pubkey123:d-tag:with:colons');

      expect(result, isNotNull);
      expect(result!.kind, equals(34236));
      expect(result.pubkey, equals('pubkey123'));
      expect(result.dTag, equals('d-tag:with:colons'));
    });

    test('returns null for invalid format with less than 3 parts', () {
      expect(parseAddressableId('34236:pubkey'), isNull);
      expect(parseAddressableId('34236'), isNull);
      expect(parseAddressableId(''), isNull);
    });

    test('returns null when kind is not a number', () {
      final result = parseAddressableId('notanumber:pubkey:dtag');

      expect(result, isNull);
    });

    test('parses kind 30023 long-form content correctly', () {
      final result = parseAddressableId('30023:pubkey:blog-post-slug');

      expect(result, isNotNull);
      expect(result!.kind, equals(30023));
      expect(result.pubkey, equals('pubkey'));
      expect(result.dTag, equals('blog-post-slug'));
    });

    test('handles empty d-tag', () {
      final result = parseAddressableId('34236:pubkey:');

      expect(result, isNotNull);
      expect(result!.kind, equals(34236));
      expect(result.pubkey, equals('pubkey'));
      expect(result.dTag, isEmpty);
    });
  });

  group('parseFcmPayload', () {
    test('returns null when the payload carries nothing routable', () {
      expect(parseFcmPayload(const {}), isNull);
      // A type with no event id and no sender pubkey is not routable.
      expect(parseFcmPayload(const {'type': 'like'}), isNull);
      expect(parseFcmPayload(const {'referencedEventId': ''}), isNull);
    });

    test('parses a campaign payload without a Nostr event target', () {
      final result = parseFcmPayload(const {
        'type': 'campaign',
        'category': 'engagement',
        'title': 'New videos',
        'body': 'See what people made.',
        'campaignRevisionId': 'revision-1',
        'tapTargetType': 'app_route',
        'tapTargetValue': '/following/new',
      });

      expect(result, isNotNull);
      expect(result!.notificationType, equals('campaign'));
      expect(result.tapTargetType, equals('app_route'));
      expect(result.tapTargetValue, equals('/following/new'));
      expect(result.eventId, isNull);
      expect(result.senderPubkey, isNull);
    });

    test('parses a like payload (referencedEventId + sender)', () {
      final result = parseFcmPayload(const {
        'type': 'like',
        'eventId': 'reaction_event',
        'referencedEventId': 'video_event',
        'senderPubkey': 'actor_hex',
      });

      expect(result, isNotNull);
      expect(result!.notificationType, equals('like'));
      expect(result.referencedEventId, equals('video_event'));
      expect(result.eventId, equals('reaction_event'));
      expect(result.senderPubkey, equals('actor_hex'));
    });

    test('parses a follow payload via senderPubkey (no referencedEventId)', () {
      // The push service sends follows with senderPubkey + eventId but no
      // referencedEventId — these must no longer be dropped.
      final result = parseFcmPayload(const {
        'type': 'follow',
        'eventId': 'contact_list_event',
        'senderPubkey': 'follower_hex',
      });

      expect(result, isNotNull);
      expect(result!.notificationType, equals('follow'));
      expect(result.referencedEventId, isNull);
      expect(result.senderPubkey, equals('follower_hex'));
      expect(result.eventId, equals('contact_list_event'));
    });

    test('parses a mention payload via eventId (no referencedEventId)', () {
      final result = parseFcmPayload(const {
        'type': 'mention',
        'eventId': 'mention_note',
        'senderPubkey': 'mentioner_hex',
      });

      expect(result, isNotNull);
      expect(result!.referencedEventId, isNull);
      expect(result.eventId, equals('mention_note'));
      expect(result.senderPubkey, equals('mentioner_hex'));
    });

    test('notificationType is null when absent', () {
      final result = parseFcmPayload(const {'eventId': 'evt'});

      expect(result, isNotNull);
      expect(result!.notificationType, isNull);
    });

    test('reads the FCM wire key "type"', () {
      final result = parseFcmPayload(const {
        'referencedEventId': 'event_abc',
        'type': 'comment',
      });

      expect(result!.notificationType, equals('comment'));
    });

    test('reads the local notification JSON key "notificationType"', () {
      final result = parseFcmPayload(const {
        'referencedEventId': 'event_abc',
        'notificationType': 'comment',
      });

      expect(result!.notificationType, equals('comment'));
    });

    test('prefers the FCM wire key when both type fields are present', () {
      final result = parseFcmPayload(const {
        'referencedEventId': 'event_abc',
        'type': 'mention',
        'notificationType': 'comment',
      });

      expect(result!.notificationType, equals('mention'));
    });

    test('preserves the full referenced event id without truncation', () {
      const fullEventId =
          '7c4d2eaa1c5f4f0e8b2d1aabcdef1234567890abcdef1234567890abcdef1234';

      final result = parseFcmPayload(const {
        'referencedEventId': fullEventId,
        'type': 'like',
        'senderPubkey': 'actor',
      });

      expect(result!.referencedEventId, equals(fullEventId));
    });

    test('parses each push-service notification kind', () {
      // The push service emits a lowercase five-value vocabulary.
      const kinds = ['like', 'comment', 'follow', 'mention', 'repost'];
      for (final kind in kinds) {
        final result = parseFcmPayload({
          'type': kind,
          'eventId': 'evt_$kind',
          'senderPubkey': 'actor_$kind',
        });

        expect(result, isNotNull, reason: '$kind payload should parse');
        expect(result!.notificationType, equals(kind));
      }
    });

    test('ignores unrelated keys in the payload', () {
      final result = parseFcmPayload(const {
        'referencedEventId': 'evt1',
        'type': 'like',
        'extra': 'ignored',
        'aps': {'badge': 5},
      });

      expect(result!.referencedEventId, equals('evt1'));
      expect(result.notificationType, equals('like'));
    });

    test('parses the authoritative referencedAddress coordinate', () {
      // The push service emits the signed a/A-tag coordinate so the client can
      // route to the stable NIP-33 address without walking the event.
      final result = parseFcmPayload(const {
        'type': 'like',
        'eventId': 'reaction_event',
        'referencedEventId': 'video_event',
        'referencedAddress': '34236:owner_hex:my-vine-id',
        'senderPubkey': 'actor_hex',
      });

      expect(result, isNotNull);
      expect(result!.referencedAddress, equals('34236:owner_hex:my-vine-id'));
    });

    test('referencedAddress is null when absent', () {
      final result = parseFcmPayload(const {
        'type': 'like',
        'referencedEventId': 'video_event',
        'senderPubkey': 'actor_hex',
      });

      expect(result, isNotNull);
      expect(result!.referencedAddress, isNull);
    });

    test('referencedAddress empty string normalizes to null', () {
      final result = parseFcmPayload(const {
        'type': 'like',
        'referencedEventId': 'video_event',
        'referencedAddress': '',
        'senderPubkey': 'actor_hex',
      });

      expect(result!.referencedAddress, isNull);
    });

    test('preserves a colon-containing d-tag in referencedAddress', () {
      final result = parseFcmPayload(const {
        'type': 'comment',
        'referencedEventId': 'comment_event',
        'referencedAddress': '34236:owner_hex:weird:d:tag',
        'senderPubkey': 'actor_hex',
      });

      expect(result!.referencedAddress, equals('34236:owner_hex:weird:d:tag'));
    });

    test('a payload carrying only referencedAddress is routable', () {
      // The coordinate alone is a valid video target, so it must not be
      // dropped as unroutable.
      final result = parseFcmPayload(const {
        'referencedAddress': '34236:owner_hex:vine-id',
      });

      expect(result, isNotNull);
      expect(result!.referencedAddress, equals('34236:owner_hex:vine-id'));
    });
  });

  group('localNotificationTapPayload', () {
    test('maps FCM type to notificationType and preserves routing fields', () {
      final payload = localNotificationTapPayload(const {
        'type': 'comment',
        'eventId': 'comment_event',
        'referencedEventId': 'video_event',
        'referencedAddress': '34236:owner_hex:my-vine-id',
        'senderPubkey': 'actor_hex',
        'title': 'New comment',
        'body': 'ignored for routing',
      });

      expect(payload, {
        'referencedEventId': 'video_event',
        'referencedAddress': '34236:owner_hex:my-vine-id',
        'eventId': 'comment_event',
        'notificationType': 'comment',
        'senderPubkey': 'actor_hex',
      });
    });

    test('preserves a campaign app-route target', () {
      final payload = localNotificationTapPayload(const {
        'type': 'campaign',
        'tapTargetType': 'app_route',
        'tapTargetValue': '/following/new',
      });

      expect(payload['notificationType'], equals('campaign'));
      expect(payload['tapTargetType'], equals('app_route'));
      expect(payload['tapTargetValue'], equals('/following/new'));
    });

    test('preserves senderPubkey for a follow with no referencedEventId', () {
      final payload = localNotificationTapPayload(const {
        'type': 'follow',
        'eventId': 'contact_event',
        'senderPubkey': 'follower_hex',
      });

      expect(payload['notificationType'], equals('follow'));
      expect(payload['senderPubkey'], equals('follower_hex'));
      expect(payload['eventId'], equals('contact_event'));
      expect(payload['referencedEventId'], isNull);
    });

    test('normalizes empty-string routing fields to null', () {
      final payload = localNotificationTapPayload(const {
        'type': 'like',
        'eventId': 'like_event',
        // An empty referencedEventId on the wire must not survive as '' on the
        // local payload; the writer shares parseFcmPayload's normalization, so
        // empty and absent are treated identically.
        'referencedEventId': '',
        'senderPubkey': 'actor_hex',
      });

      expect(payload['referencedEventId'], isNull);
      expect(payload['eventId'], equals('like_event'));
      expect(payload['notificationType'], equals('like'));
      expect(payload['senderPubkey'], equals('actor_hex'));
    });

    test('preserves the authoritative referencedAddress coordinate', () {
      final payload = localNotificationTapPayload(const {
        'type': 'like',
        'eventId': 'reaction_event',
        'referencedEventId': 'video_event',
        'referencedAddress': '34236:owner_hex:my-vine-id',
        'senderPubkey': 'actor_hex',
      });

      expect(
        payload['referencedAddress'],
        equals('34236:owner_hex:my-vine-id'),
      );
    });
  });
}
