// ABOUTME: Tests for deriving reply metadata from NIP-22 tags on video events.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent reply metadata', () {
    const rootAddressableId =
        '34236:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        ':parent-d-tag';

    test('detects a video reply and prefers the root addressable route', () {
      final event = Event(
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        34236,
        const [
          ['d', 'reply-d-tag'],
          [
            'A',
            rootAddressableId,
            '',
          ],
          [
            'E',
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            '',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ],
          ['K', '34236'],
          [
            'P',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ],
          [
            'e',
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            '',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ],
          ['k', '34236'],
          [
            'p',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ],
          ['url', 'https://media.divine.video/reply.mp4'],
        ],
        'Reply video',
        createdAt: 1778120201,
      );

      final video = VideoEvent.fromNostrEvent(event);

      expect(video.isVideoReply, isTrue);
      expect(
        video.replyRootEventId,
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      expect(video.replyRootAddressableId, rootAddressableId);
      expect(video.replyRootRouteId, rootAddressableId);
    });

    test('does not treat non-video uppercase references as video replies', () {
      final event = Event(
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        34236,
        const [
          [
            'E',
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            '',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ],
          ['K', '1111'],
          ['url', 'https://media.divine.video/video.mp4'],
        ],
        'Not a video reply',
        createdAt: 1778120201,
      );

      final video = VideoEvent.fromNostrEvent(event);

      expect(video.isVideoReply, isFalse);
      expect(video.replyRootRouteId, isNull);
    });

    test('detects cached rawTags-only video replies', () {
      const parentEventId =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final video = VideoEvent(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        pubkey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        createdAt: 1778120201,
        content: '',
        timestamp: DateTime.utc(2026, 5, 7),
        title: 'Reply video',
        videoUrl: 'https://media.divine.video/reply',
        rawTags: const {
          'E': parentEventId,
          'K': '34236',
          'A': rootAddressableId,
          'e': parentEventId,
          'k': '34236',
          'a': rootAddressableId,
        },
        inspiredByVideo: const InspiredByInfo(addressableId: rootAddressableId),
      );

      expect(video.isVideoReply, isTrue);
      expect(video.replyRootEventId, parentEventId);
      expect(video.replyRootAddressableId, rootAddressableId);
      expect(video.replyRootRouteId, rootAddressableId);
      expect(video.creditedInspiredByPubkeys, isEmpty);
    });
  });
}
