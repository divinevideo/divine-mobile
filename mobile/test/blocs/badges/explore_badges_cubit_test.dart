import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/explore_badges_cubit.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  setUpAll(
    () => registerFallbackValue(
      BadgeCoordinate(pubkey: _issuer, identifier: 'fallback'),
    ),
  );
  group(ExploreBadgesCubit, () {
    late _MockBadgeRepository repository;

    setUp(() {
      repository = _MockBadgeRepository();
    });

    test(
      'reveals 24 communities at a time without another discovery read',
      () async {
        final definitions = List.generate(
          55,
          (index) => Nip58BadgeDefinition(
            event: _definition.event,
            coordinate: '30009:$_issuer:group-$index',
            dTag: 'group-$index',
            name: 'Group $index',
          ),
        );
        when(repository.loadPublicDefinitions)
            .thenAnswer((_) async => definitions);
        final cubit = ExploreBadgesCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.visibleDefinitions, hasLength(24));
        cubit.showMore();
        expect(cubit.state.visibleDefinitions, hasLength(48));
        cubit.showMore();
        expect(cubit.state.visibleDefinitions, hasLength(55));
        expect(cubit.state.hasMore, isFalse);
        verify(repository.loadPublicDefinitions).called(1);
      },
    );

    test('superseded discovery cannot overwrite a newer refresh', () async {
      final first = Completer<List<Nip58BadgeDefinition>>();
      var calls = 0;
      when(repository.loadPublicDefinitions)
          .thenAnswer((_) => calls++ == 0 ? first.future : Future.value([]));
      final cubit = ExploreBadgesCubit(repository: repository);
      addTearDown(cubit.close);
      final old = cubit.load();
      await cubit.refresh();
      first.complete([_definition]);
      await old;
      expect(cubit.state.definitions, isEmpty);
    });

    test('a preview from before refresh cannot append people to the replacement snapshot', () async {
      final old = Completer<List<String>>();
      var previewCalls = 0;
      when(repository.loadPublicDefinitions)
          .thenAnswer((_) async => [_definition]);
      when(
        () => repository.loadHolderPreview(any()),
      ).thenAnswer((_) => previewCalls++ == 0 ? old.future : Future.value([]));
      final cubit = ExploreBadgesCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.loadPreview(_definition.coordinate);
      await cubit.refresh();
      old.complete(['3'.padLeft(64, '0')]);
      await pumpEventQueue();
      expect(cubit.state.previews, isEmpty);
      cubit.loadPreview(_definition.coordinate);
      await pumpEventQueue();
      expect(cubit.state.previews[_definition.coordinate], isEmpty);
      verify(() => repository.loadHolderPreview(any())).called(2);
    });

    test(
      'only four preview reads run and closed cubits discard late results',
      () async {
        final definitions = List.generate(
          6,
          (i) => Nip58BadgeDefinition(
            event: _definition.event,
            coordinate: '30009:$_issuer:group-$i',
            dTag: 'group-$i',
          ),
        );
        when(repository.loadPublicDefinitions)
            .thenAnswer((_) async => definitions);
        final pending = <Completer<List<String>>>[];
        when(() => repository.loadHolderPreview(any())).thenAnswer((_) {
          final result = Completer<List<String>>();
          pending.add(result);
          return result.future;
        });
        final cubit = ExploreBadgesCubit(repository: repository);
        await cubit.load();
        for (final definition in definitions) {
          cubit.loadPreview(definition.coordinate);
        }
        cubit.loadPreview(definitions.first.coordinate);
        expect(pending, hasLength(4));
        pending.first.complete(['3'.padLeft(64, '0')]);
        await pumpEventQueue();
        expect(pending, hasLength(5));
        expect(
          cubit.state.previews[definitions.first.coordinate],
          hasLength(1),
        );
        await cubit.close();
        for (final result in pending.skip(1)) {
          result.complete([]);
        }
        await pumpEventQueue();
        expect(pending, hasLength(5));
      },
    );

    group('loadPreview', () {
      final definitions = List.generate(
        5,
        (i) => Nip58BadgeDefinition(
          event: _definition.event,
          coordinate: '30009:$_issuer:group-$i',
          dTag: 'group-$i',
        ),
      );
      final holder = '3'.padLeft(64, '0');

      blocTest<ExploreBadgesCubit, ExploreBadgesState>(
        'a failed preview keeps the badge, reports the failure and frees '
        'its slot',
        setUp: () {
          when(
            repository.loadPublicDefinitions,
          ).thenAnswer((_) async => definitions);
          when(() => repository.loadHolderPreview(any())).thenAnswer((
            invocation,
          ) async {
            final coordinate =
                invocation.positionalArguments.single as BadgeCoordinate;
            if (coordinate.identifier != 'group-4') {
              throw Exception('holder index unavailable');
            }
            return [holder];
          });
        },
        build: () => ExploreBadgesCubit(repository: repository),
        act: (cubit) async {
          await cubit.load();
          for (final definition in definitions) {
            cubit.loadPreview(definition.coordinate);
          }
          await pumpEventQueue();
        },
        skip: 2,
        expect: () => [
          isA<ExploreBadgesState>()
              .having((s) => s.status, 'status', ExploreBadgesStatus.loaded)
              .having((s) => s.definitions, 'definitions', hasLength(5))
              .having((s) => s.previews, 'previews', {
                definitions.last.coordinate: [holder],
              }),
        ],
        errors: () => List.filled(4, isA<Exception>()),
      );
    });

    group('load', () {
      blocTest<ExploreBadgesCubit, ExploreBadgesState>(
        'discovers public community definitions',
        setUp: () {
          when(
            repository.loadPublicDefinitions,
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
            repository.loadPublicDefinitions,
          ).thenThrow(
            const BadgeReadIncompleteException(
              'Badge definitions could not be fully loaded',
            ),
          );
        },
        build: () => ExploreBadgesCubit(repository: repository),
        act: (cubit) => cubit.load(),
        errors: () => [isA<BadgeReadIncompleteException>()],
        expect: () => const [
          ExploreBadgesState(status: ExploreBadgesStatus.loading),
          ExploreBadgesState(status: ExploreBadgesStatus.failure),
        ],
      );
    });

    group('refresh', () {
      blocTest<ExploreBadgesCubit, ExploreBadgesState>(
        'failed refresh retains previously loaded definitions',
        setUp: () {
          when(repository.loadPublicDefinitions)
              .thenThrow(const BadgeReadIncompleteException('incomplete read'));
        },
        seed: () => ExploreBadgesState(
          status: ExploreBadgesStatus.loaded,
          definitions: [_definition],
        ),
        build: () => ExploreBadgesCubit(repository: repository),
        act: (cubit) => cubit.refresh(),
        errors: () => [isA<BadgeReadIncompleteException>()],
        expect: () => [
          isA<ExploreBadgesState>()
              .having((s) => s.status, 'status', ExploreBadgesStatus.loaded)
              .having((s) => s.definitions, 'retained definitions', [
                _definition,
              ]),
        ],
      );

      blocTest<ExploreBadgesCubit, ExploreBadgesState>(
        'keeps the list on screen while reloading',
        setUp: () {
          when(
            repository.loadPublicDefinitions,
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

final String _issuer = '2'.padLeft(64, '0');

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
