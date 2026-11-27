// ABOUTME: Tests for VideoEditorFilterBloc: sessions, the picked filter, its
// ABOUTME: opacity and its settings.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/models/video_editor/filter_settings.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  final crema = PresetFilters.crema;
  final clarendon = PresetFilters.clarendon;
  final cremaLight = filterSettingsCardsOf(crema).first;

  group(VideoEditorFilterBloc, () {
    group('$VideoEditorFilterSessionStarted', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'starts a new filter with nothing picked',
        build: VideoEditorFilterBloc.new,
        seed: () => VideoEditorFilterState(
          selectedFilter: crema,
          opacity: 0.4,
          settingValues: const {'temperature': -0.1},
          isSettingsOpen: true,
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterSessionStarted()),
        expect: () => [const VideoEditorFilterState()],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'starts on a committed filter as it was set up',
        build: VideoEditorFilterBloc.new,
        act: (bloc) => bloc.add(
          VideoEditorFilterSessionStarted(
            filterId: 'filter-1',
            filter: EditedFilter(
              preset: crema,
              values: const {'temperature': -0.1},
              opacity: 0.6,
            ),
          ),
        ),
        expect: () => [
          VideoEditorFilterState(
            selectedFilter: crema,
            opacity: 0.6,
            settingValues: const {'temperature': -0.1},
            editingFilterId: 'filter-1',
          ),
        ],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'adds a new filter when the committed one has no settings',
        build: VideoEditorFilterBloc.new,
        act: (bloc) => bloc.add(
          const VideoEditorFilterSessionStarted(filterId: 'filter-1'),
        ),
        expect: () => [const VideoEditorFilterState()],
      );
    });

    group('$VideoEditorFilterSelected', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'picks a preset at its own values',
        build: VideoEditorFilterBloc.new,
        seed: () => VideoEditorFilterState(
          selectedFilter: crema,
          settingValues: const {'temperature': -0.1},
        ),
        act: (bloc) => bloc.add(VideoEditorFilterSelected(clarendon)),
        expect: () => [VideoEditorFilterState(selectedFilter: clarendon)],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'keeps the settings when the picked preset is tapped again',
        build: VideoEditorFilterBloc.new,
        seed: () => VideoEditorFilterState(
          selectedFilter: crema,
          settingValues: const {'temperature': -0.1},
        ),
        act: (bloc) => bloc.add(VideoEditorFilterSelected(crema)),
        expect: () => const <VideoEditorFilterState>[],
      );
    });

    group('$VideoEditorFilterOpacityChanged', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'sets the opacity',
        build: VideoEditorFilterBloc.new,
        seed: () => VideoEditorFilterState(selectedFilter: crema),
        act: (bloc) => bloc.add(const VideoEditorFilterOpacityChanged(0.3)),
        expect: () => [
          VideoEditorFilterState(selectedFilter: crema, opacity: 0.3),
        ],
      );
    });

    group('$VideoEditorFilterSettingChanged', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'changes a setting, brought into its range',
        build: VideoEditorFilterBloc.new,
        seed: () => VideoEditorFilterState(selectedFilter: crema),
        act: (bloc) => bloc
          ..add(const VideoEditorFilterSettingChanged('temperature', -0.1))
          ..add(const VideoEditorFilterSettingChanged('brightness', 5.0)),
        expect: () => [
          VideoEditorFilterState(
            selectedFilter: crema,
            settingValues: const {'temperature': -0.1},
          ),
          VideoEditorFilterState(
            selectedFilter: crema,
            settingValues: const {'temperature': -0.1, 'brightness': 0.3},
          ),
        ],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        "drops a change back to the preset's own value",
        build: VideoEditorFilterBloc.new,
        seed: () => VideoEditorFilterState(
          selectedFilter: crema,
          settingValues: const {'saturation': 0.2},
        ),
        act: (bloc) => bloc.add(
          const VideoEditorFilterSettingChanged('saturation', -0.05),
        ),
        expect: () => [VideoEditorFilterState(selectedFilter: crema)],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'ignores a key the picked filter has no setting for',
        build: VideoEditorFilterBloc.new,
        seed: () => VideoEditorFilterState(selectedFilter: crema),
        act: (bloc) =>
            bloc.add(const VideoEditorFilterSettingChanged('step9.color', 0)),
        expect: () => const <VideoEditorFilterState>[],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'ignores a setting while nothing is picked',
        build: VideoEditorFilterBloc.new,
        act: (bloc) =>
            bloc.add(const VideoEditorFilterSettingChanged('brightness', 0.1)),
        expect: () => const <VideoEditorFilterState>[],
      );
    });

    group('$VideoEditorFilterSettingsReset', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'puts back the settings of one card only',
        build: VideoEditorFilterBloc.new,
        seed: () => VideoEditorFilterState(
          selectedFilter: crema,
          settingValues: const {'brightness': 0.1, 'temperature': -0.1},
        ),
        act: (bloc) => bloc.add(VideoEditorFilterSettingsReset(cremaLight)),
        expect: () => [
          VideoEditorFilterState(
            selectedFilter: crema,
            settingValues: const {'temperature': -0.1},
          ),
        ],
      );
    });

    group('$VideoEditorFilterSettingsToggled', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'opens and closes the settings',
        build: VideoEditorFilterBloc.new,
        seed: () => VideoEditorFilterState(selectedFilter: crema),
        act: (bloc) => bloc
          ..add(const VideoEditorFilterSettingsToggled(open: true))
          ..add(const VideoEditorFilterSettingsToggled(open: false)),
        expect: () => [
          VideoEditorFilterState(selectedFilter: crema, isSettingsOpen: true),
          VideoEditorFilterState(selectedFilter: crema),
        ],
      );
    });

    group('session end', () {
      final editing = VideoEditorFilterState(
        selectedFilter: crema,
        opacity: 0.5,
        settingValues: const {'temperature': -0.1},
        isSettingsOpen: true,
        editingFilterId: 'filter-1',
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        '$VideoEditorFilterCancelled clears the session',
        build: VideoEditorFilterBloc.new,
        seed: () => editing,
        act: (bloc) => bloc.add(const VideoEditorFilterCancelled()),
        expect: () => [const VideoEditorFilterState()],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        '$VideoEditorFilterConfirmed clears the session',
        build: VideoEditorFilterBloc.new,
        seed: () => editing,
        act: (bloc) => bloc.add(const VideoEditorFilterConfirmed()),
        expect: () => [const VideoEditorFilterState()],
      );
    });
  });

  group(VideoEditorFilterState, () {
    test('shows the settings only while open for a filter that has some', () {
      expect(
        VideoEditorFilterState(
          selectedFilter: crema,
          isSettingsOpen: true,
        ).showsSettings,
        isTrue,
      );
      expect(
        VideoEditorFilterState(selectedFilter: crema).showsSettings,
        isFalse,
      );
      expect(
        VideoEditorFilterState(
          selectedFilter: PresetFilters.none,
          isSettingsOpen: true,
        ).showsSettings,
        isFalse,
      );
    });

    test('edited is the picked preset with its settings and opacity', () {
      final state = VideoEditorFilterState(
        selectedFilter: crema,
        opacity: 0.4,
        settingValues: const {'temperature': -0.1},
      );

      expect(
        state.edited,
        EditedFilter(
          preset: crema,
          values: const {'temperature': -0.1},
          opacity: 0.4,
        ),
      );
      expect(const VideoEditorFilterState().edited, isNull);
    });
  });
}
