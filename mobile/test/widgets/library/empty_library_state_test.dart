// ABOUTME: Tests for EmptyLibraryState widget
// ABOUTME: Verifies icon, title, subtitle, and optional record button

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';

void main() {
  final en = AppLocalizationsEn();

  group(EmptyLibraryState, () {
    Widget buildWidget({
      DivineIconName icon = DivineIconName.filmSlate,
      String title = 'Test Title',
      String subtitle = 'Test Subtitle',
      bool showRecordButton = true,
      TextScaler textScaler = TextScaler.noScaling,
      double? slotHeight,
    }) {
      final state = EmptyLibraryState(
        icon: icon,
        title: title,
        subtitle: subtitle,
        showRecordButton: showRecordButton,
      );
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          // Every library tab hands the empty state a bounded slot — the one
          // a list would otherwise fill.
          body: slotHeight == null
              ? state
              : Center(
                  child: SizedBox(height: slotHeight, child: state),
                ),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays icon with correct $DivineIconName', (tester) async {
        await tester.pumpWidget(buildWidget(icon: DivineIconName.play));

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.play,
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays title text', (tester) async {
        await tester.pumpWidget(buildWidget(title: 'No Clips Yet'));

        expect(find.text('No Clips Yet'), findsOneWidget);
      });

      testWidgets('displays subtitle text', (tester) async {
        await tester.pumpWidget(
          buildWidget(subtitle: 'Clips will appear here'),
        );

        expect(find.text('Clips will appear here'), findsOneWidget);
      });

      testWidgets('displays record button by default', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text(en.libraryRecordVideo), findsOneWidget);
        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('hides record button when showRecordButton is false', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(showRecordButton: false));

        expect(find.text(en.libraryRecordVideo), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
      });

      testWidgets('displays circular container with icon', (tester) async {
        await tester.pumpWidget(buildWidget());

        final container = tester.widget<Container>(
          find.ancestor(
            of: find.byType(DivineIcon),
            matching: find.byType(Container),
          ),
        );

        expect(container.decoration, isA<BoxDecoration>());
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.shape, BoxShape.circle);
      });

      testWidgets('scrolls instead of overflowing a slot it outgrows', (
        tester,
      ) async {
        // #7242: the icon circle is a fixed 120px while the title and
        // subtitle grow on the raw text scaler, so at accessibility sizes the
        // column is taller than the slot a library tab gives it. It used to
        // clip the end of the subtitle behind an overflow stripe.
        //
        // One case per test on purpose: a RenderFlex reports its overflow
        // once per render object, so a loop that reuses the subtree would
        // report the first case and pass silently for the rest.
        await tester.pumpWidget(
          buildWidget(
            subtitle: en.libraryArchiveEmptySubtitle,
            showRecordButton: false,
            textScaler: const TextScaler.linear(3.5),
            slotHeight: 500,
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('reaches the record button once the slot is outgrown', (
        tester,
      ) async {
        // Scrolling is only worth anything if what left the viewport can be
        // brought back — the record button is the last child, so it is the
        // first thing lost.
        await tester.pumpWidget(
          buildWidget(
            subtitle: en.libraryNoClipsYetSubtitle,
            textScaler: const TextScaler.linear(3.5),
            slotHeight: 500,
          ),
        );

        await tester.scrollUntilVisible(
          find.text(en.libraryRecordVideo),
          200,
          scrollable: find.byType(Scrollable).last,
        );

        expect(find.text(en.libraryRecordVideo), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('stays put while it fits its slot', (tester) async {
        // Below the sizes that overflow, the empty state is centred and
        // static — the scroll view must not turn it into a scrollable page.
        await tester.pumpWidget(
          buildWidget(
            subtitle: en.libraryNoClipsYetSubtitle,
            slotHeight: 500,
          ),
        );

        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position;
        expect(position.maxScrollExtent, equals(0));
      });

      testWidgets('drives the sheet controller it is handed', (tester) async {
        // In selection mode the library is a DraggableScrollableSheet body,
        // and the empty state stands in for the grid that would otherwise own
        // the sheet's controller. Without it the sheet cannot be dragged from
        // the one screen state that has nothing else to grab.
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: Scaffold(
              body: DraggableScrollableSheet(
                initialChildSize: 0.9,
                builder: (context, sheetController) => ColoredBox(
                  color: VineTheme.theme.colorScheme.surface,
                  child: EmptyLibraryState(
                    scrollController: sheetController,
                    icon: DivineIconName.filmSlate,
                    title: 'No Clips Yet',
                    subtitle: en.libraryNoClipsYetSubtitle,
                    showRecordButton: false,
                  ),
                ),
              ),
            ),
          ),
        );

        final before = tester.getTopLeft(find.byType(EmptyLibraryState)).dy;
        await tester.drag(find.text('No Clips Yet'), const Offset(0, 200));
        await tester.pumpAndSettle();

        expect(
          tester.getTopLeft(find.byType(EmptyLibraryState)).dy,
          greaterThan(before),
        );
      });

      testWidgets('record button has videocam icon', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.videoCamera,
          ),
          findsOneWidget,
        );
      });
    });
  });
}
