// ABOUTME: Tests which videos trust decisions treat as archived Vines.
// ABOUTME: A self-applied tag counts only when the server could not check.

import 'package:models/models.dart';
import 'package:test/test.dart';

VideoEvent _video({
  bool platformTag = false,
  bool verifiedArchive = false,
  bool verificationUnknown = false,
  int createdAt = 1700000000,
  String? publishedAt,
  Map<String, String> rawTags = const {},
}) => VideoEvent(
  id: 'a' * 64,
  pubkey: 'b' * 64,
  createdAt: createdAt,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000, isUtc: true),
  rawTags: {if (platformTag) 'platform': 'vine', ...rawTags},
  publishedAt: publishedAt,
  isVerifiedArchive: verifiedArchive,
  isArchiveVerificationUnknown: verificationUnknown,
);

void main() {
  group(VideoEvent, () {
    group('isClassicVine', () {
      test('includes Vine imports through the last second of 2017 UTC', () {
        expect(
          _video(platformTag: true, createdAt: 1514764799).isClassicVine,
          isTrue,
        );
        expect(
          _video(platformTag: true, createdAt: 1514764800).isClassicVine,
          isFalse,
        );
      });

      test('uses the original publish date for a recently imported Vine', () {
        expect(
          _video(platformTag: true, publishedAt: '1451606400').isClassicVine,
          isTrue,
        );
        expect(
          _video(
            platformTag: true,
            rawTags: const {'published_at': '1451606400'},
          ).isClassicVine,
          isTrue,
        );
      });

      test(
        'does not fall back to an older event over a later publish date',
        () {
          expect(
            _video(
              platformTag: true,
              createdAt: 1451606400,
              publishedAt: '1514764800',
            ).isClassicVine,
            isFalse,
          );
        },
      );

      test('does not label unrelated old videos as Vines', () {
        expect(_video(createdAt: 1451606400).isClassicVine, isFalse);
      });

      test('accepts verified archive origin without a platform tag', () {
        expect(
          _video(verifiedArchive: true, createdAt: 1451606400).isClassicVine,
          isTrue,
        );
      });

      test('does not label Vine imports with missing or invalid dates', () {
        for (final createdAt in [0, -1, 1700000000]) {
          expect(
            _video(platformTag: true, createdAt: createdAt).isClassicVine,
            isFalse,
          );
        }
      });

      test('display classification does not grant archive trust', () {
        final video = _video(platformTag: true, createdAt: 1451606400);
        expect(video.isClassicVine, isTrue);
        expect(video.countsAsArchiveVine, isFalse);
        expect(video.isVerifiedArchive, isFalse);
        expect(video.archiveAudioReuseEnabled, isFalse);
      });
    });

    group('countsAsArchiveVine', () {
      test('is true for a video the server verified', () {
        expect(_video(verifiedArchive: true).countsAsArchiveVine, isTrue);
      });

      test('ignores the tag when the server checked and did not verify', () {
        expect(_video(platformTag: true).countsAsArchiveVine, isFalse);
      });

      test('falls back to the tag when the server could not check', () {
        expect(
          _video(
            platformTag: true,
            verificationUnknown: true,
          ).countsAsArchiveVine,
          isTrue,
        );
      });

      test('is false for an untagged video the server could not check', () {
        expect(
          _video(verificationUnknown: true).countsAsArchiveVine,
          isFalse,
        );
      });
    });
  });
}
