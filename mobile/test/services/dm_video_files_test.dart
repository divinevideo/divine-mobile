// ABOUTME: Unit tests for the file naming and error text shared by what the
// ABOUTME: video DM store keeps: no name leaves its folder, no error its path.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/dm_video_files.dart';

void main() {
  group('dmVideoSafeName', () {
    test('keeps the letters and digits of a pubkey or a message id', () {
      expect(dmVideoSafeName('Ab09' * 16), equals('Ab09' * 16));
    });

    test('drops separators and dots, so a name cannot leave its folder', () {
      expect(dmVideoSafeName('../owner/clip.mp4'), equals('ownerclipmp4'));
    });
  });

  group('dmVideoFileErrorCause', () {
    test('names the OS error but not the path', () {
      final cause = dmVideoFileErrorCause(
        const FileSystemException(
          'Cannot open file',
          '/cache/dm_videos/owner/clip.mp4',
          OSError('No space left on device', 28),
        ),
      );

      expect(cause, contains('No space left on device'));
      expect(cause, isNot(contains('/cache/dm_videos')));
    });

    test('says there was no OS error when there was none', () {
      expect(
        dmVideoFileErrorCause(
          const FileSystemException('Cannot open file', '/cache/clip.mp4'),
        ),
        equals('no OS error'),
      );
    });
  });
}
