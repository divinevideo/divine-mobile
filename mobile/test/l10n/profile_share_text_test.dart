import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';

void main() {
  group('profile share text', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test('preserves the complete URL in $locale', () {
        final l10n = lookupAppLocalizations(Locale(locale.languageCode));
        const url = 'https://alice.divine.video';
        final text = l10n.profileShareText('Alice', url);

        expect(text, contains(url));
        expect(text, isNot(contains('divine.video/profile/https://')));
        expect('https://'.allMatches(text), hasLength(1));
      });
    }
  });
}
