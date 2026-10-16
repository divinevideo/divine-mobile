// ABOUTME: Tests for PrivateKeySearchWarning, the notice shown in place of a
// ABOUTME: search when the typed text looks like a private key.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/private_key_search_warning.dart';

const _privateKey =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

Widget _app(String query) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: PrivateKeySearchWarning(query: query)),
);

void main() {
  group(PrivateKeySearchWarning, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    group('renders', () {
      testWidgets('the warning when the query holds a private key', (
        tester,
      ) async {
        await tester.pumpWidget(_app('my key $_privateKey'));

        expect(find.text(l10n.searchPrivateKeyWarning), findsOneWidget);
      });

      testWidgets('without the key itself', (tester) async {
        await tester.pumpWidget(_app(_privateKey));

        expect(find.textContaining('nsec1'), findsNothing);
      });

      testWidgets('nothing for ordinary search text', (tester) async {
        await tester.pumpWidget(_app('cats'));

        expect(find.text(l10n.searchPrivateKeyWarning), findsNothing);
      });
    });
  });
}
