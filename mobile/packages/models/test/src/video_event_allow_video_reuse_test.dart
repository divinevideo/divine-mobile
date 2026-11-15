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

    test('is true when the event omits the marker', () {
      final video = VideoEvent.fromNostrEvent(buildEvent());

      expect(video.allowVideoReuse, isTrue);
    });

    test('is false for an explicit decline', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'false'));

      expect(video.allowVideoReuse, isFalse);
    });

    test('is false for a decline in another case', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'FALSE'));

      expect(video.allowVideoReuse, isFalse);
      expect(video.videoReuseConsent, ReuseConsent.declined);
    });

    test('is false for a decline padded with whitespace', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: ' False '));

      expect(video.allowVideoReuse, isFalse);
      expect(video.videoReuseConsent, ReuseConsent.declined);
    });

    test('is true for a grant in another case', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'TRUE'));

      expect(video.allowVideoReuse, isTrue);
      expect(video.videoReuseConsent, ReuseConsent.granted);
    });

    test('is false for a marker that is neither true nor false', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'maybe'));

      expect(video.allowVideoReuse, isFalse);
      expect(video.videoReuseConsent, ReuseConsent.invalid);
    });

    test('reports an absent marker as unspecified', () {
      final video = VideoEvent.fromNostrEvent(buildEvent());

      expect(video.videoReuseConsent, ReuseConsent.unspecified);
    });

    test('reads a decline from rawTags after a JSON-cache round-trip', () {
      final original = VideoEvent.fromNostrEvent(buildEvent(marker: 'FALSE'));

      final restored = VideoEvent.fromJson(original.toJson());

      expect(restored.nostrEventTags, isEmpty);
      expect(restored.allowVideoReuse, isFalse);
    });

    test('survives a JSON-cache round-trip that drops nostrEventTags', () {
      final original = VideoEvent.fromNostrEvent(buildEvent(marker: 'true'));

      final restored = VideoEvent.fromJson(original.toJson());

      expect(restored.nostrEventTags, isEmpty);
      expect(restored.allowVideoReuse, isTrue);
    });
  });
}
