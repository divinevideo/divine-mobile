// ABOUTME: Static guards for the native auto-stop event contract.
// ABOUTME: Pins that a stop which captured nothing still reaches Dart (#9261).

import 'package:flutter_test/flutter_test.dart';

import 'helpers/native_source.dart';

void main() {
  // A native stop that captured nothing must still reach Dart, or the recorder
  // keeps showing a recording that no longer exists. The signal is a payload
  // with no filePath; a nil `userInfo` would be dropped by the plugin's guard.
  group('native auto-stop contract', () {
    group('iOS', () {
      late final String controllerSource;

      setUpAll(() {
        controllerSource = readIosNativeSource('CameraController.swift');
      });

      test('sends an empty payload when there is no result', () {
        final send = declarationAt(
          controllerSource,
          'private func sendAutoStopEvent(',
        );

        expect(send, contains('result: [String: Any]?'));
        expect(send, contains('userInfo: result ?? [:]'));
      });

      test('the max-duration auto-stop reports every outcome', () {
        final autoStop = declarationAt(
          controllerSource,
          'private func autoStopRecording()',
        );

        expect(autoStop, contains('self?.sendAutoStopEvent(result: result)'));
        expect(autoStop, isNot(contains('if let result')));
      });

      test('the interruption salvage reports every outcome', () {
        final salvage = declarationAt(
          controllerSource,
          'private func salvageInterruptedRecording(',
        );

        expect(salvage, contains('self?.sendAutoStopEvent(result: result)'));
        expect(salvage, isNot(contains('if let result')));
      });
    });

    group('macOS', () {
      test('the max-duration auto-stop reports every outcome', () {
        final autoStop = declarationAt(
          readMacosNativeSource('CameraController+Recording.swift'),
          'func autoStopRecording()',
        );

        expect(autoStop, contains('userInfo: result ?? [:]'));
        expect(autoStop, isNot(contains('if let result')));
      });
    });

    group('Android', () {
      test('the max-duration auto-stop reports every outcome', () {
        final autoStop = declarationAt(
          readAndroidNativeSource('CameraController.kt'),
          'private fun autoStopRecording()',
        );

        expect(
          autoStop,
          contains('onAutoStopListener?.invoke(result ?: emptyMap())'),
        );
      });
    });
  });
}
