import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `rebuildQueueForLoopingChange` runs on every `setLooping` call, which the
/// feed makes for every video it starts. It resumes at `player.currentTime()`,
/// and an `AVQueuePlayer` with no current item answers an invalid time there.
/// Seeking to an invalid time raises an Objective-C
/// NSInvalidArgumentException that Swift cannot catch, so the app aborts.
/// There is no Dart runtime surface for this, so the guard is pinned as a
/// source contract.
void main() {
  group('Apple looping rebuild seek contract', () {
    test('seeks to a numeric resume time, falling back to zero', () {
      final body = _rebuildQueueForLoopingChangeBody();

      final guard = body.indexOf(
        'let resumeTime = playerTime.isNumeric ? playerTime : .zero',
      );
      final seek = body.indexOf('player.seek(to: resumeTime');

      expect(guard, greaterThanOrEqualTo(0));
      expect(seek, greaterThanOrEqualTo(0));
      expect(
        guard,
        lessThan(seek),
        reason:
            'The resume time must be checked with isNumeric before the seek; '
            'the crash happens inside seek(to:).',
      );
      expect(
        body,
        isNot(contains('seek(to: player.currentTime()')),
        reason: 'Seeking straight to currentTime() restores the crash.',
      );
    });
  });
}

String _rebuildQueueForLoopingChangeBody() {
  final source = _appleSourceFile().readAsStringSync();
  const signature = 'private func rebuildQueueForLoopingChange()';
  final start = source.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: 'Missing $signature');

  final next = source.indexOf('private func ', start + signature.length);
  return source.substring(start, next < 0 ? source.length : next);
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the contract is asserted once.
File _appleSourceFile() {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
}
