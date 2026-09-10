// ABOUTME: Verifies viewer-independent original-sound reuse policy.
// ABOUTME: Makes classic Vine audio reusable unless a server takedown applies.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('originalSoundReuseTerms', () {
    VideoEvent video({
      required bool isVerifiedArchive,
      String? marker,
      bool archiveAudioReuseEnabled = true,
    }) {
      final rawTags = <String, String>{};
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
        isVerifiedArchive: isVerifiedArchive,
        archiveAudioReuseEnabled: archiveAudioReuseEnabled,
      );
    }

    for (final isVerifiedArchive in [false, true]) {
      final source = isVerifiedArchive ? 'verified archive' : 'ordinary video';

      test('grants explicit consent for $source', () {
        expect(
          originalSoundReuseTerms(
            video(marker: 'true', isVerifiedArchive: isVerifiedArchive),
          ),
          isTrue,
        );
      });

      test('interprets an explicit decline correctly for $source', () {
        expect(
          originalSoundReuseTerms(
            video(marker: 'false', isVerifiedArchive: isVerifiedArchive),
          ),
          isVerifiedArchive ? isTrue : isFalse,
        );
      });

      test('interprets a malformed marker correctly for $source', () {
        expect(
          originalSoundReuseTerms(
            video(marker: 'invalid', isVerifiedArchive: isVerifiedArchive),
          ),
          isVerifiedArchive ? isTrue : isFalse,
        );
      });
    }

    test('applies enabled legacy policy to an unmarked verified archive', () {
      expect(originalSoundReuseTerms(video(isVerifiedArchive: true)), isTrue);
    });

    test('defers an unmarked ordinary video to viewer-aware policy', () {
      expect(originalSoundReuseTerms(video(isVerifiedArchive: false)), isNull);
    });

    test('fails closed when archive audio compatibility is disabled', () {
      expect(
        originalSoundReuseTerms(
          video(isVerifiedArchive: true, archiveAudioReuseEnabled: false),
        ),
        isNull,
      );
    });

    test('ignores a self-authored classic Vine platform tag', () {
      final spoofed = video(
        isVerifiedArchive: false,
      ).copyWith(rawTags: const {'platform': 'vine'});

      expect(originalSoundReuseTerms(spoofed), isNull);
    });
  });
}
