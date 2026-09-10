import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';

void main() {
  group(SearchSectionErrorState, () {
    Widget buildSubject({required VoidCallback onRetry}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [SearchSectionErrorState(onRetry: onRetry)],
          ),
        ),
      );
    }

    testWidgets('renders warning icon', (tester) async {
      await tester.pumpWidget(buildSubject(onRetry: () {}));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.warningCircle,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders "Something went wrong" text', (tester) async {
      await tester.pumpWidget(buildSubject(onRetry: () {}));

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders "Try again" button', (tester) async {
      await tester.pumpWidget(buildSubject(onRetry: () {}));

      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('calls onRetry when button is tapped', (tester) async {
      var retryCalled = false;
      await tester.pumpWidget(buildSubject(onRetry: () => retryCalled = true));

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });
  });
}
