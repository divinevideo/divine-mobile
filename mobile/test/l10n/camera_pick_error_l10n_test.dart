// ABOUTME: Tests the CameraPickError -> localized-copy mapping.
// ABOUTME: Proves the mapping is total, distinct, translated, and leak-free.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/camera_pick_error_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/camera_pick_error.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('CameraPickErrorL10n', () {
    test('maps every reason to a non-empty message', () {
      for (final reason in CameraPickError.values) {
        expect(
          l10n.cameraPickErrorMessage(reason),
          isNotEmpty,
          reason: 'no message for $reason',
        );
      }
    });

    test('maps every reason to a distinct message', () {
      final messages = CameraPickError.values
          .map(l10n.cameraPickErrorMessage)
          .toList();
      expect(
        messages.toSet(),
        hasLength(messages.length),
        reason: 'two reasons resolve to the same copy',
      );
    });

    test('is localized per locale (en differs from de)', () {
      final de = lookupAppLocalizations(const Locale('de'));
      for (final reason in CameraPickError.values) {
        expect(
          l10n.cameraPickErrorMessage(reason),
          isNot(equals(de.cameraPickErrorMessage(reason))),
          reason: '$reason is an English mirror in de, not a translation',
        );
      }
    });

    test('no message carries exception vocabulary', () {
      // #3589: this replaced `profileSetupCameraAccessFailed('$e')`, which
      // rendered `PlatformException(camera_access_denied, ..., null, null)`.
      for (final locale in AppLocalizations.supportedLocales) {
        final localized = lookupAppLocalizations(locale);
        for (final reason in CameraPickError.values) {
          final message = localized.cameraPickErrorMessage(reason);
          for (final token in const [
            'PlatformException',
            'camera_access',
            'null',
          ]) {
            expect(
              message,
              isNot(contains(token)),
              reason: '$locale/$reason leaks "$token"',
            );
          }
        }
      }
    });
  });
}
