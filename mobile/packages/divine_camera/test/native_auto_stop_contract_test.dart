// ABOUTME: Static guards for the native auto-stop event contract.
// ABOUTME: Pins that a stop which captured nothing still reaches Dart (#9261).

import 'package:flutter_test/flutter_test.dart';

import 'helpers/native_source.dart';

/// A Swift stop-completion [closure] reaches [send] for every result: it has
/// no early exit or `else` branch, and the nil-result block does not own it.
void _expectSwiftSendsEveryResult(String closure, {required String send}) {
  expect(closure, contains(send));
  expect(closure, isNot(contains('return')));
  expect(closure, isNot(contains('else')));
  expect(declarationAt(closure, 'if result == nil {'), isNot(contains(send)));
}

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

        _expectSwiftSendsEveryResult(
          declarationAt(autoStop, 'stopRecording { [weak self] result, error'),
          send: 'self?.sendAutoStopEvent(result: result)',
        );
      });

      test('the interruption salvage reports every outcome', () {
        final salvage = declarationAt(
          controllerSource,
          'private func salvageInterruptedRecording(',
        );

        _expectSwiftSendsEveryResult(
          declarationAt(salvage, 'stopRecording { [weak self] result, error'),
          send: 'self?.sendAutoStopEvent(result: result)',
        );
      });
    });

    group('macOS', () {
      test('the max-duration auto-stop reports every outcome', () {
        final autoStop = declarationAt(
          readMacosNativeSource('CameraController+Recording.swift'),
          'func autoStopRecording()',
        );

        _expectSwiftSendsEveryResult(
          declarationAt(autoStop, 'stopRecording { result, error'),
          send: 'userInfo: result ?? [:]',
        );
      });
    });

    group('Android', () {
      test('the max-duration auto-stop reports every outcome', () {
        final callback = declarationAt(
          readAndroidNativeSource('CameraController.kt'),
          'autoStopCallback = { result, error ->',
        );
        const send = 'onAutoStopListener?.invoke(result ?: emptyMap())';

        expect(callback, contains(send));
        expect(callback, isNot(contains('return@')));
        expect(
          declarationAt(callback, 'if (result != null) {'),
          isNot(contains(send)),
        );
        expect(declarationAt(callback, '} else {'), isNot(contains(send)));
      });
    });
  });
}
