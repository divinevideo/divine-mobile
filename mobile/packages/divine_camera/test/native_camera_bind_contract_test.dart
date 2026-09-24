// ABOUTME: Static guards for how often the native camera binds: the saved
// ABOUTME: stabilization mode rides the first bind, and pause really unbinds.

import 'package:flutter_test/flutter_test.dart';

import 'helpers/native_source.dart';

void main() {
  group('native camera bind contract', () {
    late final String androidPlugin;
    late final String androidController;
    late final String iosPlugin;
    late final String iosController;

    setUpAll(() {
      androidPlugin = readAndroidNativeSource('DivineCameraPlugin.kt');
      androidController = readAndroidNativeSource('CameraController.kt');
      iosPlugin = readIosNativeSource('DivineCameraPlugin.swift');
      iosController = readIosNativeSource('CameraController.swift');
    });

    group('initial stabilization mode', () {
      test('both plugins read it off the channel', () {
        // A key dropped here would silently open unstabilized: the recorder
        // no longer re-applies the saved mode after start.
        expect(
          androidPlugin,
          contains('call.argument<String>("videoStabilizationMode")'),
        );
        expect(iosPlugin, contains('args["videoStabilizationMode"]'));
      });

      test('Android resolves it before the first bind', () {
        final initialize = declarationAt(
          androidController,
          '    fun initialize(',
        );
        final modeAt = initialize.indexOf('requestedStabilizationMode =');
        final bindAt = initialize.indexOf('ProcessCameraProvider.getInstance');
        expect(modeAt, isNonNegative);
        expect(modeAt, lessThan(bindAt));
      });

      test('Android opens unsupported modes with stabilization off', () {
        final gate = declarationAt(
          androidController,
          'private fun initialStabilizationMode(',
        );
        expect(
          gate,
          contains('availableVideoStabilizationModesForCurrentLens()'),
        );
        expect(gate, contains('STABILIZATION_OFF'));
      });

      test('iOS falls back to off when the connection rejects the mode', () {
        expect(
          iosController,
          contains(
            'if !applyVideoStabilization() && '
            'requestedStabilizationMode != .off {',
          ),
        );
      });
    });

    group('Android pause', () {
      late final String pause;
      late final String resume;

      setUpAll(() {
        pause = declarationAt(androidController, '    fun pausePreview(');
        resume = declarationAt(androidController, '    fun resumePreview(');
      });

      test('the plugin forwards whether the pause releases the camera', () {
        expect(
          androidPlugin,
          contains('call.argument<Boolean>("releaseAudio") ?: true'),
        );
        expect(
          androidPlugin,
          contains('pausePreview(releaseCamera = releaseAudio)'),
        );
      });

      test('a releasing pause unbinds the use cases', () {
        expect(pause, contains('provider.unbindAll()'));
        expect(pause, contains('isPaused = true'));
      });

      test('a transient pause keeps the camera bound', () {
        expect(pause, contains('if (!releaseCamera || isPaused) return'));
      });

      test('a recording in progress is never interrupted', () {
        final guardAt = pause.indexOf('if (isRecording || recording != null)');
        expect(guardAt, isNonNegative);
        expect(guardAt, lessThan(pause.indexOf('provider.unbindAll()')));
      });

      test('resume rebinds only after a releasing pause', () {
        expect(resume, contains('if (isPaused) {'));
        expect(resume, contains('rebindAfterPause(provider)'));
      });

      test('the rebind restores zoom and torch', () {
        final rebind = declarationAt(
          androidController,
          'private fun rebindAfterPause(',
        );
        expect(rebind, contains('setZoomRatio(currentZoom)'));
        expect(rebind, contains('enableTorch(true)'));
      });
    });

    test('Android scans the cameras once per process', () {
      final check = declarationAt(
        androidController,
        'private fun checkCameraAvailability(',
      );
      expect(
        check,
        startsWith(
          'private fun checkCameraAvailability() {\n'
          '        cachedInventory?.let {',
        ),
      );
      expect(check, contains('cachedInventory = CameraInventory('));
    });
  });
}
