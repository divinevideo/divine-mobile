// ABOUTME: Tests for ListAttributionChip widget - displays curated list attribution
// ABOUTME: Verifies dark theme styling, list name display, and navigation on tap

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/list_attribution_chip.dart';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group('ListAttributionChip', () {
    CuratedList createTestList({required String id, required String name}) {
      return CuratedList(
        id: id,
        name: name,
        videoEventIds: const ['video1', 'video2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    Widget createTestWidget({
      required Set<String> listIds,
      required Map<String, CuratedList> listMap,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListAttributionChip(
            listIds: listIds,
            listLookup: (id) => listMap[id],
          ),
        ),
      );
    }

    testWidgets('returns SizedBox.shrink when listIds is empty', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(listIds: {}, listMap: {}));

      // Should not find Wrap widget when listIds is empty
      expect(find.byType(Wrap), findsNothing);
      // Should not find any playlist icons
      expect(_divineIcon(DivineIconName.playlist), findsNothing);
    });

    testWidgets('displays single list chip when one listId provided', (
      tester,
    ) async {
      final testList = createTestList(id: 'list1', name: 'Cool Videos');

      await tester.pumpWidget(
        createTestWidget(listIds: {'list1'}, listMap: {'list1': testList}),
      );
      await tester.pump();

      expect(find.text('Cool Videos'), findsOneWidget);
      expect(_divineIcon(DivineIconName.playlist), findsOneWidget);
    });

    testWidgets('displays up to 2 list chips when multiple listIds provided', (
      tester,
    ) async {
      final list1 = createTestList(id: 'list1', name: 'Cool Videos');
      final list2 = createTestList(id: 'list2', name: 'Funny Clips');
      final list3 = createTestList(id: 'list3', name: 'Music Videos');

      await tester.pumpWidget(
        createTestWidget(
          listIds: {'list1', 'list2', 'list3'},
          listMap: {'list1': list1, 'list2': list2, 'list3': list3},
        ),
      );
      await tester.pump();

      // Should only show 2 chips (not 3)
      expect(_divineIcon(DivineIconName.playlist), findsNWidgets(2));
    });

    testWidgets('uses fallback name "List" when list not found', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(listIds: {'unknown'}, listMap: {}),
      );
      await tester.pump();

      expect(find.text('List'), findsOneWidget);
    });

    testWidgets('chip has correct styling with vineGreen border', (
      tester,
    ) async {
      final testList = createTestList(id: 'list1', name: 'Cool Videos');

      await tester.pumpWidget(
        createTestWidget(listIds: {'list1'}, listMap: {'list1': testList}),
      );
      await tester.pump();

      // Find the Container with the border decoration
      final containers = tester.widgetList<Container>(find.byType(Container));
      final chipContainer = containers.where((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          return decoration.border != null && decoration.borderRadius != null;
        }
        return false;
      }).firstOrNull;

      expect(chipContainer, isNotNull);
      final decoration = chipContainer!.decoration! as BoxDecoration;
      expect(decoration.borderRadius, equals(BorderRadius.circular(12)));
    });

    testWidgets('icon is vineGreen color and 14px size', (tester) async {
      final testList = createTestList(id: 'list1', name: 'Cool Videos');

      await tester.pumpWidget(
        createTestWidget(listIds: {'list1'}, listMap: {'list1': testList}),
      );
      await tester.pump();

      final icon = tester.widget<DivineIcon>(
        _divineIcon(DivineIconName.playlist),
      );
      expect(icon.size, equals(14));
      expect(icon.color, equals(VineTheme.vineGreen));
    });

    testWidgets('text is vineGreen color and 12px size', (tester) async {
      final testList = createTestList(id: 'list1', name: 'Cool Videos');

      await tester.pumpWidget(
        createTestWidget(listIds: {'list1'}, listMap: {'list1': testList}),
      );
      await tester.pump();

      final text = tester.widget<Text>(find.text('Cool Videos'));
      expect(text.style?.fontSize, equals(12));
      expect(text.style?.color, equals(VineTheme.vineGreen));
    });

    testWidgets('uses Wrap widget with 4px spacing', (tester) async {
      final list1 = createTestList(id: 'list1', name: 'Cool Videos');
      final list2 = createTestList(id: 'list2', name: 'Funny Clips');

      await tester.pumpWidget(
        createTestWidget(
          listIds: {'list1', 'list2'},
          listMap: {'list1': list1, 'list2': list2},
        ),
      );
      await tester.pump();

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, equals(4));
    });

    testWidgets('chip is tappable with GestureDetector', (tester) async {
      final testList = createTestList(id: 'list1', name: 'Cool Videos');
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListAttributionChip(
              listIds: const {'list1'},
              listLookup: (id) => id == 'list1' ? testList : null,
              onListTap: (listId, listName) {
                tapped = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify GestureDetector exists for tap handling
      expect(find.byType(GestureDetector), findsOneWidget);

      // Tap should trigger callback
      await tester.tap(find.text('Cool Videos'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('has cardBackground color', (tester) async {
      final testList = createTestList(id: 'list1', name: 'Cool Videos');

      await tester.pumpWidget(
        createTestWidget(listIds: {'list1'}, listMap: {'list1': testList}),
      );
      await tester.pump();

      // Find the Container with the background color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final chipContainer = containers.where((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color != null;
        }
        return false;
      }).firstOrNull;

      expect(chipContainer, isNotNull);
      final decoration = chipContainer!.decoration! as BoxDecoration;
      // VineTheme.cardBackground is Color(0xFF1A1A1A)
      expect(decoration.color, equals(const Color(0xFF1A1A1A)));
    });

    testWidgets('has correct padding (8px horizontal, 2px vertical)', (
      tester,
    ) async {
      final testList = createTestList(id: 'list1', name: 'Cool Videos');

      await tester.pumpWidget(
        createTestWidget(listIds: {'list1'}, listMap: {'list1': testList}),
      );
      await tester.pump();

      // Find the Container with padding
      final containers = tester.widgetList<Container>(find.byType(Container));
      final chipContainer = containers.where((container) {
        return container.padding ==
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2);
      }).firstOrNull;

      expect(chipContainer, isNotNull);
    });

    testWidgets('has 4px spacing between icon and text in Row', (tester) async {
      final testList = createTestList(id: 'list1', name: 'Cool Videos');

      await tester.pumpWidget(
        createTestWidget(listIds: {'list1'}, listMap: {'list1': testList}),
      );
      await tester.pump();

      // Verify Row contains SizedBox with width 4 for spacing
      final rows = tester.widgetList<Row>(find.byType(Row));
      final chipRow = rows.where((row) {
        return row.children.any(
          (widget) => widget is SizedBox && widget.width == 4,
        );
      }).firstOrNull;

      expect(chipRow, isNotNull);
    });
  });
}
