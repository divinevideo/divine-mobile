// ABOUTME: Widget tests for VideoEditorTimelineInteractiveBody.
// ABOUTME: Pins the bottom scroll padding that keeps the lowest strip visible
// ABOUTME: and that the strips scroll vertically from beside a short timeline.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_interactive_body.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  group(VideoEditorTimelineInteractiveBody, () {
    late _MockVideoEditorMainBloc mainBloc;
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      overlayBloc = _MockTimelineOverlayBloc();

      when(() => mainBloc.stream)
          .thenAnswer((_) => const Stream<VideoEditorMainState>.empty());
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
      when(() => overlayBloc.stream)
          .thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
    });

    /// Pumps the body into a 400 x 800 viewport with a 34 px bottom safe
    /// area. `halfScreen` is 200, so a timeline narrower than the viewport
    /// leaves bare horizontal scroll padding on both sides of it.
    Future<
      ({
        ScrollController horizontal,
        ScrollController vertical,
        ScrollController overlayStrips,
      })
    >
    pumpBody(
      WidgetTester tester, {
      Duration totalDuration = const Duration(seconds: 12),
      double pixelsPerSecond = 80,
      double totalWidth = 960,
    }) async {
      final scrollController = ScrollController();
      final verticalScrollController = ScrollController();
      final overlayStripsScrollController = ScrollController();
      final playhead = ValueNotifier(Duration.zero);
      final volumePreview = ValueNotifier<double?>(null);
      addTearDown(scrollController.dispose);
      addTearDown(verticalScrollController.dispose);
      addTearDown(overlayStripsScrollController.dispose);
      addTearDown(playhead.dispose);
      addTearDown(volumePreview.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(padding: const EdgeInsets.only(bottom: 34)),
                child: SizedBox(
                  width: 400,
                  height: 800,
                  child: MultiBlocProvider(
                    providers: [
                      BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
                      BlocProvider<TimelineOverlayBloc>.value(
                        value: overlayBloc,
                      ),
                    ],
                    child: VideoEditorTimelineInteractiveBody(
                      playheadPosition: playhead,
                      totalDuration: totalDuration,
                      formatPosition: (_) => '',
                      onStepPosition: (_, _, _) {},
                      onPointerDown: (_) {},
                      onPointerMove: (_) {},
                      onPointerUp: (_) {},
                      onPointerCancel: (_) {},
                      onScrollNotification: (_) => false,
                      scrollController: scrollController,
                      isPinching: false,
                      isTrimming: false,
                      halfScreen: 200,
                      pixelsPerSecond: pixelsPerSecond,
                      clips: const <DivineVideoClip>[],
                      totalWidth: totalWidth,
                      isInteracting: false,
                      onReorder: (_) {},
                      onReorderChanged: (_) {},
                      trimmingClipId: null,
                      onTrimChanged: ({
                        required clipId,
                        required isStart,
                        required trimStart,
                        required trimEnd,
                      }) {},
                      onTrimDragChanged: (_) {},
                      onClipTapped: (_) {},
                      isMultiSelectMode: false,
                      selectedClipIds: const <String>{},
                      onOverlayItemMoved: ({
                        required item,
                        required startTime,
                        required row,
                        required insertAbove,
                      }) {},
                      onOverlayItemMoving: ({
                        required item,
                        required startTime,
                      }) {},
                      onOverlayItemTrimmed: ({
                        required item,
                        required startTime,
                        required endTime,
                        required isStart,
                      }) {},
                      onOverlayTrimDragChanged: (_) {},
                      onOverlayItemTapped: (_) {},
                      onOverlayDragStarted: (_) {},
                      onOverlayDragEnded: () {},
                      verticalScrollController: verticalScrollController,
                      overlayStripsScrollController:
                          overlayStripsScrollController,
                      volumePreviewNotifier: volumePreview,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return (
        horizontal: scrollController,
        vertical: verticalScrollController,
        overlayStrips: overlayStripsScrollController,
      );
    }

    testWidgets(
      'pads the vertical scroll view past the bottom safe area so the lowest '
      'strip is reachable',
      (tester) async {
        final (:vertical, horizontal: _, overlayStrips: _) = await pumpBody(
          tester,
        );

        final outerScrollView = tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere((s) => identical(s.controller, vertical));

        // _scrollBottomPadding (100) + bottom safe-area inset (34).
        expect(
          outerScrollView.padding,
          equals(const EdgeInsets.only(bottom: 134)),
        );
      },
    );

    group('overlay strips vertical scroll', () {
      /// Eight stacked layer rows: taller than the strips area, so there is
      /// vertical scroll extent to prove a drag reached the strips.
      setUp(() {
        when(() => overlayBloc.state).thenReturn(
          TimelineOverlayState(
            items: [
              for (var row = 0; row < 8; row++)
                TimelineOverlayItem(
                  id: 'layer-$row',
                  type: TimelineOverlayType.layer,
                  startTime: Duration.zero,
                  endTime: const Duration(seconds: 2),
                  label: 'Text $row',
                  row: row,
                ),
            ],
          ),
        );
      });

      // A 100 px timeline in a 400 px viewport: at scroll offset 0 the body
      // spans x = 200..300, so x < 200 and x > 300 are bare scroll padding.
      Future<({ScrollController horizontal, ScrollController overlayStrips})>
      pumpShortTimeline(WidgetTester tester) async {
        final (:horizontal, vertical: _, :overlayStrips) = await pumpBody(
          tester,
          totalDuration: const Duration(seconds: 2),
          pixelsPerSecond: 50,
          totalWidth: 100,
        );
        return (horizontal: horizontal, overlayStrips: overlayStrips);
      }

      testWidgets('scrolls when dragging on the strips', (tester) async {
        final (:overlayStrips, horizontal: _) = await pumpShortTimeline(
          tester,
        );

        await tester.dragFrom(const Offset(250, 300), const Offset(0, -120));
        await tester.pump();

        expect(overlayStrips.offset, greaterThan(0));
      });

      testWidgets(
        'scrolls when dragging in the padding left of a short timeline',
        (tester) async {
          // Regression: the strips' vertical scroll view was exactly as wide
          // as the timeline, so a drag that started on the empty area beside a
          // short composition reached only the horizontal scroll view and the
          // strips did not move.
          final (:overlayStrips, horizontal: _) = await pumpShortTimeline(
            tester,
          );

          await tester.dragFrom(const Offset(50, 300), const Offset(0, -120));
          await tester.pump();

          expect(overlayStrips.offset, greaterThan(0));
        },
      );

      testWidgets(
        'scrolls when dragging in the padding right of a short timeline',
        (tester) async {
          final (:overlayStrips, horizontal: _) = await pumpShortTimeline(
            tester,
          );

          await tester.dragFrom(const Offset(350, 300), const Offset(0, -120));
          await tester.pump();

          expect(overlayStrips.offset, greaterThan(0));
        },
      );

      testWidgets(
        'still scrubs the timeline when dragging horizontally in the padding',
        (tester) async {
          // The strips' scroll view now shares that area with the horizontal
          // one, so the gesture arena has to keep handing sideways drags to
          // the timeline scrub.
          final (:horizontal, :overlayStrips) = await pumpShortTimeline(
            tester,
          );

          await tester.dragFrom(const Offset(50, 300), const Offset(-60, 0));
          await tester.pump();

          expect(horizontal.offset, greaterThan(0));
          expect(overlayStrips.offset, equals(0));
        },
      );
    });
  });
}
