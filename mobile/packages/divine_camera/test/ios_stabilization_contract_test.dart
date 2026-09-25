// ABOUTME: Static guards for iOS video stabilization recorder constraints.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS stabilization recorder contract', () {
    late final String controllerSource;

    setUpAll(() {
      final controllerFile = [
        File(
          'darwin/divine_camera/Sources/divine_camera/CameraController.swift',
        ),
        File(
          'packages/divine_camera/darwin/divine_camera/Sources/divine_camera/CameraController.swift',
        ),
      ].firstWhere((file) => file.existsSync());

      controllerSource = controllerFile.readAsStringSync();
    });

    test('does not advertise previewOptimized for full-resolution output', () {
      expect(
        controllerSource,
        isNot(contains('candidates.append((.previewOptimized')),
      );
      expect(
        controllerSource,
        contains('previewOptimized is intentionally omitted for this recorder'),
      );
    });

    test('rejects previewOptimized requests before saving native intent', () {
      expect(
        controllerSource,
        contains('let previous = requestedStabilizationMode'),
      );
      expect(
        controllerSource,
        contains('requestedStabilizationMode = previous'),
      );
      expect(
        controllerSource,
        contains('Self.isPreviewOptimized(requestedStabilizationMode)'),
      );
    });

    test('drives the preview from a dedicated preview-sized output', () {
      // The preview-optimized path needs a second, preview-sized data output —
      // that is the eligibility requirement for .previewOptimized on a data
      // output (the recorder still records from the full-resolution output).
      expect(
        controllerSource,
        contains('func setupPreviewOptimizedOutputIfPossible'),
      );
      expect(
        controllerSource,
        contains('deliversPreviewSizedOutputBuffers = true'),
      );
    });

    test('gates the second output behind a runtime feasibility check', () {
      // A single AVCaptureSession may reject a second video data output, so the
      // preview-optimized path must be guarded and fall back to the existing
      // single-output preview rather than regress on unsupported devices.
      expect(controllerSource, contains('session.canAddOutput(output)'));
      expect(controllerSource, contains('using single-output preview'));
    });

    test('applies previewOptimized to the preview connection only', () {
      // previewOptimized is applied to the preview output (and only while the
      // user has stabilization on); the recorded file keeps the user-selected
      // overscan mode on the full-resolution output.
      expect(controllerSource, contains('.previewOptimized : .off'));
      expect(controllerSource, contains('previewOptimizedActive = true'));
    });
  });
}
