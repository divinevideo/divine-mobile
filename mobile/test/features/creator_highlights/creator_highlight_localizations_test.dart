import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:openvine/l10n/l10n.dart';

void main() {
  group('Creator highlight view counts', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test('uses ${locale.languageCode} number formatting', () {
        final l10n = lookupAppLocalizations(locale);
        final numbers = NumberFormat.decimalPattern(locale.toLanguageTag());

        for (final views in [0, 1, 12345, 1234567]) {
          expect(
            l10n.creatorHighlightWeeklyViews(views),
            contains(numbers.format(views)),
            reason: 'The view count should follow the selected app language.',
          );
        }
      });
    }
  });
}
