// ABOUTME: Tests the grouped editor font list: category headers, and that a
// ABOUTME: pick reports the catalogue index saved styles persist.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_font_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool allowRuntimeFetching;

  setUpAll(() {
    allowRuntimeFetching = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDownAll(
    () => GoogleFonts.config.allowRuntimeFetching = allowRuntimeFetching,
  );

  final l10n = lookupAppLocalizations(const Locale('en'));
  final oswaldIndex = VideoEditorConstants.textFontCatalogue.indexWhere(
    (entry) => entry.familyName == 'Oswald',
  );

  /// Runs [body], which may build rows that render in a font's own face.
  ///
  /// google_fonts cannot fetch the faces that are not bundled in a test, so
  /// those expected load failures go to a nested zone: the assertions are
  /// about the list, not the loads. Anything else still fails the test.
  Future<void> ignoringFontLoads(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final unexpected = <Object>[];
    await runZonedGuarded(body, (error, stackTrace) {
      if (!'$error'.contains('allowRuntimeFetching is false')) {
        unexpected.add(error);
      }
    });
    await tester.runAsync(pumpEventQueue);
    expect(unexpected, isEmpty);
  }

  Future<void> pumpList(
    WidgetTester tester, {
    int selectedIndex = 0,
    ValueChanged<int>? onSelected,
    ScrollController? controller,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await ignoringFontLoads(
      tester,
      () => tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoEditorFontList(
              selectedIndex: selectedIndex,
              onSelected: onSelected ?? (_) {},
              controller: controller,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapChip(WidgetTester tester, String label) =>
      ignoringFontLoads(tester, () async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      });

  bool isChipSelected(WidgetTester tester, String label) {
    final button = tester.widget<DivineButton>(
      find.ancestor(of: find.text(label), matching: find.byType(DivineButton)),
    );
    return button.type == DivineButtonType.secondary;
  }

  group(VideoEditorFontList, () {
    group('renders', () {
      testWidgets('the first category header above the default font', (
        tester,
      ) async {
        await pumpList(tester);

        final header = find.text(
          l10n.videoEditorFontCategorySans.toUpperCase(),
        );
        expect(header, findsOneWidget);
        expect(
          tester.getSemantics(header),
          isSemantics(isHeader: true),
        );
        expect(
          tester.getTopLeft(header).dy,
          lessThan(tester.getTopLeft(find.text('Inter')).dy),
        );
      });

      testWidgets('lists a font under its category, not catalogue position', (
        tester,
      ) async {
        await pumpList(tester);

        // Roboto Mono sits between Poppins and Oswald in the catalogue, but
        // belongs to the mono section further down.
        expect(
          tester.getTopLeft(find.text('Oswald')).dy,
          greaterThan(tester.getTopLeft(find.text('Poppins')).dy),
        );
        expect(find.text('Roboto Mono'), findsNothing);
      });

      testWidgets('marks the selected font', (tester) async {
        await pumpList(tester, selectedIndex: oswaldIndex);

        final row = find.ancestor(
          of: find.text('Oswald'),
          matching: find.byType(Row),
        );
        expect(
          find.descendant(of: row, matching: find.byType(DivineIcon)),
          findsOneWidget,
        );
        expect(find.byType(DivineIcon), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('reports the catalogue index of a picked font', (
        tester,
      ) async {
        int? picked;
        await pumpList(tester, onSelected: (index) => picked = index);

        await tester.tap(find.text('Oswald'));

        expect(oswaldIndex, 9);
        expect(picked, oswaldIndex);
      });

      testWidgets(
        'reports the catalogue index, not the row, for a font whose row '
        'differs from it',
        (tester) async {
          // Oswald's row and catalogue index happen to coincide (9), so the
          // test above cannot tell them apart. DM Sans sits in row 23 of the
          // grouped list but at catalogue index 63.
          final dmSansIndex = VideoEditorConstants.textFontCatalogue.indexWhere(
            (entry) => entry.familyName == 'DM Sans',
          );
          int? picked;
          await pumpList(tester, onSelected: (index) => picked = index);

          await tester.tap(find.text('DM Sans'));

          expect(dmSansIndex, 63);
          expect(picked, dmSansIndex);
        },
      );
    });

    group('category chips', () {
      testWidgets('offer one chip per section, the first one active', (
        tester,
      ) async {
        await pumpList(tester);

        for (final label in [
          l10n.videoEditorFontCategorySans,
          l10n.videoEditorFontCategoryHeadline,
          l10n.videoEditorFontCategoryScript,
          l10n.videoEditorFontCategorySerif,
          l10n.videoEditorFontCategoryEffect,
          l10n.videoEditorFontCategoryMono,
          l10n.videoEditorFontCategoryThemed,
          l10n.videoEditorFontCategoryOtherScripts,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(
          isChipSelected(tester, l10n.videoEditorFontCategorySans),
          isTrue,
        );
        expect(
          isChipSelected(tester, l10n.videoEditorFontCategorySerif),
          isFalse,
        );
      });

      testWidgets("jump the list to the section's header", (tester) async {
        await pumpList(tester);
        final serifHeader = find.text(
          l10n.videoEditorFontCategorySerif.toUpperCase(),
        );
        expect(serifHeader, findsNothing);

        await tapChip(tester, l10n.videoEditorFontCategorySerif);

        final listTop = tester.getTopLeft(find.byType(ListView)).dy;
        expect(
          tester.getTopLeft(serifHeader).dy - listTop,
          inInclusiveRange(0, 60),
        );
        expect(
          tester.getTopLeft(find.text('Merriweather')).dy,
          greaterThan(tester.getTopLeft(serifHeader).dy),
        );
        expect(
          isChipSelected(tester, l10n.videoEditorFontCategorySerif),
          isTrue,
        );
        expect(
          isChipSelected(tester, l10n.videoEditorFontCategorySans),
          isFalse,
        );
      });

      testWidgets('keep a late section active when its jump hits the end', (
        tester,
      ) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await pumpList(tester, controller: controller);

        await tapChip(tester, l10n.videoEditorFontCategoryThemed);

        // The last sections are shorter than the viewport, so the jump is
        // clamped at the end of the list.
        expect(controller.offset, controller.position.maxScrollExtent);
        expect(
          isChipSelected(tester, l10n.videoEditorFontCategoryThemed),
          isTrue,
        );
        expect(
          isChipSelected(tester, l10n.videoEditorFontCategoryOtherScripts),
          isFalse,
        );
      });

      testWidgets('follow the section the user scrolls to', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await pumpList(tester, controller: controller);
        await tapChip(tester, l10n.videoEditorFontCategoryThemed);

        await ignoringFontLoads(tester, () async {
          await tester.drag(find.byType(ListView), const Offset(0, 20000));
          await tester.pumpAndSettle();
        });

        expect(controller.offset, 0);
        expect(
          isChipSelected(tester, l10n.videoEditorFontCategorySans),
          isTrue,
        );
        expect(
          isChipSelected(tester, l10n.videoEditorFontCategoryThemed),
          isFalse,
        );
      });
    });
  });
}
