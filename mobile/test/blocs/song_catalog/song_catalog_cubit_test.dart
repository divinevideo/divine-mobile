// ABOUTME: Tests for SongCatalogCubit: the most played songs, searching,
// ABOUTME: out-of-order answers, failures and retrying.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/song_catalog/song_catalog_cubit.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:sounds_repository/sounds_repository.dart';

class _MockSongCatalogRepository extends Mock
    implements SongCatalogRepository {}

AudioEvent _song(String id) => AudioEvent(
  id: 'apple_music_$id',
  pubkey: AudioEvent.externalProviderMarker,
  createdAt: 0,
  url: 'https://example.com/previews/$id.m4a',
  title: 'Song $id',
);

void main() {
  group(SongCatalogCubit, () {
    late _MockSongCatalogRepository repository;

    final trending = [_song('top-1'), _song('top-2')];
    final matches = [_song('match-1')];

    setUp(() {
      repository = _MockSongCatalogRepository();
    });

    SongCatalogCubit buildCubit() => SongCatalogCubit(repository: repository);

    group('showSongsFor', () {
      blocTest<SongCatalogCubit, SongCatalogState>(
        'lists the most played songs for a blank query',
        setUp: () => when(
          repository.fetchTrendingSongs,
        ).thenAnswer((_) async => trending),
        build: buildCubit,
        act: (cubit) => cubit.showSongsFor(''),
        expect: () => [
          const SongCatalogState(status: SongCatalogStatus.loading),
          SongCatalogState(
            status: SongCatalogStatus.success,
            trending: trending,
          ),
        ],
        verify: (cubit) {
          expect(cubit.state.songs, equals(trending));
          verify(repository.fetchTrendingSongs).called(1);
        },
      );

      blocTest<SongCatalogCubit, SongCatalogState>(
        'lists the songs matching a trimmed query',
        setUp: () => when(
          () => repository.searchSongs('night'),
        ).thenAnswer((_) async => matches),
        build: buildCubit,
        act: (cubit) => cubit.showSongsFor('  night '),
        expect: () => [
          const SongCatalogState(
            status: SongCatalogStatus.loading,
            query: 'night',
          ),
          SongCatalogState(
            status: SongCatalogStatus.success,
            query: 'night',
            results: matches,
          ),
        ],
        verify: (cubit) => expect(cubit.state.songs, equals(matches)),
      );

      blocTest<SongCatalogCubit, SongCatalogState>(
        'asks once for a query it already shows',
        setUp: () => when(
          () => repository.searchSongs('night'),
        ).thenAnswer((_) async => matches),
        build: buildCubit,
        act: (cubit) async {
          await cubit.showSongsFor('night');
          await cubit.showSongsFor('night');
        },
        verify: (_) => verify(() => repository.searchSongs('night')).called(1),
      );

      blocTest<SongCatalogCubit, SongCatalogState>(
        'brings the most played songs back when the search is cleared, '
        'without asking again',
        setUp: () {
          when(
            repository.fetchTrendingSongs,
          ).thenAnswer((_) async => trending);
          when(
            () => repository.searchSongs('night'),
          ).thenAnswer((_) async => matches);
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.showSongsFor('');
          await cubit.showSongsFor('night');
          await cubit.showSongsFor('');
        },
        skip: 4,
        expect: () => [
          SongCatalogState(
            status: SongCatalogStatus.success,
            trending: trending,
          ),
        ],
        verify: (cubit) {
          expect(cubit.state.songs, equals(trending));
          verify(repository.fetchTrendingSongs).called(1);
        },
      );

      test('shows the answer to the latest query when an earlier one comes '
          'in late', () async {
        final earlier = Completer<List<AudioEvent>>();
        when(
          () => repository.searchSongs('ni'),
        ).thenAnswer((_) => earlier.future);
        when(
          () => repository.searchSongs('night'),
        ).thenAnswer((_) async => matches);
        final cubit = buildCubit();
        addTearDown(cubit.close);

        final first = cubit.showSongsFor('ni');
        await cubit.showSongsFor('night');
        earlier.complete([_song('stale')]);
        await first;

        expect(cubit.state.query, equals('night'));
        expect(cubit.state.status, equals(SongCatalogStatus.success));
        expect(cubit.state.songs, equals(matches));
      });

      test('ignores a late failure of an earlier query', () async {
        final earlier = Completer<List<AudioEvent>>();
        when(
          () => repository.searchSongs('ni'),
        ).thenAnswer((_) => earlier.future);
        when(
          () => repository.searchSongs('night'),
        ).thenAnswer((_) async => matches);
        final cubit = buildCubit();
        addTearDown(cubit.close);

        final first = cubit.showSongsFor('ni');
        await cubit.showSongsFor('night');
        earlier.completeError(
          const AppleMusicApiException('Apple Music request failed'),
        );
        await first;

        expect(cubit.state.status, equals(SongCatalogStatus.success));
        expect(cubit.state.songs, equals(matches));
      });

      blocTest<SongCatalogCubit, SongCatalogState>(
        'fails when the catalog cannot be reached',
        setUp: () => when(repository.fetchTrendingSongs).thenThrow(
          const AppleMusicApiException(
            'Apple Music request failed',
            statusCode: 401,
          ),
        ),
        build: buildCubit,
        act: (cubit) => cubit.showSongsFor(''),
        expect: () => const [
          SongCatalogState(status: SongCatalogStatus.loading),
          SongCatalogState(status: SongCatalogStatus.failure),
        ],
        errors: () => [isA<AppleMusicApiException>()],
      );

      blocTest<SongCatalogCubit, SongCatalogState>(
        'fails and reports an error it does not expect',
        setUp: () => when(
          () => repository.searchSongs('night'),
        ).thenThrow(StateError('unexpected')),
        build: buildCubit,
        act: (cubit) => cubit.showSongsFor('night'),
        expect: () => const [
          SongCatalogState(
            status: SongCatalogStatus.loading,
            query: 'night',
          ),
          SongCatalogState(
            status: SongCatalogStatus.failure,
            query: 'night',
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (error) => error.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      test('drops an answer that arrives after close', () async {
        final pending = Completer<List<AudioEvent>>();
        when(repository.fetchTrendingSongs).thenAnswer((_) => pending.future);
        final cubit = buildCubit();

        final load = cubit.showSongsFor('');
        await cubit.close();
        pending.complete(trending);

        await expectLater(load, completes);
        expect(cubit.state.status, equals(SongCatalogStatus.loading));
      });
    });

    group('retry', () {
      blocTest<SongCatalogCubit, SongCatalogState>(
        'loads the list that failed again',
        setUp: () {
          var attempts = 0;
          when(repository.fetchTrendingSongs).thenAnswer((_) async {
            if (attempts++ == 0) {
              throw const AppleMusicApiException('Apple Music request failed');
            }
            return trending;
          });
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.showSongsFor('');
          await cubit.retry();
        },
        skip: 2,
        expect: () => [
          const SongCatalogState(status: SongCatalogStatus.loading),
          SongCatalogState(
            status: SongCatalogStatus.success,
            trending: trending,
          ),
        ],
        errors: () => [isA<AppleMusicApiException>()],
      );

      blocTest<SongCatalogCubit, SongCatalogState>(
        'does nothing while the list has not failed',
        setUp: () => when(
          repository.fetchTrendingSongs,
        ).thenAnswer((_) async => trending),
        build: buildCubit,
        act: (cubit) async {
          await cubit.showSongsFor('');
          await cubit.retry();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(SongCatalogStatus.success));
          verify(repository.fetchTrendingSongs).called(1);
        },
      );
    });
  });
}
