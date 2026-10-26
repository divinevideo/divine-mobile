// ABOUTME: Tests the place suggestions for info stickers: debounced while the
// ABOUTME: creator types, and what shows when a search finds nothing or fails.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/info_sticker/info_sticker_place_search_bloc.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';

class _MockInfoStickerRepository extends Mock
    implements InfoStickerRepository {}

const _bern = InfoStickerPlace(name: 'Bern', latitude: 46.95, longitude: 7.45);

void main() {
  group(InfoStickerPlaceSearchBloc, () {
    late _MockInfoStickerRepository repository;

    setUp(() {
      repository = _MockInfoStickerRepository();
    });

    InfoStickerPlaceSearchBloc build() => InfoStickerPlaceSearchBloc(
      repository: repository,
      languageCode: 'de',
    );

    group(InfoStickerPlaceQueryChanged, () {
      blocTest<InfoStickerPlaceSearchBloc, InfoStickerPlaceSearchState>(
        'searches only what was typed last, after a pause',
        setUp: () => when(
          () => repository.searchPlaces('Bern', languageCode: 'de'),
        ).thenAnswer((_) async => [_bern]),
        build: build,
        act: (bloc) => bloc
          ..add(const InfoStickerPlaceQueryChanged('Be'))
          ..add(const InfoStickerPlaceQueryChanged('Ber'))
          ..add(const InfoStickerPlaceQueryChanged('Bern')),
        wait: searchDebounceDuration * 2,
        expect: () => const [
          InfoStickerPlaceSearchState(
            query: 'Bern',
            status: InfoStickerPlaceSearchStatus.loading,
          ),
          InfoStickerPlaceSearchState(
            query: 'Bern',
            places: [_bern],
            status: InfoStickerPlaceSearchStatus.success,
          ),
        ],
        verify: (_) => verify(
          () => repository.searchPlaces(any(), languageCode: 'de'),
        ).called(1),
      );

      blocTest<InfoStickerPlaceSearchBloc, InfoStickerPlaceSearchState>(
        'clears the suggestions for a query too short to search',
        build: build,
        seed: () => const InfoStickerPlaceSearchState(
          query: 'Bern',
          places: [_bern],
          status: InfoStickerPlaceSearchStatus.success,
        ),
        act: (bloc) => bloc.add(const InfoStickerPlaceQueryChanged('B')),
        wait: searchDebounceDuration * 2,
        expect: () => const [InfoStickerPlaceSearchState(query: 'B')],
        verify: (_) => verifyNever(
          () => repository.searchPlaces(
            any(),
            languageCode: any(named: 'languageCode'),
          ),
        ),
      );

      blocTest<InfoStickerPlaceSearchBloc, InfoStickerPlaceSearchState>(
        'reports a search that failed',
        setUp: () => when(
          () => repository.searchPlaces('Bern', languageCode: 'de'),
        ).thenThrow(const InfoStickerLookupException('offline')),
        build: build,
        act: (bloc) => bloc.add(const InfoStickerPlaceQueryChanged('Bern')),
        wait: searchDebounceDuration * 2,
        verify: (bloc) => expect(
          bloc.state.status,
          InfoStickerPlaceSearchStatus.failure,
        ),
      );
    });
  });
}
