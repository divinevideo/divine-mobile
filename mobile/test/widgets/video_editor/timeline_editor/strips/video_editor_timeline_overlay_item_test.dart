// ABOUTME: Widget tests for TimelineOverlayItemTile.
// ABOUTME: Verifies label rendering and drag visual state.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_item.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show DrawPaintItem, PaintLayer, PaintMode, PaintedModel, WidgetLayer;

void main() {
  group(TimelineOverlayItemTile, () {
    const item = TimelineOverlayItem(
      id: 'item-1',
      type: TimelineOverlayType.layer,
      startTime: Duration.zero,
      endTime: Duration(seconds: 3),
      label: 'Layer Label',
    );

    testWidgets('renders item label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TimelineOverlayItemTile(
              item: item,
              width: 120,
              height: 40,
              color: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Layer Label'), findsOneWidget);
    });

    testWidgets('applies foreground decoration while dragging', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TimelineOverlayItemTile(
              item: item,
              width: 120,
              height: 40,
              color: Colors.blue,
              isDragging: true,
            ),
          ),
        ),
      );

      final animated = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(animated.foregroundDecoration, isNotNull);
    });

    group('sound waveform', () {
      StereoWaveformPainter findWaveformPainter(WidgetTester tester) {
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((c) => c.painter)
            .whereType<StereoWaveformPainter>()
            .single;
        return painter;
      }

      Widget buildSound(TimelineOverlayItem item) {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: TimelineOverlayItemTile(
                item: item,
                width: 120,
                height: 56,
                color: Colors.blue,
              ),
            ),
          ),
        );
      }

      testWidgets(
        'windows the waveform to the start offset when left-trimmed',
        (tester) async {
          final soundItem = TimelineOverlayItem(
            id: 'sound-1',
            type: TimelineOverlayType.sound,
            // A left-trim that consumed 2s of the head: the visible span is
            // 4s, starting 2s into an 8s source.
            startTime: const Duration(seconds: 2),
            endTime: const Duration(seconds: 6),
            label: 'Beat',
            sourceDuration: const Duration(seconds: 8),
            startOffset: const Duration(seconds: 2),
            waveformLeftChannel: Float32List.fromList(
              List<double>.generate(64, (i) => (i % 8) / 8),
            ),
          );

          await tester.pumpWidget(buildSound(soundItem));

          final painter = findWaveformPainter(tester);
          // The full source is the mapping basis, the visible span is what's
          // shown, and the head offset scrolls the bars instead of clipping
          // the tail.
          expect(painter.audioDuration, const Duration(seconds: 8));
          expect(painter.maxDuration, const Duration(seconds: 4));
          expect(painter.startOffset, const Duration(seconds: 2));
        },
      );

      testWidgets(
        'falls back to zero offset when the source duration is unknown',
        (tester) async {
          final soundItem = TimelineOverlayItem(
            id: 'sound-2',
            type: TimelineOverlayType.sound,
            startTime: const Duration(seconds: 2),
            endTime: const Duration(seconds: 6),
            label: 'Beat',
            // No sourceDuration: there's no basis to resolve the offset, so
            // the painter must not scroll the head out of view.
            startOffset: const Duration(seconds: 2),
            waveformLeftChannel: Float32List.fromList(
              List<double>.generate(64, (i) => (i % 8) / 8),
            ),
          );

          await tester.pumpWidget(buildSound(soundItem));

          final painter = findWaveformPainter(tester);
          expect(painter.startOffset, Duration.zero);
          expect(painter.audioDuration, const Duration(seconds: 4));
          expect(painter.maxDuration, const Duration(seconds: 4));
        },
      );
    });

    group('_StickerPreview', () {
      WidgetLayer buildStickerLayer({Map<String, dynamic>? meta}) {
        return WidgetLayer(
          width: 40,
          widget: const SizedBox(width: 40, height: 40),
          meta: meta,
        );
      }

      testWidgets('shows layerName from valid sticker meta', (tester) async {
        const sticker = StickerData.asset(
          'assets/stickers/test.png',
          description: LocalizedText({'en': 'Test sticker'}),
          tags: ['test'],
          packData: StickerPackData.fallback,
        );
        final stickerItem = TimelineOverlayItem(
          id: 'sticker-1',
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          endTime: const Duration(seconds: 3),
          label: 'Fallback Label',
          layer: buildStickerLayer(meta: sticker.toJson()),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TimelineOverlayItemTile(
                item: stickerItem,
                width: 120,
                height: 40,
                color: Colors.blue,
              ),
            ),
          ),
        );

        final element = tester.element(find.byType(TimelineOverlayItemTile));
        final l10n = AppLocalizations.of(element);
        final locale = Localizations.localeOf(element).languageCode;
        expect(
          find.text(
            sticker.layerName(
              locale,
              packDisplayName: l10n.videoEditorStickersDivineOriginals,
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('Fallback Label'), findsNothing);
      });

      testWidgets(
        'falls back to item.label when WidgetLayer meta is malformed',
        (tester) async {
          final stickerItem = TimelineOverlayItem(
            id: 'sticker-2',
            type: TimelineOverlayType.layer,
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
            label: 'Fallback Label',
            layer: buildStickerLayer(
              meta: {'not': 'sticker', 'shaped': true},
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: TimelineOverlayItemTile(
                  item: stickerItem,
                  width: 120,
                  height: 40,
                  color: Colors.blue,
                ),
              ),
            ),
          );

          expect(find.text('Fallback Label'), findsOneWidget);
        },
      );
    });

    group('_PaintPreview', () {
      PaintLayer buildPaintLayer(int strokeCount) => PaintLayer(
        rawSize: const Size(10, 10),
        opacity: 1,
        items: [
          for (var i = 0; i < strokeCount; i++)
            PaintedModel(
              mode: PaintMode.freeStyle,
              offsets: const [Offset.zero, Offset(10, 10)],
              erasedOffsets: const [],
              color: const Color(0xFFFF0000),
              strokeWidth: 6,
              opacity: 1,
            ),
        ],
      );

      int drawPaintItemCount(WidgetTester tester) => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((paint) => paint.painter is DrawPaintItem)
          .length;

      Widget buildTile(PaintLayer layer) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TimelineOverlayItemTile(
            item: TimelineOverlayItem(
              id: 'draw-1',
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              endTime: const Duration(seconds: 3),
              layer: layer,
            ),
            width: 120,
            height: 40,
            color: Colors.blue,
          ),
        ),
      );

      testWidgets('renders one painter per stroke for a merged layer', (
        tester,
      ) async {
        await tester.pumpWidget(buildTile(buildPaintLayer(3)));

        expect(drawPaintItemCount(tester), 3);
      });

      testWidgets('renders a single painter for a one-stroke layer', (
        tester,
      ) async {
        await tester.pumpWidget(buildTile(buildPaintLayer(1)));

        expect(drawPaintItemCount(tester), 1);
      });
    });

    group('multi-select overlay', () {
      Finder checkBadge() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.check,
      );

      Widget buildTile(OverlayMultiSelectState state) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TimelineOverlayItemTile(
            item: item,
            width: 120,
            height: 40,
            color: Colors.blue,
            multiSelectState: state,
          ),
        ),
      );

      testWidgets('shows a check badge when selected', (tester) async {
        await tester.pumpWidget(buildTile(OverlayMultiSelectState.selected));

        expect(checkBadge(), findsOneWidget);
      });

      testWidgets('shows no check badge when unselected', (tester) async {
        await tester.pumpWidget(buildTile(OverlayMultiSelectState.unselected));

        expect(checkBadge(), findsNothing);
      });

      testWidgets('shows no check badge when not multi-selecting', (
        tester,
      ) async {
        await tester.pumpWidget(buildTile(OverlayMultiSelectState.none));

        expect(checkBadge(), findsNothing);
      });
    });
  });
}
