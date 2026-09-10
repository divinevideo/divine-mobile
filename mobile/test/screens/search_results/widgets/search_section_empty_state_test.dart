import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';

void main() {
  group(SearchSectionEmptyState, () {
    Widget buildSubject({required String query}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [SearchSectionEmptyState(query: query)],
          ),
        ),
      );
    }

    testWidgets('renders search icon', (tester) async {
      await tester.pumpWidget(buildSubject(query: 'flutter'));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.search,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders query in message', (tester) async {
      await tester.pumpWidget(buildSubject(query: 'flutter'));

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).searchNoResultsFound('flutter'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders suggestion text', (tester) async {
      await tester.pumpWidget(buildSubject(query: 'flutter'));

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).soundsNoSoundsFoundDescription,
        ),
        findsOneWidget,
      );
    });
  });
}
