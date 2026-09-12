import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_section_initial_state.dart';

void main() {
  group(SearchSectionInitialState, () {
    Widget buildSubject({
      String title = 'Search for videos',
      String subtitle = 'Find vines by keyword',
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SearchSectionInitialState(title: title, subtitle: subtitle),
            ],
          ),
        ),
      );
    }

    testWidgets('renders search icon', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.search,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders provided title', (tester) async {
      await tester.pumpWidget(
        buildSubject(title: 'Search for people', subtitle: 'Find creators'),
      );

      expect(find.text('Search for people'), findsOneWidget);
    });

    testWidgets('renders provided subtitle', (tester) async {
      await tester.pumpWidget(
        buildSubject(title: 'Search for tags', subtitle: 'Find topics'),
      );

      expect(find.text('Find topics'), findsOneWidget);
    });
  });
}
