// ABOUTME: Tests for the allow_video_reuse marker on video events, including
// ABOUTME: recovery from rawTags after a JSON-cache round-trip.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent.allowVideoReuse', () {
    Event buildEvent({String? marker}) {
      return Event(
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        34236,
        [
          const ['d', 'video-reuse-d-tag'],
          const ['url', 'https://media.divine.video/reuse.mp4'],
          if (marker != null) ['allow_video_reuse', marker],
        ],
        'Video reuse video',
        createdAt: 1778120201,
      );
    }

    test('is true when the event carries the marker', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'true'));

      expect(video.allowVideoReuse, isTrue);
    });

    test('is false when the event omits the marker', () {
      final video = VideoEvent.fromNostrEvent(buildEvent());

      expect(video.allowVideoReuse, isFalse);
    });

    test('is false for an explicit decline', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'false'));

      expect(video.allowVideoReuse, isFalse);
    });

    test('is false for a malformed marker', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'TRUE'));

      expect(video.allowVideoReuse, isFalse);
    });

    test('survives a JSON-cache round-trip that drops nostrEventTags', () {
      final original = VideoEvent.fromNostrEvent(buildEvent(marker: 'true'));

      final restored = VideoEvent.fromJson(original.toJson());

      expect(restored.nostrEventTags, isEmpty);
      expect(restored.allowVideoReuse, isTrue);
    });
  });
}
