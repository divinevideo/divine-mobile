// ABOUTME: Tests for the allow_audio_reuse marker derivation on video events,
// ABOUTME: including recovery from rawTags after a JSON-cache round-trip.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent.allowAudioReuse', () {
    Event buildEvent({String? marker}) {
      return Event(
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        34236,
        [
          const ['d', 'audio-reuse-d-tag'],
          const ['url', 'https://media.divine.video/reuse.mp4'],
          if (marker != null) ['allow_audio_reuse', marker],
        ],
        'Audio reuse video',
        createdAt: 1778120201,
      );
    }

    test('is true when the live event carries the marker', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'true'));

      expect(video.allowAudioReuse, isTrue);
      expect(video.audioReuseConsent, AudioReuseConsent.granted);
    });

    test('is false when the live event omits the marker', () {
      final video = VideoEvent.fromNostrEvent(buildEvent());

      expect(video.allowAudioReuse, isFalse);
      expect(video.audioReuseConsent, AudioReuseConsent.unspecified);
    });

    test('distinguishes an explicit decline from an omitted marker', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'false'));

      expect(video.allowAudioReuse, isFalse);
      expect(video.audioReuseConsent, AudioReuseConsent.declined);
    });

    test('treats a malformed marker as invalid rather than absent', () {
      final video = VideoEvent.fromNostrEvent(buildEvent(marker: 'TRUE'));

      expect(video.allowAudioReuse, isFalse);
      expect(video.audioReuseConsent, AudioReuseConsent.invalid);
    });

    test('prefers the live marker over a divergent rawTags value', () {
      final video = VideoEvent(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        pubkey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        createdAt: 1778120201,
        content: '',
        timestamp: DateTime.utc(2026, 5, 7),
        title: 'Audio reuse video',
        videoUrl: 'https://media.divine.video/reuse.mp4',
        nostrEventTags: const [
          ['allow_audio_reuse', 'false'],
        ],
        rawTags: const {'allow_audio_reuse': 'true'},
      );

      // Live tags win over rawTags. A future reorder of the lookup that
      // consulted rawTags first would flip this to true and fail here.
      expect(video.allowAudioReuse, isFalse);
    });

    test('survives a JSON-cache round-trip that drops nostrEventTags', () {
      final original = VideoEvent.fromNostrEvent(buildEvent(marker: 'true'));

      final restored = VideoEvent.fromJson(original.toJson());

      // Regression guard: the cache path drops nostrEventTags but preserves
      // rawTags, so the marker must still be recoverable.
      expect(restored.nostrEventTags, isEmpty);
      expect(restored.allowAudioReuse, isTrue);
    });

    test('is true from a rawTags-only cached event', () {
      final video = VideoEvent(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        pubkey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        createdAt: 1778120201,
        content: '',
        timestamp: DateTime.utc(2026, 5, 7),
        title: 'Audio reuse video',
        videoUrl: 'https://media.divine.video/reuse.mp4',
        rawTags: const {'allow_audio_reuse': 'true'},
      );

      expect(video.allowAudioReuse, isTrue);
    });

    test('is false from a cached event without the marker', () {
      final video = VideoEvent(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        pubkey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        createdAt: 1778120201,
        content: '',
        timestamp: DateTime.utc(2026, 5, 7),
        title: 'Audio reuse video',
        videoUrl: 'https://media.divine.video/reuse.mp4',
      );

      expect(video.allowAudioReuse, isFalse);
    });
  });
}
