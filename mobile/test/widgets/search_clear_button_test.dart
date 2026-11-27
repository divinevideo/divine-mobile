// ABOUTME: Widget tests for the x that empties a search field: when it shows
// ABOUTME: and what a tap on it does.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/search_clear_button.dart';

void main() {
  group(SearchClearButton, () {
    late TextEditingController controller;
    late int clearedCount;

    setUp(() {
      controller = TextEditingController();
      clearedCount = 0;
    });

    tearDown(() => controller.dispose());

    Widget buildSubject() => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: VineTheme.theme,
      home: Scaffold(
        body: TextField(
          controller: controller,
          decoration: InputDecoration(
            suffixIcon: SearchClearButton(
              controller: controller,
              onCleared: () => clearedCount++,
            ),
          ),
        ),
      ),
    );

    final clearButton = find.byKey(const Key('search_clear_button'));

    group('renders', () {
      testWidgets('nothing while the field is empty', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(clearButton, findsNothing);
      });

      testWidgets('an x once the field holds text', (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.enterText(find.byType(TextField), 'drum');
        await tester.pumpAndSettle();

        expect(clearButton, findsOneWidget);
        expect(
          find.bySemanticsLabel(
            lookupAppLocalizations(
              const Locale('en'),
            ).userPickerClearSearchSemantics,
          ),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('empties the field, reports it and hides on tap', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.enterText(find.byType(TextField), 'drum');
        await tester.pumpAndSettle();

        await tester.tap(clearButton);
        await tester.pumpAndSettle();

        expect(controller.text, isEmpty);
        expect(clearedCount, 1);
        expect(clearButton, findsNothing);
      });
    });
  });
}
