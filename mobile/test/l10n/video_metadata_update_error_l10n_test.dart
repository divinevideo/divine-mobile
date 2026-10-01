// ABOUTME: Tests the VideoMetadataUpdateError -> localized-copy mapping.
// ABOUTME: Proves the mapping is total, distinct, translated, and leak-free.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/video_metadata_update_error_l10n.dart';
import 'package:openvine/models/video_metadata_update_error.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('VideoMetadataUpdateErrorL10n', () {
    test('maps every reason to a non-empty message', () {
      for (final reason in VideoMetadataUpdateError.values) {
        expect(
          l10n.videoMetadataUpdateErrorMessage(reason),
          isNotEmpty,
          reason: 'no message for $reason',
        );
      }
    });

    test('maps every reason to a distinct message', () {
      final messages = VideoMetadataUpdateError.values
          .map(l10n.videoMetadataUpdateErrorMessage)
          .toList();
      expect(
        messages.toSet(),
        hasLength(messages.length),
        reason: 'two reasons resolve to the same copy',
      );
    });

    test('is localized per locale (en differs from de)', () {
      final de = lookupAppLocalizations(const Locale('de'));
      for (final reason in VideoMetadataUpdateError.values) {
        expect(
          l10n.videoMetadataUpdateErrorMessage(reason),
          isNot(equals(de.videoMetadataUpdateErrorMessage(reason))),
          reason: '$reason is an English mirror in de, not a translation',
        );
      }
    });

    test('no message carries exception vocabulary', () {
      // #3589: these replaced `shareMenuFailedToUpdateVideo('$error')`, which
      // rendered `Exception: Failed to publish updated event` verbatim.
      for (final locale in AppLocalizations.supportedLocales) {
        final localized = lookupAppLocalizations(locale);
        for (final reason in VideoMetadataUpdateError.values) {
          final message = localized.videoMetadataUpdateErrorMessage(reason);
          for (final token in const [
            'Exception',
            'errno',
            'PlatformException',
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
