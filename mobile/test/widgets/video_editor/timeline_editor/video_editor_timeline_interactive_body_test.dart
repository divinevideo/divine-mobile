// ABOUTME: Widget tests for VideoEditorTimelineInteractiveBody.
// ABOUTME: Pins the bottom scroll padding that keeps the lowest strip visible.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
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

      when(
        () => mainBloc.stream,
      ).thenAnswer((_) => const Stream<VideoEditorMainState>.empty());
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
    });

    testWidgets(
      'pads the vertical scroll view past the bottom safe area so the lowest '
      'strip is reachable',
      (tester) async {
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
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(bottom: 34),
                  ),
                  child: SizedBox(
                    width: 400,
                    height: 800,
                    child: MultiBlocProvider(
                      providers: [
                        BlocProvider<VideoEditorMainBloc>.value(
                          value: mainBloc,
                        ),
                        BlocProvider<TimelineOverlayBloc>.value(
                          value: overlayBloc,
                        ),
                      ],
                      child: VideoEditorTimelineInteractiveBody(
                        playheadPosition: playhead,
                        totalDuration: const Duration(seconds: 12),
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
                        pixelsPerSecond: 80,
                        clips: const <DivineVideoClip>[],
                        totalWidth: 960,
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

        final outerScrollView = tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere(
              (s) => identical(s.controller, verticalScrollController),
            );

        // _scrollBottomPadding (100) + bottom safe-area inset (34).
        expect(
          outerScrollView.padding,
          equals(const EdgeInsets.only(bottom: 134)),
        );
      },
    );
  });
}
