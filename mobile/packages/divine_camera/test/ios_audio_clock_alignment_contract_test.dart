// ABOUTME: Static guards for the iOS recorder's audio-to-video clock alignment.
// ABOUTME: Audio buffers must be retimed onto the video session clock first.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readNativeSource(String fileName) {
  final file = [
    File('ios/Classes/$fileName'),
    File('packages/divine_camera/ios/Classes/$fileName'),
  ].firstWhere((file) => file.existsSync());

  return file.readAsStringSync();
}

/// Returns the Swift declaration or block starting at [signature] up to its
/// closing brace, so an assertion cannot match an identical line elsewhere in
/// the file, nor a line that sits outside the scope being asserted on.
String _declarationAt(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('No declaration starting with "$signature".');
  }

  var depth = 0;
  for (var i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  throw StateError('Unbalanced braces after "$signature".');
}

void main() {
  group('iOS recording audio clock alignment', () {
    late final String source;
    late final String audioBranch;
    late final String retime;

    setUpAll(() {
      source = _readNativeSource('CameraController.swift');
      audioBranch = _declarationAt(source, 'else if output == audioOutput {');
      retime = _declarationAt(
        source,
        'private func retimedToVideoClock(',
      );
    });

    test('retimes every audio buffer before anything reads its PTS', () {
      // The recorder runs audio and video in two AVCaptureSessions, and each
      // session stamps its buffers on its own synchronizationClock. The
      // writer session is opened with a video PTS, so an audio PTS handed
      // over unconverted lands wherever the audio clock happens to sit -- a
      // field iPhone measured it 0.9-1.8s behind, which the writer edited out
      // at the head and repaid as silence at the tail (#7888). The
      // conversion has to come first: the lead-in diagnostics compare against
      // the anchor, and the append is what the writer keeps.
      final retimeCall = audioBranch.indexOf(
        'let sampleBuffer = retimedToVideoClock(sampleBuffer)',
      );
      final firstSeen = audioBranch.indexOf('firstSeenAudioPTS =');
      final append = audioBranch.indexOf('audioInput.append(sampleBuffer)');
      expect(retimeCall, greaterThan(-1));
      expect(firstSeen, greaterThan(retimeCall));
      expect(append, greaterThan(retimeCall));
    });

    test(
      'converts from the audio session clock onto the video session clock',
      () {
        // Direction matters: the writer anchor is a video PTS, so audio moves
        // onto the video clock, never the reverse. Both clocks are read from
        // the sessions themselves rather than assumed to be the host clock --
        // whether a session runs on the host clock or an audio clock is the
        // framework's decision, and CMSyncConvertTime is the conversion
        // AVCaptureSession.h documents for exactly this.
        expect(
          retime,
          contains('synchronizationClock(of: audioCaptureSession)'),
        );
        expect(retime, contains('synchronizationClock(of: captureSession)'));
        expect(
          retime,
          contains(
            'CMSyncConvertTime(rawPTS, from: audioClock, to: videoClock)',
          ),
        );
      },
    );

    test('is a no-op when both sessions already share a clock', () {
      // Nothing to convert then, and skipping the copy keeps the append path
      // as cheap as before on devices where the framework hands both
      // sessions the same clock.
      expect(retime, contains('audioClock != videoClock else'));
    });

    test('keeps the per-sample timing shape of the original buffer', () {
      // An audio buffer carries hundreds of samples under one timing entry
      // whose duration is the per-sample duration, not the buffer's. Reading
      // the entry back from the buffer and replacing only the timestamps is
      // what keeps the retimed copy the same length; building a fresh entry
      // from CMSampleBufferGetDuration would stretch every buffer by its
      // sample count.
      expect(
        retime,
        contains('CMSampleBufferGetSampleTimingInfo('),
      );
      expect(retime, contains('sampleBuffer, at: 0, timingInfoOut: &timing)'));
      expect(retime, isNot(contains('CMSampleBufferGetDuration')));
      expect(retime, contains('CMSampleBufferCreateCopyWithNewTiming('));
      expect(retime, contains('sampleTimingEntryCount: 1'));
    });

    test('falls back to the original buffer rather than dropping audio', () {
      // A failed copy must not cost the clip its audio; the unconverted
      // buffer is the pre-fix behaviour and strictly better than silence.
      expect(retime, contains('guard status == noErr, let retimed else {'));
      final fallback = retime.indexOf('guard status == noErr, let retimed');
      expect(
        retime.indexOf('return sampleBuffer', fallback),
        greaterThan(fallback),
      );
    });

    test('reports the measured clock offset per recording', () {
      // Whether a device is affected at all is a property of its clocks, not
      // of the code, so the breadcrumb has to carry the offset the fix
      // absorbed: that is how the next log export says how widespread the
      // condition is. Reset at every start so one recording's reading never
      // rides into the next.
      final start = _declarationAt(
        source,
        'private func startRecordingAfterAudioReady(',
      );
      expect(start, contains('self.audioClockOffset = nil'));
      expect(retime, contains('audioClockOffset = convertedPTS - rawPTS'));
      final diagnostics = _declarationAt(
        source,
        'private func logAudioAlignmentDiagnostics(',
      );
      expect(diagnostics, contains('clockOffsetMs='));
    });
  });
}
