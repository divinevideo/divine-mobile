// ABOUTME: Tests for VideoEditorFilterBloc - filter selection, opacity, and cancel.
// ABOUTME: Covers initial state, filter events, and state transitions.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show PresetFilters;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorFilterBloc', () {
    VideoEditorFilterBloc buildBloc() {
      return VideoEditorFilterBloc();
    }

    test(
      'initial state has filters from [VideoEditorConstants.filters]',
      () async {
        final bloc = buildBloc();
        expect(bloc.state.filters, equals(VideoEditorConstants.filters));
        expect(bloc.state.selectedFilter, isNull);
        expect(bloc.state.opacity, 1.0);
        expect(bloc.state.hasFilter, isFalse);
        await bloc.close();
      },
    );

    group('VideoEditorFilterSelected', () {
      final testFilter =
          VideoEditorConstants.filters[1]; // First non-None filter

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'emits state with selected filter',
        build: buildBloc,
        act: (bloc) => bloc.add(VideoEditorFilterSelected(testFilter)),
        expect: () => [
          isA<VideoEditorFilterState>().having(
            (s) => s.selectedFilter,
            'selectedFilter',
            testFilter,
          ),
        ],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'updates selected filter when changed',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: VideoEditorConstants.filters,
          selectedFilter: VideoEditorConstants.filters[1],
        ),
        act: (bloc) => bloc.add(
          VideoEditorFilterSelected(VideoEditorConstants.filters[2]),
        ),
        expect: () => [
          isA<VideoEditorFilterState>().having(
            (s) => s.selectedFilter,
            'selectedFilter',
            VideoEditorConstants.filters[2],
          ),
        ],
      );
    });

    group('VideoEditorFilterOpacityChanged', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'emits state with updated opacity',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorFilterOpacityChanged(0.5)),
        expect: () => [
          isA<VideoEditorFilterState>().having(
            (s) => s.opacity,
            'opacity',
            0.5,
          ),
        ],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'updates opacity when filter is selected',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: VideoEditorConstants.filters,
          selectedFilter: VideoEditorConstants.filters[1],
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterOpacityChanged(0.5)),
        expect: () => [
          isA<VideoEditorFilterState>().having(
            (s) => s.opacity,
            'opacity',
            0.5,
          ),
        ],
      );
    });

    group('VideoEditorFilterCancelled', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'restores to initial values from when editor was opened',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: VideoEditorConstants.filters,
          selectedFilter: VideoEditorConstants.filters[2],
          opacity: 0.5,
          initialSelectedFilter: VideoEditorConstants.filters[1],
          initialOpacity: 0.8,
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterCancelled()),
        expect: () => [
          isA<VideoEditorFilterState>()
              .having(
                (s) => s.selectedFilter,
                'selectedFilter',
                VideoEditorConstants.filters[1],
              )
              .having((s) => s.opacity, 'opacity', 0.8),
        ],
      );
    });

    group('VideoEditorFilterEditorInitialized', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'stores current values as initial values for cancel',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: VideoEditorConstants.filters,
          selectedFilter: VideoEditorConstants.filters[1],
          opacity: 0.7,
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterEditorInitialized()),
        expect: () => [
          isA<VideoEditorFilterState>()
              .having(
                (s) => s.initialSelectedFilter,
                'initialSelectedFilter',
                VideoEditorConstants.filters[1],
              )
              .having((s) => s.initialOpacity, 'initialOpacity', 0.7)
              // Current values unchanged
              .having(
                (s) => s.selectedFilter,
                'selectedFilter',
                VideoEditorConstants.filters[1],
              )
              .having((s) => s.opacity, 'opacity', 0.7),
        ],
      );
    });
  });

  group('VideoEditorFilterState', () {
    test('hasFilter returns false when selectedFilter is null', () {
      final state = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
      );
      expect(state.hasFilter, isFalse);
    });

    test(
      'hasFilter returns false when selectedFilter is PresetFilters.none',
      () {
        final state = VideoEditorFilterState(
          filters: VideoEditorConstants.filters,
          selectedFilter: PresetFilters.none,
        );
        expect(state.hasFilter, isFalse);
      },
    );

    test('hasFilter returns true when a real filter is selected', () {
      final state = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
        selectedFilter: VideoEditorConstants.filters[1], // Non-None filter
      );
      expect(state.hasFilter, isTrue);
    });

    test('isSelected returns true for matching filter', () {
      final filter = VideoEditorConstants.filters[1];
      final state = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
        selectedFilter: filter,
      );
      expect(state.isSelected(filter), isTrue);
    });

    test('isSelected returns false for non-matching filter', () {
      final state = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
        selectedFilter: VideoEditorConstants.filters[1],
      );
      expect(state.isSelected(VideoEditorConstants.filters[2]), isFalse);
    });

    test(
      'isSelected returns true for None filter when selectedFilter is null',
      () {
        final state = VideoEditorFilterState(
          filters: VideoEditorConstants.filters,
        );
        expect(state.isSelected(PresetFilters.none), isTrue);
      },
    );

    test('copyWith creates new state with updated values', () {
      final original = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
      );

      final updated = original.copyWith(
        selectedFilter: VideoEditorConstants.filters[1],
        opacity: 0.5,
      );

      expect(updated.filters, equals(VideoEditorConstants.filters));
      expect(updated.selectedFilter, equals(VideoEditorConstants.filters[1]));
      expect(updated.opacity, 0.5);
      // Original unchanged
      expect(original.selectedFilter, isNull);
      expect(original.opacity, 1.0);
    });

    test('copyWith preserves values when not specified', () {
      final filter = VideoEditorConstants.filters[1];
      final original = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
        selectedFilter: filter,
        opacity: 0.7,
      );

      final updated = original.copyWith();

      expect(updated.filters, equals(original.filters));
      expect(updated.selectedFilter, equals(original.selectedFilter));
      expect(updated.opacity, equals(original.opacity));
    });

    test('props contains all fields for equality', () {
      final state = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
        selectedFilter: VideoEditorConstants.filters[1],
        opacity: 0.5,
        initialSelectedFilter: VideoEditorConstants.filters[2],
        initialOpacity: 0.8,
      );

      expect(state.props, [
        VideoEditorConstants.filters,
        VideoEditorConstants.filters[1],
        0.5,
        VideoEditorConstants.filters[2],
        0.8,
        const <dynamic>[],
        const <dynamic>[],
      ]);
    });

    test('equality works correctly', () {
      final state1 = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
        selectedFilter: VideoEditorConstants.filters[1],
        opacity: 0.5,
      );
      final state2 = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
        selectedFilter: VideoEditorConstants.filters[1],
        opacity: 0.5,
      );
      final state3 = VideoEditorFilterState(
        filters: VideoEditorConstants.filters,
        selectedFilter: VideoEditorConstants.filters[2],
        opacity: 0.5,
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });

  group('VideoEditorFilterEvent', () {
    test('VideoEditorFilterSelected props contains filter', () {
      final filter = VideoEditorConstants.filters[1];
      final event = VideoEditorFilterSelected(filter);
      expect(event.props, [filter]);
    });

    test('VideoEditorFilterOpacityChanged props contains opacity', () {
      const event = VideoEditorFilterOpacityChanged(0.75);
      expect(event.props, [0.75]);
    });

    test('VideoEditorFilterCancelled props is empty', () {
      const event = VideoEditorFilterCancelled();
      expect(event.props, isEmpty);
    });

    test('event equality works correctly', () {
      final filter = VideoEditorConstants.filters[1];
      final event1 = VideoEditorFilterSelected(filter);
      final event2 = VideoEditorFilterSelected(filter);
      final event3 = VideoEditorFilterSelected(VideoEditorConstants.filters[2]);

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });
  });
}
