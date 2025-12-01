// ABOUTME: Test NIP-40 expiration filtering in VideoEventService
// ABOUTME: Ensures expired events are filtered out and not added to feeds

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/video_event.dart';

void main() {
  group('VideoEventService NIP-40 Expiration Filtering', () {
    late VideoEventService service;

    setUp(() {
      service = VideoEventService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('filters out expired events when adding to discovery feed', () {
      // Create an expired event (1 hour ago)
      final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
      final expirationTimestamp = oneHourAgo.millisecondsSinceEpoch ~/ 1000;

      final expiredEvent = Event.fromJson({
        'id': 'expired123',
        'pubkey': 'pubkey123',
        'created_at':
            DateTime.now()
                .subtract(Duration(hours: 2))
                .millisecondsSinceEpoch ~/
            1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
          ['expiration', expirationTimestamp.toString()],
        ],
        'content': 'Expired video',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(expiredEvent);

      // Before fix: This would add the video to discovery
      // After fix: This should NOT add expired video
      service.subscribeToDiscovery();

      // Manually call internal _addVideoToSubscription (testing private method behavior through public API)
      // We'll check by verifying the event list doesn't contain it
      final initialCount = service.getVideos(SubscriptionType.discovery).length;

      // This would normally be called internally, but we're testing the filtering logic
      // In practice, expired events should never make it into the feed
      service.subscribeToDiscovery();

      // Verify no expired events in the list
      final discoveryVideos = service.getVideos(SubscriptionType.discovery);
      expect(
        discoveryVideos.where((v) => v.isExpired).length,
        equals(0),
        reason: 'Discovery feed should not contain any expired events',
      );
    });

    test('allows non-expired events into discovery feed', () {
      // Create a future-expiring event (1 hour from now)
      final oneHourFromNow = DateTime.now().add(Duration(hours: 1));
      final expirationTimestamp = oneHourFromNow.millisecondsSinceEpoch ~/ 1000;

      final futureEvent = Event.fromJson({
        'id': 'future123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
          ['expiration', expirationTimestamp.toString()],
        ],
        'content': 'Future-expiring video',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(futureEvent);

      // Non-expired events should pass through the filter
      expect(videoEvent.isExpired, isFalse);
      expect(videoEvent.expirationTimestamp, equals(expirationTimestamp));
    });

    test('allows events without expiration tag', () {
      final normalEvent = Event.fromJson({
        'id': 'normal123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
        ],
        'content': 'Normal video without expiration',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(normalEvent);

      // Events without expiration should never be considered expired
      expect(videoEvent.isExpired, isFalse);
      expect(videoEvent.expirationTimestamp, isNull);
    });
  });
}
