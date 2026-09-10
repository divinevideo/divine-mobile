// ABOUTME: Widget tests for TimelineOverlayStrip.
// ABOUTME: Validates rendering, item tapping, collapse mode, and trim handles.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';

void main() {
  group(TimelineOverlayStrip, () {
    const testItem = TimelineOverlayItem(
      id: 'item-1',
      type: TimelineOverlayType.layer,
      startTime: Duration(seconds: 1),
      endTime: Duration(seconds: 6),
      label: 'Test Layer',
    );

    const testItem2 = TimelineOverlayItem(
      id: 'item-2',
      type: TimelineOverlayType.layer,
      startTime: Duration(seconds: 3),
      endTime: Duration(seconds: 7),
      row: 1,
      label: 'Second Layer',
    );

    Widget buildWidget({
      List<TimelineOverlayItem> items = const [testItem],
      int rowCount = 1,
      double totalWidth = 600,
      double pixelsPerSecond = 50,
      Duration totalDuration = const Duration(seconds: 30),
      List<int> clipEdgesMs = const [0, 30000],
      Color color = VineTheme.primary,
      bool isCollapsed = false,
      String? selectedItemId,
      ValueChanged<TimelineOverlayItem>? onItemTapped,
      OverlayMoveCallback? onItemMoved,
      OverlayTrimCallback? onTrimChanged,
      ValueChanged<bool>? onTrimDragChanged,
      ValueChanged<TimelineOverlayItem>? onDragStarted,
      VoidCallback? onDragEnded,
    }) {
      return BlocProvider(
        create: (_) => TimelineOverlayBloc(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TimelineOverlayStrip(
                items: items,
                rowCount: rowCount,
                totalWidth: totalWidth,
                pixelsPerSecond: pixelsPerSecond,
                totalDuration: totalDuration,
                clipEdgesMs: clipEdgesMs,
                color: color,
                isCollapsed: isCollapsed,
                selectedItemId: selectedItemId,
                onItemTapped: onItemTapped,
                onItemMoved: onItemMoved,
                onTrimChanged: onTrimChanged,
                onTrimDragChanged: onTrimDragChanged,
                onDragStarted: onDragStarted,
                onDragEnded: onDragEnded,
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $TimelineOverlayStrip', (tester) async {
        await tester.pumpWidget(buildWidget());
        expect(find.byType(TimelineOverlayStrip), findsOneWidget);
      });

      testWidgets('renders nothing when items list is empty', (tester) async {
        await tester.pumpWidget(buildWidget(items: []));
        // Empty strip renders a SizedBox.shrink, no Stack
        final stripFinder = find.byType(TimelineOverlayStrip);
        expect(stripFinder, findsOneWidget);
        expect(
          find.descendant(of: stripFinder, matching: find.byType(Stack)),
          findsNothing,
        );
      });

      testWidgets('renders item label text', (tester) async {
        await tester.pumpWidget(buildWidget());
        expect(find.text('Test Layer'), findsOneWidget);
      });

      testWidgets('renders multiple items in separate rows', (tester) async {
        await tester.pumpWidget(
          buildWidget(items: const [testItem, testItem2], rowCount: 2),
        );
        expect(find.text('Test Layer'), findsOneWidget);
        expect(find.text('Second Layer'), findsOneWidget);
      });

      testWidgets('does not render item with zero trimmed duration', (
        tester,
      ) async {
        const zeroItem = TimelineOverlayItem(
          id: 'zero',
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          endTime: Duration.zero,
          label: 'Zero',
        );
        await tester.pumpWidget(buildWidget(items: const [zeroItem]));
        expect(find.text('Zero'), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('calls onItemTapped when item is tapped', (tester) async {
        TimelineOverlayItem? tappedItem;
        await tester.pumpWidget(
          buildWidget(onItemTapped: (item) => tappedItem = item),
        );

        await tester.tap(find.text('Test Layer'));
        expect(tappedItem?.id, equals('item-1'));
      });

      testWidgets('calls onDragStarted on long press', (tester) async {
        TimelineOverlayItem? draggedItem;
        await tester.pumpWidget(
          buildWidget(onDragStarted: (item) => draggedItem = item),
        );

        await tester.longPress(find.text('Test Layer'));
        await tester.pumpAndSettle();
        expect(draggedItem?.id, equals('item-1'));
      });
    });

    group('collapse mode', () {
      testWidgets('renders all items in single row when collapsed', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            items: const [testItem, testItem2],
            rowCount: 2,
            isCollapsed: true,
          ),
        );

        // Find the SizedBox inside the strip that sets height.
        final sizedBoxes = find.descendant(
          of: find.byType(TimelineOverlayStrip),
          matching: find.byType(SizedBox),
        );
        // First SizedBox sets the strip dimensions.
        final stripBox = tester.widget<SizedBox>(sizedBoxes.first);
        expect(stripBox.height, equals(TimelineConstants.overlayRowHeight));
      });

      testWidgets('uses multiple row heights when not collapsed', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(items: const [testItem, testItem2], rowCount: 2),
        );

        final sizedBoxes = find.descendant(
          of: find.byType(TimelineOverlayStrip),
          matching: find.byType(SizedBox),
        );
        final stripBox = tester.widget<SizedBox>(sizedBoxes.first);
        expect(stripBox.height, equals(TimelineConstants.overlayRowHeight * 2));
      });
    });

    group('trim handles', () {
      testWidgets('does not show trim handles for unselected items', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(TimelineTrimHandles), findsNothing);
      });
    });

    group('accessibility', () {
      testWidgets('item has semantic label', (tester) async {
        await tester.pumpWidget(buildWidget());

        final semantics = tester.getSemantics(find.text('Test Layer'));
        expect(semantics.label, contains('Test Layer'));
      });
    });
  });
}
