import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/services/video_editor/video_editor_beat_resolver.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../helpers/audio_samples.dart';

void main() {
  group(VideoEditorEffectsCubit, () {
    const vhs = EditorVideoEffect(
      id: 'vhs',
      effect: VideoEffect.vhs(
        intensity: 0.4,
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 3),
      ),
    );
    const vignette = EditorVideoEffect(
      id: 'vignette',
      effect: VideoEffect.vignette(),
    );
    const echo = EditorVideoEffect.custom(
      id: 'echo',
      custom: CustomVideoEffect(
        id: echoVideoEffectId,
        params: {EditorVideoEffect.intensityParam: 0.5},
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 4),
      ),
    );

    VideoEditorEffectsCubit buildCubit() =>
        VideoEditorEffectsCubit(createId: () => 'new');

    group('syncApplied', () {
      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'mirrors the effects committed to the history',
        build: buildCubit,
        act: (cubit) => cubit.syncApplied(const [vhs]),
        expect: () => [
          const VideoEditorEffectsState(applied: [vhs]),
        ],
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'emits nothing when the effects did not change',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [vhs]),
        act: (cubit) => cubit.syncApplied(const [vhs]),
        expect: () => <VideoEditorEffectsState>[],
      );
    });

    group('startEditing', () {
      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'opens on the given effect and its intensity',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [vignette, vhs]),
        act: (cubit) => cubit.startEditing(effectId: 'vhs'),
        verify: (cubit) {
          expect(cubit.state.isEditing, isTrue);
          expect(cubit.state.editingId, 'vhs');
          expect(cubit.state.selectedType?.builtIn, VideoEffectType.vhs);
          expect(cubit.state.intensity, 0.4);
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'opens a new effect on "none" at the default intensity',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(
          applied: [vhs],
          selectedType: EditorEffectType.builtIn(VideoEffectType.glitch),
          intensity: 0.1,
        ),
        act: (cubit) => cubit.startEditing(),
        verify: (cubit) {
          expect(cubit.state.editingId, isNull);
          expect(cubit.state.selectedType, isNull);
          expect(
            cubit.state.intensity,
            VideoEditorEffectsCubit.defaultIntensity,
          );
          expect(
            [for (final e in cubit.state.previewEffects) e.effect],
            [vhs.effect],
          );
        },
      );
    });

    group('while editing', () {
      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'previews the selection in place of the edited effect, over the '
        'whole video',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [vhs, vignette]),
        act: (cubit) => cubit
          ..startEditing(effectId: 'vhs')
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.pixelate))
          ..setIntensity(1.7),
        verify: (cubit) {
          expect(cubit.state.intensity, 1);
          expect(
            [for (final e in cubit.state.previewEffects) e.effect],
            [
              const VideoEffect.pixelate(),
              vignette.effect,
            ],
          );
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'previews a new effect on top of the committed ones',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [vhs]),
        act: (cubit) => cubit
          ..startEditing()
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.strobe)),
        verify: (cubit) {
          expect(
            [for (final e in cubit.state.previewEffects) e.effect],
            [
              vhs.effect,
              const VideoEffect.strobe(
                intensity: VideoEditorEffectsCubit.defaultIntensity,
              ),
            ],
          );
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'previews a flashing pick without the other flashing effects',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(
          applied: [
            EditorVideoEffect(
              id: 'negative',
              effect: VideoEffect.negativeFlash(
                startTime: Duration(seconds: 1),
                endTime: Duration(seconds: 2),
              ),
            ),
            vignette,
          ],
        ),
        act: (cubit) => cubit
          ..startEditing()
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.strobe)),
        verify: (cubit) {
          expect(
            [for (final e in cubit.state.previewEffects) e.effect],
            [
              vignette.effect,
              const VideoEffect.strobe(
                intensity: VideoEditorEffectsCubit.defaultIntensity,
              ),
            ],
          );
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'cancel goes back to previewing the committed effects',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [vhs]),
        act: (cubit) => cubit
          ..startEditing(effectId: 'vhs')
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.glitch))
          ..cancel(),
        verify: (cubit) {
          expect(cubit.state.isEditing, isFalse);
          expect(cubit.state.editingId, isNull);
          expect(
            [for (final e in cubit.state.previewEffects) e.effect],
            [vhs.effect],
          );
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'feeds a newly picked echo to the native preview after the '
        'committed one, and keeps it out of the built-in preview',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [vhs, echo]),
        act: (cubit) => cubit
          ..startEditing()
          ..selectType(EditorEffectType.echo)
          ..setIntensity(0.8),
        verify: (cubit) {
          expect(cubit.state.previewCustomEffects, [
            echo.custom,
            const CustomVideoEffect(
              id: echoVideoEffectId,
              params: {EditorVideoEffect.intensityParam: 0.8},
            ),
          ]);
          expect(cubit.state.previewEffects, const [vhs]);
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'feeds an edited echo to the native preview in place of its '
        'committed copy',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [echo, vhs]),
        act: (cubit) => cubit
          ..startEditing(effectId: 'echo')
          ..setIntensity(0.9),
        verify: (cubit) {
          expect(cubit.state.previewCustomEffects, [
            const CustomVideoEffect(
              id: echoVideoEffectId,
              params: {EditorVideoEffect.intensityParam: 0.9},
            ),
          ]);
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'cancel goes back to feeding the committed echo to the native '
        'preview',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [echo]),
        act: (cubit) => cubit
          ..startEditing(effectId: 'echo')
          ..setIntensity(0.9)
          ..cancel(),
        verify: (cubit) {
          expect(cubit.state.previewCustomEffects, [echo.custom]);
        },
      );
    });

    group('confirm', () {
      test('adds a new effect over the whole video after the others', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs])
          ..startEditing()
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.glitch))
          ..setIntensity(0.5);
        addTearDown(cubit.close);

        const added = EditorVideoEffect(
          id: 'new',
          effect: VideoEffect.glitch(intensity: 0.5),
        );
        expect(cubit.confirm().effects, const [vhs, added]);
        expect(cubit.state.isEditing, isFalse);
        expect(cubit.state.applied, const [vhs, added]);
      });

      test('adds the echo as a custom effect the preview leaves out', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs])
          ..startEditing()
          ..selectType(EditorEffectType.echo)
          ..setIntensity(0.6);
        addTearDown(cubit.close);

        expect(cubit.state.previewEffects, const [vhs]);
        const added = EditorVideoEffect.custom(
          id: 'new',
          custom: CustomVideoEffect(
            id: echoVideoEffectId,
            params: {EditorVideoEffect.intensityParam: 0.6},
          ),
        );
        expect(cubit.confirm().effects, const [vhs, added]);
      });

      test('changes an edited effect in place and keeps its window', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs, vignette])
          ..startEditing(effectId: 'vhs')
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.oldFilm))
          ..setIntensity(0.9);
        addTearDown(cubit.close);

        expect(cubit.confirm().effects, const [
          EditorVideoEffect(
            id: 'vhs',
            effect: VideoEffect.oldFilm(
              intensity: 0.9,
              startTime: Duration(seconds: 1),
              endTime: Duration(seconds: 3),
            ),
          ),
          vignette,
        ]);
      });

      test('removes the edited effect for "none" and for zero intensity', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs, vignette])
          ..startEditing(effectId: 'vhs')
          ..selectType(null);
        addTearDown(cubit.close);
        expect(cubit.confirm().effects, const [vignette]);

        cubit
          ..startEditing(effectId: 'vignette')
          ..setIntensity(0);
        expect(cubit.confirm().effects, isEmpty);
        expect(cubit.state.applied, isEmpty);
      });

      test('lets a new flashing effect replace another one in its window, '
          'and says so', () {
        const negative = EditorVideoEffect(
          id: 'negative',
          effect: VideoEffect.negativeFlash(
            startTime: Duration(seconds: 1),
            endTime: Duration(seconds: 2),
          ),
        );
        final cubit = buildCubit()
          ..syncApplied(const [negative, vignette])
          ..startEditing()
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.strobe));
        addTearDown(cubit.close);

        final result = cubit.confirm();

        expect(result.replacedFlashing, isTrue);
        expect(result.effects.map((e) => e.id), ['vignette', 'new']);
        expect(cubit.state.applied, result.effects);
      });

      test('reports no replacement when nothing flashes on top', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs])
          ..startEditing()
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.strobe));
        addTearDown(cubit.close);

        expect(cubit.confirm().replacedFlashing, isFalse);
      });

      test('adds nothing when a new effect is left on "none"', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs])
          ..startEditing();
        addTearDown(cubit.close);

        expect(cubit.confirm().effects, const [vhs]);
      });
    });

    group('on the beat', () {
      final music = AudioEvent(
        id: 'music',
        pubkey: 'a' * 64,
        createdAt: 1735689600,
        url: '/tmp/music.mp3',
        duration: 30,
      );
      final mutedClip = DivineVideoClip(
        id: 'clip',
        video: EditorVideo.file('${Directory.systemTemp.path}/clip.mp4'),
        duration: const Duration(seconds: 6),
        recordedAt: DateTime(2026),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
        volume: 0,
      );

      /// A cubit whose music reads as a kick every half second, or fails to
      /// read with [failure].
      VideoEditorEffectsCubit buildWithMusic({
        List<AudioExtractConfigs>? reads,
        Exception? failure,
      }) => VideoEditorEffectsCubit(
        createId: () => 'new',
        beatResolver: VideoEditorBeatResolver(
          extractAudio: (configs) async {
            reads?.add(configs);
            if (failure != null) throw failure;
            return drumLoopWav(configs);
          },
        ),
      );

      Future<VideoEditorEffectsState> settled(VideoEditorEffectsCubit cubit) =>
          cubit.state.beatStatus == VideoEditorBeatStatus.loading
          ? cubit.stream.firstWhere(
              (state) => state.beatStatus != VideoEditorBeatStatus.loading,
            )
          : Future.value(cubit.state);

      test('commits onBeat only for an effect that can fire on the beat', () {
        final cubit = buildCubit()
          ..startEditing()
          ..selectType(
            const EditorEffectType.builtIn(VideoEffectType.zoomPulse),
          )
          ..setOnBeat(onBeat: true);
        expect(cubit.confirm().effects.single.onBeat, isTrue);

        cubit
          ..startEditing()
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.vignette))
          ..setOnBeat(onBeat: true);
        expect(cubit.confirm().effects.last.onBeat, isFalse);
      });

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'opens an effect on the beat with the switch on',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(
          applied: [
            EditorVideoEffect(
              id: 'zoom',
              effect: VideoEffect.zoomPulse(),
              onBeat: true,
            ),
          ],
        ),
        act: (cubit) => cubit.startEditing(effectId: 'zoom'),
        verify: (cubit) => expect(cubit.state.onBeat, isTrue),
      );

      test('finds the beats of the music once an effect needs them', () async {
        final reads = <AudioExtractConfigs>[];
        final cubit = buildWithMusic(reads: reads)
          ..syncBeatSource(sounds: [music], clips: [mutedClip]);
        expect(cubit.state.beatStatus, VideoEditorBeatStatus.idle);
        expect(reads, isEmpty);

        cubit
          ..startEditing()
          ..selectType(
            const EditorEffectType.builtIn(VideoEffectType.zoomPulse),
          )
          ..setOnBeat(onBeat: true);
        final state = await settled(cubit);

        expect(state.beatStatus, VideoEditorBeatStatus.ready);
        // A kick every half second of the six-second video.
        expect(state.beats.length, inInclusiveRange(11, 12));
        expect(reads, hasLength(1));
        await cubit.close();
      });

      test('says when nothing makes a sound or the music cannot be '
          'read', () async {
        final silent = buildWithMusic()
          ..syncBeatSource(sounds: const [], clips: [mutedClip])
          ..startEditing()
          ..selectType(
            const EditorEffectType.builtIn(VideoEffectType.zoomPulse),
          )
          ..setOnBeat(onBeat: true);
        expect(
          (await settled(silent)).beatStatus,
          VideoEditorBeatStatus.noSound,
        );

        final unreadable =
            buildWithMusic(failure: PlatformException(code: 'gone'))
              ..syncBeatSource(sounds: [music], clips: [mutedClip])
              ..startEditing()
              ..selectType(
                const EditorEffectType.builtIn(VideoEffectType.zoomPulse),
              )
              ..setOnBeat(onBeat: true);
        expect(
          (await settled(unreadable)).beatStatus,
          VideoEditorBeatStatus.failed,
        );
        await silent.close();
        await unreadable.close();
      });
    });
  });
}
