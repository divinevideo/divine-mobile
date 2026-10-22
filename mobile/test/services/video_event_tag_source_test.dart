// ABOUTME: Tests for recovering raw Nostr tags before video republishing.
// ABOUTME: Covers JSON-rehydrated VideoEvent copies that lost nostrEventTags.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_tag_source.dart';

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

void main() {
  group('sourceOriginalVideoTags', () {
    const eventId = 'event-id';
    const pubkey =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    final tags = <List<String>>[
      ['d', 'video-id'],
      ['title', 'Original title'],
    ];

    VideoEvent videoWithTags() => VideoEvent(
      id: eventId,
      pubkey: pubkey,
      createdAt: 1700000000,
      content: 'caption',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      nostrEventTags: tags,
    );

    VideoEvent videoWithoutTags() => VideoEvent(
      id: eventId,
      pubkey: pubkey,
      createdAt: 1700000000,
      content: 'caption',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    test('returns tags already present on the video', () {
      final cache = _MockPersonalEventCacheService();

      final result = sourceOriginalVideoTags(
        video: videoWithTags(),
        personalEventCache: cache,
      );

      expect(result, tags);
      verifyNever(() => cache.getEventById(any()));
    });

    test('recovers tags from the personal cache when video tags are empty', () {
      final cache = _MockPersonalEventCacheService();
      final cachedEvent = Event(pubkey, 32222, tags, 'caption');
      when(() => cache.getEventById(eventId)).thenReturn(cachedEvent);

      final result = sourceOriginalVideoTags(
        video: videoWithoutTags(),
        personalEventCache: cache,
      );

      expect(result, tags);
    });

    test('returns an empty list when no tags can be recovered', () {
      final cache = _MockPersonalEventCacheService();
      when(() => cache.getEventById(eventId)).thenReturn(null);

      final result = sourceOriginalVideoTags(
        video: videoWithoutTags(),
        personalEventCache: cache,
      );

      expect(result, isEmpty);
    });

    test('drops the client tag carried on the video (#8176)', () {
      final cache = _MockPersonalEventCacheService();
      final video = VideoEvent(
        id: eventId,
        pubkey: pubkey,
        createdAt: 1700000000,
        content: 'caption',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        nostrEventTags: [...tags, Nip89ClientTag.tag],
      );

      final result = sourceOriginalVideoTags(
        video: video,
        personalEventCache: cache,
      );

      expect(result, tags);
    });

    test('drops the client tag recovered from the personal cache (#8176)', () {
      final cache = _MockPersonalEventCacheService();
      final cachedEvent = Event(pubkey, 32222, [
        ...tags,
        ['client', 'OtherClient'],
      ], 'caption');
      when(() => cache.getEventById(eventId)).thenReturn(cachedEvent);

      final result = sourceOriginalVideoTags(
        video: videoWithoutTags(),
        personalEventCache: cache,
      );

      expect(result, tags);
    });
  });
}
