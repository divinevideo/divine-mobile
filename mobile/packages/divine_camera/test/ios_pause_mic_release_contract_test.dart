// ABOUTME: Static guards for the iOS mic release on pause (#10195).
// ABOUTME: A take still being written keeps the mic until its file is done.

import 'package:flutter_test/flutter_test.dart';

import 'helpers/native_source.dart';

void main() {
  // Deactivating the shared AVAudioSession under a running finishWriting
  // fails the file with "Operation Interrupted". Backgrounding pauses twice
  // (`.hidden`, then `.paused`), and the second pause lands while the first
  // one's salvage is still being written.
  group('iOS mic release while a take is finalizing', () {
    late final String stop;
    late final String pause;
    late final String pauseOnSessionQueue;

    setUpAll(() {
      final source = readDarwinNativeSource('CameraController.swift');
      stop = declarationAt(source, 'func stopRecording(');
      pause = declarationAt(source, 'func pausePreview(');
      pauseOnSessionQueue = declarationAt(pause, 'sessionQueue.async');
    });

    test('a stop marks the take as finalizing in the turn that ends it', () {
      // A pause landing between the two would see neither a recording nor a
      // file being written, and release the mic under the writer.
      final ended = stop.indexOf('isRecording = false');
      final marked = stop.indexOf('isFinalizingRecording = true');
      final handedOff = stop.indexOf('videoOutputQueue.async');
      expect(ended, greaterThan(-1));
      expect(marked, greaterThan(ended));
      expect(handedOff, greaterThan(marked));
    });

    test('a pause reads the flag on main, after its own salvage', () {
      // The first background pause salvages the take itself; reading before
      // that would miss the write it just started.
      final salvage = pause.indexOf(
        'salvageInterruptedRecording(reason: "app backgrounded")',
      );
      final read = pause.indexOf('let finalizing = isFinalizingRecording');
      final hop = pause.indexOf('sessionQueue.async');
      expect(salvage, greaterThan(-1));
      expect(read, greaterThan(salvage));
      expect(hop, greaterThan(read));
      expect(pauseOnSessionQueue, isNot(contains('isFinalizingRecording')));
    });

    test('a pause keeps the mic while a file is still being written', () {
      const keepWhileWriting =
          'if releaseAudio, !finalizing, !self.isRecording {';
      expect(pause, contains(keepWhileWriting));
      expect(
        declarationAt(pauseOnSessionQueue, keepWhileWriting),
        contains('self.releaseAudioForPause()'),
      );
      expect('releaseAudioForPause()'.allMatches(pause), hasLength(1));
    });
  });
}
