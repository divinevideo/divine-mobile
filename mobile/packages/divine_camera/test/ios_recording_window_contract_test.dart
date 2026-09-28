// ABOUTME: Static guards for the Apple recorder's capture-time window.
// ABOUTME: Late video must not open the clip before the tap or cut its end.

import 'package:flutter_test/flutter_test.dart';

import 'helpers/native_source.dart';

void main() {
  group('Apple recorder recording window', () {
    late final String source;
    late final String delegate;
    late final String videoBranch;
    late final String audioBranch;

    setUpAll(() {
      source = readDarwinNativeSource('CameraController.swift');
      delegate = declarationAt(
        source,
        'func captureOutput(_ output: AVCaptureOutput,',
      );
      videoBranch = declarationAt(delegate, 'if output == videoOutput {');
      audioBranch = declarationAt(delegate, 'else if output == audioOutput {');
    });

    test('opens the writer session only on a frame captured after the tap', () {
      // A look-ahead stabilization mode delivers each frame ~1.5s after it
      // was captured, stamped with its capture time. Anchoring on the first
      // frame *delivered* after the tap opened the clip on picture filmed
      // before it, under 1.5s of silence -- the audio did not exist yet.
      final preRoll = videoBranch.indexOf(
        'guard timestamp >= window.start else {',
      );
      final anchor = videoBranch.indexOf('writer.startSession(atSourceTime:');
      expect(preRoll, greaterThan(-1));
      expect(anchor, greaterThan(preRoll));
      expect(
        declarationAt(videoBranch, 'guard timestamp >= window.start else {'),
        contains('return'),
      );
    });

    test(
      'opens the window before the recording is visible to the delegate',
      () {
        // captureOutput reads the window on videoOutputQueue. A buffer that
        // sees isRecording but no window would fall back to anchoring on
        // whatever frame arrives first.
        final start = declarationAt(
          source,
          'private func startRecordingAfterAudioReady(',
        );
        final window = start.indexOf(
          'self.recordingWindow = RecordingWindow(start: self.videoClockNow()',
        );
        final recording = start.indexOf('self.isRecording = true');
        expect(window, greaterThan(-1));
        expect(recording, greaterThan(window));
      },
    );

    test('holds audio until the session opens, then appends it first', () {
      // The mic delivers ~1.5s ahead of a look-ahead video pipeline. The
      // sound captured in that time has to wait for the first frame rather
      // than be dropped, or the silent head just moves inside the window.
      final beforeSession = declarationAt(
        audioBranch,
        'if !isWriterSessionStarted {',
      );
      expect(beforeSession, contains('holdPendingAudio(sampleBuffer'));
      expect(beforeSession, isNot(contains('appendAudio(')));

      final anchor = videoBranch.indexOf('writer.startSession(atSourceTime:');
      final flush = videoBranch.indexOf('appendPendingAudio(to: audioInput)');
      expect(flush, greaterThan(anchor));
    });

    test('drops held audio the session starts after', () {
      final flush = declarationAt(
        source,
        'private func appendPendingAudio(to audioInput: AVAssetWriterInput)',
      );
      expect(
        flush,
        contains('Self.endTime(of: next) <= anchor'),
      );
      final hold = declarationAt(
        source,
        'private func holdPendingAudio(',
      );
      expect(hold, contains('Self.endTime(of: sampleBuffer) > start'));
      expect(hold, contains('Self.maxPendingAudioSeconds'));
    });

    test('closes the window on capture time before the stop is visible', () {
      // The stop instant is read on the call, not when the pipeline catches
      // up, and set before isRecording goes false so a buffer that no longer
      // sees the recording still sees where it ends.
      final stop = declarationAt(source, 'func stopRecording(');
      final stopPTS = stop.indexOf('let stopPTS = videoClockNow()');
      final closed = stop.indexOf('_recordingWindow?.stop = stopPTS');
      final notRecording = stop.indexOf('isRecording = false');
      expect(stopPTS, greaterThan(-1));
      expect(closed, greaterThan(stopPTS));
      expect(notRecording, greaterThan(closed));
    });

    test('waits for frames captured before the stop, but not forever', () {
      // Stopping on delivery cut the last ~1.5s the user filmed. The first
      // frame captured at or after the stop ends the wait; a timeout covers a
      // pipeline that stops delivering.
      final stopFrame = declarationAt(
        videoBranch,
        'if let stop = window.stop, timestamp >= stop {',
      );
      expect(stopFrame, contains('finishPendingStop(end: "delivered")'));
      expect(stopFrame, contains('return'));

      final stop = declarationAt(source, 'func stopRecording(');
      expect(stop, contains('self.pendingStopFinish = finish'));
      expect(stop, contains('deadline: .now() + Self.maxStopDrainSeconds'));
      expect(stop, contains('self.finishPendingStop(end: "timeout")'));
    });

    test('keeps sound captured after the stop out of the clip', () {
      expect(
        audioBranch,
        contains(
          r'let beforeStop = window.stop.map { timestamp < $0 } ?? true',
        ),
      );
      expect(
        audioBranch,
        contains('if beforeStop && writer.status == .writing'),
      );
    });

    test('does not wait on a pipeline that can no longer deliver', () {
      // A lost camera or a paused preview delivers nothing more; waiting out
      // the timeout there risks the encoder not surviving a background
      // (#9210).
      final salvage = declarationAt(
        source,
        'private func salvageInterruptedRecording(',
      );
      expect(salvage, contains('stopRecording(drainPipeline: false)'));
      expect(salvage, contains('finishStopDrainEarly('));
      expect(
        declarationAt(source, 'func pausePreview('),
        contains('finishStopDrainEarly('),
      );
      expect(
        declarationAt(source, 'func release('),
        contains('finishStopDrainEarly('),
      );
    });

    test('flushes held audio before the session is ended', () {
      final finalize = declarationAt(
        source,
        'private func finalizeRecording(',
      );
      final closeWindow = finalize.indexOf('recordingWindow = nil');
      final flush = finalize.indexOf('appendPendingAudio(to: audioInput)');
      final end = finalize.indexOf('writer.endSession(atSourceTime:');
      final finished = finalize.indexOf('audioWriterInput?.markAsFinished()');
      expect(closeWindow, greaterThan(-1));
      expect(flush, greaterThan(closeWindow));
      expect(end, greaterThan(flush));
      expect(finished, greaterThan(end));
    });

    test('retimes audio for as long as the window is open', () {
      // The window outlives isRecording while a stop drains; audio captured
      // just before the stop still has to land on the video clock.
      final retime = declarationAt(
        source,
        'private func retimedToVideoClock(',
      );
      expect(
        retime,
        contains('guard recordingWindow != nil else { return sampleBuffer }'),
      );
    });
  });
}
