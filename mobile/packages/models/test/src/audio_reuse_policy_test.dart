// ABOUTME: Verifies viewer-independent original-sound reuse policy.
// ABOUTME: Preserves classic Vine compatibility without overriding declines.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('originalSoundReuseTerms', () {
    VideoEvent video({required bool isClassicVine, String? marker}) {
      final rawTags = <String, String>{
        if (isClassicVine) 'platform': 'vine',
      };
      if (marker case final value?) {
        rawTags['allow_audio_reuse'] = value;
      }
      return VideoEvent(
        id: 'a' * 64,
        pubkey: 'b' * 64,
        createdAt: 1700000000,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        rawTags: rawTags,
      );
    }

    for (final isClassicVine in [false, true]) {
      final source = isClassicVine ? 'classic Vine' : 'ordinary video';

      test('grants explicit consent for $source', () {
        expect(
          originalSoundReuseTerms(
            video(marker: 'true', isClassicVine: isClassicVine),
          ),
          isTrue,
        );
      });

      test('honors explicit decline for $source', () {
        expect(
          originalSoundReuseTerms(
            video(marker: 'false', isClassicVine: isClassicVine),
          ),
          isFalse,
        );
      });

      test('fails closed for a malformed marker on $source', () {
        expect(
          originalSoundReuseTerms(
            video(marker: 'invalid', isClassicVine: isClassicVine),
          ),
          isFalse,
        );
      });
    }

    test('grants compatibility reuse for an unmarked classic Vine', () {
      expect(originalSoundReuseTerms(video(isClassicVine: true)), isTrue);
    });

    test('defers an unmarked ordinary video to viewer-aware policy', () {
      expect(originalSoundReuseTerms(video(isClassicVine: false)), isNull);
    });
  });
}
