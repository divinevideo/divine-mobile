// ABOUTME: Tests for LibraryToolbar widget
// ABOUTME: Covers title truncation, narrow-width overflow, and callbacks

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/library/library_toolbar.dart';

void main() {
  final en = AppLocalizationsEn();

  /// Wide enough for every action, narrow enough to stay a phone.
  const wideWidth = 520.0;

  /// A small phone in portrait — the width #7165 reported.
  const narrowWidth = 320.0;

  group(LibraryToolbar, () {
    Finder iconButton(DivineIconName icon) => find.byWidgetPredicate(
      (widget) => widget is DivineIconButton && widget.icon == icon,
    );

    Widget buildWidget({
      double width = wideWidth,
      TextScaler textScaler = TextScaler.noScaling,
      bool isLibrarySelectionMode = false,
      bool canExitSelectionMode = true,
      bool isClipsTabActive = true,
      VoidCallback? onLeadingPressed,
      VoidCallback? onOpenSortMenu,
      VoidCallback? onEnterSelectionMode,
      bool isTrashFilterActive = false,
      VoidCallback? onEmptyTrash,
      VoidCallback? onManageActiveCategory,
      VoidCallback? onMoveSelectedClips,
      VoidCallback? onDeleteSelectedClips,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: LibraryToolbar(
                isLibrarySelectionMode: isLibrarySelectionMode,
                canExitSelectionMode: canExitSelectionMode,
                isClipsTabActive: isClipsTabActive,
                onLeadingPressed: onLeadingPressed ?? () {},
                onOpenSortMenu: onOpenSortMenu ?? () {},
                onEnterSelectionMode: onEnterSelectionMode ?? () {},
                isTrashFilterActive: isTrashFilterActive,
                onEmptyTrash: onEmptyTrash,
                onManageActiveCategory: onManageActiveCategory,
                onMoveSelectedClips: onMoveSelectedClips,
                onDeleteSelectedClips: onDeleteSelectedClips,
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays the library title', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text(en.profileMyLibraryLabel), findsOneWidget);
      });

      testWidgets('title is limited to a single line with ellipsis', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final title = tester.widget<Text>(find.text(en.profileMyLibraryLabel));
        expect(title.maxLines, equals(1));
        expect(title.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('shows back leading icon outside selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(iconButton(DivineIconName.caretLeft), findsOneWidget);
        expect(iconButton(DivineIconName.x), findsNothing);
        expect(
          find.bySemanticsLabel(en.libraryCloseSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('shows close leading icon in selection mode', (tester) async {
        await tester.pumpWidget(buildWidget(isLibrarySelectionMode: true));

        expect(iconButton(DivineIconName.x), findsOneWidget);
        expect(iconButton(DivineIconName.caretLeft), findsNothing);
        expect(
          find.bySemanticsLabel(en.libraryStopSelectingClipsSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('locked selection mode labels leading action as close', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            isLibrarySelectionMode: true,
            canExitSelectionMode: false,
          ),
        );

        expect(
          find.bySemanticsLabel(en.libraryCloseSemanticLabel),
          findsOneWidget,
        );
        expect(iconButton(DivineIconName.caretLeft), findsOneWidget);
        expect(iconButton(DivineIconName.x), findsNothing);
      });

      testWidgets('shows back icon for a preserved selection on Drafts', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            isLibrarySelectionMode: true,
            canExitSelectionMode: false,
            isClipsTabActive: false,
          ),
        );

        expect(iconButton(DivineIconName.caretLeft), findsOneWidget);
        expect(iconButton(DivineIconName.x), findsNothing);
        expect(
          find.bySemanticsLabel(en.libraryCloseSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('hides clip actions when clips tab is inactive', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(isClipsTabActive: false));

        expect(find.text(en.librarySelect), findsNothing);
        expect(iconButton(DivineIconName.funnelSimple), findsNothing);
        expect(iconButton(DivineIconName.trash), findsNothing);
        expect(iconButton(DivineIconName.dotsThree), findsNothing);
      });

      testWidgets('shows clip actions when clips tab is active', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text(en.librarySelect), findsOneWidget);
        expect(iconButton(DivineIconName.funnelSimple), findsOneWidget);
        expect(
          find.bySemanticsLabel(en.libraryDisplayOptionsLabel),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(en.librarySelectClipsSemanticLabel),
          findsOneWidget,
        );
        expect(iconButton(DivineIconName.dotsThree), findsNothing);
      });

      testWidgets('swaps Select for move and delete in selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(isLibrarySelectionMode: true));

        expect(find.text(en.librarySelect), findsNothing);
        expect(
          find.bySemanticsLabel(en.libraryMoveSelectedClipsTooltip),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(en.libraryDeleteSelectedClipsTooltip),
          findsOneWidget,
        );
      });

      testWidgets('offers only Empty trash while the trash filter is on', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(isTrashFilterActive: true, onEmptyTrash: () {}),
        );

        expect(find.text(en.libraryTrashEmptyAllLabel), findsOneWidget);
        expect(find.text(en.librarySelect), findsNothing);
        expect(iconButton(DivineIconName.funnelSimple), findsNothing);
      });

      testWidgets('hides Empty trash when the bin is empty', (tester) async {
        await tester.pumpWidget(buildWidget(isTrashFilterActive: true));

        expect(find.text(en.libraryTrashEmptyAllLabel), findsNothing);
        expect(iconButton(DivineIconName.dotsThree), findsNothing);
      });

      testWidgets('shows the manage action only for a category filter', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        expect(iconButton(DivineIconName.pencilSimple), findsNothing);

        await tester.pumpWidget(buildWidget(onManageActiveCategory: () {}));
        expect(
          find.bySemanticsLabel(en.libraryCategoryManageSemanticLabel),
          findsOneWidget,
        );
      });
    });

    group('layout', () {
      testWidgets('keeps the same height across every action set', (
        tester,
      ) async {
        // The toolbar sits above the clip grid, so any height change shifts
        // the content under it. Switching to the trash filter swaps the whole
        // action set, which must not move the grid.
        final heights = <String, double>{};
        final cases = <String, Widget>{
          'browse': buildWidget(),
          'selection': buildWidget(
            isLibrarySelectionMode: true,
            onMoveSelectedClips: () {},
            onDeleteSelectedClips: () {},
          ),
          'category active': buildWidget(onManageActiveCategory: () {}),
          'trash with items': buildWidget(
            isTrashFilterActive: true,
            onEmptyTrash: () {},
          ),
          'trash empty': buildWidget(isTrashFilterActive: true),
          'drafts tab': buildWidget(isClipsTabActive: false),
          'collapsed': buildWidget(width: narrowWidth),
        };

        for (final entry in cases.entries) {
          await tester.pumpWidget(entry.value);
          heights[entry.key] = tester
              .getSize(find.byType(LibraryToolbar))
              .height;
        }

        expect(
          heights.values.toSet(),
          hasLength(1),
          reason: 'toolbar height varies by action set: $heights',
        );
      });
    });

    group('narrow widths', () {
      testWidgets('collapses clip actions into an overflow button', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(width: narrowWidth, onManageActiveCategory: () {}),
        );

        expect(iconButton(DivineIconName.dotsThree), findsOneWidget);
        expect(iconButton(DivineIconName.pencilSimple), findsNothing);
        expect(iconButton(DivineIconName.funnelSimple), findsNothing);
        expect(
          find.bySemanticsLabel(en.libraryMoreActionsSemanticLabel),
          findsOneWidget,
        );
        // The primary action is not one of them.
        expect(find.text(en.librarySelect), findsOneWidget);
      });

      testWidgets('keeps a readable title while the row has room', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(width: 420));

        final titleWidth = tester
            .getSize(find.text(en.profileMyLibraryLabel))
            .width;
        expect(titleWidth, greaterThanOrEqualTo(72));
      });

      testWidgets('lets the title yield once the row runs out of room', (
        tester,
      ) async {
        // The collapse buys the title its room back, but the primary action
        // outranks it: past that point the title is what shrinks.
        await tester.pumpWidget(buildWidget(width: narrowWidth));

        expect(find.text(en.librarySelect), findsOneWidget);
        expect(find.text(en.profileMyLibraryLabel), findsOneWidget);
        expect(
          tester.getSize(find.text(en.profileMyLibraryLabel)).width,
          greaterThan(0),
        );
      });

      testWidgets('keeps the primary action when only part of the row fits', (
        tester,
      ) async {
        // A large text scale on a small phone eats the room the icon buttons
        // need, but not the room for Select — the least important actions
        // leave first.
        await tester.pumpWidget(
          buildWidget(
            width: narrowWidth,
            textScaler: const TextScaler.linear(2),
            onManageActiveCategory: () {},
          ),
        );

        expect(find.text(en.librarySelect), findsOneWidget);
        expect(iconButton(DivineIconName.dotsThree), findsOneWidget);
        expect(iconButton(DivineIconName.pencilSimple), findsNothing);
        expect(iconButton(DivineIconName.funnelSimple), findsNothing);

        await tester.tap(iconButton(DivineIconName.dotsThree));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryDisplayOptionsLabel), findsOneWidget);
        expect(
          find.text(en.libraryCategoryManageSemanticLabel),
          findsOneWidget,
        );
        expect(find.text(en.librarySelectClipsSemanticLabel), findsNothing);
      });

      testWidgets('shrinks the lone Empty trash chip instead of hiding it', (
        tester,
      ) async {
        // Nothing can collapse when the bin is the only mode on offer, so the
        // chip narrows until it fits and ellipsizes its label.
        await tester.pumpWidget(
          buildWidget(
            width: narrowWidth,
            textScaler: const TextScaler.linear(2),
            isTrashFilterActive: true,
            onEmptyTrash: () {},
          ),
        );

        expect(find.text(en.libraryTrashEmptyAllLabel), findsOneWidget);
        expect(iconButton(DivineIconName.dotsThree), findsNothing);
        expect(
          tester.getSize(find.byType(DivineButton)).width,
          lessThanOrEqualTo(narrowWidth),
        );
      });

      testWidgets('does not overflow at any phone width', (tester) async {
        for (var width = 280.0; width <= 520.0; width += 5) {
          for (final build in [
            () => buildWidget(width: width, onManageActiveCategory: () {}),
            () => buildWidget(
              width: width,
              isLibrarySelectionMode: true,
              onMoveSelectedClips: () {},
              onDeleteSelectedClips: () {},
            ),
            () => buildWidget(
              width: width,
              isTrashFilterActive: true,
              onEmptyTrash: () {},
            ),
          ]) {
            await tester.pumpWidget(build());

            expect(
              tester.takeException(),
              isNull,
              reason: 'toolbar overflowed at ${width}dp',
            );
          }
        }
      });

      testWidgets('keeps the primary action in the row at any width', (
        tester,
      ) async {
        // Select is how a user reaches every per-clip action, so it never
        // moves behind the overflow button — however narrow the row gets.
        for (var width = 280.0; width <= 520.0; width += 5) {
          for (final scaler in [
            TextScaler.noScaling,
            const TextScaler.linear(2),
          ]) {
            await tester.pumpWidget(
              buildWidget(
                width: width,
                textScaler: scaler,
                onManageActiveCategory: () {},
              ),
            );

            expect(
              find.text(en.librarySelect),
              findsOneWidget,
              reason: 'Select left the row at ${width}dp, scale $scaler',
            );
          }
        }
      });

      testWidgets('does not collapse a lone icon-only action', (tester) async {
        // Collapsing one icon action swaps it for a more button of the same
        // width: the row would be no narrower and sorting would cost a tap
        // more. Below the width where both fit, the row keeps them both.
        await tester.pumpWidget(buildWidget(width: narrowWidth));

        expect(iconButton(DivineIconName.dotsThree), findsNothing);
        expect(iconButton(DivineIconName.funnelSimple), findsOneWidget);
        expect(find.text(en.librarySelect), findsOneWidget);
      });

      testWidgets('keeps the same actions past the icon scaling cap', (
        tester,
      ) async {
        // Selecting offers only icon actions, so every width the toolbar
        // estimates — buttons and the title it holds back for — is on
        // DivineIcon's capped curve. Past the cap a larger text scale must
        // not push another action into the menu.
        for (var width = 280.0; width <= 520.0; width += 5) {
          final visible = <int>[];
          for (final scale in [1.3, 2.0]) {
            await tester.pumpWidget(
              buildWidget(
                width: width,
                textScaler: TextScaler.linear(scale),
                isLibrarySelectionMode: true,
                onMoveSelectedClips: () {},
                onDeleteSelectedClips: () {},
              ),
            );
            visible.add(
              find
                  .byWidgetPredicate((widget) => widget is DivineIconButton)
                  .evaluate()
                  .length,
            );
          }

          expect(
            visible.first,
            equals(visible.last),
            reason: 'row lost an action between 1.3x and 2x at ${width}dp',
          );
        }
      });

      testWidgets('estimates an icon button at the width it renders', (
        tester,
      ) async {
        // Every icon action is estimated as one 48px tap target, whatever its
        // type: at `small` DivineIconButton centres its pill in an explicit
        // 48px box, so the bordered secondary and the borderless destructive
        // land on the same outer bounds however wide their pills draw. If
        // that stops holding, the estimate goes under and the row overflows.
        await tester.pumpWidget(
          buildWidget(
            isLibrarySelectionMode: true,
            onMoveSelectedClips: () {},
            onDeleteSelectedClips: () {},
          ),
        );

        expect(
          tester.getSize(iconButton(DivineIconName.folderOpen)).width,
          equals(48),
        );
        expect(
          tester.getSize(iconButton(DivineIconName.trash)).width,
          equals(48),
        );
      });

      testWidgets('estimates a Select chip no narrower than it renders', (
        tester,
      ) async {
        // The toolbar decides the collapse while building, so it estimates
        // the chip as label + 40px of chrome. An estimate below the rendered
        // width would overflow the row instead of collapsing it.
        //
        // Both halves are measured off the rendered chip. A `TextPainter` of
        // the test's own would resolve whichever font `google_fonts` has
        // registered by the time it runs — a real one once an earlier test
        // has pumped, the fallback on a cold cache — so comparing one against
        // a rendered width makes the pin depend on what ran first.
        await tester.pumpWidget(buildWidget());

        final label = tester.getSize(find.text(en.librarySelect)).width;
        final rendered = tester.getSize(find.byType(DivineButton).first).width;
        expect(rendered - label, moreOrLessEquals(40, epsilon: 0.01));

        // ...and the label the toolbar measures is styled like the one it
        // renders, so the two widths are of the same text.
        final chipStyle = tester
            .widget<Text>(find.text(en.librarySelect))
            .style;
        final measured = VineTheme.titleMediumFont();
        expect(chipStyle?.fontFamily, equals(measured.fontFamily));
        expect(
          chipStyle?.fontFamilyFallback,
          equals(measured.fontFamilyFallback),
        );
        expect(chipStyle?.fontSize, equals(measured.fontSize));
        expect(chipStyle?.fontWeight, equals(measured.fontWeight));
        expect(chipStyle?.letterSpacing, equals(measured.letterSpacing));
      });
    });

    group('overflow menu', () {
      testWidgets('lists every collapsed action', (tester) async {
        await tester.pumpWidget(
          buildWidget(width: narrowWidth, onManageActiveCategory: () {}),
        );

        await tester.tap(iconButton(DivineIconName.dotsThree));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryDisplayOptionsLabel), findsOneWidget);
        expect(
          find.text(en.libraryCategoryManageSemanticLabel),
          findsOneWidget,
        );
        // Select stayed in the row, so it is not repeated here.
        expect(find.text(en.librarySelectClipsSemanticLabel), findsNothing);
      });

      testWidgets('manage row triggers onManageActiveCategory', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            width: narrowWidth,
            onManageActiveCategory: () => pressed = true,
          ),
        );

        await tester.tap(iconButton(DivineIconName.dotsThree));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.libraryCategoryManageSemanticLabel));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      });

      testWidgets('display options row triggers onOpenSortMenu', (
        tester,
      ) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            width: narrowWidth,
            onOpenSortMenu: () => pressed = true,
            onManageActiveCategory: () {},
          ),
        );

        await tester.tap(iconButton(DivineIconName.dotsThree));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.libraryDisplayOptionsLabel));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      });

      testWidgets('move row triggers onMoveSelectedClips', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            width: narrowWidth,
            textScaler: const TextScaler.linear(2),
            isLibrarySelectionMode: true,
            onMoveSelectedClips: () => pressed = true,
            onDeleteSelectedClips: () {},
          ),
        );

        await tester.tap(iconButton(DivineIconName.dotsThree));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.libraryMoveSelectedClipsTooltip));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      });

      testWidgets('never collapses the destructive primary action', (
        tester,
      ) async {
        // Delete is the primary action while selecting, so it stays on the
        // row and out of the menu even at the narrowest width.
        await tester.pumpWidget(
          buildWidget(
            width: narrowWidth,
            textScaler: const TextScaler.linear(2),
            isLibrarySelectionMode: true,
            onMoveSelectedClips: () {},
            onDeleteSelectedClips: () {},
          ),
        );

        expect(iconButton(DivineIconName.trash), findsOneWidget);

        await tester.tap(iconButton(DivineIconName.dotsThree));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryDeleteSelectedClipsTooltip), findsNothing);
      });

      testWidgets('a shrunken Empty trash chip still triggers onEmptyTrash', (
        tester,
      ) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            width: narrowWidth,
            textScaler: const TextScaler.linear(2),
            isTrashFilterActive: true,
            onEmptyTrash: () => pressed = true,
          ),
        );

        await tester.tap(find.text(en.libraryTrashEmptyAllLabel));
        expect(pressed, isTrue);
      });
    });

    group('interactions', () {
      testWidgets('leading button triggers onLeadingPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(onLeadingPressed: () => pressed = true),
        );

        await tester.tap(iconButton(DivineIconName.caretLeft));
        expect(pressed, isTrue);
      });

      testWidgets('sort button triggers onOpenSortMenu', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(onOpenSortMenu: () => pressed = true),
        );

        await tester.tap(iconButton(DivineIconName.funnelSimple));
        expect(pressed, isTrue);
      });

      testWidgets('Select button triggers onEnterSelectionMode', (
        tester,
      ) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(onEnterSelectionMode: () => pressed = true),
        );

        await tester.tap(find.text(en.librarySelect));
        expect(pressed, isTrue);
      });

      testWidgets('Empty trash button triggers onEmptyTrash', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            isTrashFilterActive: true,
            onEmptyTrash: () => pressed = true,
          ),
        );

        await tester.tap(find.text(en.libraryTrashEmptyAllLabel));
        expect(pressed, isTrue);
      });

      testWidgets('manage button triggers onManageActiveCategory', (
        tester,
      ) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(onManageActiveCategory: () => pressed = true),
        );

        await tester.tap(iconButton(DivineIconName.pencilSimple));
        expect(pressed, isTrue);
      });

      testWidgets('move button triggers onMoveSelectedClips', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            isLibrarySelectionMode: true,
            onMoveSelectedClips: () => pressed = true,
          ),
        );

        await tester.tap(iconButton(DivineIconName.folderOpen));
        expect(pressed, isTrue);
      });

      testWidgets('delete button triggers onDeleteSelectedClips', (
        tester,
      ) async {
        var pressed = false;
        await tester.pumpWidget(
          buildWidget(
            isLibrarySelectionMode: true,
            onDeleteSelectedClips: () => pressed = true,
          ),
        );

        await tester.tap(iconButton(DivineIconName.trash));
        expect(pressed, isTrue);
      });
    });
  });
}
