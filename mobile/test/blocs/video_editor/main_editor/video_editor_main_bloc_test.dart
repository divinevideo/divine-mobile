// ABOUTME: Tests for VideoEditorMainBloc - main editor state management.
// ABOUTME: Covers all 18 event handlers, state transitions, and edge cases.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';

void main() {
  group(VideoEditorMainBloc, () {
    VideoEditorMainBloc buildBloc() => VideoEditorMainBloc();

    test('initial state has correct defaults', () {
      final bloc = buildBloc();
      expect(bloc.state.canUndo, isFalse);
      expect(bloc.state.canRedo, isFalse);
      expect(bloc.state.openSubEditor, isNull);
      expect(bloc.state.isSubEditorOpen, isFalse);
      expect(bloc.state.isLayerInteractionActive, isFalse);
      expect(bloc.state.isLayerOverRemoveArea, isFalse);
      expect(bloc.state.isPlaying, isFalse);
      expect(bloc.state.isPlayerReady, isFalse);
      expect(bloc.state.isExternalPauseRequested, isFalse);
      expect(bloc.state.playbackRestartCounter, equals(0));
      expect(bloc.state.playbackToggleCounter, equals(0));
      expect(bloc.state.seekPosition, equals(Duration.zero));
      expect(bloc.state.seekCounter, equals(0));
      expect(bloc.state.currentPosition, equals(Duration.zero));
      expect(bloc.state.totalDuration, equals(Duration.zero));
      expect(bloc.state.isVolumeEditMode, isFalse);
      expect(bloc.state.isReordering, isFalse);
      expect(bloc.state.isMarkerMode, isFalse);
      bloc.close();
    });

    group(VideoEditorMainCapabilitiesChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with updated canUndo and canRedo',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorMainCapabilitiesChanged(
            canUndo: true,
            canRedo: true,
          ),
        ),
        expect: () => [
          isA<VideoEditorMainState>()
              .having((s) => s.canUndo, 'canUndo', isTrue)
              .having((s) => s.canRedo, 'canRedo', isTrue),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with updated capabilities when layers are provided',
        build: buildBloc,
        act: (bloc) {
          bloc.add(
            const VideoEditorMainCapabilitiesChanged(
              canUndo: false,
              canRedo: false,
              layers: [],
            ),
          );
        },
        expect: () => [
          isA<VideoEditorMainState>()
              .having((s) => s.canUndo, 'canUndo', isFalse)
              .having((s) => s.canRedo, 'canRedo', isFalse),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'preserves unrelated fields when layers param is null',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isPlaying: true),
        act: (bloc) => bloc.add(
          const VideoEditorMainCapabilitiesChanged(
            canUndo: true,
            canRedo: false,
          ),
        ),
        expect: () => [
          isA<VideoEditorMainState>()
              .having((s) => s.canUndo, 'canUndo', isTrue)
              .having((s) => s.isPlaying, 'isPlaying', isTrue),
        ],
      );
    });

    group(VideoEditorLayerInteractionStarted, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isLayerInteractionActive true',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorLayerInteractionStarted()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isLayerInteractionActive,
            'isLayerInteractionActive',
            isTrue,
          ),
        ],
      );
    });

    group(VideoEditorLayerInteractionEnded, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isLayerInteractionActive false '
        'and isLayerOverRemoveArea false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(
          isLayerInteractionActive: true,
          isLayerOverRemoveArea: true,
        ),
        act: (bloc) => bloc.add(const VideoEditorLayerInteractionEnded()),
        expect: () => [
          isA<VideoEditorMainState>()
              .having(
                (s) => s.isLayerInteractionActive,
                'isLayerInteractionActive',
                isFalse,
              )
              .having(
                (s) => s.isLayerOverRemoveArea,
                'isLayerOverRemoveArea',
                isFalse,
              ),
        ],
      );
    });

    group(VideoEditorLayerOverRemoveAreaChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isLayerOverRemoveArea true',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorLayerOverRemoveAreaChanged(isOver: true)),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isLayerOverRemoveArea,
            'isLayerOverRemoveArea',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'does not emit when value has not changed',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isLayerOverRemoveArea: true),
        act: (bloc) =>
            bloc.add(const VideoEditorLayerOverRemoveAreaChanged(isOver: true)),
        expect: () => <VideoEditorMainState>[],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits when value changes from true to false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isLayerOverRemoveArea: true),
        act: (bloc) => bloc.add(
          const VideoEditorLayerOverRemoveAreaChanged(isOver: false),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isLayerOverRemoveArea,
            'isLayerOverRemoveArea',
            isFalse,
          ),
        ],
      );
    });

    group(VideoEditorMainOpenSubEditor, () {
      for (final type in SubEditorType.values) {
        blocTest<VideoEditorMainBloc, VideoEditorMainState>(
          'emits state with openSubEditor set to ${type.name}',
          build: buildBloc,
          act: (bloc) => bloc.add(VideoEditorMainOpenSubEditor(type)),
          expect: () => [
            isA<VideoEditorMainState>()
                .having((s) => s.openSubEditor, 'openSubEditor', type)
                .having((s) => s.isSubEditorOpen, 'isSubEditorOpen', isTrue),
          ],
        );
      }
    });

    group(VideoEditorMainSubEditorClosed, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with openSubEditor cleared',
        build: buildBloc,
        seed: () =>
            const VideoEditorMainState(openSubEditor: SubEditorType.text),
        act: (bloc) => bloc.add(const VideoEditorMainSubEditorClosed()),
        expect: () => [
          isA<VideoEditorMainState>()
              .having((s) => s.openSubEditor, 'openSubEditor', isNull)
              .having((s) => s.isSubEditorOpen, 'isSubEditorOpen', isFalse),
        ],
      );
    });

    group(VideoEditorPlaybackChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isPlaying true',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorPlaybackChanged(isPlaying: true)),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isPlaying false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isPlaying: true),
        act: (bloc) =>
            bloc.add(const VideoEditorPlaybackChanged(isPlaying: false)),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isFalse,
          ),
        ],
      );
    });

    group(VideoEditorPlayerReady, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isPlayerReady true',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorPlayerReady()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isPlayerReady,
            'isPlayerReady',
            isTrue,
          ),
        ],
      );
    });

    group(VideoEditorExternalPauseRequested, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isExternalPauseRequested true',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorExternalPauseRequested(isPaused: true)),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isExternalPauseRequested,
            'isExternalPauseRequested',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isExternalPauseRequested false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isExternalPauseRequested: true),
        act: (bloc) =>
            bloc.add(const VideoEditorExternalPauseRequested(isPaused: false)),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isExternalPauseRequested,
            'isExternalPauseRequested',
            isFalse,
          ),
        ],
      );
    });

    group(VideoEditorPlaybackRestartRequested, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'increments playbackRestartCounter',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorPlaybackRestartRequested()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.playbackRestartCounter,
            'playbackRestartCounter',
            equals(1),
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'increments from existing counter value',
        build: buildBloc,
        seed: () => const VideoEditorMainState(playbackRestartCounter: 5),
        act: (bloc) => bloc.add(const VideoEditorPlaybackRestartRequested()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.playbackRestartCounter,
            'playbackRestartCounter',
            equals(6),
          ),
        ],
      );
    });

    group(VideoEditorPlaybackToggleRequested, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'increments playbackToggleCounter',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorPlaybackToggleRequested()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.playbackToggleCounter,
            'playbackToggleCounter',
            equals(1),
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'increments from existing counter value',
        build: buildBloc,
        seed: () => const VideoEditorMainState(playbackToggleCounter: 3),
        act: (bloc) => bloc.add(const VideoEditorPlaybackToggleRequested()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.playbackToggleCounter,
            'playbackToggleCounter',
            equals(4),
          ),
        ],
      );
    });

    group(VideoEditorSeekRequested, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with seekPosition and increments seekCounter',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorSeekRequested(Duration(seconds: 5))),
        expect: () => [
          isA<VideoEditorMainState>()
              .having(
                (s) => s.seekPosition,
                'seekPosition',
                equals(const Duration(seconds: 5)),
              )
              .having((s) => s.seekCounter, 'seekCounter', equals(1)),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'increments seekCounter from existing value',
        build: buildBloc,
        seed: () => const VideoEditorMainState(
          seekPosition: Duration(seconds: 2),
          seekCounter: 5,
        ),
        act: (bloc) =>
            bloc.add(const VideoEditorSeekRequested(Duration(seconds: 10))),
        expect: () => [
          isA<VideoEditorMainState>()
              .having(
                (s) => s.seekPosition,
                'seekPosition',
                equals(const Duration(seconds: 10)),
              )
              .having((s) => s.seekCounter, 'seekCounter', equals(6)),
        ],
      );
    });

    group(VideoEditorPositionChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with updated currentPosition',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorPositionChanged(Duration(milliseconds: 1500)),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.currentPosition,
            'currentPosition',
            equals(const Duration(milliseconds: 1500)),
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'updates currentPosition from existing value',
        build: buildBloc,
        seed: () =>
            const VideoEditorMainState(currentPosition: Duration(seconds: 1)),
        act: (bloc) =>
            bloc.add(const VideoEditorPositionChanged(Duration(seconds: 3))),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.currentPosition,
            'currentPosition',
            equals(const Duration(seconds: 3)),
          ),
        ],
      );
    });

    group(VideoEditorDurationChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with updated totalDuration',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorDurationChanged(Duration(seconds: 30))),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.totalDuration,
            'totalDuration',
            equals(const Duration(seconds: 30)),
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'updates totalDuration from existing value',
        build: buildBloc,
        seed: () =>
            const VideoEditorMainState(totalDuration: Duration(seconds: 10)),
        act: (bloc) =>
            bloc.add(const VideoEditorDurationChanged(Duration(seconds: 60))),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.totalDuration,
            'totalDuration',
            equals(const Duration(seconds: 60)),
          ),
        ],
      );
    });

    group(VideoEditorVolumeEditModeToggled, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'toggles isVolumeEditMode from false to true',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorVolumeEditModeToggled()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isVolumeEditMode,
            'isVolumeEditMode',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'toggles isVolumeEditMode from true to false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isVolumeEditMode: true),
        act: (bloc) => bloc.add(const VideoEditorVolumeEditModeToggled()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isVolumeEditMode,
            'isVolumeEditMode',
            isFalse,
          ),
        ],
      );
    });

    group(VideoEditorMarkerModeChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'enters marker mode when isActive is true',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorMarkerModeChanged(isActive: true)),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isMarkerMode,
            'isMarkerMode',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'leaves marker mode when isActive is false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isMarkerMode: true),
        act: (bloc) =>
            bloc.add(const VideoEditorMarkerModeChanged(isActive: false)),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isMarkerMode,
            'isMarkerMode',
            isFalse,
          ),
        ],
      );
    });

    group(VideoEditorSlidePointPlacementChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'hands the screen to the canvas when placement starts',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorSlidePointPlacementChanged(isPlacing: true),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isPlacingSlidePoint,
            'isPlacingSlidePoint',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'gives the screen back when placement ends',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isPlacingSlidePoint: true),
        act: (bloc) => bloc.add(
          const VideoEditorSlidePointPlacementChanged(isPlacing: false),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isPlacingSlidePoint,
            'isPlacingSlidePoint',
            isFalse,
          ),
        ],
      );

      // The picker pauses playback through its own event, so entering
      // placement must not disturb anything else the editor is doing.
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'leaves the rest of the editor state alone',
        build: buildBloc,
        seed: () => const VideoEditorMainState(
          canUndo: true,
          isPlaying: true,
          isMarkerMode: true,
        ),
        act: (bloc) => bloc.add(
          const VideoEditorSlidePointPlacementChanged(isPlacing: true),
        ),
        expect: () => [
          const VideoEditorMainState(
            canUndo: true,
            isPlaying: true,
            isMarkerMode: true,
            isPlacingSlidePoint: true,
          ),
        ],
      );
    });

    group(VideoEditorReorderingChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isReordering true',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorReorderingChanged(isReordering: true)),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isReordering,
            'isReordering',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isReordering false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isReordering: true),
        act: (bloc) =>
            bloc.add(const VideoEditorReorderingChanged(isReordering: false)),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isReordering,
            'isReordering',
            isFalse,
          ),
        ],
      );
    });
  });

  group('$VideoEditorMainState', () {
    test('isSubEditorOpen returns true when openSubEditor is set', () {
      const state = VideoEditorMainState(openSubEditor: SubEditorType.draw);
      expect(state.isSubEditorOpen, isTrue);
    });

    test('isSubEditorOpen returns false when openSubEditor is null', () {
      const state = VideoEditorMainState();
      expect(state.isSubEditorOpen, isFalse);
    });

    test('copyWith preserves all fields by default', () {
      const original = VideoEditorMainState(
        canUndo: true,
        canRedo: true,
        openSubEditor: SubEditorType.text,
        isLayerInteractionActive: true,
        isLayerOverRemoveArea: true,
        isPlaying: true,
        isPlayerReady: true,
        isExternalPauseRequested: true,
        playbackRestartCounter: 5,
        playbackToggleCounter: 3,
        seekPosition: Duration(seconds: 7),
        seekCounter: 2,
        currentPosition: Duration(seconds: 4),
        totalDuration: Duration(seconds: 30),
        isVolumeEditMode: true,
        isReordering: true,
      );

      final copy = original.copyWith();

      expect(copy.canUndo, isTrue);
      expect(copy.canRedo, isTrue);
      expect(copy.openSubEditor, SubEditorType.text);
      expect(copy.isLayerInteractionActive, isTrue);
      expect(copy.isLayerOverRemoveArea, isTrue);
      expect(copy.isPlaying, isTrue);
      expect(copy.isPlayerReady, isTrue);
      expect(copy.isExternalPauseRequested, isTrue);
      expect(copy.playbackRestartCounter, equals(5));
      expect(copy.playbackToggleCounter, equals(3));
      expect(copy.seekPosition, equals(const Duration(seconds: 7)));
      expect(copy.seekCounter, equals(2));
      expect(copy.currentPosition, equals(const Duration(seconds: 4)));
      expect(copy.totalDuration, equals(const Duration(seconds: 30)));
      expect(copy.isVolumeEditMode, isTrue);
      expect(copy.isReordering, isTrue);
    });

    test('copyWith with clearOpenSubEditor sets openSubEditor to null', () {
      const original = VideoEditorMainState(
        openSubEditor: SubEditorType.filter,
      );

      final copy = original.copyWith(clearOpenSubEditor: true);

      expect(copy.openSubEditor, isNull);
    });

    test('supports value equality', () {
      const state1 = VideoEditorMainState(canUndo: true);
      const state2 = VideoEditorMainState(canUndo: true);
      expect(state1, equals(state2));
    });

    test('different states are not equal', () {
      const state1 = VideoEditorMainState(canUndo: true);
      const state2 = VideoEditorMainState(canRedo: true);
      expect(state1, isNot(equals(state2)));
    });
  });

  group('$VideoEditorMainEvent equality', () {
    test('$VideoEditorMainCapabilitiesChanged with same props are equal', () {
      const event1 = VideoEditorMainCapabilitiesChanged(
        canUndo: true,
        canRedo: false,
      );
      const event2 = VideoEditorMainCapabilitiesChanged(
        canUndo: true,
        canRedo: false,
      );
      expect(event1, equals(event2));
    });

    test('$VideoEditorMainCapabilitiesChanged with different props '
        'are not equal', () {
      const event1 = VideoEditorMainCapabilitiesChanged(
        canUndo: true,
        canRedo: false,
      );
      const event2 = VideoEditorMainCapabilitiesChanged(
        canUndo: false,
        canRedo: true,
      );
      expect(event1, isNot(equals(event2)));
    });

    test('$VideoEditorLayerInteractionStarted events are equal', () {
      const event1 = VideoEditorLayerInteractionStarted();
      const event2 = VideoEditorLayerInteractionStarted();
      expect(event1, equals(event2));
    });

    test('$VideoEditorLayerInteractionEnded events are equal', () {
      const event1 = VideoEditorLayerInteractionEnded();
      const event2 = VideoEditorLayerInteractionEnded();
      expect(event1, equals(event2));
    });

    test(
      '$VideoEditorLayerOverRemoveAreaChanged with same isOver are equal',
      () {
        const event1 = VideoEditorLayerOverRemoveAreaChanged(isOver: true);
        const event2 = VideoEditorLayerOverRemoveAreaChanged(isOver: true);
        expect(event1, equals(event2));
      },
    );

    test('$VideoEditorLayerOverRemoveAreaChanged with different isOver '
        'are not equal', () {
      const event1 = VideoEditorLayerOverRemoveAreaChanged(isOver: true);
      const event2 = VideoEditorLayerOverRemoveAreaChanged(isOver: false);
      expect(event1, isNot(equals(event2)));
    });

    test('$VideoEditorMainOpenSubEditor with same type are equal', () {
      const event1 = VideoEditorMainOpenSubEditor(SubEditorType.text);
      const event2 = VideoEditorMainOpenSubEditor(SubEditorType.text);
      expect(event1, equals(event2));
    });

    test(
      '$VideoEditorMainOpenSubEditor with different types are not equal',
      () {
        const event1 = VideoEditorMainOpenSubEditor(SubEditorType.text);
        const event2 = VideoEditorMainOpenSubEditor(SubEditorType.draw);
        expect(event1, isNot(equals(event2)));
      },
    );

    test('$VideoEditorMainSubEditorClosed events are equal', () {
      const event1 = VideoEditorMainSubEditorClosed();
      const event2 = VideoEditorMainSubEditorClosed();
      expect(event1, equals(event2));
    });

    test('$VideoEditorPlaybackChanged with same isPlaying are equal', () {
      const event1 = VideoEditorPlaybackChanged(isPlaying: true);
      const event2 = VideoEditorPlaybackChanged(isPlaying: true);
      expect(event1, equals(event2));
    });

    test(
      '$VideoEditorPlaybackChanged with different isPlaying are not equal',
      () {
        const event1 = VideoEditorPlaybackChanged(isPlaying: true);
        const event2 = VideoEditorPlaybackChanged(isPlaying: false);
        expect(event1, isNot(equals(event2)));
      },
    );

    test('$VideoEditorPlayerReady events are equal', () {
      const event1 = VideoEditorPlayerReady();
      const event2 = VideoEditorPlayerReady();
      expect(event1, equals(event2));
    });

    test('$VideoEditorExternalPauseRequested with same isPaused are equal', () {
      const event1 = VideoEditorExternalPauseRequested(isPaused: true);
      const event2 = VideoEditorExternalPauseRequested(isPaused: true);
      expect(event1, equals(event2));
    });

    test('$VideoEditorExternalPauseRequested with different isPaused '
        'are not equal', () {
      const event1 = VideoEditorExternalPauseRequested(isPaused: true);
      const event2 = VideoEditorExternalPauseRequested(isPaused: false);
      expect(event1, isNot(equals(event2)));
    });

    test('$VideoEditorPlaybackRestartRequested events are equal', () {
      const event1 = VideoEditorPlaybackRestartRequested();
      const event2 = VideoEditorPlaybackRestartRequested();
      expect(event1, equals(event2));
    });

    test('$VideoEditorPlaybackToggleRequested events are equal', () {
      const event1 = VideoEditorPlaybackToggleRequested();
      const event2 = VideoEditorPlaybackToggleRequested();
      expect(event1, equals(event2));
    });

    test('$VideoEditorSeekRequested with same position are equal', () {
      const event1 = VideoEditorSeekRequested(Duration(seconds: 5));
      const event2 = VideoEditorSeekRequested(Duration(seconds: 5));
      expect(event1, equals(event2));
    });

    test('$VideoEditorSeekRequested with different positions '
        'are not equal', () {
      const event1 = VideoEditorSeekRequested(Duration(seconds: 5));
      const event2 = VideoEditorSeekRequested(Duration(seconds: 10));
      expect(event1, isNot(equals(event2)));
    });

    test('$VideoEditorPositionChanged with same position are equal', () {
      const event1 = VideoEditorPositionChanged(Duration(seconds: 3));
      const event2 = VideoEditorPositionChanged(Duration(seconds: 3));
      expect(event1, equals(event2));
    });

    test('$VideoEditorPositionChanged with different positions '
        'are not equal', () {
      const event1 = VideoEditorPositionChanged(Duration(seconds: 3));
      const event2 = VideoEditorPositionChanged(Duration(seconds: 7));
      expect(event1, isNot(equals(event2)));
    });

    test('$VideoEditorDurationChanged with same duration are equal', () {
      const event1 = VideoEditorDurationChanged(Duration(seconds: 30));
      const event2 = VideoEditorDurationChanged(Duration(seconds: 30));
      expect(event1, equals(event2));
    });

    test('$VideoEditorDurationChanged with different durations '
        'are not equal', () {
      const event1 = VideoEditorDurationChanged(Duration(seconds: 30));
      const event2 = VideoEditorDurationChanged(Duration(seconds: 60));
      expect(event1, isNot(equals(event2)));
    });

    test('$VideoEditorVolumeEditModeToggled events are equal', () {
      const event1 = VideoEditorVolumeEditModeToggled();
      const event2 = VideoEditorVolumeEditModeToggled();
      expect(event1, equals(event2));
    });

    test('$VideoEditorReorderingChanged with same value are equal', () {
      const event1 = VideoEditorReorderingChanged(isReordering: true);
      const event2 = VideoEditorReorderingChanged(isReordering: true);
      expect(event1, equals(event2));
    });

    test('$VideoEditorReorderingChanged with different values '
        'are not equal', () {
      const event1 = VideoEditorReorderingChanged(isReordering: true);
      const event2 = VideoEditorReorderingChanged(isReordering: false);
      expect(event1, isNot(equals(event2)));
    });
  });

  group(SubEditorType, () {
    test('has 8 values', () {
      expect(SubEditorType.values, hasLength(8));
    });

    test('contains expected types', () {
      expect(
        SubEditorType.values,
        containsAll([
          SubEditorType.text,
          SubEditorType.draw,
          SubEditorType.filter,
          SubEditorType.tune,
          SubEditorType.stickers,
          SubEditorType.music,
          SubEditorType.clips,
          SubEditorType.captions,
        ]),
      );
    });
  });
}
