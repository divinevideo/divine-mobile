// ABOUTME: Tests for VideoSeriesCubit: which series a video is an episode of,
// ABOUTME: its episode number and count, and its position in the list.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_series/video_series_cubit.dart';
import 'package:openvine/observability/reportable_error.dart';

import '../../helpers/test_pubkeys.dart';

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _ErrorRecordingObserver extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

final String _author = testPubkeyFromSeed(1);
final String _seriesCoordinate = '30005:$_author:road-trip';

String _episode(String dTag) => '34236:$_author:$dTag';

CuratedList _series(List<String> references) => CuratedList(
  id: 'road-trip',
  name: 'Road trip',
  pubkey: _author,
  videoEventIds: references,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  playOrder: PlayOrder.manual,
  preservedTags: const [
    ['series', 'true'],
  ],
);

void main() {
  group(VideoSeriesCubit, () {
    late _MockCuratedListRepository repository;

    VideoSeriesCubit buildCubit({String? episodeCoordinate}) =>
        VideoSeriesCubit(
          repository: repository,
          seriesCoordinate: _seriesCoordinate,
          episodeCoordinate: episodeCoordinate ?? _episode('day-2'),
        );

    void answerSeries(Future<CuratedList?> Function() answer) {
      when(
        () => repository.fetchSeriesContaining(
          seriesCoordinate: any(named: 'seriesCoordinate'),
          episodeCoordinate: any(named: 'episodeCoordinate'),
        ),
      ).thenAnswer((_) => answer());
    }

    setUp(() {
      repository = _MockCuratedListRepository();
    });

    test('starts loading', () {
      expect(buildCubit().state, equals(const VideoSeriesLoading()));
    });

    group('load', () {
      final series = _series([
        _episode('day-1'),
        _episode('day-2'),
        _episode('day-3'),
      ]);

      blocTest<VideoSeriesCubit, VideoSeriesState>(
        'emits the episode number, the count and the list position',
        setUp: () => answerSeries(() async => series),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          VideoSeriesEpisode(
            series: series,
            authorPubkey: _author,
            episodeNumber: 2,
            episodeCount: 3,
            listPosition: 1,
          ),
        ],
        verify: (_) => verify(
          () => repository.fetchSeriesContaining(
            seriesCoordinate: _seriesCoordinate,
            episodeCoordinate: _episode('day-2'),
          ),
        ).called(1),
      );

      final mixed = _series([
        'e' * 64,
        _episode('day-1'),
        '34236:${testPubkeyFromSeed(2)}:borrowed',
        _episode('day-2'),
      ]);

      blocTest<VideoSeriesCubit, VideoSeriesState>(
        'counts only episodes, but takes the position among every entry',
        setUp: () => answerSeries(() async => mixed),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          VideoSeriesEpisode(
            series: mixed,
            authorPubkey: _author,
            episodeNumber: 2,
            episodeCount: 2,
            listPosition: 3,
          ),
        ],
      );

      blocTest<VideoSeriesCubit, VideoSeriesState>(
        'emits none when no series holds the video',
        setUp: () => answerSeries(() async => null),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [const VideoSeriesNone()],
      );

      blocTest<VideoSeriesCubit, VideoSeriesState>(
        'emits none when the series it is given does not hold the video',
        setUp: () => answerSeries(() async => series),
        build: () => buildCubit(episodeCoordinate: _episode('day-9')),
        act: (cubit) => cubit.load(),
        expect: () => [const VideoSeriesNone()],
      );

      blocTest<VideoSeriesCubit, VideoSeriesState>(
        'reports a failed read and emits none',
        setUp: () => answerSeries(() async => throw StateError('broken')),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [const VideoSeriesNone()],
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      test('does not emit after close when the read finishes late', () async {
        final observer = _ErrorRecordingObserver();
        final previousObserver = Bloc.observer;
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = previousObserver);
        final read = Completer<CuratedList?>();
        answerSeries(() => read.future);
        final cubit = buildCubit();

        final loading = cubit.load();
        await cubit.close();
        read.complete(series);

        await expectLater(loading, completes);
        expect(cubit.state, equals(const VideoSeriesLoading()));
        // An emit after close throws, and load would report it as an error.
        expect(observer.errors, isEmpty);
      });
    });
  });
}
