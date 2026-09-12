// MaterialIconSource is deprecated but still fully supported; these tests
// intentionally exercise it to guard that support, not migrate off it.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('DiVineAppBarAction', () {
    test('creates with required parameters', () {
      final action = DiVineAppBarAction(
        icon: const MaterialIconSource(Icons.search),
        onPressed: () {},
      );

      expect(action.icon, isA<MaterialIconSource>());
      expect(action.onPressed, isNotNull);
      expect(action.tooltip, isNull);
      expect(action.semanticLabel, isNull);
      expect(action.backgroundColor, isNull);
      expect(action.iconColor, isNull);
    });

    test('creates with all parameters', () {
      final action = DiVineAppBarAction(
        icon: const MaterialIconSource(Icons.search),
        onPressed: () {},
        tooltip: 'Search',
        semanticLabel: 'Search button',
        backgroundColor: Colors.red,
        iconColor: Colors.blue,
      );

      expect(action.tooltip, 'Search');
      expect(action.semanticLabel, 'Search button');
      expect(action.backgroundColor, Colors.red);
      expect(action.iconColor, Colors.blue);
    });
  });

  group('DiVineAppBarActions', () {
    Widget buildTestWidget({
      required List<DiVineAppBarAction> actions,
      DiVineAppBarStyle style = DiVineAppBarStyle.defaultStyle,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: DiVineAppBarActions(
            actions: actions,
            style: style,
          ),
        ),
      );
    }

    testWidgets('renders nothing when actions list is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget(actions: []));

      expect(find.byType(DivineAppBarIconButton), findsNothing);
    });

    testWidgets('renders action buttons', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          actions: [
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.search),
              onPressed: () {},
            ),
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.settings),
              onPressed: () {},
            ),
          ],
        ),
      );

      expect(find.byType(DivineAppBarIconButton), findsNWidgets(2));
    });

    testWidgets('calls onPressed when action is tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestWidget(
          actions: [
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.search),
              onPressed: () => tapped = true,
            ),
          ],
        ),
      );

      await tester.tap(find.byType(DivineAppBarIconButton));
      expect(tapped, isTrue);
    });

    testWidgets('uses style for spacing', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          actions: [
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.search),
              onPressed: () {},
            ),
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.settings),
              onPressed: () {},
            ),
          ],
          style: const DiVineAppBarStyle(actionButtonSpacing: 16),
        ),
      );

      // Find the SizedBox used for spacing between buttons
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final spacer = sizedBoxes.firstWhere(
        (box) => box.width == 16,
        orElse: () => throw StateError('Spacer not found'),
      );
      expect(spacer.width, 16);
    });

    group('accessibility', () {
      Widget buildThemed(List<DiVineAppBarAction> actions, ThemeData theme) {
        return MaterialApp(
          theme: theme,
          home: Scaffold(
            body: DiVineAppBarActions(
              actions: actions,
              style: DiVineAppBarStyle.defaultStyle,
            ),
          ),
        );
      }

      List<DiVineAppBarAction> labelledActions() => [
        DiVineAppBarAction(
          icon: const MaterialIconSource(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
        DiVineAppBarAction(
          icon: const MaterialIconSource(Icons.settings),
          onPressed: () {},
          semanticLabel: 'Settings',
        ),
      ];

      testWidgets('labelled actions meet the labeled-tap-target guideline', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildThemed(labelledActions(), VineTheme.theme),
        );

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('actions meet the 48dp / 44pt tap-target guidelines', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildThemed(labelledActions(), VineTheme.theme),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('semanticLabel reaches the rendered button', (tester) async {
        await tester.pumpWidget(
          buildThemed(labelledActions(), VineTheme.lightTheme),
        );

        expect(find.bySemanticsLabel('Search'), findsOneWidget);
        expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      });
    });
  });
}
