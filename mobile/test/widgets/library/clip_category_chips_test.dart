// ABOUTME: Tests for the clip library's filter chip row
// ABOUTME: Covers built-in filters, user categories, and management callbacks

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_category.dart';
import 'package:openvine/widgets/library/clip_category_chips.dart';

void main() {
  final en = AppLocalizationsEn();

  group(ClipCategoryChips, () {
    final travel = ClipCategory(
      id: 'cat-travel',
      name: 'Travel',
      createdAt: DateTime(2026, 3, 5),
    );
    final food = ClipCategory(
      id: 'cat-food',
      name: 'Food',
      createdAt: DateTime(2026, 3, 6),
      orderIndex: 1,
    );

    Widget buildWidget({
      List<ClipCategory> categories = const [],
      ClipLibraryFilter selected = const ClipLibraryAllFilter(),
      ValueChanged<ClipLibraryFilter>? onSelected,
      bool showBuiltInFilters = true,
      VoidCallback? onCreateCategory,
      ValueChanged<ClipCategory>? onManageCategory,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: ClipCategoryChips(
            categories: categories,
            selected: selected,
            onSelected: onSelected ?? (_) {},
            showBuiltInFilters: showBuiltInFilters,
            onCreateCategory: onCreateCategory,
            onManageCategory: onManageCategory,
          ),
        ),
      );
    }

    testWidgets('shows the three built-in filters before user categories', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(categories: [travel, food]));

      expect(find.text(en.libraryFilterAll), findsOneWidget);
      expect(find.text(en.libraryFilterArchive), findsOneWidget);
      expect(find.text(en.libraryFilterDeleted), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);

      final allX = tester.getTopLeft(find.text(en.libraryFilterAll)).dx;
      final deletedX = tester.getTopLeft(find.text(en.libraryFilterDeleted)).dx;
      final travelX = tester.getTopLeft(find.text('Travel')).dx;
      expect(allX, lessThan(deletedX));
      expect(deletedX, lessThan(travelX));
    });

    testWidgets('picker mode drops Archive, Deleted, and the new-chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(categories: [travel], showBuiltInFilters: false),
      );

      expect(find.text(en.libraryFilterAll), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text(en.libraryFilterArchive), findsNothing);
      expect(find.text(en.libraryFilterDeleted), findsNothing);
      expect(find.text(en.libraryCategoryNewChipLabel), findsNothing);
    });

    testWidgets('reports the tapped filter', (tester) async {
      final tapped = <ClipLibraryFilter>[];
      await tester.pumpWidget(
        buildWidget(categories: [travel], onSelected: tapped.add),
      );

      await tester.tap(find.text(en.libraryFilterArchive));
      await tester.tap(find.text('Travel'));

      expect(tapped, [
        const ClipLibraryArchiveFilter(),
        ClipLibraryCategoryFilter(travel.id),
      ]);
    });

    testWidgets('marks the active category chip as selected', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          categories: [travel, food],
          selected: ClipLibraryCategoryFilter(travel.id),
        ),
      );

      DivineButtonType chipType(String label) => tester
          .widget<DivineButton>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(DivineButton),
            ),
          )
          .type;

      expect(chipType('Travel'), DivineButtonType.secondary);
      expect(chipType('Food'), DivineButtonType.ghostSecondary);
      expect(
        chipType(en.libraryFilterAll),
        DivineButtonType.ghostSecondary,
      );
    });

    testWidgets('the new-category chip triggers onCreateCategory', (
      tester,
    ) async {
      var pressed = false;
      await tester.pumpWidget(
        buildWidget(onCreateCategory: () => pressed = true),
      );

      await tester.tap(find.text(en.libraryCategoryNewChipLabel));

      expect(pressed, isTrue);
    });

    testWidgets('long-pressing a category triggers onManageCategory', (
      tester,
    ) async {
      final managed = <ClipCategory>[];
      await tester.pumpWidget(
        buildWidget(categories: [travel], onManageCategory: managed.add),
      );

      await tester.longPress(find.text('Travel'));

      expect(managed, [travel]);
    });

    testWidgets('long-pressing a built-in filter manages nothing', (
      tester,
    ) async {
      final managed = <ClipCategory>[];
      await tester.pumpWidget(
        buildWidget(categories: [travel], onManageCategory: managed.add),
      );

      await tester.longPress(find.text(en.libraryFilterArchive));

      expect(managed, isEmpty);
    });

    testWidgets('exposes the manage shortcut as a semantics action', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(categories: [travel], onManageCategory: (_) {}),
      );

      final handle = tester.ensureSemantics();
      // Without the action, rename/delete is reachable only by a raw long
      // press, which a screen reader can neither announce nor trigger.
      final node = tester.getSemantics(find.text('Travel'));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.longPress),
        isTrue,
      );
      // `onLongPressHint` lands in SemanticsHintOverrides, which
      // SemanticsData does not carry — read it off the node.
      expect(
        node.hintOverrides?.onLongPressHint,
        en.libraryCategoryManageSemanticLabel,
      );
      handle.dispose();
    });

    testWidgets('built-in filters carry no manage action', (tester) async {
      await tester.pumpWidget(
        buildWidget(categories: [travel], onManageCategory: (_) {}),
      );

      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(find.text(en.libraryFilterArchive));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.longPress),
        isFalse,
      );
      handle.dispose();
    });
  });
}
