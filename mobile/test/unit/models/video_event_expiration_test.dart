// ABOUTME: Test NIP-40 expiration timestamp handling in VideoEvent
// ABOUTME: Ensures events with expiration tags are properly parsed and filtered

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('VideoEvent NIP-40 Expiration', () {
    test('parses expiration tag from event', () {
      // Create event with expiration tag set to 1 hour from now
      final oneHourFromNow = DateTime.now().add(Duration(hours: 1));
      final expirationTimestamp = oneHourFromNow.millisecondsSinceEpoch ~/ 1000;

      final event = Event.fromJson({
        'id': 'test123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
          ['expiration', expirationTimestamp.toString()],
        ],
        'content': 'Test video',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      expect(videoEvent.expirationTimestamp, equals(expirationTimestamp));
    });

    test('returns null expiration for events without expiration tag', () {
      final event = Event.fromJson({
        'id': 'test123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
        ],
        'content': 'Test video',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      expect(videoEvent.expirationTimestamp, isNull);
    });

    test('isExpired returns false for events without expiration', () {
      final event = Event.fromJson({
        'id': 'test123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
        ],
        'content': 'Test video',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      expect(videoEvent.isExpired, isFalse);
    });

    test('isExpired returns false for events with future expiration', () {
      final oneHourFromNow = DateTime.now().add(Duration(hours: 1));
      final expirationTimestamp = oneHourFromNow.millisecondsSinceEpoch ~/ 1000;

      final event = Event.fromJson({
        'id': 'test123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
          ['expiration', expirationTimestamp.toString()],
        ],
        'content': 'Test video',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      expect(videoEvent.isExpired, isFalse);
    });

    test('isExpired returns true for events with past expiration', () {
      final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
      final expirationTimestamp = oneHourAgo.millisecondsSinceEpoch ~/ 1000;

      final event = Event.fromJson({
        'id': 'test123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
          ['expiration', expirationTimestamp.toString()],
        ],
        'content': 'Test video',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      expect(videoEvent.isExpired, isTrue);
    });

    test(
      'isExpired returns true for events expiring in exactly 0 seconds (boundary)',
      () {
        final now = DateTime.now();
        final expirationTimestamp = now.millisecondsSinceEpoch ~/ 1000;

        final event = Event.fromJson({
          'id': 'test123',
          'pubkey': 'pubkey123',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 34236,
          'tags': [
            ['url', 'https://example.com/video.mp4'],
            ['expiration', expirationTimestamp.toString()],
          ],
          'content': 'Test video',
          'sig': 'sig123',
        });

        final videoEvent = VideoEvent.fromNostrEvent(event);

        // Event should be expired if current time >= expiration time
        expect(videoEvent.isExpired, isTrue);
      },
    );

    test('handles invalid expiration timestamp gracefully', () {
      final event = Event.fromJson({
        'id': 'test123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
          ['expiration', 'not-a-number'],
        ],
        'content': 'Test video',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Invalid expiration should be treated as null
      expect(videoEvent.expirationTimestamp, isNull);
      expect(videoEvent.isExpired, isFalse);
    });
  });
}
