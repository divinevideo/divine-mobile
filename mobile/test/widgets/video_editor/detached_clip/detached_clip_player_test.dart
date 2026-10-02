// ABOUTME: Tests how a detached clip's companion player follows the editor
// ABOUTME: playhead, driven by notifiers against a mocked native controller.

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_player.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockDivineVideoPlayerController extends Mock
    implements DivineVideoPlayerController {}

DivineVideoClip _clip() => DivineVideoClip(
  id: 'clip-1',
  video: EditorVideo.file('/documents/clip-1.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .square,
  originalAspectRatio: 1,
);

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));

  group(DetachedClipPlayer, () {
    group('follow', () {
      late _MockDivineVideoPlayerController controller;
      late ValueNotifier<Duration> playhead;
      late ValueNotifier<bool> advancing;
      late DetachedClipPlayer player;

      setUp(() {
        controller = _MockDivineVideoPlayerController();
        when(
          () => controller.setLooping(looping: any(named: 'looping')),
        ).thenAnswer((_) async {});
        when(() => controller.seekTo(any())).thenAnswer((_) async {});
        when(() => controller.play()).thenAnswer((_) async {});
        when(() => controller.pause()).thenAnswer((_) async {});
        // Finished on its last frame: the clip ran out before the editor
        // reached the end of the layer's window.
        when(() => controller.state).thenReturn(
          const DivineVideoPlayerState(
            status: PlaybackStatus.completed,
            position: Duration(seconds: 2),
          ),
        );
        playhead = ValueNotifier(const Duration(milliseconds: 1900));
        advancing = ValueNotifier(true);
        player = DetachedClipPlayer.withController(controller, _clip());
        player.follow(
          playhead: playhead,
          advancing: advancing,
          windowEnd: const Duration(seconds: 2),
        );
        addTearDown(() {
          player.detach();
          playhead.dispose();
          advancing.dispose();
        });
      });

      test('plays a finished clip again when the composition loops back '
          'into its window', () async {
        playhead.value = const Duration(milliseconds: 1950);
        await pumpEventQueue();
        verify(() => controller.play()).called(1);

        playhead.value = Duration.zero;
        await pumpEventQueue();

        verify(() => controller.seekTo(Duration.zero)).called(1);
        verify(() => controller.play()).called(1);
      });

      test('leaves a finished clip paused when a scrub moves it while the '
          'editor is paused', () async {
        advancing.value = false;

        playhead.value = Duration.zero;
        await pumpEventQueue();

        verify(() => controller.seekTo(Duration.zero)).called(1);
        verifyNever(() => controller.play());
      });
    });
  });
}
