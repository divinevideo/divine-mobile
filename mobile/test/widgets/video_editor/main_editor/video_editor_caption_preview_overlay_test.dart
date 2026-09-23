// ABOUTME: Widget tests for VideoEditorCaptionPreviewOverlay — the CC pill that
// ABOUTME: follows the per-frame play time without rebuilding every frame.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/caption_pill.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_caption_preview_overlay.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

TimelineOverlayItem _cue(String id, String label, int startMs, int endMs) =>
    TimelineOverlayItem(
      id: id,
      type: TimelineOverlayType.captions,
      startTime: Duration(milliseconds: startMs),
      endTime: Duration(milliseconds: endMs),
      label: label,
    );

void main() {
  group(VideoEditorCaptionPreviewOverlay, () {
    late _MockVideoEditorMainBloc mainBloc;
    late _MockTimelineOverlayBloc overlayBloc;
    late StreamController<VideoEditorMainState> mainStateChanges;
    late ValueNotifier<Duration> playTime;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      overlayBloc = _MockTimelineOverlayBloc();
      mainStateChanges = StreamController<VideoEditorMainState>.broadcast();
      playTime = ValueNotifier(Duration.zero);
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
      when(
        () => mainBloc.stream,
      ).thenAnswer((_) => mainStateChanges.stream);
      when(() => overlayBloc.state).thenReturn(
        TimelineOverlayState(
          items: [
            _cue('first', 'Hello there', 0, 1000),
            _cue('second', 'Second line', 1500, 2500),
          ],
        ),
      );
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
    });

    tearDown(() async {
      await mainStateChanges.close();
      playTime.dispose();
    });

    Widget buildWidget() => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: VideoEditorScope(
        editorKey: GlobalKey<ProImageEditorState>(),
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
        onOpenMusicLibrary: () {},
        onOpenVoiceOver: () {},
        onOpenCaptions: () {},
        onAddEditTextLayer: ([layer]) async => null,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
            BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
          ],
          child: const Stack(children: [VideoEditorCaptionPreviewOverlay()]),
        ),
      ),
    );

    group('renders', () {
      testWidgets('the cue active at the play time', (tester) async {
        playTime.value = const Duration(milliseconds: 200);
        await tester.pumpWidget(buildWidget());

        expect(find.text('Hello there'), findsOneWidget);

        playTime.value = const Duration(milliseconds: 1600);
        await tester.pump();

        expect(find.text('Hello there'), findsNothing);
        expect(find.text('Second line'), findsOneWidget);

        playTime.value = const Duration(milliseconds: 1200);
        await tester.pump();

        expect(find.byType(CaptionPill), findsNothing);
      });

      testWidgets('the cue at the bloc position before the play time has been '
          'driven', (tester) async {
        when(() => mainBloc.state).thenReturn(
          const VideoEditorMainState(
            currentPosition: Duration(milliseconds: 2000),
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.text('Second line'), findsOneWidget);
      });

      testWidgets('updates the fallback cue when the bloc position changes '
          'while play time is zero', (tester) async {
        when(() => mainBloc.state).thenReturn(
          const VideoEditorMainState(
            currentPosition: Duration(milliseconds: 2000),
          ),
        );

        await tester.pumpWidget(buildWidget());
        expect(find.text('Second line'), findsOneWidget);

        const correctedState = VideoEditorMainState();
        when(() => mainBloc.state).thenReturn(correctedState);
        mainStateChanges.add(correctedState);
        await tester.pump();

        expect(find.text('Second line'), findsNothing);
        expect(find.text('Hello there'), findsOneWidget);
      });
    });

    group('play time ticks', () {
      testWidgets('inside the same cue schedule no rebuild', (tester) async {
        playTime.value = const Duration(milliseconds: 100);
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();
        expect(find.text('Hello there'), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isFalse);

        playTime.value = const Duration(milliseconds: 116);

        // A per-frame tick that leaves the cue unchanged must not dirty the
        // pill — during playback that was a rebuild and relayout every frame.
        expect(tester.binding.hasScheduledFrame, isFalse);

        playTime.value = const Duration(milliseconds: 1600);

        expect(tester.binding.hasScheduledFrame, isTrue);
      });
    });
  });
}
