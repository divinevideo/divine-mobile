// ABOUTME: Widget tests for TimelineOverlayPositionedItem.
// ABOUTME: Verifies base positioning and tap interaction.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_positioned_item.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show WidgetLayer;

void main() {
  group(TimelineOverlayPositionedItem, () {
    testWidgets('uses timeline-derived position when not dragging', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'overlay-1',
        type: TimelineOverlayType.layer,
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 3),
        row: 2,
        label: 'My Overlay',
      );

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
                  isSelected: false,
                  snappedStartMs: 0,
                  dragDeltaY: 0,
                  rowHeight: 40,
                  pixelsPerSecond: 100,
                  totalDuration: const Duration(seconds: 10),
                  clipEdgesMs: const [0, 10000],
                  color: Colors.blue,
                  isCollapsed: false,
                  trimExpansion: 0,
                  onTap: () {},
                  onLongPressStart: () {},
                  onLongPressMoveUpdate: (_) {},
                  onLongPressEnd: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.left, equals(100));
      expect(
        positioned.top,
        equals(2 * 40 + TimelineConstants.overlayRowGap / 2),
      );
      expect(find.text('My Overlay'), findsOneWidget);
    });

    testWidgets('offsets position by clip gaps when crossing clip ends', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'overlay-gap',
        type: TimelineOverlayType.layer,
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 3),
        label: 'Gap Overlay',
      );

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
                  isSelected: false,
                  snappedStartMs: 0,
                  dragDeltaY: 0,
                  rowHeight: 40,
                  pixelsPerSecond: 100,
                  totalDuration: const Duration(seconds: 3),
                  // Three clips: a gap precedes the start at 1s and the
                  // item spans the boundary at 1s but not the one at 3s.
                  clipEdgesMs: const [0, 1000, 3000],
                  color: Colors.blue,
                  isCollapsed: false,
                  trimExpansion: 0,
                  onTap: () {},
                  onLongPressStart: () {},
                  onLongPressMoveUpdate: (_) {},
                  onLongPressEnd: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      // 1s @ 100pps = 100px + 1px gap at the 1s boundary.
      expect(positioned.left, equals(100 + TimelineConstants.clipGap));
      // Width lives on the child tile for unselected items.
      final tile = tester.widget<TimelineOverlayItemTile>(
        find.byType(TimelineOverlayItemTile),
      );
      // Width spans 1s..3s = 200px (no further internal gap consumed).
      expect(tile.width, equals(200));
    });

    testWidgets('invokes onTap callback', (tester) async {
      var tapCount = 0;
      const item = TimelineOverlayItem(
        id: 'overlay-2',
        type: TimelineOverlayType.layer,
        startTime: Duration.zero,
        endTime: Duration(seconds: 1),
        label: 'Tap Target',
      );

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
                  isSelected: false,
                  snappedStartMs: 0,
                  dragDeltaY: 0,
                  rowHeight: 40,
                  pixelsPerSecond: 100,
                  totalDuration: const Duration(seconds: 10),
                  clipEdgesMs: const [0, 10000],
                  color: Colors.green,
                  isCollapsed: true,
                  trimExpansion: 0,
                  onTap: () => tapCount++,
                  onLongPressStart: () {},
                  onLongPressMoveUpdate: (_) {},
                  onLongPressEnd: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(tapCount, equals(1));
    });
    testWidgets('announces a sticker by its description, not just "Sticker"', (
      tester,
    ) async {
      // The main editor canvas is wrapped in ExcludeSemantics, so this strip is
      // the only place a screen reader can learn which stickers are on a clip.
      // The bloc labels every WidgetLayer generically; the description comes
      // from the tile. If either half regresses, the sticker becomes anonymous.
      const sticker = StickerData.asset(
        'assets/stickers/test.png',
        description: LocalizedText({'en': 'Test sticker'}),
        tags: [],
        packData: StickerPackData.fallback,
      );
      final item = TimelineOverlayItem(
        id: 'sticker-1',
        type: TimelineOverlayType.layer,
        startTime: Duration.zero,
        endTime: const Duration(seconds: 3),
        label: 'Sticker',
        layer: WidgetLayer(
          widget: const SizedBox.shrink(),
          meta: sticker.toJson(),
        ),
      );

      final handle = tester.ensureSemantics();

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
                  isSelected: false,
                  snappedStartMs: 0,
                  dragDeltaY: 0,
                  rowHeight: 40,
                  pixelsPerSecond: 100,
                  totalDuration: const Duration(seconds: 10),
                  clipEdgesMs: const [0, 10000],
                  color: Colors.blue,
                  isCollapsed: false,
                  trimExpansion: 0,
                  onTap: () {},
                  onLongPressStart: () {},
                  onLongPressMoveUpdate: (_) {},
                  onLongPressEnd: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final semantics = tester.getSemantics(
        find.byType(TimelineOverlayPositionedItem),
      );
      expect(semantics.label, contains('Test sticker'));

      handle.dispose();
    });
  });
}
