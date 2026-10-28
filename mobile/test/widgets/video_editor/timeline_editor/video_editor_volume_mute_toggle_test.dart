// ABOUTME: Tests the timeline's mute-all toggle: what it decides from the
// ABOUTME: clip and sound volumes, and which volume it sends to both blocs.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_volume_mute_toggle.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

DivineVideoClip _clip({required double volume}) => DivineVideoClip(
  id: 'clip-a',
  video: EditorVideo.file('/test/clip-a.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
  volume: volume,
);

AudioEvent _sound({
  required String id,
  required double volume,
  String? anchorClipId,
}) => AudioEvent(
  id: id,
  pubkey: 'pubkey-$id',
  createdAt: 1704067200,
  volume: volume,
  anchorClipId: anchorClipId,
);

void main() {
  group('toggleAllTimelineVolumeMuted', () {
    late _MockClipEditorBloc clipBloc;
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      clipBloc = _MockClipEditorBloc();
      overlayBloc = _MockTimelineOverlayBloc();
    });

    Future<void> toggle(
      WidgetTester tester, {
      required List<DivineVideoClip> clips,
      required List<AudioEvent> audioTracks,
    }) async {
      when(() => clipBloc.state).thenReturn(ClipEditorState(clips: clips));
      when(
        () => overlayBloc.state,
      ).thenReturn(TimelineOverlayState(audioTracks: audioTracks));

      late BuildContext context;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ClipEditorBloc>.value(value: clipBloc),
            BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
          ],
          child: Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox();
            },
          ),
        ),
      );

      toggleAllTimelineVolumeMuted(context);
    }

    void expectVolumeSent(double volume) {
      verify(
        () => clipBloc.add(ClipEditorAllClipsVolumeChanged(volume: volume)),
      ).called(1);
      verify(
        () => overlayBloc.add(
          TimelineOverlayAllAudioVolumeChanged(volume: volume),
        ),
      ).called(1);
    }

    testWidgets('mutes everything while any added sound is still audible', (
      tester,
    ) async {
      await toggle(
        tester,
        clips: [_clip(volume: 0)],
        audioTracks: [_sound(id: 'song', volume: 0.4)],
      );

      expectVolumeSent(0);
    });

    testWidgets('turns everything back up once clips and sounds are muted', (
      tester,
    ) async {
      await toggle(
        tester,
        clips: [_clip(volume: 0)],
        audioTracks: [_sound(id: 'song', volume: 0)],
      );

      expectVolumeSent(1);
    });

    testWidgets(
      "ignores a clip's own anchored sound, which follows the clip's volume",
      (tester) async {
        await toggle(
          tester,
          clips: [_clip(volume: 0)],
          audioTracks: [
            _sound(id: 'song', volume: 0),
            _sound(id: 'video_clip-a', volume: 1, anchorClipId: 'clip-a'),
          ],
        );

        expectVolumeSent(1);
      },
    );
  });
}
