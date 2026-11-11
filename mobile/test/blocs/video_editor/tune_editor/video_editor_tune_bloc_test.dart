// ABOUTME: Tests for VideoEditorTuneBloc - selection, value changes, cancel.
// ABOUTME: Covers initial state, seeding from active adjustments, and restore.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/adjust_color_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show TuneAdjustmentMatrix;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorTuneBloc, () {
    VideoEditorTuneBloc buildBloc() => VideoEditorTuneBloc();

    test(
      'initial state exposes all tune adjustments at neutral values',
      () async {
        final bloc = buildBloc();
        expect(
          bloc.state.adjustments,
          equals(VideoEditorConstants.tuneAdjustments),
        );
        expect(bloc.state.selectedIndex, 0);
        expect(bloc.state.values, isEmpty);
        expect(bloc.state.selectedValue, 0);
        await bloc.close();
      },
    );

    group('VideoEditorTuneEditorInitialized', () {
      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'seeds values from active adjustments and snapshots them',
        build: buildBloc,
        act: (bloc) => bloc.add(
          VideoEditorTuneEditorInitialized([
            TuneAdjustmentMatrix(
              id: 'brightness',
              value: 0.2,
              matrix: const [],
            ),
            TuneAdjustmentMatrix(id: 'contrast', value: -0.1, matrix: const []),
          ]),
        ),
        expect: () => [
          isA<VideoEditorTuneState>()
              .having((s) => s.values['brightness'], 'brightness', 0.2)
              .having((s) => s.values['contrast'], 'contrast', -0.1)
              .having((s) => s.initialValues['brightness'], 'initial', 0.2)
              .having((s) => s.selectedIndex, 'selectedIndex', 0)
              .having((s) => s.values.length, 'values count', 2),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'resets selectedIndex to 0 on re-init',
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          selectedIndex: 3,
        ),
        act: (bloc) => bloc.add(const VideoEditorTuneEditorInitialized([])),
        expect: () => [
          isA<VideoEditorTuneState>().having(
            (s) => s.selectedIndex,
            'selectedIndex',
            0,
          ),
        ],
      );
    });

    group('VideoEditorTuneAdjustmentSelected', () {
      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'updates the selected adjustment index',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorTuneAdjustmentSelected(2)),
        expect: () => [
          isA<VideoEditorTuneState>()
              .having((s) => s.selectedIndex, 'selectedIndex', 2)
              .having(
                (s) => s.selectedAdjustment.id,
                'selectedAdjustment.id',
                VideoEditorConstants.tuneAdjustments[2].id,
              ),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'ignores an out-of-range index',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const VideoEditorTuneAdjustmentSelected(-1))
          ..add(
            VideoEditorTuneAdjustmentSelected(
              VideoEditorConstants.tuneAdjustments.length,
            ),
          ),
        expect: () => <VideoEditorTuneState>[],
      );
    });

    group('VideoEditorTuneValueChanged', () {
      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'sets the value for the currently selected adjustment',
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          selectedIndex: 1, // contrast
        ),
        act: (bloc) => bloc.add(const VideoEditorTuneValueChanged(0.3)),
        expect: () => [
          isA<VideoEditorTuneState>()
              .having((s) => s.values['contrast'], 'contrast', 0.3)
              .having((s) => s.selectedValue, 'selectedValue', 0.3),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'keeps values for other adjustments untouched',
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          // selectedIndex defaults to 0 (brightness).
          values: const {'contrast': -0.2},
        ),
        act: (bloc) => bloc.add(const VideoEditorTuneValueChanged(0.5)),
        expect: () => [
          isA<VideoEditorTuneState>()
              .having((s) => s.values['brightness'], 'brightness', 0.5)
              .having((s) => s.values['contrast'], 'contrast', -0.2),
        ],
      );
    });

    group('VideoEditorTuneValueChanged with an id', () {
      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'sets that adjustment and selects it',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorTuneValueChanged(-0.4, id: 'blueHue')),
        expect: () => [
          isA<VideoEditorTuneState>()
              .having((s) => s.values, 'values', {'blueHue': -0.4})
              .having((s) => s.selectedAdjustment.id, 'selected', 'blueHue')
              .having(
                (s) => s.section,
                'section',
                VideoEditorTuneSection.color,
              ),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'ignores an adjustment the bar does not have',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorTuneValueChanged(0.4, id: 'unknown')),
        expect: () => <VideoEditorTuneState>[],
      );
    });

    group('VideoEditorTuneColorBandSelected', () {
      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'remembers the band and selects its hue, opening the Color section',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorTuneColorBandSelected(AdjustColorBand.aqua),
        ),
        expect: () => [
          isA<VideoEditorTuneState>()
              .having((s) => s.colorBand, 'colorBand', AdjustColorBand.aqua)
              .having((s) => s.selectedAdjustment.id, 'selected', 'aquaHue')
              .having(
                (s) => s.section,
                'section',
                VideoEditorTuneSection.color,
              ),
        ],
      );
    });

    group('VideoEditorTuneCurveChannelSelected', () {
      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'remembers the curve and opens the Curve section',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorTuneCurveChannelSelected(AdjustCurveChannel.green),
        ),
        expect: () => [
          isA<VideoEditorTuneState>()
              .having(
                (s) => s.curveChannel,
                'curveChannel',
                AdjustCurveChannel.green,
              )
              .having(
                (s) => s.selectedAdjustment.id,
                'selected',
                'curveGreenBlacks',
              )
              .having(
                (s) => s.section,
                'section',
                VideoEditorTuneSection.curve,
              ),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'keeps the colour band for when the Color section opens again',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const VideoEditorTuneColorBandSelected(AdjustColorBand.purple))
          ..add(
            const VideoEditorTuneCurveChannelSelected(AdjustCurveChannel.red),
          ),
        skip: 1,
        expect: () => [
          isA<VideoEditorTuneState>()
              .having((s) => s.colorBand, 'colorBand', AdjustColorBand.purple)
              .having(
                (s) => s.section,
                'section',
                VideoEditorTuneSection.curve,
              ),
        ],
      );
    });

    group('VideoEditorTuneState', () {
      test('lists the twelve sliders as chips, without the sections', () {
        final state = VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
        );

        expect(
          state.sliderAdjustments.map((a) => a.id),
          [
            'brightness',
            'contrast',
            'highlights',
            'shadows',
            'saturation',
            'vibrance',
            'exposure',
            'hue',
            'temperature',
            'tint',
            'fade',
            'sharpen',
          ],
        );
      });

      test('marks a section adjusted only while one of its values is set', () {
        final state = VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          values: const {
            'brightness': 0.2,
            'redLightness': 0,
            'curveRgbWhites': -0.1,
          },
        );

        expect(state.isSectionAdjusted(VideoEditorTuneSection.color), isFalse);
        expect(state.isSectionAdjusted(VideoEditorTuneSection.curve), isTrue);
        expect(state.isSectionAdjusted(VideoEditorTuneSection.slider), isTrue);
      });
    });

    group('VideoEditorTuneCancelled', () {
      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'restores the values captured when the editor opened',
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          values: const {'brightness': 0.4},
          initialValues: const {'brightness': 0.1},
        ),
        act: (bloc) => bloc.add(const VideoEditorTuneCancelled()),
        expect: () => [
          isA<VideoEditorTuneState>().having(
            (s) => s.values['brightness'],
            'brightness',
            0.1,
          ),
        ],
      );
    });

    group('VideoEditorTuneConfirmed', () {
      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'promotes the current values to the restore baseline',
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          values: const {'brightness': 0.4},
          initialValues: const {'brightness': 0.1},
        ),
        act: (bloc) => bloc.add(const VideoEditorTuneConfirmed()),
        expect: () => [
          isA<VideoEditorTuneState>().having(
            (s) => s.initialValues['brightness'],
            'initialValues.brightness',
            0.4,
          ),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'clears the editing set id',
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          editingSetId: 'set-1',
        ),
        act: (bloc) => bloc.add(const VideoEditorTuneConfirmed()),
        expect: () => [
          isA<VideoEditorTuneState>().having(
            (s) => s.editingSetId,
            'editingSetId',
            isNull,
          ),
        ],
      );
    });

    group('VideoEditorTuneSessionStarted', () {
      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'records the edited set id',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoEditorTuneSessionStarted(setId: 'set-1')),
        expect: () => [
          isA<VideoEditorTuneState>().having(
            (s) => s.editingSetId,
            'editingSetId',
            'set-1',
          ),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'opens on the first slider even when the last session ended on Color',
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          selectedIndex: VideoEditorConstants.tuneAdjustments.indexWhere(
            (a) => a.id == 'blueHue',
          ),
        ),
        act: (bloc) => bloc.add(const VideoEditorTuneSessionStarted()),
        expect: () => [
          isA<VideoEditorTuneState>().having(
            (s) => s.section,
            'section',
            VideoEditorTuneSection.slider,
          ),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'clears the editing set id for a new session',
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          editingSetId: 'set-1',
        ),
        act: (bloc) => bloc.add(const VideoEditorTuneSessionStarted()),
        expect: () => [
          isA<VideoEditorTuneState>().having(
            (s) => s.editingSetId,
            'editingSetId',
            isNull,
          ),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        "replaces the previous session's values with the new session's",
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          values: const {'sharpen': 0.5},
        ),
        act: (bloc) => bloc.add(
          const VideoEditorTuneSessionStarted(
            setId: 'set-2',
            values: {'shadows': 0.3},
          ),
        ),
        expect: () => [
          isA<VideoEditorTuneState>().having(
            (s) => s.values,
            'values',
            {'shadows': 0.3},
          ),
        ],
      );

      blocTest<VideoEditorTuneBloc, VideoEditorTuneState>(
        'is preserved across VideoEditorTuneEditorInitialized',
        build: buildBloc,
        seed: () => VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
          values: const {'brightness': 0.5},
          editingSetId: 'set-1',
        ),
        act: (bloc) => bloc.add(
          VideoEditorTuneEditorInitialized([
            TuneAdjustmentMatrix(id: 'contrast', value: -0.2, matrix: const []),
          ]),
        ),
        expect: () => [
          isA<VideoEditorTuneState>()
              .having((s) => s.values['contrast'], 'seeded value', -0.2)
              .having((s) => s.editingSetId, 'editingSetId', 'set-1'),
        ],
      );
    });
  });
}
