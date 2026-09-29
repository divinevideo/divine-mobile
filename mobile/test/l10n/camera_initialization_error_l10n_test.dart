// ABOUTME: Tests the CameraInitializationError -> localized-string mapping.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/camera_initialization_error_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('CameraInitializationErrorL10n', () {
    test('maps every reason to a non-empty message', () {
      for (final error in CameraInitializationError.values) {
        expect(
          l10n.cameraInitializationErrorMessage(error),
          isNotEmpty,
          reason: 'no message for $error',
        );
      }
    });

    test('maps every reason to a distinct message', () {
      final messages = CameraInitializationError.values
          .map(l10n.cameraInitializationErrorMessage)
          .toList();
      expect(
        messages.toSet(),
        hasLength(messages.length),
        reason: 'two reasons resolve to the same copy',
      );
    });

    // The whole point of #3591: no reason may render implementation detail.
    test('never leaks exception or platform vocabulary', () {
      for (final error in CameraInitializationError.values) {
        final message = l10n.cameraInitializationErrorMessage(error);
        for (final leak in const [
          'Exception',
          'PlatformException',
          'INIT_',
          'initialization failed',
          'null',
        ]) {
          expect(
            message,
            isNot(contains(leak)),
            reason: '$error copy contains "$leak"',
          );
        }
      }
    });

    test('is localized per locale', () {
      final de = lookupAppLocalizations(const Locale('de'));
      for (final error in CameraInitializationError.values) {
        expect(
          de.cameraInitializationErrorMessage(error),
          isNot(l10n.cameraInitializationErrorMessage(error)),
          reason: '$error is not translated for de',
        );
      }
    });
  });
}
