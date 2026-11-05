// ABOUTME: Tests which videos trust decisions treat as archived Vines.
// ABOUTME: A self-applied tag counts only when the server could not check.

import 'package:models/models.dart';
import 'package:test/test.dart';

VideoEvent _video({
  bool platformTag = false,
  bool verifiedArchive = false,
  bool verificationUnknown = false,
}) => VideoEvent(
  id: 'a' * 64,
  pubkey: 'b' * 64,
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.utc(2023, 11, 14),
  rawTags: platformTag ? const {'platform': 'vine'} : const {},
  isVerifiedArchive: verifiedArchive,
  isArchiveVerificationUnknown: verificationUnknown,
);

void main() {
  group(VideoEvent, () {
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
