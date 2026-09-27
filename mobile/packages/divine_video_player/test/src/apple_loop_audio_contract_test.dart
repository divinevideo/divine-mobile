import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// On Apple platforms a looping clip's sound is played by `ClipAudioLoop`, an
/// `AVAudioEngine` loop that runs without a gap across the seam, while the
/// muted `AVPlayer` shows the picture.
///
/// The queue player reports `.playing` again every time `AVPlayerLooper`
/// moves on to its next item, and the new item's clock is still stopped at
/// that moment. Placing the loop again there stopped the sound at every seam:
/// a click, ~100 ms of silence and the loop's last stretch played twice,
/// measured in the engine's output on the simulator and heard on an iPad.
///
/// None of this has a Dart runtime surface and the package's Swift harness
/// cannot run an `AVPlayer`, so the invariants are pinned as a source
/// contract, as the other Apple guards are.
void main() {
  group('Apple loop audio contract', () {
    test('a playing loop is not placed again when the player '
        're-reports playing', () {
      final realign = _body(
        _instanceSource(),
        'private func realignClipAudioLoop(',
      );

      expect(
        realign,
        contains('} else if loop.isRunning {\n            return\n        }'),
        reason:
            'A running loop is already in step with the picture; only a '
            'forced realign may place it again.',
      );
      expect(
        _instanceSource(),
        contains('self.realignClipAudioLoop(force: true)'),
        reason:
            'A seek moves the picture away from the running loop, so it is '
            'the one caller that must force the loop to be placed again.',
      );
    });

    test('drift is corrected by crossfading, never by a restart', () {
      final check = _body(
        _instanceSource(),
        'private func checkClipAudioLoop(',
      );

      expect(check, contains('loop.start(alignedTo: item)'));
      expect(
        check,
        isNot(contains('.pause()')),
        reason:
            'Stopping the loop to place it again is heard as a stop in the '
            'sound; start(alignedTo:) crossfades onto the second node '
            'instead.',
      );
    });

    test('the loop never stops itself while the picture clock waits', () {
      final loop = _loopSource();
      final start = _body(loop, 'func start(alignedTo item: AVPlayerItem)');

      expect(
        start,
        contains(
          'guard let timebase = item.timebase, '
          'CMTimebaseGetRate(timebase) > 0 else {\n'
          '            return false\n'
          '        }',
        ),
        reason:
            'While the item clock is stopped the loop must carry on as it '
            'is; stopping it there silenced every seam.',
      );
      expect(
        loop,
        contains('toBus: engine.mainMixerNode.nextAvailableInputBus'),
        reason:
            'Connected without a bus, both nodes land on bus 0 and the '
            'second connection silently drops the first — the loop plays '
            'nothing at all.',
      );
    });

    test('an output change places the stopped loop again', () {
      expect(
        _loopSource(),
        contains('forName: .AVAudioEngineConfigurationChange'),
        reason:
            'The engine stops itself on a route change, such as Bluetooth '
            'connecting, and drops what the nodes had scheduled. With the '
            'player muted, the clip stays silent unless the loop is placed '
            'again.',
      );
      expect(
        _body(_instanceSource(), 'private func adoptClipAudioLoop('),
        contains('loop.onStoppedByConfigurationChange = {'),
      );
    });

    test('a paused loop holds no running output', () {
      expect(
        _body(_loopSource(), 'func pause()'),
        contains('if engine.isRunning { engine.pause() }'),
        reason:
            'Feed players sit paused in the pool for a long time; a running '
            'engine keeps the audio hardware busy for nothing.',
      );
    });

    test('a superseded setClips installs nothing', () {
      final source = _instanceSource();

      expect(source, contains('setClipsGeneration += 1'));
      expect(
        source,
        contains(
          'guard !self.abandonsSetClips(callGeneration, built: built, '
          'result: result) else {',
        ),
        reason:
            'A build that awaited past a newer call must not leave its '
            'loader, loop source or first-frame start on the newer item.',
      );
    });

    test('only a looping feed clip streams through the kept download', () {
      final source = _instanceSource();

      expect(
        source,
        contains(
          'if clipsRaw.count == 1, startMs == 0, clipVol == 1.0, '
          'clipSpeed == 1.0,\n                trimToCommonTrackEnd,',
        ),
        reason:
            'Only a surface that loops a finished clip declares '
            'trimToCommonTrackEnd; any other single clip streams as '
            'AVFoundation would.',
      );
      expect(
        _sourceFile('CachingAssetLoader.swift').readAsStringSync(),
        contains('static let maxKeptBytes: Int64 = 16 * 1024 * 1024'),
        reason:
            'A feed plays only the first seconds of a long video; keeping all '
            'of it to loop them would waste the data.',
      );
    });
  });
}

/// The body of the Swift function whose declaration starts with [signature],
/// up to its closing brace at the same indentation.
String _body(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: '$signature is missing');
  final lineStart = source.lastIndexOf('\n', start) + 1;
  final indent = source.substring(lineStart, start);
  final end = source.indexOf('\n$indent}', start);
  expect(end, greaterThan(start), reason: '$signature has no end');
  return source.substring(start, end);
}

String _instanceSource() =>
    _sourceFile('DivineVideoPlayerInstance.swift').readAsStringSync();

String _loopSource() => _sourceFile('ClipAudioLoop.swift').readAsStringSync();

File _sourceFile(String name) {
  const sources = 'darwin/divine_video_player/Sources/divine_video_player/';
  final packageRelative = File('$sources$name');
  if (packageRelative.existsSync()) {
    return packageRelative;
  }
  return File('packages/divine_video_player/$sources$name');
}
