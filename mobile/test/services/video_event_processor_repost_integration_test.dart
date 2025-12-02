// ABOUTME: Integration test demonstrating complete repost processing flow
// ABOUTME: Tests NIP-18 repost functionality with embedded video events

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/video_event_processor.dart';

void main() {
  group('VideoEventProcessor Repost Integration', () {
    late VideoEventProcessor processor;

    setUp(() {
      processor = VideoEventProcessor();
    });

    tearDown(() {
      processor.dispose();
    });

    test(
      'complete repost flow: embed video in kind 6, process and emit',
      () async {
        // Arrange
        final receivedEvents = [];
        processor.videoEventStream.listen(receivedEvents.add);

        // Create a complete NIP-18 repost with embedded video
        const reposterPubkey =
            '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
        const authorPubkey =
            'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
        final repostEvent = Event(
          reposterPubkey, // Valid hex pubkey
          6, // Kind 6 repost
          [
            ['e', 'video123'],
            ['p', authorPubkey],
            ['k', '34236'],
          ],
          // NIP-18: Embedded original video event as JSON
          '''
{
  "id": "video123",
  "pubkey": "$authorPubkey",
  "created_at": 1234567890,
  "kind": 34236,
  "tags": [
    ["url", "https://example.com/awesome-video.mp4"],
    ["title", "Awesome Video"],
    ["t", "nostr"],
    ["t", "bitcoin"]
  ],
  "content": "Check out this cool video!",
  "sig": "${'0123456789abcdef' * 8}"
}''',
          createdAt: 1234567900,
        )..id = 'repost456';

        // Act
        processor.processEvent(repostEvent);
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(
          receivedEvents.length,
          1,
          reason: 'Should emit one reposted video',
        );

        final repostedVideo = receivedEvents.first;
        expect(
          repostedVideo.isRepost,
          isTrue,
          reason: 'Should be marked as repost',
        );
        expect(repostedVideo.reposterId, equals('repost456'));
        expect(repostedVideo.reposterPubkey, equals(reposterPubkey));
        expect(
          repostedVideo.id,
          equals('video123'),
          reason: 'Should preserve original ID',
        );
        expect(
          repostedVideo.pubkey,
          equals(authorPubkey),
          reason: 'Should preserve original author',
        );
        expect(
          repostedVideo.videoUrl,
          equals('https://example.com/awesome-video.mp4'),
        );
        expect(repostedVideo.title, equals('Awesome Video'));
        expect(repostedVideo.hashtags, contains('nostr'));
        expect(repostedVideo.hashtags, contains('bitcoin'));
      },
    );

    test('should handle multiple video kinds being reposted', () async {
      // Arrange
      final receivedEvents = [];
      processor.videoEventStream.listen(receivedEvents.add);

      // Test kind 22 (short video)
      const pubkey22 =
          'def1234567890abcdef1234567890abcdef1234567890abcdef1234567890abc';
      const author22 =
          'fed0987654321fedcfed0987654321fedcfed0987654321fedcfed0987654321';
      final repostKind22 = Event(
        pubkey22,
        6,
        [
          ['e', 'video_kind22'],
        ],
        '''
{
  "id": "video_kind22",
  "pubkey": "$author22",
  "created_at": 1234567890,
  "kind": 22,
  "tags": [["url", "https://example.com/short.mp4"]],
  "content": "Short video",
  "sig": "${'0123456789abcdef' * 8}"
}''',
        createdAt: 1234567900,
      )..id = 'repost_kind22';

      // Test kind 34236 (addressable short video)
      const pubkey34236 =
          'abc9876543210abcabc9876543210abcabc9876543210abcabc9876543210abc';
      const author34236 =
          'cba0123456789cbacba0123456789cbacba0123456789cbacba0123456789cba';
      final repostKind34236 = Event(
        pubkey34236,
        6,
        [
          ['e', 'video_kind34236'],
        ],
        '''
{
  "id": "video_kind34236",
  "pubkey": "$author34236",
  "created_at": 1234567891,
  "kind": 34236,
  "tags": [["url", "https://example.com/addressable.mp4"]],
  "content": "Addressable video",
  "sig": "${'0123456789abcdef' * 8}"
}''',
        createdAt: 1234567901,
      )..id = 'repost_kind34236';

      // Act
      processor.processEvent(repostKind22);
      processor.processEvent(repostKind34236);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(receivedEvents.length, 2, reason: 'Should process both reposts');
      expect(receivedEvents[0].id, equals('video_kind22'));
      expect(receivedEvents[1].id, equals('video_kind34236'));
      expect(receivedEvents[0].isRepost, isTrue);
      expect(receivedEvents[1].isRepost, isTrue);
    });

    test('should skip reposts of non-video events', () async {
      // Arrange
      final receivedEvents = [];
      final errors = [];
      processor.videoEventStream.listen(receivedEvents.add);
      processor.errorStream.listen(errors.add);

      // Repost of a text note (kind 1)
      const pubkeyText =
          '1111111111111111222222222222222233333333333333334444444444444444';
      const authorText =
          '5555555555555555666666666666666677777777777777778888888888888888';
      final repostTextNote = Event(
        pubkeyText,
        6,
        [
          ['e', 'textnote123'],
        ],
        '''
{
  "id": "textnote123",
  "pubkey": "$authorText",
  "created_at": 1234567890,
  "kind": 1,
  "tags": [],
  "content": "Just a text note",
  "sig": "${'0123456789abcdef' * 8}"
}''',
        createdAt: 1234567900,
      )..id = 'repost_textnote';

      // Act
      processor.processEvent(repostTextNote);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(
        receivedEvents.length,
        0,
        reason: 'Should not emit non-video reposts',
      );
      expect(
        errors.length,
        0,
        reason: 'Should not generate errors for non-video reposts',
      );
    });

    test('should handle malformed repost content gracefully', () async {
      // Arrange
      final errors = [];
      processor.errorStream.listen(errors.add);

      // Repost with invalid JSON
      const pubkeyBad =
          '9999999999999999aaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbcccccccccccccccc';
      final repostBadJson = Event(
        pubkeyBad,
        6,
        [
          ['e', 'video123'],
        ],
        'This is not valid JSON',
        createdAt: 1234567900,
      )..id = 'repost_badjson';

      // Act
      processor.processEvent(repostBadJson);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(
        errors.length,
        1,
        reason: 'Should report error for malformed JSON',
      );
      expect(errors.first, contains('Error processing repost event'));
    });
  });
}
