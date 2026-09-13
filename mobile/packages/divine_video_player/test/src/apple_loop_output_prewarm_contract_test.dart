import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `AVPlayerLooper` cycles a small set of item copies, so every one of them
/// is given a video output before it becomes current and the seam has
/// nothing left to build. That leaves several outputs reporting to one
/// delegate at once, and a set of items the looper no longer owns once
/// looping is switched off. Neither has a Dart runtime surface, so the two
/// invariants are pinned as a source contract.
void main() {
  group('Apple looper output prewarm contract', () {
    test('only the current output may deliver frames or re-arm', () {
      final source = _textureOutputSourceFile().readAsStringSync();

      // A queued item is flushed when the looper prepares it, and its output
      // then announces media data. Copying from it at the player's time hands
      // over the next lap's first frame while the current lap is still
      // playing — the frame-0-before-lap-end skip.
      expect(
        _functionBody(source, 'func outputMediaDataWillChange('),
        contains('videoOutput === self.videoOutput'),
        reason:
            'A warmed output that is not current must be ignored, or its '
            'first frame lands on the texture before the current lap ends.',
      );
      expect(
        _functionBody(source, 'func outputSequenceWasFlushed('),
        contains('guard output === videoOutput'),
        reason:
            "A flush on a queued item must not reset the current output's "
            'delivery bookkeeping or re-arm a notification from it.',
      );
    });

    test('adopting a prewarmed output re-arms the first-frame signal', () {
      final source = _textureOutputSourceFile().readAsStringSync();

      // `attachCurrentItemOutputs` prewarms immediately before it attaches,
      // so a new clip set's first attach adopts an already-warm output and
      // takes this branch. `onFirstFrame` fires once per
      // `hasDeliveredFirstFrame`, and on the texture path it is the only
      // thing that clears Flutter's loader — so without the reset here the
      // second video on a reused player renders under the loader forever.
      expect(
        _warmAdoptBranch(
          _functionBody(source, 'func attach(to item: AVPlayerItem)'),
        ),
        contains('hasDeliveredFirstFrame = false'),
        reason:
            'Adopting a warm output must reset the first-frame flag like the '
            'cold path does, or onFirstFrame never fires for the next video.',
      );
    });

    test("switching looping off drops the previous looper's items", () {
      final source = _playerSourceFile().readAsStringSync();

      // An empty set is what prunes: every warmed item the looper no longer
      // owns is released with its output and decoder, instead of being
      // pinned until dispose.
      expect(
        _functionBody(source, 'private func prewarmLoopingOutputs('),
        contains('prewarm(items: playerLooper?.loopingPlayerItems ?? [])'),
        reason:
            'Without a looper the warm set must be handed an empty list so '
            'the old items are pruned, not skipped.',
      );
    });
  });
}

/// The branch of `attach(to:)` that adopts an already-warm output, from its
/// `if let warm` opener to the `return` that ends it.
String _warmAdoptBranch(String attachBody) {
  final start = attachBody.indexOf('if let warm');
  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'Expected `attach(to:)` to keep its warm-output adopt branch.',
  );
  final end = attachBody.indexOf('return', start);
  expect(
    end,
    greaterThan(start),
    reason: 'Expected the warm-output adopt branch to return early.',
  );
  return attachBody.substring(start, end);
}

/// Source text of the function opening at [signature], up to the next
/// declaration at the same indentation.
String _functionBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'Expected to find `$signature` in the Apple player source.',
  );
  final next = source.indexOf(
    RegExp(r'\n    (private |func |///|// MARK)'),
    start + signature.length + 1,
  );
  return source.substring(start, next == -1 ? source.length : next);
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so each contract is asserted
/// once against the shared file.
File _textureOutputSourceFile() =>
    _darwinSourceFile('VideoTextureOutput.swift');

File _playerSourceFile() =>
    _darwinSourceFile('DivineVideoPlayerInstance.swift');

File _darwinSourceFile(String name) {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/$name',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/$name',
  );
}
