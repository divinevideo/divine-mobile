import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/badges/badge_videos_cubit.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockBadgeVideoPager extends Mock implements BadgeVideoPager {}

void main() {
  group(BadgeVideosCubit, () {
    late _MockBadgeRepository badgeRepository;
    late _MockVideosRepository videosRepository;
    late _MockBadgeVideoPager pager;

    setUp(() {
      badgeRepository = _MockBadgeRepository();
      videosRepository = _MockVideosRepository();
      pager = _MockBadgeVideoPager();
      when(
        () => badgeRepository.loadAcceptedHolders(_coordinate),
      ).thenAnswer((_) async => {'holder'});
      when(
        () => videosRepository.createBadgeVideoPager({'holder'}),
      ).thenReturn(pager);
    });

    BadgeVideosCubit buildCubit() => BadgeVideosCubit(
      badgeRepository: badgeRepository,
      videosRepository: videosRepository,
      coordinate: _coordinate,
    );

    group('load', () {
      blocTest<BadgeVideosCubit, BadgeVideosState>(
        'uses a supplied holder snapshot without reading the badge again',
        setUp: () {
          when(() => pager.loadMore()).thenAnswer((_) async => [_video('a')]);
          when(() => pager.hasMore).thenReturn(false);
        },
        build: buildCubit,
        act: (cubit) => cubit.loadForHolders({'holder'}),
        expect: () => [
          const BadgeVideosState(status: BadgeVideosStatus.loading),
          BadgeVideosState(
            status: BadgeVideosStatus.loaded,
            videos: [_video('a')],
          ),
        ],
        verify: (_) => verifyNever(
          () => badgeRepository.loadAcceptedHolders(_coordinate),
        ),
      );

      blocTest<BadgeVideosCubit, BadgeVideosState>(
        'loads the first page of holder videos',
        setUp: () {
          when(() => pager.loadMore()).thenAnswer((_) async => [_video('a')]);
          when(() => pager.hasMore).thenReturn(true);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const BadgeVideosState(status: BadgeVideosStatus.loading),
          BadgeVideosState(
            status: BadgeVideosStatus.loaded,
            videos: [_video('a')],
            hasMore: true,
          ),
        ],
      );

      blocTest<BadgeVideosCubit, BadgeVideosState>(
        'fails when the holders cannot be fully loaded',
        setUp: () {
          when(
            () => badgeRepository.loadAcceptedHolders(_coordinate),
          ).thenThrow(StateError('Badge holders could not be fully loaded'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        errors: () => [isA<StateError>()],
        expect: () => const [
          BadgeVideosState(status: BadgeVideosStatus.loading),
          BadgeVideosState(status: BadgeVideosStatus.failure),
        ],
      );
    });

    group('loadMore', () {
      blocTest<BadgeVideosCubit, BadgeVideosState>(
        'appends the next page',
        setUp: () {
          var page = 0;
          when(() => pager.loadMore()).thenAnswer(
            (_) async => [_video(page++ == 0 ? 'a' : 'b')],
          );
          when(() => pager.hasMore).thenAnswer((_) => page < 2);
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.loadMore();
        },
        skip: 2,
        expect: () => [
          BadgeVideosState(
            status: BadgeVideosStatus.loaded,
            videos: [_video('a')],
            hasMore: true,
            isLoadingMore: true,
          ),
          BadgeVideosState(
            status: BadgeVideosStatus.loaded,
            videos: [_video('a'), _video('b')],
          ),
        ],
      );

      blocTest<BadgeVideosCubit, BadgeVideosState>(
        'counts a failed page without dropping loaded videos',
        setUp: () {
          var page = 0;
          when(() => pager.loadMore()).thenAnswer((_) async {
            if (page++ > 0) throw Exception('by-authors unavailable');
            return [_video('a')];
          });
          when(() => pager.hasMore).thenReturn(true);
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.loadMore();
        },
        skip: 3,
        errors: () => [isA<Exception>()],
        expect: () => [
          BadgeVideosState(
            status: BadgeVideosStatus.loaded,
            videos: [_video('a')],
            hasMore: true,
            loadMoreFailures: 1,
          ),
        ],
      );

      blocTest<BadgeVideosCubit, BadgeVideosState>(
        'does nothing before the first page loads',
        build: buildCubit,
        act: (cubit) => cubit.loadMore(),
        expect: () => const <BadgeVideosState>[],
        verify: (_) => verifyNever(() => pager.loadMore()),
      );
    });
  });
}

const _coordinate = BadgeCoordinate(
  pubkey: '0000000000000000000000000000000000000000000000000000000000000065',
  identifier: 'scene-stealer',
);

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: '0000000000000000000000000000000000000000000000000000000000000066',
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
  videoUrl: 'https://example.com/$id.mp4',
);
