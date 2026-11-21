import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';
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
        'previews a Time pick without the other Time effects, and keeps the '
        'rest',
        build: buildCubit,
        seed: () => VideoEditorEffectsState(
          applied: [
            EditorVideoEffect.of(
              id: 'echo',
              type: EditorEffectType.echo,
              intensity: 0.5,
            ),
            EditorVideoEffect.of(
              id: 'comic',
              type: EditorEffectType.comic,
              intensity: 0.5,
            ),
          ],
        ),
        act: (cubit) => cubit
          ..startEditing()
          ..selectType(EditorEffectType.motionOnly),
        verify: (cubit) {
          expect(
            [for (final e in cubit.state.previewCustomEffects) e.id],
            [comicVideoEffectId, motionOnlyVideoEffectId],
          );
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'previews picked lightning without the built-in flashing effects',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(
          applied: [
            EditorVideoEffect(id: 'strobe', effect: VideoEffect.strobe()),
            vignette,
          ],
        ),
        act: (cubit) => cubit
          ..startEditing()
          ..selectType(EditorEffectType.lightning),
        verify: (cubit) {
          expect(cubit.state.previewEffects, const [vignette]);
          expect(
            [for (final e in cubit.state.previewCustomEffects) e.id],
            [lightningVideoEffectId],
          );
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'previews a picked strobe without committed lightning, and keeps '
        'disco',
        build: buildCubit,
        seed: () => VideoEditorEffectsState(
          applied: [
            EditorVideoEffect.of(
              id: 'lightning',
              type: EditorEffectType.lightning,
              intensity: 0.7,
            ),
            EditorVideoEffect.of(
              id: 'disco',
              type: EditorEffectType.disco,
              intensity: 0.7,
            ),
          ],
        ),
        act: (cubit) => cubit
          ..startEditing()
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.strobe)),
        verify: (cubit) {
          expect(
            [for (final e in cubit.state.previewCustomEffects) e.id],
            [discoVideoEffectId],
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
        'feeds a newly picked echo to the native preview in place of the '
        'committed one it would replace, and keeps it out of the built-in '
        'preview',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [vhs, echo]),
        act: (cubit) => cubit
          ..startEditing()
          ..selectType(EditorEffectType.echo)
          ..setIntensity(0.8),
        verify: (cubit) {
          expect(cubit.state.previewCustomEffects, const [
            CustomVideoEffect(
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

      test('removes an edited effect dialed down to no intensity', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs, vignette])
          ..startEditing(effectId: 'vhs')
          ..setIntensity(0);
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

        expect(result.replaced, EditorEffectExclusiveGroup.flashing);
        expect(result.effects.map((e) => e.id), ['vignette', 'new']);
        expect(cubit.state.applied, result.effects);
      });

      test('reports no replacement when nothing flashes on top', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs])
          ..startEditing()
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.strobe));
        addTearDown(cubit.close);

        expect(cubit.confirm().replaced, isNull);
      });

      test('lets a new Time effect replace another one in its window, and '
          'says so', () {
        final echo = EditorVideoEffect.of(
          id: 'echo',
          type: EditorEffectType.echo,
          intensity: 0.5,
        );
        final cubit = buildCubit()
          ..syncApplied([echo, vignette])
          ..startEditing()
          ..selectType(EditorEffectType.timeWarp);
        addTearDown(cubit.close);

        final result = cubit.confirm();

        expect(result.replaced, EditorEffectExclusiveGroup.earlierFrames);
        expect(result.effects.map((e) => e.id), ['vignette', 'new']);
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

      test('commits the zoom blur on the beat as a custom effect', () {
        final cubit = buildCubit()
          ..startEditing()
          ..selectType(EditorEffectType.zoomBlur)
          ..setOnBeat(onBeat: true);

        final committed = cubit.confirm().effects.single;

        expect(committed.custom?.id, zoomBlurVideoEffectId);
        expect(committed.onBeat, isTrue);
        expect(cubit.state.needsBeats, isTrue);
      });

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'opens a zoom blur on the beat with the switch on',
        build: buildCubit,
        seed: () => VideoEditorEffectsState(
          applied: [
            EditorVideoEffect.of(
              id: 'zoom',
              type: EditorEffectType.zoomBlur,
              intensity: 0.6,
              onBeat: true,
            ),
          ],
        ),
        act: (cubit) => cubit.startEditing(effectId: 'zoom'),
        verify: (cubit) {
          expect(cubit.state.selectedType, EditorEffectType.zoomBlur);
          expect(cubit.state.onBeat, isTrue);
          expect(cubit.state.selectionOnBeat, isTrue);
        },
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

    group('drops settings', () {
      const custom = DropsEffectSettings(count: 2, size: 0.8, seed: 9);
      final committed = EditorVideoEffect.custom(
        id: 'drops',
        custom: CustomVideoEffect(
          id: dropsVideoEffectId,
          params: {
            ...custom.toParams(),
            EditorVideoEffect.intensityParam: 0.6,
          },
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 2),
        ),
      );

      test('a new drops effect stores the default settings next to its '
          'intensity', () async {
        final cubit = buildCubit()
          ..startEditing()
          ..selectType(EditorEffectType.drops);

        final result = cubit.confirm();

        expect(result.effects.single.custom!.params, {
          ...const DropsEffectSettings().toParams(),
          EditorVideoEffect.intensityParam:
              VideoEditorEffectsCubit.defaultIntensity,
        });
        await cubit.close();
      });

      test(
        'the picked drops show their settings in the native preview',
        () async {
          final cubit = buildCubit()
            ..startEditing()
            ..selectType(EditorEffectType.drops)
            ..setDropsSettings(custom);

          final preview = cubit.state.previewCustomEffects.single;

          expect(preview.id, dropsVideoEffectId);
          expect(DropsEffectSettings.fromParams(preview.params), custom);
          await cubit.close();
        },
      );

      test('editing committed drops starts from their settings and keeps '
          'them, and their window, on confirm', () async {
        final cubit = buildCubit()
          ..syncApplied([committed])
          ..startEditing(effectId: 'drops');
        expect(cubit.state.dropsSettings, custom);

        cubit.setIntensity(0.9);
        final edited = cubit.confirm().effects.single;

        expect(DropsEffectSettings.fromParams(edited.custom!.params), custom);
        expect(edited.intensity, 0.9);
        expect(edited.startTime, const Duration(seconds: 1));
        expect(edited.endTime, const Duration(seconds: 2));
        await cubit.close();
      });

      test('a new effect starts from the default settings again', () async {
        final cubit = buildCubit()
          ..syncApplied([committed])
          ..startEditing(effectId: 'drops');
        expect(cubit.state.dropsSettings, custom);

        cubit
          ..cancel()
          ..startEditing();

        expect(cubit.state.dropsSettings, const DropsEffectSettings());
        await cubit.close();
      });

      test('other effects store none of the drops settings', () async {
        final cubit = buildCubit()
          ..startEditing()
          ..selectType(EditorEffectType.echo)
          ..setDropsSettings(custom);

        expect(cubit.confirm().effects.single.custom!.params, {
          EditorVideoEffect.intensityParam:
              VideoEditorEffectsCubit.defaultIntensity,
        });
        await cubit.close();
      });

      test('shuffleDrops picks a seed other than the current one', () async {
        final seeds = [9, 9, 4];
        final cubit =
            VideoEditorEffectsCubit(
                createId: () => 'new',
                createSeed: () => seeds.removeAt(0),
              )
              ..startEditing()
              ..selectType(EditorEffectType.drops)
              ..setDropsSettings(custom);

        cubit.shuffleDrops();

        expect(cubit.state.dropsSettings, custom.copyWith(seed: 4));
        await cubit.close();
      });
    });

    group('intros and outros', () {
      const videoEnd = Duration(seconds: 6);
      const editorState = VideoEditorEffectsState(timelineEnd: videoEnd);

      VideoEditorEffectsCubit editing({
        List<EditorVideoEffect> applied = const [],
        String? effectId,
      }) {
        final cubit = VideoEditorEffectsCubit(createId: () => 'new')
          ..emit(editorState.copyWith(applied: applied))
          ..startEditing(effectId: effectId);
        addTearDown(cubit.close);
        return cubit;
      }

      EditorVideoEffect introOutro(
        String id,
        EditorEffectType type, {
        double? intensity,
        Duration? startTime,
        Duration? endTime,
      }) => EditorVideoEffect.of(
        id: id,
        type: type,
        intensity: intensity ?? type.introOutroLook!.startingIntensity,
        startTime: startTime,
        endTime: endTime,
      );

      test('learns where the video ends on the editor timeline from its '
          'clips', () {
        DivineVideoClip clip(String id, {ClipTransition? transition}) =>
            DivineVideoClip(
              id: id,
              video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
              duration: const Duration(seconds: 2),
              recordedAt: DateTime(2026),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
              transition: transition,
            );
        // The dissolve overlaps the clips, so the exported video ends half a
        // second before the editor timeline does.
        final cubit = buildCubit()
          ..syncBeatSource(
            sounds: const [],
            clips: [
              clip(
                'a',
                transition: const ClipTransition(
                  type: ClipTransitionType.dissolve,
                ),
              ),
              clip('b'),
            ],
          );
        addTearDown(cubit.close);

        expect(cubit.state.timelineEnd, const Duration(seconds: 4));
      });

      test("adds a new intro over the first second, at its look's starting "
          'structure', () {
        final cubit = editing()..selectType(EditorEffectType.introCircle);

        expect(
          cubit.state.intensity,
          IntroOutroLook.circle.startingIntensity,
        );
        expect(cubit.confirm().effects, [
          introOutro(
            'new',
            EditorEffectType.introCircle,
            startTime: Duration.zero,
            endTime: const Duration(seconds: 1),
          ),
        ]);
      });

      test('adds a new outro over the last second, open to the end', () {
        final cubit = editing(applied: const [vignette])
          ..selectType(EditorEffectType.outroFade);

        expect(cubit.confirm().effects, [
          vignette,
          introOutro(
            'new',
            EditorEffectType.outroFade,
            startTime: const Duration(seconds: 5),
          ),
        ]);
      });

      test('previews a picked intro where it goes, not over the whole '
          'video', () {
        final cubit = editing(applied: const [echo])
          ..selectType(EditorEffectType.introFocus);

        expect(cubit.state.previewCustomEffects, [
          echo.custom,
          introOutro(
            'picked',
            EditorEffectType.introFocus,
            startTime: Duration.zero,
            endTime: const Duration(seconds: 1),
          ).custom,
        ]);
      });

      test('keeps the structure switching between the intro and the outro '
          'of a look, starts any other look or effect fresh, and restores '
          'what one was left at', () {
        final cubit = editing()
          ..selectType(EditorEffectType.introCurtain)
          ..setIntensity(0.9)
          ..selectType(EditorEffectType.outroCurtain);
        expect(cubit.state.intensity, 0.9);

        cubit.selectType(EditorEffectType.outroFocus);
        expect(cubit.state.intensity, IntroOutroLook.focus.startingIntensity);

        cubit.selectType(EditorEffectType.snow);
        expect(cubit.state.intensity, VideoEditorEffectsCubit.defaultIntensity);

        cubit
          ..setIntensity(0.2)
          ..selectType(EditorEffectType.outroCinema);
        expect(cubit.state.intensity, IntroOutroLook.cinema.startingIntensity);

        cubit.selectType(const EditorEffectType.builtIn(VideoEffectType.vhs));
        expect(cubit.state.intensity, 0.2);

        cubit.selectType(EditorEffectType.introCurtain);
        expect(cubit.state.intensity, 0.9);
      });

      test('brings an edited intro or outro back to its own structure after '
          'trying other effects', () {
        final cubit =
            editing(
                applied: [
                  introOutro(
                    'outro',
                    EditorEffectType.outroFade,
                    intensity: 1,
                    startTime: const Duration(seconds: 5),
                  ),
                ],
                effectId: 'outro',
              )
              ..selectType(EditorEffectType.outroCircle)
              ..selectType(EditorEffectType.outroFade);

        expect(cubit.state.intensity, 1);
      });

      test('adds an intro at no intensity, which is a structure of its '
          'look, and keeps an edited one dialed down to it', () {
        final added = editing()
          ..selectType(EditorEffectType.introFade)
          ..setIntensity(0);
        expect(added.confirm().effects.single.intensity, 0);

        final edited = editing(
          applied: [
            introOutro(
              'outro',
              EditorEffectType.outroCircle,
              intensity: 0.8,
              startTime: const Duration(seconds: 5),
            ),
          ],
          effectId: 'outro',
        )..setIntensity(0);
        expect(edited.confirm().effects, [
          introOutro(
            'outro',
            EditorEffectType.outroCircle,
            intensity: 0,
            startTime: const Duration(seconds: 5),
          ),
        ]);
      });

      test('keeps the trimmed window of an intro switched to another '
          'intro', () {
        final trimmed = introOutro(
          'intro',
          EditorEffectType.introFade,
          startTime: Duration.zero,
          endTime: const Duration(milliseconds: 2500),
        );
        final cubit = editing(applied: [trimmed], effectId: 'intro')
          ..selectType(EditorEffectType.introCinema);

        // The preview already shows it there, in the middle of its window.
        expect(
          cubit.state.introOutroPreviewPosition(playing: false),
          const Duration(milliseconds: 1250),
        );
        expect(cubit.confirm().effects, [
          introOutro(
            'intro',
            EditorEffectType.introCinema,
            startTime: Duration.zero,
            endTime: const Duration(milliseconds: 2500),
          ),
        ]);
      });

      test('moves an intro switched to an outro to the end of the '
          'video', () {
        final intro = introOutro(
          'intro',
          EditorEffectType.introFade,
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        );
        final cubit = editing(applied: [intro], effectId: 'intro')
          ..selectType(EditorEffectType.outroFade);

        expect(cubit.confirm().effects, [
          introOutro(
            'intro',
            EditorEffectType.outroFade,
            startTime: const Duration(seconds: 5),
          ),
        ]);
      });

      test('places an effect over the whole video switched to an intro as '
          'a new intro, and an intro switched back over the whole video', () {
        final toIntro = editing(applied: const [echo], effectId: 'echo')
          ..selectType(EditorEffectType.introCurtain);
        expect(toIntro.confirm().effects.single.startTime, Duration.zero);
        expect(
          toIntro.state.applied.single.endTime,
          const Duration(seconds: 1),
        );

        final intro = introOutro(
          'intro',
          EditorEffectType.introCurtain,
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        );
        final toWhole = editing(applied: [intro], effectId: 'intro')
          ..selectType(EditorEffectType.snow);
        final whole = toWhole.confirm().effects.single;
        expect(whole.type, EditorEffectType.snow);
        expect(whole.startTime, isNull);
        expect(whole.endTime, isNull);
      });

      group('introOutroPreviewPosition', () {
        test('is the start of a picked intro while the video plays', () {
          final cubit = editing()..selectType(EditorEffectType.introFade);

          expect(
            cubit.state.introOutroPreviewPosition(playing: true),
            Duration.zero,
          );
        });

        test('is a second before a picked outro while the video plays', () {
          final cubit = editing()..selectType(EditorEffectType.outroFade);

          expect(
            cubit.state.introOutroPreviewPosition(playing: true),
            const Duration(seconds: 4),
          );
        });

        test('is the middle of its window while the video is paused', () {
          final cubit = editing()..selectType(EditorEffectType.outroCircle);

          expect(
            cubit.state.introOutroPreviewPosition(playing: false),
            const Duration(milliseconds: 5500),
          );
        });

        test('is null for an effect over the whole video, or none', () {
          final cubit = editing();
          expect(cubit.state.introOutroPreviewPosition(playing: true), isNull);

          cubit.selectType(EditorEffectType.snow);
          expect(cubit.state.introOutroPreviewPosition(playing: true), isNull);
        });
      });
    });
  });
}
