// ABOUTME: Gesture-level test for left-trimming a sound overlay item.
// ABOUTME: Verifies the start handle moves the start, never the end.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_positioned_item.dart';

typedef _TrimCall = ({Duration start, Duration end, bool isStart});

void main() {
  group('audio left trim', () {
    late List<_TrimCall> calls;

    Future<void> pumpSelectedSound(
      WidgetTester tester, {
      required TimelineOverlayItem item,
      double pixelsPerSecond = 100,
      List<int> clipEdgesMs = const [0, 30000],
      Duration totalDuration = const Duration(seconds: 30),
    }) async {
      calls = [];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                TimelineOverlayPositionedItem(
                  item: item,
                  isDragging: false,
                  isSelected: true,
                  snappedStartMs: 0,
                  dragDeltaY: 0,
                  rowHeight: 56,
                  pixelsPerSecond: pixelsPerSecond,
                  totalDuration: totalDuration,
                  clipEdgesMs: clipEdgesMs,
                  color: Colors.blue,
                  isCollapsed: false,
                  trimExpansion: 16,
                  onTap: () {},
                  onLongPressStart: () {},
                  onLongPressMoveUpdate: (_) {},
                  onLongPressEnd: () {},
                  onTrimDragChanged: (_) {},
                  onTrimChanged:
                      ({
                        required item,
                        required startTime,
                        required endTime,
                        required isStart,
                      }) {
                        calls.add((
                          start: startTime,
                          end: endTime,
                          isStart: isStart,
                        ));
                      },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Drags the left/start trim handle horizontally by [dx] pixels.
    Future<void> dragStartHandle(WidgetTester tester, double dx) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final handle = find.descendant(
        of: find.bySemanticsLabel(
          l10n.videoEditorTimelineTrimStartSemanticLabel,
        ),
        matching: find.byType(GestureDetector),
      );
      expect(handle, findsOneWidget);
      final center = tester.getCenter(handle);
      final gesture = await tester.startGesture(center);
      // Move in small steps so onHorizontalDragUpdate fires repeatedly.
      const steps = 10;
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(Offset(dx / steps, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    testWidgets(
      'dragging the start handle right moves the start, keeps the end',
      (tester) async {
        // 6s-long clip starting 5s into a 30s source, plenty of headroom so
        // the maxDuration move-conversion cannot fire.
        await pumpSelectedSound(
          tester,
          item: const TimelineOverlayItem(
            id: 'sound-1',
            type: TimelineOverlayType.sound,
            startTime: Duration(seconds: 5),
            endTime: Duration(seconds: 11),
            label: 'Beat',
            maxDuration: Duration(seconds: 25),
            sourceDuration: Duration(seconds: 30),
            startOffset: Duration(seconds: 5),
          ),
        );

        await dragStartHandle(tester, 100); // +1s

        expect(calls, isNotEmpty);
        final last = calls.last;
        expect(last.isStart, isTrue);
        expect(last.end, const Duration(seconds: 11));
        expect(last.start.inMilliseconds, greaterThan(5000));
        expect(last.start, lessThan(const Duration(seconds: 11)));
      },
    );

    testWidgets(
      'start handle keeps the end fixed when span equals maxDuration',
      (tester) async {
        // Extracted-audio shape: the visible span equals the remaining
        // source (span == maxDuration).
        await pumpSelectedSound(
          tester,
          item: const TimelineOverlayItem(
            id: 'sound-2',
            type: TimelineOverlayType.sound,
            startTime: Duration(seconds: 5),
            endTime: Duration(seconds: 11),
            label: 'Extracted',
            maxDuration: Duration(seconds: 6),
            sourceDuration: Duration(seconds: 6),
          ),
        );

        await dragStartHandle(tester, 100); // +1s

        expect(calls, isNotEmpty);
        final last = calls.last;
        expect(last.isStart, isTrue);
        expect(last.end, const Duration(seconds: 11));
        expect(last.start.inMilliseconds, greaterThan(5000));
      },
    );
  });
}
