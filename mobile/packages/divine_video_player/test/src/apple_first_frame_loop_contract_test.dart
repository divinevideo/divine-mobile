import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Divine derivative opens its video track with a 21–23 ms empty edit.
/// `AVPlayerLooper` does not join an item that starts with one to the next
/// gaplessly: each lap started ~200 ms late on an iPad Air (M4) and ~400 ms
/// late on macOS and the simulator, with the last frame held all that time,
/// and a composition cut from zero held it ~55 ms. Started at the first frame,
/// both paths joined every lap on time — the same start Android uses.
///
/// None of this has a Dart runtime surface and the package's Swift harness
/// cannot run an `AVPlayer`, so the invariants are pinned as a source
/// contract, as the other Apple guards are.
void main() {
  group('Apple first-frame loop contract', () {
    test('only a short empty edit is skipped', () {
      final source = _instanceSource();

      expect(
        source,
        contains('private static let maxLeadingEmptyEditSeconds = 0.1'),
        reason: 'The bound Android applies; a longer lead is content.',
      );
      expect(source, contains('guard let segments = try? await track.load('));
      expect(source, contains('let first = segments.first, first.isEmpty'));
    });

    test('the direct path loops from the first frame', () {
      final source = _instanceSource();

      expect(
        source,
        contains('loopStart = await Self.leadingEmptyEditEnd(of: videoTrack)'),
      );
      expect(
        source,
        contains('loopTimeRange = CMTimeRange(start: loopStart, end: loopEnd)'),
        reason:
            'The looper honours only its own range when it wraps, so that is '
            'where each lap has to start past the empty edit.',
      );
    });

    test('a composition is cut from the first frame', () {
      final source = _instanceSource();

      expect(
        source,
        contains('if trimToCommonTrackEnd, startMs == 0 {'),
        reason:
            'Only a clip starting at zero, as on Android: an explicit start is '
            "the caller's own cut.",
      );
      expect(
        source,
        contains(
          'startTime = await Self.leadingEmptyEditEnd(of: sourceVideoTrack)',
        ),
      );
    });

    test('the sound loop starts where the picture does', () {
      final source = _instanceSource();

      expect(source, contains('fileStart: loopStart,'));
      expect(source, contains('itemStart: loopStart'));
      expect(source, contains('fileStart: build.firstClipFileStart,'));
      expect(
        _loopSource(),
        contains('(decoded.firstTime.seconds - source.fileStart.seconds)'),
        reason:
            'The decode is placed against the lap start, so the audio under '
            'the empty edit is dropped as the picture skips it.',
      );
    });
  });
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
