// ABOUTME: Static guards for the iOS recorder's audio-to-video clock alignment.
// ABOUTME: Audio buffers must be retimed onto the video session clock first.

import 'package:flutter_test/flutter_test.dart';

import 'helpers/native_source.dart';

void main() {
  group('iOS recording audio clock alignment', () {
    late final String source;
    late final String audioBranch;
    late final String retime;

    setUpAll(() {
      source = readIosNativeSource('CameraController.swift');
      audioBranch = declarationAt(source, 'else if output == audioOutput {');
      retime = declarationAt(
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

    test('reports zero when both sessions already share a clock', () {
      // Nothing needs converting, but recording the zero keeps diagnostics
      // distinct from a buffer whose clocks or timing could not be read.
      final sharedClock = declarationAt(
        retime,
        'if audioClock == videoClock {',
      );
      expect(sharedClock, contains('audioClockOffset = .zero'));
      expect(sharedClock, contains('return sampleBuffer'));
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

    test('counts every path a buffer can leave unconverted', () {
      // A retry-fallback that logs nothing looks identical to a clean
      // recording: clockOffsetMs is a property of the clocks, not of any one
      // buffer, so it stays set even on a recording where every later
      // buffer failed to retime. This counter is what tells the two apart.
      expect(source, contains('private var audioRetimeFailureCount = 0'));

      final start = declarationAt(
        source,
        'private func startRecordingAfterAudioReady(',
      );
      expect(start, contains('self.audioRetimeFailureCount = 0'));

      // Every early-return path inside retimedToVideoClock that can fire
      // while recording -- an unavailable clock, unreadable timing info, a
      // non-numeric converted timestamp, or a failed retimed copy -- counts
      // the buffer as unconverted before returning it unchanged.
      expect(
        'audioRetimeFailureCount += 1'.allMatches(retime).length,
        equals(4),
      );

      final diagnostics = declarationAt(
        source,
        'private func logAudioAlignmentDiagnostics(',
      );
      expect(
        diagnostics,
        contains(r'retimeFailures=\(self.audioRetimeFailureCount)'),
      );
    });

    test('rejects a converted timestamp the sync call could not produce', () {
      // CMSyncConvertTime can return a non-numeric CMTime; appending that to
      // the writer would fail the whole asset-writer session rather than
      // just this buffer, which is worse than the pre-fix misalignment.
      final convert = retime.indexOf('let convertedPTS = CMSyncConvertTime(');
      final guardLine = retime.indexOf('guard convertedPTS.isNumeric else {');
      expect(convert, greaterThan(-1));
      expect(guardLine, greaterThan(convert));
    });

    test(
      'only records the offset once the retimed buffer reaches the writer',
      () {
        // Latching the offset before the copy is known to succeed makes the
        // breadcrumb claim every buffer converted, when a persistent copy
        // failure means none after the first one did.
        final copyGuard = retime.indexOf(
          'guard status == noErr, let retimed else {',
        );
        final offsetAssignment = retime.indexOf(
          'audioClockOffset = convertedPTS - rawPTS',
        );
        expect(copyGuard, greaterThan(-1));
        expect(offsetAssignment, greaterThan(copyGuard));
      },
    );

    test('reports the measured clock offset per recording', () {
      // Whether a device is affected at all is a property of its clocks, not
      // of the code, so the breadcrumb has to carry the offset the fix
      // absorbed: that is how the next log export says how widespread the
      // condition is. Reset at every start so one recording's reading never
      // rides into the next.
      final start = declarationAt(
        source,
        'private func startRecordingAfterAudioReady(',
      );
      expect(start, contains('self.audioClockOffset = nil'));
      expect(retime, contains('audioClockOffset = convertedPTS - rawPTS'));
      final diagnostics = declarationAt(
        source,
        'private func logAudioAlignmentDiagnostics(',
      );
      expect(diagnostics, contains('clockOffsetMs='));
    });

    test('has no reachable pre-16.0 fallback for the sync clock', () {
      // The app pins IPHONEOS_DEPLOYMENT_TARGET to 16.0 (mobile/ios and
      // mobile/ios/Podfile), so a masterClock fallback behind
      // #available(iOS 15.4, *) could never execute -- dead code standing in
      // for a compatibility path the app does not support.
      final clockFn = declarationAt(
        source,
        'private func synchronizationClock(',
      );
      expect(clockFn, contains('return session.synchronizationClock'));
      expect(clockFn, isNot(contains('#available')));
      expect(clockFn, isNot(contains('masterClock')));
    });
  });
}
