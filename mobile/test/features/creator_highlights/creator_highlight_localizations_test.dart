import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:openvine/l10n/l10n.dart';

void main() {
  group('Creator highlight counts', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test('uses ${locale.languageCode} number formatting', () {
        final l10n = lookupAppLocalizations(locale);
        final numbers = NumberFormat.decimalPattern(locale.toLanguageTag());

        for (final views in [0, 1, 12345, 1234567]) {
          for (final message in [
            l10n.creatorHighlightWeeklyViews(views),
            l10n.creatorHighlightTopVideoViews(views),
            l10n.creatorHighlightWeeklyLikes(views),
            l10n.creatorHighlightWeeklyComments(views),
          ]) {
            expect(
              message,
              contains(numbers.format(views)),
              reason: 'Counts should follow the selected app language.',
            );
          }
        }
      });
    }
  });
}
