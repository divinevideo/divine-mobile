// ABOUTME: Tests for VideoEditorCategoryPicker on its own: the sections it is
// ABOUTME: handed, including ones its callers never pass today.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/video_editor_category_picker.dart';

void main() {
  group(VideoEditorCategoryPicker, () {
    Widget buildWidget(
      Map<String, List<String>> sections, {
      String? initialCategory,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: .bottomCenter,
            child: VideoEditorCategoryPicker<String, String>(
              sections: sections,
              categoryLabel: (_, category) => category,
              isSelected: (_) => false,
              initialCategory: initialCategory,
              tileBuilder: (_, item, isSelected) =>
                  VideoEditorCategoryPickerTile(
                    label: item,
                    isSelected: isSelected,
                    onTap: () {},
                    preview: const SizedBox.expand(),
                  ),
            ),
          ),
        ),
      );
    }

    void usePhoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(402, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    List<String> items(String prefix, int count) => [
      for (var i = 0; i < count; i++) '$prefix$i',
    ];

    Finder grid() => find.byType(CustomScrollView);

    Finder tab(String category) => find.descendant(
      of: find.byType(TabBar),
      matching: find.text(category),
    );

    Finder header(String category) => find.descendant(
      of: find.byType(SliverToBoxAdapter),
      matching: find.text(category),
    );

    ScrollPosition gridPosition(WidgetTester tester) =>
        tester.widget<CustomScrollView>(grid()).controller!.position;

    group('renders', () {
      testWidgets('opens at the start when the initial category has no '
          'section', (tester) async {
        usePhoneSize(tester);
        await tester.pumpWidget(
          buildWidget({
            'a': items('a', 10),
            'b': items('b', 10),
          }, initialCategory: 'missing'),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(gridPosition(tester).pixels, 0);
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
          0,
        );
      });

      testWidgets('follows a change in the number of sections', (
        tester,
      ) async {
        usePhoneSize(tester);
        await tester.pumpWidget(
          buildWidget({
            'a': items('a', 4),
            'b': items('b', 4),
            'c': items('c', 4),
          }),
        );
        await tester.pumpWidget(
          buildWidget({
            'a': items('a', 4),
            'b': items('b', 4),
          }),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).controller!.length,
          2,
        );
      });
    });

    group('navigation', () {
      testWidgets('an empty section leaves the titles after it where a tab '
          'scrolls them', (tester) async {
        usePhoneSize(tester);
        await tester.pumpWidget(
          buildWidget({
            'a': items('a', 10),
            'empty': const [],
            'c': items('c', 10),
            'd': items('d', 40),
          }),
        );
        final gridTop = tester.getRect(grid()).top;

        await tester.tap(tab('c'));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(header('c')).top - gridTop,
          inInclusiveRange(0, 10),
        );
      });
    });
  });
}
