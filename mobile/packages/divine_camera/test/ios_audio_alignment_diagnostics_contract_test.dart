// ABOUTME: Static guards for the iOS recording audio-alignment breadcrumb.
// ABOUTME: A finished clip must carry why its audio started where it did.

import 'package:flutter_test/flutter_test.dart';

import 'helpers/native_source.dart';

void main() {
  group('iOS recording audio-alignment diagnostics', () {
    late final String source;
    late final String diagnostics;

    setUpAll(() {
      source = readIosNativeSource('CameraController.swift');
      diagnostics = declarationAt(
        source,
        'private func logAudioAlignmentDiagnostics(',
      );
    });

    test('reports every field a leading-silence report needs', () {
      // #7888 was reported as "the first two seconds have no audio" and could
      // not be reproduced in-house, so the clip itself has to say which of the
      // candidate causes applied. Each key below discriminates between them:
      // appendLeadIn vs micLeadIn separates a late mic from the writer gate
      // dropping buffers, tapToCapture catches a slow start that loses leading
      // content without shifting audio at all, and the attach path plus the
      // session state on entry say whether the record tap paid for a
      // reconfigure. Drop one and the next report is unactionable again.
      for (final key in const [
        'appendLeadInMs=',
        'micLeadInMs=',
        'audioTrackStartMs=',
        'tapToCaptureMs=',
        'attachMs=',
        'attachPath=',
        'entry=[',
        'stabilization=',
      ]) {
        expect(diagnostics, contains(key), reason: 'missing $key');
      }
    });

    test('reads the audio track start from the finished asset', () {
      // The in-flight PTS values say what the writer was handed; only the
      // finished file says what a player will actually do with it.
      expect(diagnostics, contains('asset.tracks(withMediaType: .audio)'));
      expect(diagnostics, contains('timeRange.start'));
    });

    test('runs for recordings that ended up without an audio track', () {
      // A clip with no audio at all is the loudest version of this bug, so the
      // breadcrumb must not sit behind the hasAudioTrack branch that only
      // covers the good case.
      final stop = declarationAt(source, 'func stopRecording(');
      final call = stop.indexOf('self.logAudioAlignmentDiagnostics(asset:');
      final branch = stop.indexOf('if hasAudioTrack {');
      expect(call, greaterThan(-1));
      expect(branch, greaterThan(-1));
      expect(call, lessThan(branch));
    });

    test('captures the writer anchor where the session is started', () {
      // The anchor is every lead-in measurement's zero point. Recording it
      // anywhere but at startSession would measure a different instant than
      // the one the audio gate compares against.
      final delegate = declarationAt(
        source,
        'func captureOutput(_ output: AVCaptureOutput,',
      );
      final anchor = delegate.indexOf('writer.startSession(atSourceTime:');
      expect(anchor, greaterThan(-1));
      expect(
        delegate.indexOf('writerAnchorPTS = timestamp'),
        greaterThan(anchor),
      );
    });

    test('records the first mic buffer before every gate that drops it', () {
      // firstSeenAudioPTS exists to answer "did the mic deliver anything at
      // all". Three gates sit between the buffer and the writer: no audio
      // writer input (attach failed), an interruption in progress, and the
      // writer session not being open yet. Behind any of them a clip whose
      // mic never delivered and a clip whose buffers were all discarded both
      // report n/a -- the one distinction the field is here to make.
      final audioBranch = declarationAt(
        source,
        'else if output == audioOutput {',
      );
      final seen = audioBranch.indexOf('firstSeenAudioPTS =');
      final appendGate = audioBranch.indexOf(
        'if isRecording, !audioInterrupted, let writer = assetWriter,',
      );
      final sessionGate = audioBranch.indexOf('if isWriterSessionStarted &&');
      expect(seen, greaterThan(-1));
      expect(appendGate, greaterThan(-1));
      expect(sessionGate, greaterThan(-1));
      expect(seen, lessThan(appendGate));
      expect(seen, lessThan(sessionGate));
    });

    test('samples the audio session state before it is repaired', () {
      // attachAudioToSessionIfNeeded() fixes a drifted category on the spot.
      // Sampling after that repair would report .playAndRecord every time and
      // hide the drift the record tap actually paid for. Both entry paths --
      // the reuse branch and the first-time build -- have their own repair
      // call, so both are pinned; the call text is matched rather than the
      // bare function name, which also appears in the surrounding comments.
      final attach = declarationAt(
        source,
        'private func attachAudioToSessionIfNeeded()',
      );

      final reuseEntry = attach.indexOf('self.lastAudioEntryRoute =');
      final reuseRepair = attach.indexOf(
        'let configured = configureAudioSessionForRecording()',
      );
      expect(reuseEntry, greaterThan(-1));
      expect(reuseRepair, greaterThan(-1));
      expect(reuseEntry, lessThan(reuseRepair));

      final buildEntry = attach.indexOf('self.lastAudioAttachPath = "build"');
      final buildRepair = attach.indexOf(
        'if !configureAudioSessionForRecording() {',
      );
      expect(buildEntry, greaterThan(-1));
      expect(buildRepair, greaterThan(-1));
      expect(buildEntry, lessThan(buildRepair));
    });

    test('measures the attach around the call, not inside it', () {
      // The cost that matters is what the record tap waits for, which includes
      // every branch attach can take -- including the ones that return early.
      final start = declarationAt(source, 'func startRecording(');
      expect(start, contains('let attachStart = Date()'));
      expect(
        start.indexOf('lastAudioAttachMs = Date().timeIntervalSince'),
        greaterThan(start.indexOf('self.attachAudioToSessionIfNeeded()')),
      );
    });

    test("pairs attachMs with this recording's own attach path", () {
      // attachAudioToSessionIfNeeded() also runs from the deferred 1s
      // pre-warm, the interruption-ended handler and resumePreview(), and
      // none of the three is gated on isRecording. Reading the process-wide
      // lastAudio* pair at stop time would print one attach's path beside
      // another attach's duration -- sessionQueue is serial, so the pre-warm
      // cannot overlap the tap's attach, but it becomes ready at its deadline
      // and runs straight after it, mid-recording.
      final start = declarationAt(source, 'func startRecording(');
      final snapshot = start.indexOf(
        'self.recordingAudioAttachPath = self.lastAudioAttachPath',
      );
      final measured = start.indexOf(
        'lastAudioAttachMs = Date().timeIntervalSince',
      );
      expect(snapshot, greaterThan(-1));
      expect(snapshot, greaterThan(measured));
      expect(
        diagnostics,
        contains(r'attachPath=\(self.recordingAudioAttachPath)'),
      );
      expect(
        diagnostics,
        contains(r'entry=[\(self.recordingAudioEntryRoute)]'),
      );
    });

    test('reports the stabilization the recorder actually used', () {
      // requestedStabilizationMode is reverted only when the mode is rejected
      // at set time. A camera switch re-applies it, discards the result and
      // leaves the stored value naming a mode the recording never had. Since
      // a look-ahead mode is the one thing in the capture path that can move
      // the writer anchor by hundreds of ms, this field has to be the mode
      // the connection carried, not the one that was asked for.
      expect(diagnostics, contains('self.reportedStabilizationString()'));
      expect(
        diagnostics,
        isNot(contains('from: self.requestedStabilizationMode')),
      );
    });
  });
}
