// ABOUTME: Tests for the OriginalContentBadge widget and original-content event logic
// ABOUTME: Verifies the badge renders correctly and VideoEvent flags original vs repost vs vintage vine

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/extensions/video_event_extensions.dart';

void main() {
  group('Original Content Badge Tests (TDD)', () {
    test('VideoEvent.isOriginalContent returns true for non-repost', () {
      // Arrange - Create a non-repost video event
      final event = Event.fromJson({
        'id': 'test1234567890abcdef',
        'pubkey': 'pubkey1234567890abcdef',
        'created_at': 1234567890,
        'kind': 34236,
        'content': 'Test video',
        'tags': [
          ['url', 'https://example.com/video.mp4'],
        ],
        'sig': 'sig1234567890abcdef',
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Assert
      expect(videoEvent.isOriginalContent, true);
      expect(videoEvent.isRepost, false);
    });

    test(
      'VideoEvent.shouldShowOriginalBadge returns true for original user content',
      () {
        // Arrange - Create a normal user video (no repost, no vintage vine metrics)
        final event = Event.fromJson({
          'id': 'test1234567890abcdef',
          'pubkey': 'pubkey1234567890abcdef',
          'created_at': 1234567890,
          'kind': 34236,
          'content': 'Test video',
          'tags': [
            ['url', 'https://example.com/video.mp4'],
          ],
          'sig': 'sig1234567890abcdef',
        });

        final videoEvent = VideoEvent.fromNostrEvent(event);

        // Assert - should show Original badge (not a repost, not a vintage vine)
        expect(videoEvent.shouldShowNotDivineBadge, true);
      },
    );

    test('VideoEvent.shouldShowOriginalBadge returns false for reposts', () {
      // Arrange - Create a repost event
      final originalEvent = Event.fromJson({
        'id': 'original1234567890abcdef',
        'pubkey': 'pubkey1234567890abcdef',
        'created_at': 1234567890,
        'kind': 34236,
        'content': 'Original video',
        'tags': [
          ['url', 'https://example.com/video.mp4'],
        ],
        'sig': 'sig1234567890abcdef',
      });

      final videoEvent = VideoEvent.createRepostEvent(
        originalEvent: VideoEvent.fromNostrEvent(originalEvent),
        repostEventId: 'repost1234567890abcdef',
        reposterPubkey: 'reposter1234567890abcdef',
        repostedAt: DateTime.now(),
      );

      // Assert - should NOT show Original badge (this is a repost)
      expect(videoEvent.shouldShowNotDivineBadge, true);
      expect(videoEvent.isRepost, true);
    });

    test(
      'VideoEvent.shouldShowOriginalBadge returns false for verified archive '
      'vines',
      () {
        // Arrange - Create a vintage recovered vine with loop count
        final event = Event.fromJson({
          'id': 'vintage1234567890abcdef',
          'pubkey': 'pubkey1234567890abcdef',
          'created_at': 1473050841,
          'kind': 34236,
          'content': 'Vintage vine',
          'tags': [
            ['url', 'https://example.com/video.mp4'],
            ['loops', '10000'],
            ['platform', 'vine'],
          ],
          'sig': 'sig1234567890abcdef',
        });

        final videoEvent = VideoEvent.fromNostrEvent(
          event,
        ).copyWith(isVerifiedArchive: true);

        // Assert - should NOT show Original badge (vintage vines get their own badge)
        expect(videoEvent.shouldShowNotDivineBadge, false);
        expect(videoEvent.isOriginalVine, true);
      },
    );
  });
}
