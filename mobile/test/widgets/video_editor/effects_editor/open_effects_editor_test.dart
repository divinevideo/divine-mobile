import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/widgets/video_editor/effects_editor/open_effects_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

void main() {
  group('openEffectsEditor', () {
    late _MockVideoEditorMainBloc mainBloc;
    late VideoEditorEffectsCubit effectsCubit;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      effectsCubit = VideoEditorEffectsCubit();
      addTearDown(effectsCubit.close);
    });

    test('opens the editor and starts a paused video', () {
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

      openEffectsEditor(mainBloc, effectsCubit, reduceMotion: false);

      expect(effectsCubit.state.isEditing, isTrue);
      expect(effectsCubit.state.startedPlayback, isTrue);
      verifyInOrder([
        () => mainBloc.add(
          const VideoEditorMainOpenSubEditor(SubEditorType.effects),
        ),
        () => mainBloc.add(const VideoEditorPlaybackToggleRequested()),
      ]);
    });

    test('leaves a playing video playing', () {
      when(
        () => mainBloc.state,
      ).thenReturn(const VideoEditorMainState(isPlaying: true));

      openEffectsEditor(mainBloc, effectsCubit, reduceMotion: false);

      expect(effectsCubit.state.startedPlayback, isFalse);
      verifyNever(
        () => mainBloc.add(const VideoEditorPlaybackToggleRequested()),
      );
    });

    test('leaves a paused video paused when reduced motion is on', () {
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

      openEffectsEditor(mainBloc, effectsCubit, reduceMotion: true);

      expect(effectsCubit.state.isEditing, isTrue);
      expect(effectsCubit.state.startedPlayback, isFalse);
      verifyNever(
        () => mainBloc.add(const VideoEditorPlaybackToggleRequested()),
      );
    });

    test('opens on the given effect', () {
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
      effectsCubit.syncApplied(const [
        EditorVideoEffect(id: 'strobe', effect: VideoEffect.strobe()),
      ]);

      openEffectsEditor(
        mainBloc,
        effectsCubit,
        reduceMotion: false,
        effectId: 'strobe',
      );

      expect(effectsCubit.state.editingId, 'strobe');
      expect(effectsCubit.state.selectedType?.builtIn, VideoEffectType.strobe);
    });
  });

  group('pausePlaybackStartedByEffectsEditor', () {
    late _MockVideoEditorMainBloc mainBloc;
    late VideoEditorEffectsCubit effectsCubit;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      effectsCubit = VideoEditorEffectsCubit();
      addTearDown(effectsCubit.close);
      when(
        () => mainBloc.state,
      ).thenReturn(const VideoEditorMainState(isPlaying: true));
    });

    test('pauses a video the editor started', () {
      effectsCubit.startEditing(startedPlayback: true);

      pausePlaybackStartedByEffectsEditor(mainBloc, effectsCubit);

      verify(
        () => mainBloc.add(const VideoEditorPlaybackToggleRequested()),
      ).called(1);
    });

    test('leaves a video playing that was already playing', () {
      effectsCubit.startEditing();

      pausePlaybackStartedByEffectsEditor(mainBloc, effectsCubit);

      verifyNever(
        () => mainBloc.add(const VideoEditorPlaybackToggleRequested()),
      );
    });

    test('leaves a video paused that the user paused in the editor', () {
      effectsCubit.startEditing(startedPlayback: true);
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

      pausePlaybackStartedByEffectsEditor(mainBloc, effectsCubit);

      verifyNever(
        () => mainBloc.add(const VideoEditorPlaybackToggleRequested()),
      );
    });
  });
}
