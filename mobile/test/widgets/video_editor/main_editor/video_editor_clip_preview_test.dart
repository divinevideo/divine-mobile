import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_clip_preview.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_player.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

void main() {
  group(VideoEditorClipPreview, () {
    const bodySize = Size(400, 800);
    const renderSize = Size(225, 400);
    const tickPosition = Duration(milliseconds: 150);

    late _MockClipEditorBloc clipEditorBloc;
    late VideoEditorMainBloc mainBloc;

    List<StopMotionClipFrame> framesNamed(List<String> names) => [
      for (final name in names)
        StopMotionClipFrame(
          path: '/tmp/$name.png',
          duration: const Duration(milliseconds: 100),
        ),
    ];

    DivineVideoClip stopMotionClip(List<StopMotionClipFrame> frames) =>
        DivineVideoClip(
          id: 'clip-1',
          duration: const Duration(milliseconds: 300),
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          stopMotionFrames: frames,
        );

    DivineVideoClip normalClip() => DivineVideoClip(
      id: 'clip-1',
      video: EditorVideo.file('/tmp/clip.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    // Called from the test body, not `setUp`: a Bloc built outside
    // `testWidgets`' fake-async zone schedules its stream delivery in the real
    // zone, so `emit` updates `bloc.state` but `tester.pump()` never flushes
    // the notification and no listener ever rebuilds.
    void createBlocs([
      ClipEditorState clipEditorState = const ClipEditorState(),
    ]) {
      clipEditorBloc = _MockClipEditorBloc();
      when(() => clipEditorBloc.state).thenReturn(clipEditorState);
      whenListen(
        clipEditorBloc,
        const Stream<ClipEditorState>.empty(),
        initialState: clipEditorState,
      );
      mainBloc = VideoEditorMainBloc();
      addTearDown(mainBloc.close);
    }

    Future<void> pumpPreview(WidgetTester tester, DivineVideoClip clip) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<ClipEditorBloc>.value(value: clipEditorBloc),
                BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              ],
              child: Scaffold(
                body: SizedBox.fromSize(
                  size: bodySize,
                  child: VideoEditorClipPreview(
                    clip: clip,
                    controller: null,
                    bodySize: bodySize,
                    renderSize: renderSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    VideoEditorPlayer readPlayer(WidgetTester tester) =>
        tester.widget<VideoEditorPlayer>(find.byType(VideoEditorPlayer));

    Future<void> tickPlayhead(WidgetTester tester) async {
      mainBloc.add(const VideoEditorPositionChanged(tickPosition));
      // First pump drains the event handler, second settles the rebuild it
      // schedules on listeners.
      await tester.pump();
      expect(mainBloc.state.currentPosition, tickPosition);
      await tester.pump();
    }

    testWidgets('a normal clip renders the player with no stop-motion inputs', (
      tester,
    ) async {
      createBlocs();

      await pumpPreview(tester, normalClip());

      final player = readPlayer(tester);
      expect(player.stopMotionFrames, isNull);
      expect(player.stopMotionPosition, isNull);
    });

    testWidgets('a normal clip does not rebuild on a playhead tick', (
      tester,
    ) async {
      createBlocs();

      await pumpPreview(tester, normalClip());
      final before = readPlayer(tester);

      await tickPlayhead(tester);

      // Same widget instance ⇒ the position subscription really is scoped to
      // the stop-motion branch, so video playback doesn't rebuild at tick rate.
      expect(identical(readPlayer(tester), before), isTrue);
    });

    testWidgets('a stop-motion clip forwards the editor position', (
      tester,
    ) async {
      createBlocs();

      await pumpPreview(tester, stopMotionClip(framesNamed(['a', 'b', 'c'])));
      expect(readPlayer(tester).stopMotionPosition, Duration.zero);

      await tickPlayhead(tester);

      expect(readPlayer(tester).stopMotionPosition, tickPosition);
    });

    testWidgets('prefers the live clip-editor frames over the clip copy', (
      tester,
    ) async {
      final staleFrames = framesNamed(['a', 'b', 'c']);
      final liveFrames = framesNamed(['a', 'b']);
      final clip = stopMotionClip(staleFrames);
      createBlocs(
        ClipEditorState(clips: [clip.copyWith(stopMotionFrames: liveFrames)]),
      );

      await pumpPreview(tester, clip);

      // A frame delete lands in ClipEditorBloc first; the clip-manager copy
      // only catches up one post-frame later via the history path.
      expect(readPlayer(tester).stopMotionFrames, liveFrames);
    });

    testWidgets('falls back to the clip frames when the editor has no match', (
      tester,
    ) async {
      final frames = framesNamed(['a', 'b', 'c']);
      createBlocs();

      await pumpPreview(tester, stopMotionClip(frames));

      expect(readPlayer(tester).stopMotionFrames, frames);
    });
  });
}
