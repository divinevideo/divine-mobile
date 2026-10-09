// ABOUTME: Widget tests for TimelineOverlayPositionedItem.
// ABOUTME: Verifies base positioning and tap interaction.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_positioned_item.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show WidgetLayer;
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffectType;

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

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

    testWidgets('announces an effect by its localized name', (tester) async {
      // The bloc labels an effect with its type's identifier, which is not a
      // word a screen reader should read out.
      const item = TimelineOverlayItem(
        id: 'effect-1',
        type: TimelineOverlayType.effect,
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
        label: 'negativeFlash',
        effectType: EditorEffectType.builtIn(VideoEffectType.negativeFlash),
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
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(semantics.label, contains(l10n.videoEditorEffectNegativeFlash));
      expect(semantics.label, isNot(contains('negativeFlash')));

      handle.dispose();
    });

    group('keyframe markers', () {
      late _MockVideoEditorMainBloc mainBloc;
      late _MockClipEditorBloc clipBloc;

      setUpAll(() {
        registerFallbackValue(const VideoEditorSeekRequested(Duration.zero));
      });

      setUp(() {
        mainBloc = _MockVideoEditorMainBloc();
        clipBloc = _MockClipEditorBloc();
        when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
        when(() => clipBloc.state).thenReturn(const ClipEditorState());
      });

      /// The canvas play time, which the timeline drives live while scrolled.
      late ValueNotifier<Duration> playTime;

      Future<void> pumpSelected(
        WidgetTester tester,
        TimelineOverlayItem item, {
        double trimExpansion = 0,
        OverlayTrimCallback? onTrimChanged,
      }) async {
        playTime = ValueNotifier(Duration.zero);
        addTearDown(playTime.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoEditorScope(
                editorKey: GlobalKey(),
                removeAreaKey: GlobalKey(),
                originalClipAspectRatio: 9 / 16,
                bodySizeNotifier: ValueNotifier(const Size(400, 600)),
                zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
                playTimeNotifier: playTime,
                playheadAdvancingNotifier: ValueNotifier<bool>(false),
                fromLibrary: false,
                onOpenCamera: () {},
                onOpenClipsEditor: () {},
                onAddStickers: () {},
                onAddEditTextLayer: ([layer]) async => null,
                onOpenMusicLibrary: () {},
                onOpenVoiceOver: () {},
                onOpenCaptions: () {},
                onOpenEffects: () {},
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
                    BlocProvider<ClipEditorBloc>.value(value: clipBloc),
                  ],
                  child: Stack(
                    children: [
                      TimelineOverlayPositionedItem(
                        item: item,
                        isDragging: false,
                        isSelected: true,
                        snappedStartMs: 0,
                        dragDeltaY: 0,
                        rowHeight: 40,
                        pixelsPerSecond: 100,
                        totalDuration: const Duration(seconds: 10),
                        clipEdgesMs: const [0, 10000],
                        color: Colors.blue,
                        isCollapsed: false,
                        trimExpansion: trimExpansion,
                        onTap: () {},
                        onLongPressStart: () {},
                        onLongPressMoveUpdate: (_) {},
                        onLongPressEnd: () {},
                        onTrimDragChanged: (_) {},
                        onTrimChanged: onTrimChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      const item = TimelineOverlayItem(
        id: 'overlay-1',
        type: TimelineOverlayType.layer,
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 3),
        // One before the layer, two on it and one after it.
        keyframeTimes: [
          Duration(milliseconds: -200),
          Duration(milliseconds: 500),
          Duration(milliseconds: 1500),
          Duration(seconds: 3),
        ],
      );

      // Each diamond is a yellow one with a dark core; the yellow one marks
      // it.
      Finder markers() => find.byWidgetPredicate(
        (w) =>
            w is DivineIcon &&
            w.icon == DivineIconName.diamondFill &&
            w.color == VineTheme.accentYellow,
      );

      testWidgets('shows the keyframes within the layer', (tester) async {
        await pumpSelected(tester, item);

        expect(markers(), findsNWidgets(2));
        // 0.5 s at 100 px a second, from the tile's left edge.
        final tileLeft = tester.getTopLeft(
          find.byType(TimelineOverlayItemTile),
        );
        expect(
          tester.getCenter(markers().first).dx - tileLeft.dx,
          closeTo(50, 0.5),
        );
      });

      testWidgets('leave the trim handle grab zone to the handle', (
        tester,
      ) async {
        Duration? trimmedStart;
        await pumpSelected(
          tester,
          item,
          // The grab zone reaches into this padding beside the tile.
          trimExpansion: 16,
          onTrimChanged:
              ({
                required item,
                required startTime,
                required endTime,
                required isStart,
              }) {
                if (isStart) trimmedStart = startTime;
              },
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        final handle = find.descendant(
          of: find.bySemanticsLabel(
            l10n.videoEditorTimelineTrimStartSemanticLabel,
          ),
          matching: find.byType(GestureDetector),
        );
        final gesture = await tester.startGesture(tester.getCenter(handle));
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(5, 0));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();

        expect(trimmedStart, greaterThan(item.startTime));
      });

      testWidgets('moves the playhead onto a keyframe tapped', (tester) async {
        await pumpSelected(tester, item);

        // The diamond lets taps through to the tile column beneath it.
        await tester.tap(markers().last, warnIfMissed: false);

        verify(
          () => mainBloc.add(
            const VideoEditorSeekRequested(Duration(milliseconds: 2500)),
          ),
        ).called(1);
      });

      testWidgets('fill in the keyframe the playhead is on as it scrubs', (
        tester,
      ) async {
        await pumpSelected(tester, item);
        // Every diamond has a dark core but the one at the playhead.
        final cores = find.byWidgetPredicate(
          (w) =>
              w is DivineIcon &&
              w.icon == DivineIconName.diamondFill &&
              w.color == TimelineConstants.trimHandleMarkerColor,
        );
        expect(cores, findsNWidgets(2));

        // Onto the keyframe 0.5 s into the layer, which starts at 1 s: the
        // canvas play time follows the scroll at once, while the main bloc
        // only catches up once the throttled seek lands.
        playTime.value = const Duration(milliseconds: 1500);
        await tester.pump();

        expect(markers(), findsNWidgets(2));
        expect(cores, findsOneWidget);
        expect(
          tester.getCenter(cores).dx,
          closeTo(tester.getCenter(markers().last).dx, 0.5),
        );

        playTime.value = const Duration(milliseconds: 1800);
        await tester.pump();
        expect(cores, findsNWidgets(2));
      });

      testWidgets('are marked on a layer that is not selected', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
                  BlocProvider<ClipEditorBloc>.value(value: clipBloc),
                ],
                child: Stack(
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
                      onTap: () => tapped = true,
                      onLongPressStart: () {},
                      onLongPressMoveUpdate: (_) {},
                      onLongPressEnd: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Small white marks rather than the selected layer's yellow ones.
        final dots = find.byWidgetPredicate(
          (w) =>
              w is DivineIcon &&
              w.icon == DivineIconName.diamondFill &&
              w.color == VineTheme.whiteText,
        );
        expect(markers(), findsNothing);
        expect(dots, findsNWidgets(2));

        // A tap on one selects the layer instead of seeking: on its upper
        // half, which sits on the tile.
        await tester.tapAt(tester.getCenter(dots.first) - const Offset(0, 3));
        expect(tapped, isTrue);
        verifyNever(
          () => mainBloc.add(any(that: isA<VideoEditorSeekRequested>())),
        );
      });
    });

    testWidgets('announces an effect on the beat as such', (tester) async {
      const item = TimelineOverlayItem(
        id: 'effect-1',
        type: TimelineOverlayType.effect,
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
        label: 'negativeFlash',
        effectType: EditorEffectType.builtIn(VideoEffectType.negativeFlash),
        effectOnBeat: true,
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
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        semantics.label,
        contains(
          l10n.videoEditorEffectOnBeatLabel(
            l10n.videoEditorEffectNegativeFlash,
          ),
        ),
      );

      handle.dispose();
    });
  });
}
