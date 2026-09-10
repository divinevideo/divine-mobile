import 'dart:convert';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_stop_motion_frame_strip.dart';

void main() {
  // 1x1 transparent PNG.
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M8AAAMBAQDJ/IY1AAAAAElFTkSuQmCC',
  );

  late Directory tempDir;
  late List<StopMotionClipFrame> frames;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('frame_strip_test');
    frames = [
      for (final name in ['a', 'b', 'c'])
        StopMotionClipFrame(
          path: (File(
            '${tempDir.path}/$name.png',
          )..writeAsBytesSync(pngBytes)).path,
          // 0.5s each → wide, easily tappable tiles at the test pps.
          duration: const Duration(milliseconds: 500),
        ),
    ];
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  /// [count] stills of 0.5s each — 50px-wide tiles at the test's 100 pps.
  List<StopMotionClipFrame> makeFrames(int count) => [
    for (var i = 0; i < count; i++)
      StopMotionClipFrame(
        path: (File(
          '${tempDir.path}/f$i.png',
        )..writeAsBytesSync(pngBytes)).path,
        duration: const Duration(milliseconds: 500),
      ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required ValueChanged<int> onFrameTapped,
    int? selectedFrameIndex,
    bool isMultiSelectMode = false,
    Set<int> selectedFrameIndexes = const {},
    void Function(int from, int to)? onReorder,
    ValueChanged<int>? onBlockMove,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: VideoEditorStopMotionFrameStrip(
              frames: frames,
              pixelsPerSecond: 100,
              selectedFrameIndex: selectedFrameIndex,
              isMultiSelectMode: isMultiSelectMode,
              selectedFrameIndexes: selectedFrameIndexes,
              onBlockMove: onBlockMove,
              onFrameTapped: onFrameTapped,
              onReorder: onReorder ?? (_, _) {},
            ),
          ),
        ),
      ),
    );
  }

  group('renders', () {
    testWidgets('renders one tile per captured still', (tester) async {
      await pump(tester, onFrameTapped: (_) {});
      expect(find.byType(Image), findsNWidgets(3));
    });

    testWidgets('renders duplicated stills without a key collision', (
      tester,
    ) async {
      // Duplicating a still reuses its file path; sibling tile keys must stay
      // unique or the Stack throws "duplicate keys found".
      frames = [...frames, frames[1]];
      await pump(tester, onFrameTapped: (_) {});

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNWidgets(4));
    });
  });

  group('tapping', () {
    testWidgets('tapping a tile reports its index', (tester) async {
      int? tapped;
      await pump(tester, onFrameTapped: (index) => tapped = index);

      await tester.tap(find.byType(Image).at(1));
      expect(tapped, 1);
    });
  });

  group('selection', () {
    testWidgets('marks the selected tile via semantics', (tester) async {
      await pump(tester, onFrameTapped: (_) {}, selectedFrameIndex: 2);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            l10n.videoEditorStopMotionFrameSemanticLabel(3, 3),
          ),
        ),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('selected tile paints a visible accent-yellow border', (
      tester,
    ) async {
      await pump(tester, onFrameTapped: (_) {}, selectedFrameIndex: 1);

      final selectedBoxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((box) {
            final decoration = box.decoration;
            return decoration is BoxDecoration &&
                decoration.border is Border &&
                (decoration.border! as Border).top.color ==
                    VineTheme.accentYellow;
          })
          .toList();

      expect(selectedBoxes, hasLength(1));
      // Foreground position — a background border would be painted underneath
      // the image that fills the same box and never be visible.
      expect(selectedBoxes.single.position, DecorationPosition.foreground);
      expect(
        ((selectedBoxes.single.decoration as BoxDecoration).border! as Border)
            .top
            .width,
        2,
      );
    });

    testWidgets('multi-select highlights every selected tile', (tester) async {
      await pump(
        tester,
        onFrameTapped: (_) {},
        isMultiSelectMode: true,
        selectedFrameIndexes: {0, 2},
      );

      final selectedBoxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((box) {
            final decoration = box.decoration;
            return decoration is BoxDecoration &&
                decoration.border is Border &&
                (decoration.border! as Border).top.color ==
                    VineTheme.accentYellow;
          });

      expect(selectedBoxes, hasLength(2));
    });

    testWidgets('multi-select taps still report the tile index', (
      tester,
    ) async {
      int? tapped;
      await pump(
        tester,
        onFrameTapped: (index) => tapped = index,
        isMultiSelectMode: true,
      );

      await tester.tap(find.byType(Image).at(2));
      expect(tapped, 2);
    });
  });

  group('dragging', () {
    testWidgets('block drag reports the drop slot among remaining stills', (
      tester,
    ) async {
      int? movedToSlot;
      await pump(
        tester,
        onFrameTapped: (_) {},
        isMultiSelectMode: true,
        selectedFrameIndexes: {0},
        onBlockMove: (slot) => movedToSlot = slot,
      );

      // Long-press the selected first tile, drag past the other two (each 50px
      // wide at 100 pps x 0.5s), release: the block lands at the end (slot 2).
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Image).at(0)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // Rebuild so the drag-in-progress move/end handlers are wired.
      await tester.pump();
      // The block pickup shows the accent-yellow insertion marker.
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == VineTheme.accentYellow,
        ),
        findsOneWidget,
        reason: 'insertion marker',
      );
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(movedToSlot, 2);
    });

    testWidgets('right-half block pickup released without dragging is a no-op', (
      tester,
    ) async {
      int? movedToSlot;
      await pump(
        tester,
        onFrameTapped: (_) {},
        isMultiSelectMode: true,
        selectedFrameIndexes: {1},
        onBlockMove: (slot) => movedToSlot = slot,
      );

      // Long-press the RIGHT half of the selected middle tile (each 50px wide),
      // then release without any drag. The block's home slot is 1 (its original
      // position), so it must stay put — not phantom-shift to slot 2.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Image).at(1)) + const Offset(15, 0),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(movedToSlot, isNull);
    });

    testWidgets(
      'right-half single-frame pickup released without dragging is a no-op',
      (tester) async {
        ({int from, int to})? reorder;
        await pump(
          tester,
          onFrameTapped: (_) {},
          onReorder: (from, to) => reorder = (from: from, to: to),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(Image).at(1)) + const Offset(15, 0),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(reorder, isNull);
      },
    );

    testWidgets(
      'non-contiguous block pickup released without dragging is a no-op',
      (tester) async {
        int? movedToSlot;
        await pump(
          tester,
          onFrameTapped: (_) {},
          isMultiSelectMode: true,
          selectedFrameIndexes: {0, 2},
          onBlockMove: (slot) => movedToSlot = slot,
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(Image).at(0)),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(movedToSlot, isNull);
      },
    );

    testWidgets('block drag does not start on an unselected tile', (
      tester,
    ) async {
      int? movedToSlot;
      await pump(
        tester,
        onFrameTapped: (_) {},
        isMultiSelectMode: true,
        selectedFrameIndexes: {2},
        onBlockMove: (slot) => movedToSlot = slot,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Image).at(0)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(movedToSlot, isNull);
    });

    testWidgets('block drag drops the selection under the finger', (
      tester,
    ) async {
      int? movedToSlot;
      frames = makeFrames(8);
      await pump(
        tester,
        onFrameTapped: (_) {},
        isMultiSelectMode: true,
        selectedFrameIndexes: {0, 1, 2, 3},
        onBlockMove: (slot) => movedToSlot = slot,
      );

      // Pick the block up by its LAST still (centre x=175) and release over the
      // 7th still (x=310). The drop follows the finger — the block lands after
      // the two unselected stills it was dragged past (slot 2), not three tiles
      // short of the finger where its own first still used to sit.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Image).at(3)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump();
      await gesture.moveBy(const Offset(135, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(movedToSlot, 2);
    });

    // The slot the finger is over is expressed in the full N-tile layout, but
    // `moveFrames` counts insertion slots among the *unselected* stills only. A
    // drag that stays inside the block therefore has to translate back to the
    // block's own home — otherwise the raw full-layout slot (4 here) is clamped
    // to the end of the remaining list and a nudge silently reorders the strip.
    testWidgets('a drag that stays inside the block reports its home slot', (
      tester,
    ) async {
      int? movedToSlot;
      frames = makeFrames(5);
      await pump(
        tester,
        onFrameTapped: (_) {},
        isMultiSelectMode: true,
        selectedFrameIndexes: {1, 2, 3},
        onBlockMove: (slot) => movedToSlot = slot,
      );

      // Pick up the block's last still (centre x=175) and nudge it 15px right —
      // far enough to count as a drag, still over the block's own stills.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Image).at(3)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump();
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Home = one unselected still (f0) sits left of the block.
      expect(movedToSlot, 1);
    });

    testWidgets('insertion marker follows the finger during a block drag', (
      tester,
    ) async {
      frames = makeFrames(8);
      await pump(
        tester,
        onFrameTapped: (_) {},
        isMultiSelectMode: true,
        selectedFrameIndexes: {0, 1, 2, 3},
        onBlockMove: (_) {},
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Image).at(3)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump();
      await gesture.moveBy(const Offset(135, 0));
      await tester.pump();

      final marker = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == VineTheme.accentYellow,
      );
      expect(
        tester.getTopLeft(marker).dx,
        closeTo(310, 30),
        reason: 'marker sits at the finger, not a block-width behind it',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('selected stills stay in place and dim during block drag', (
      tester,
    ) async {
      frames = makeFrames(5);
      await pump(
        tester,
        onFrameTapped: (_) {},
        isMultiSelectMode: true,
        selectedFrameIndexes: {1, 2, 3},
        onBlockMove: (_) {},
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Image).at(2)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity == 0.35,
        ),
        findsNWidgets(3),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('block drag does not start on an unselected tile', (
      tester,
    ) async {
      int? movedToSlot;
      await pump(
        tester,
        onFrameTapped: (_) {},
        isMultiSelectMode: true,
        selectedFrameIndexes: {2},
        onBlockMove: (slot) => movedToSlot = slot,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Image).at(0)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(movedToSlot, isNull);
    });
  });
}
