// ABOUTME: Static guards for the iOS recorder-to-editor audio-session handoff.
// ABOUTME: disposeCamera must not resolve before the capture sessions stop.

import 'package:flutter_test/flutter_test.dart';

import 'helpers/native_source.dart';

void main() {
  group('iOS camera dispose audio-session handoff', () {
    late final String disposeCamera;
    late final String release;

    setUpAll(() {
      disposeCamera = declarationAt(
        readDarwinNativeSource('DivineCameraPlugin.swift'),
        'private func disposeCamera(',
      );
      release = declarationAt(
        readDarwinNativeSource('CameraController.swift'),
        'func release(',
      );
    });

    test('disposeCamera resolves through the teardown completion', () {
      // Resolving before CameraController.release() has stopped the capture
      // sessions makes the caller's setCategory(.playback) fail with
      // InsufficientPriority (OSStatus 561017449), which leaves the editor
      // playing back through the recorder's .playAndRecord session.
      expect(disposeCamera, contains('controller.release {'));
      expect(disposeCamera, isNot(contains('cameraController?.release()')));
    });

    test('disposeCamera still answers when there is no camera', () {
      // The completion is the only remaining path to `result`, so the
      // no-controller case needs its own early return or Dart waits forever.
      expect(
        disposeCamera,
        contains('guard let controller = cameraController'),
      );
    });

    test('release takes a completion and fires it after the teardown', () {
      expect(
        release,
        startsWith('func release(completion: (() -> Void)? = nil) {'),
      );

      // Pin the dispatch inside the queued teardown and after the capture
      // sessions stop. Asserting `contains` over the whole declaration still
      // passes when the dispatch is hoisted out of the block, or moved to its
      // top -- and either of those fires the completion before the capture
      // sessions are stopped, which is the bug this file guards.
      final teardown = declarationAt(release, 'sessionQueue.async {');
      expect(teardown, contains('self.audioCaptureSession?.stopRunning()'));
      expect(
        teardown,
        contains('DispatchQueue.main.async(execute: completion)'),
      );
      expect(
        teardown.indexOf('DispatchQueue.main.async(execute: completion)'),
        greaterThan(
          teardown.indexOf('self.audioCaptureSession?.stopRunning()'),
        ),
      );
    });

    test('release retains the controller so the completion always fires', () {
      // A `guard let self else { return }` inside the queued teardown would
      // drop the completion and hang the Dart caller awaiting disposeCamera.
      expect(release, isNot(contains('[weak self]')));
    });
  });
}
