// ABOUTME: Widget tests for the stop-motion frame-list commit command.
// ABOUTME: Verifies audio that covered the composition follows a hold change.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/screens/video_editor/stop_motion_frame_transform_screen.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/stop_motion/stop_motion_frame_commands.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

void main() {
  group(commitStopMotionFrames, () {
    const clipId = 'clip_sm_1';
    const frameCount = 9;

    late _MockClipEditorBloc bloc;
    late _MockTimelineOverlayBloc overlayBloc;
    late _MockProImageEditorState editor;
    late _MockStateManager stateManager;

    setUpAll(() {
      registerFallbackValue(const ClipEditorEditingStopped());
      registerFallbackValue(const TimelineMarkersRebased([]));
    });

    List<StopMotionClipFrame> framesHeldFor(int framesPerImage) => [
      for (var i = 0; i < frameCount; i++)
        StopMotionClipFrame(
          path: '/tmp/frame_$i.jpg',
          duration: StopMotionFrameOps.framesPerImageToDuration(framesPerImage),
        ),
    ];

    DivineVideoClip clipWith(List<StopMotionClipFrame> frames) =>
        DivineVideoClip(
          id: clipId,
          stopMotionFrames: frames,
          duration: StopMotionFrameOps.totalDuration(frames),
          recordedAt: DateTime(2026),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );

    setUp(() {
      bloc = _MockClipEditorBloc();
      overlayBloc = _MockTimelineOverlayBloc();
      editor = _MockProImageEditorState();
      stateManager = _MockStateManager();

      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
      when(() => editor.stateManager).thenReturn(stateManager);
      when(
        () => editor.addHistory(
          layers: any(named: 'layers'),
          filters: any(named: 'filters'),
          meta: any(named: 'meta'),
          newLayer: any(named: 'newLayer'),
          transformConfigs: any(named: 'transformConfigs'),
          tuneAdjustments: any(named: 'tuneAdjustments'),
          blur: any(named: 'blur'),
          heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
          blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
        ),
      ).thenAnswer((_) {});
      when(() => editor.setState(any())).thenAnswer((invocation) {
        (invocation.positionalArguments.single as VoidCallback)();
      });
    });

    Future<void> commit(
      WidgetTester tester, {
      required List<StopMotionClipFrame> frames,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoEditorScope(
            editorKey: GlobalKey<ProImageEditorState>(),
            editorOverride: editor,
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: ValueNotifier(Duration.zero),
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
                BlocProvider<ClipEditorBloc>.value(value: bloc),
                BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              ],
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => commitStopMotionFrames(
                    context,
                    clipId: clipId,
                    frames: frames,
                  ),
                  child: const Text('commit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('commit'));
      await tester.pump();
    }

    List<AudioEvent> capturedAudio() {
      final meta =
          verify(
                () => editor.addHistory(
                  layers: any(named: 'layers'),
                  filters: any(named: 'filters'),
                  meta: captureAny(named: 'meta'),
                  newLayer: any(named: 'newLayer'),
                  transformConfigs: any(named: 'transformConfigs'),
                  tuneAdjustments: any(named: 'tuneAdjustments'),
                  blur: any(named: 'blur'),
                  heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
                  blockCaptureScreenshot: any(
                    named: 'blockCaptureScreenshot',
                  ),
                ),
              ).captured.single
              as Map<String, dynamic>;
      final raw =
          meta[VideoEditorConstants.audioStateHistoryKey] as List<dynamic>;
      return raw.cast<Map<String, dynamic>>().map(AudioEvent.fromJson).toList();
    }

    testWidgets('stretches a sound that covered the composition when a longer '
        'hold restretches it', (tester) async {
      // #6401: nine stills at the default hold are a fraction of a second, and
      // a sound added there is clamped to that. Holding each still for 12
      // output frames stretches the video to seconds — the sound has to grow
      // with it, or publish muxes a long video with a snippet of audio.
      final captured = framesHeldFor(StopMotionFrameOps.defaultFramesPerImage);
      final stretched = framesHeldFor(12);
      final sound = AudioEvent(
        id: 'sound-1',
        pubkey: 'bundled',
        createdAt: 0,
        url: 'asset://sounds/loop.mp3',
        duration: 30,
        endTime: StopMotionFrameOps.totalDuration(captured),
      );
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.audioStateHistoryKey: [sound.toJson()],
      });
      when(
        () => bloc.state,
      ).thenReturn(ClipEditorState(clips: [clipWith(captured)]));

      await commit(tester, frames: stretched);

      expect(
        capturedAudio().single.endTime,
        StopMotionFrameOps.totalDuration(stretched),
      );
    });

    testWidgets('leaves a sound the user trimmed short of the composition', (
      tester,
    ) async {
      final captured = framesHeldFor(StopMotionFrameOps.defaultFramesPerImage);
      final sound = AudioEvent(
        id: 'sound-1',
        pubkey: 'bundled',
        createdAt: 0,
        url: 'asset://sounds/loop.mp3',
        duration: 30,
        endTime: const Duration(milliseconds: 200),
      );
      when(() => stateManager.activeMeta).thenReturn({
        VideoEditorConstants.audioStateHistoryKey: [sound.toJson()],
      });
      when(
        () => bloc.state,
      ).thenReturn(ClipEditorState(clips: [clipWith(captured)]));

      await commit(tester, frames: framesHeldFor(12));

      // The clip edit is still committed; only the audio window is untouched.
      expect(
        capturedAudio().single.endTime,
        const Duration(milliseconds: 200),
      );
    });

    group(transformStopMotionFrame, () {
      Future<void> transform(
        WidgetTester tester, {
        required String targetClipId,
        required int frameIndex,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<ClipEditorBloc>.value(value: bloc),
                BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              ],
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => transformStopMotionFrame(
                    context,
                    clipId: targetClipId,
                    frameIndex: frameIndex,
                  ),
                  child: const Text('transform'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('transform'));
        await tester.pumpAndSettle();
      }

      testWidgets('does not open the editor for an out-of-range still', (
        tester,
      ) async {
        when(() => bloc.state).thenReturn(
          ClipEditorState(clips: [clipWith(framesHeldFor(1))]),
        );

        await transform(tester, targetClipId: clipId, frameIndex: frameCount);

        expect(find.byType(StopMotionFrameTransformScreen), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('does not open the editor for an unknown clip', (
        tester,
      ) async {
        when(() => bloc.state).thenReturn(
          ClipEditorState(clips: [clipWith(framesHeldFor(1))]),
        );

        await transform(tester, targetClipId: 'gone', frameIndex: 0);

        expect(find.byType(StopMotionFrameTransformScreen), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
