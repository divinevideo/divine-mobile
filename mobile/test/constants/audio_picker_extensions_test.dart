// ABOUTME: Tests that the formats the audio pickers offer are the ones the
// ABOUTME: import accepts and the ones its refusal copy names.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/audio_picker_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/audio_mime_type.dart';

void main() {
  group('audioPickerExtensions', () {
    test('lists only formats the import accepts', () {
      for (final extension in audioPickerExtensions) {
        expect(
          audioMimeTypeForPath('sound.$extension'),
          isNotNull,
          reason: '.$extension is offered but the import would refuse it',
        );
      }
    });

    test('are all named by the import hint and the refusal copy', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      for (final copy in [
        l10n.soundUploadSupportedFormats,
        l10n.soundsImportUnsupportedFormat,
      ]) {
        for (final extension in audioPickerExtensions) {
          expect(copy, contains(extension.toUpperCase()));
        }
      }
    });
  });
}
