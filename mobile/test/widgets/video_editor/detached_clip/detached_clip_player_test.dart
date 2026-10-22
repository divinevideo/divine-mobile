// ABOUTME: Tests how a detached clip's companion player follows the editor
// ABOUTME: playhead, driven by notifiers against a mocked native controller.

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_speed_choice.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/detached_clip_composite.dart';
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

    group('detachedClipPlayerSource', () {
      // Four seconds under the Hero curve, trimmed so the body does not start
      // at the file's beginning.
      final ramped = DivineVideoClip(
        id: 'clip-1',
        video: EditorVideo.file('/documents/clip-1.mp4'),
        duration: const Duration(seconds: 5),
        trimStart: const Duration(milliseconds: 500),
        trimEnd: const Duration(milliseconds: 500),
        recordedAt: DateTime(2026),
        targetAspectRatio: .square,
        originalAspectRatio: 1,
        speedRamp: ClipSpeedRampPreset.hero.ramp,
      );
      const bodyPath = '/cache/speed_clips/body.mp4';

      test('plays a ramped clip from its rendered body at normal speed', () {
        final source = detachedClipPlayerSource(
          ramped,
          path: '/documents/clip-1.mp4',
          bodyPath: bodyPath,
        );

        expect(source.uri, equals(bodyPath));
        expect(source.start, equals(Duration.zero));
        expect(source.end, isNull);
        expect(source.playbackSpeed, equals(1.0));
      });

      test("retimes the file at the ramp's average speed without a body", () {
        final source = detachedClipPlayerSource(
          ramped,
          path: '/documents/clip-1.mp4',
        );

        expect(source.uri, equals('/documents/clip-1.mp4'));
        expect(source.start, equals(const Duration(milliseconds: 500)));
        expect(source.end, equals(const Duration(milliseconds: 4500)));
        expect(source.playbackSpeed, equals(ramped.averagePlaybackSpeed));
      });

      test(
        'reads the body at the moment the export reads its ramped render',
        () {
          // The export composites the clip flattened with its ramp, the same
          // render as the body, from its own start; the companion reads the
          // body at the playhead's distance into the layer.
          const layerStart = Duration(seconds: 1);
          final window = detachedClipWindow(
            clip: ramped,
            sourceOffset: Duration.zero,
            layerStart: layerStart,
            layerEnd: layerStart + ramped.playbackDuration,
            timelineMap: TransitionTimelineMap.fromClips([
              ramped.copyWith(
                clearSpeedRamp: true,
                duration: const Duration(seconds: 9),
              ),
            ]),
            speedFlattened: true,
          );
          expect(window.start, equals(layerStart));

          for (final ms in [0, 400, 1000, 2000, 3000]) {
            final playhead = layerStart + Duration(milliseconds: ms);
            expect(
              detachedClipPlayerPosition(
                playhead,
                ramped,
                layerStart: layerStart,
              ),
              equals(window.trimStart + (playhead - window.start!)),
              reason: 'playhead $playhead',
            );
          }
        },
      );
    });
  });
}
