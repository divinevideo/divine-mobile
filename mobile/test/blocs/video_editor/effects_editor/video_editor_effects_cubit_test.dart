import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

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
          expect(cubit.state.selectedType, VideoEffectType.vhs);
          expect(cubit.state.intensity, 0.4);
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'opens a new effect on "none" at the default intensity',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(
          applied: [vhs],
          selectedType: VideoEffectType.glitch,
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
          expect(cubit.state.previewEffects, [vhs.effect]);
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
          ..selectType(VideoEffectType.pixelate)
          ..setIntensity(1.7),
        verify: (cubit) {
          expect(cubit.state.intensity, 1);
          expect(cubit.state.previewEffects, [
            const VideoEffect.pixelate(),
            vignette.effect,
          ]);
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'previews a new effect on top of the committed ones',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [vhs]),
        act: (cubit) => cubit
          ..startEditing()
          ..selectType(VideoEffectType.strobe),
        verify: (cubit) {
          expect(cubit.state.previewEffects, [
            vhs.effect,
            const VideoEffect.strobe(
              intensity: VideoEditorEffectsCubit.defaultIntensity,
            ),
          ]);
        },
      );

      blocTest<VideoEditorEffectsCubit, VideoEditorEffectsState>(
        'cancel goes back to previewing the committed effects',
        build: buildCubit,
        seed: () => const VideoEditorEffectsState(applied: [vhs]),
        act: (cubit) => cubit
          ..startEditing(effectId: 'vhs')
          ..selectType(VideoEffectType.glitch)
          ..cancel(),
        verify: (cubit) {
          expect(cubit.state.isEditing, isFalse);
          expect(cubit.state.editingId, isNull);
          expect(cubit.state.previewEffects, [vhs.effect]);
        },
      );
    });

    group('confirm', () {
      test('adds a new effect over the whole video after the others', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs])
          ..startEditing()
          ..selectType(VideoEffectType.glitch)
          ..setIntensity(0.5);
        addTearDown(cubit.close);

        const added = EditorVideoEffect(
          id: 'new',
          effect: VideoEffect.glitch(intensity: 0.5),
        );
        expect(cubit.confirm(), const [vhs, added]);
        expect(cubit.state.isEditing, isFalse);
        expect(cubit.state.applied, const [vhs, added]);
      });

      test('changes an edited effect in place and keeps its window', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs, vignette])
          ..startEditing(effectId: 'vhs')
          ..selectType(VideoEffectType.oldFilm)
          ..setIntensity(0.9);
        addTearDown(cubit.close);

        expect(cubit.confirm(), const [
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
        expect(cubit.confirm(), const [vignette]);

        cubit
          ..startEditing(effectId: 'vignette')
          ..setIntensity(0);
        expect(cubit.confirm(), isEmpty);
        expect(cubit.state.applied, isEmpty);
      });

      test('adds nothing when a new effect is left on "none"', () {
        final cubit = buildCubit()
          ..syncApplied(const [vhs])
          ..startEditing();
        addTearDown(cubit.close);

        expect(cubit.confirm(), const [vhs]);
      });
    });
  });
}
