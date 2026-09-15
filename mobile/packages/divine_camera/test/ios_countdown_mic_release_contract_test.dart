// ABOUTME: Static guards for the iOS mic release around the countdown (#4539).
// ABOUTME: The beeps must play into a closed mic; the record tap reopens it.

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
  group('iOS countdown mic release', () {
    late final String controller;
    late final String plugin;
    late final String suspend;
    late final String resume;

    setUpAll(() {
      controller = _readNativeSource('CameraController.swift');
      plugin = _readNativeSource('DivineCameraPlugin.swift');
      suspend = _declarationAt(
        controller,
        'func suspendAudioCapture(completion:',
      );
      resume = _declarationAt(
        controller,
        'func resumeAudioCapture(completion:',
      );
    });

    test('plugin dispatches both method names', () {
      // A missing case answers FlutterMethodNotImplemented, which Dart
      // surfaces as a MissingPluginException in the middle of every
      // countdown.
      final handle = _declarationAt(plugin, 'public func handle(');
      expect(handle, contains('case "suspendAudioCapture":'));
      expect(handle, contains('case "resumeAudioCapture":'));
    });

    test('plugin answers both calls without a controller', () {
      // The controller's completion is the only path to `result`, so the
      // no-controller case needs its own early return or Dart waits forever.
      for (final name in ['suspendAudioCapture', 'resumeAudioCapture']) {
        final dispatch = _declarationAt(plugin, 'private func $name(');
        expect(
          dispatch,
          contains('guard let controller = cameraController'),
          reason: name,
        );
        expect(dispatch, contains('result(nil)'), reason: name);
      }
    });

    test('suspend stops the capture session but keeps the audio session', () {
      // The beeps play on the shared AVAudioSession, and the reopen must take
      // the cheap "restart" path in attachAudioToSessionIfNeeded(). A
      // setActive(false) here would silence the countdown and force the
      // deactivate/reconfigure/activate cycle onto the record tap.
      expect(suspend, contains('session.stopRunning()'));
      expect(suspend, isNot(contains('setActive(')));
      expect(suspend, isNot(contains('setCategory(')));
    });

    test('suspend never touches a recording in progress', () {
      // Stopping the capture session mid-recording leaves the writer with no
      // audio buffers — a clip with a silent or missing track.
      expect(suspend, contains('!self.isRecording'));
      expect(
        suspend.indexOf('!self.isRecording'),
        lessThan(suspend.indexOf('session.stopRunning()')),
      );
    });

    test('suspend latches the flag even before the pre-warm has built', () {
      // The flag is what keeps the deferred pre-warm from reopening the mic
      // mid-countdown, so it must be set before the "nothing to stop" exit.
      expect(suspend, contains('self.isAudioCaptureSuspended = true'));
      expect(
        suspend.indexOf('self.isAudioCaptureSuspended = true'),
        lessThan(
          suspend.indexOf('guard let session = self.audioCaptureSession'),
        ),
      );
    });

    test('deferred pre-warm leaves a suspended mic closed', () {
      final preWarm = _declarationAt(
        controller,
        'sessionQueue.asyncAfter(deadline: .now() + 1.0)',
      );
      expect(preWarm, contains('!self.isAudioCaptureSuspended'));
      expect(
        preWarm.indexOf('!self.isAudioCaptureSuspended'),
        lessThan(preWarm.indexOf('attachAudioToSessionIfNeeded()')),
      );
    });

    test('interruption recovery leaves a suspended mic closed', () {
      final handler = _declarationAt(
        controller,
        '@objc private func handleAudioSessionInterruption(',
      );
      final recovery = _declarationAt(handler, 'sessionQueue.async {');
      expect(recovery, contains('!self.isAudioCaptureSuspended'));
      expect(
        recovery.indexOf('!self.isAudioCaptureSuspended'),
        lessThan(recovery.indexOf('attachAudioToSessionIfNeeded()')),
      );
    });

    test(
      'resume reopens through the record-tap attach and clears the flag',
      () {
        expect(resume, contains('self.isAudioCaptureSuspended = false'));
        expect(resume, contains('attachAudioToSessionIfNeeded()'));
        expect(
          resume.indexOf('self.isAudioCaptureSuspended = false'),
          lessThan(resume.indexOf('attachAudioToSessionIfNeeded()')),
        );
      },
    );

    test('resume does not reopen the mic while the preview is paused', () {
      // The app is not visible; resumePreview() reattaches on return, and
      // grabbing the mic here would show the lock-screen recording indicator
      // #5869 removed.
      expect(resume, contains('!self.isPaused'));
      expect(
        resume.indexOf('!self.isPaused'),
        lessThan(resume.indexOf('attachAudioToSessionIfNeeded()')),
      );
    });

    test('suspend and resume always answer the Dart caller', () {
      // The completion is deferred ahead of the weak-self guard, so a
      // controller released mid-countdown still answers instead of leaving
      // the bloc awaiting the call forever. For suspend it also means the
      // beeps start only once the mic is actually closed.
      const completion =
          'defer { DispatchQueue.main.async(execute: completion) }';
      for (final (name, declaration) in [
        ('suspend', suspend),
        ('resume', resume),
      ]) {
        expect(declaration, contains(completion), reason: name);
        expect(
          declaration.indexOf(completion),
          lessThan(declaration.indexOf('guard let self = self')),
          reason: name,
        );
      }
    });

    test('record tap clears the flag before it attaches', () {
      // A cancelled countdown never resumes; the next recording must reopen
      // the mic on its own rather than record without audio.
      final start = _declarationAt(controller, 'func startRecording(');
      expect(start, contains('self.isAudioCaptureSuspended = false'));
      expect(
        start.indexOf('self.isAudioCaptureSuspended = false'),
        lessThan(start.indexOf('self.attachAudioToSessionIfNeeded()')),
      );
    });

    test('resumePreview clears the flag before it attaches', () {
      final resumePreview = _declarationAt(
        controller,
        'func resumePreview(completion:',
      );
      expect(resumePreview, contains('self.isAudioCaptureSuspended = false'));
      expect(
        resumePreview.indexOf('self.isAudioCaptureSuspended = false'),
        lessThan(resumePreview.indexOf('self.attachAudioToSessionIfNeeded()')),
      );
    });
  });
}
