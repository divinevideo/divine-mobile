import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/explore_badges_cubit.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group(ExploreBadgesCubit, () {
    late _MockBadgeRepository repository;

    setUp(() {
      repository = _MockBadgeRepository();
    });

    group('load', () {
      blocTest<ExploreBadgesCubit, ExploreBadgesState>(
        'loads the definitions of the curated issuers',
        setUp: () {
          when(
            () => repository.loadDefinitionsByIssuers(exploreBadgeIssuers),
          ).thenAnswer((_) async => [_definition]);
        },
        build: () => ExploreBadgesCubit(repository: repository),
        act: (cubit) => cubit.load(),
        expect: () => [
          const ExploreBadgesState(status: ExploreBadgesStatus.loading),
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
          ),
        ],
      );

      blocTest<ExploreBadgesCubit, ExploreBadgesState>(
        'fails on an incomplete definition walk',
        setUp: () {
          when(
            () => repository.loadDefinitionsByIssuers(exploreBadgeIssuers),
          ).thenThrow(
            StateError('Badge definitions could not be fully loaded'),
          );
        },
        build: () => ExploreBadgesCubit(repository: repository),
        act: (cubit) => cubit.load(),
        errors: () => [isA<StateError>()],
        expect: () => const [
          ExploreBadgesState(status: ExploreBadgesStatus.loading),
          ExploreBadgesState(status: ExploreBadgesStatus.failure),
        ],
      );
    });

    group('refresh', () {
      blocTest<ExploreBadgesCubit, ExploreBadgesState>(
        'keeps the list on screen while reloading',
        setUp: () {
          when(
            () => repository.loadDefinitionsByIssuers(exploreBadgeIssuers),
          ).thenAnswer((_) async => [_definition]);
        },
        seed: () => const ExploreBadgesState(
          status: ExploreBadgesStatus.loaded,
        ),
        build: () => ExploreBadgesCubit(repository: repository),
        act: (cubit) => cubit.refresh(),
        expect: () => [
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
          ),
        ],
      );
    });
  });
}

const _issuer =
    'e21369e63b98f58de8aa171ec9794006eb0118891ae70895106d44525b718d2b';

final _definition = Nip58BadgeDefinition(
  event: Event.fromJson({
    'id': '1'.padLeft(64, '0'),
    'pubkey': _issuer,
    'created_at': 1000,
    'kind': EventKind.badgeDefinition,
    'tags': <List<String>>[],
    'content': '',
    'sig': '',
  }),
  coordinate: '30009:$_issuer:daily-diviner',
  dTag: 'daily-diviner',
  name: 'Diviner of the Day',
);
