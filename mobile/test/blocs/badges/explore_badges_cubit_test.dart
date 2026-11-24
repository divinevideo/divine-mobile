import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/explore_badges_cubit.dart';

class _IndexedRepository extends Mock implements BadgeRepository {
  @override
  List<Nip58BadgeDefinition> mergeDiscoveryDefinitions(
    List<Nip58BadgeDefinition> primary,
    List<Nip58BadgeDefinition> federated,
  ) => mergeBadgeDiscoveryDefinitions(primary, federated);
}

class _MockBadgeRepository extends Mock implements BadgeRepository {
  @override
  List<Nip58BadgeDefinition> mergeDiscoveryDefinitions(
    List<Nip58BadgeDefinition> primary,
    List<Nip58BadgeDefinition> federated,
  ) => mergeBadgeDiscoveryDefinitions(primary, federated);

  @override
  Future<List<IndexedBadgeDiscovery>> loadIndexedDiscovery({
    bool Function()? isActive,
  }) async => [
    for (final definition in await loadPublicDefinitions())
      (definition: definition, videos: const <BadgeVideoPreview>[]),
  ];

  @override
  Future<List<Nip58BadgeDefinition>> loadFederatedDiscovery() async => const [];
}

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

    test(
      'publishes ranked clips while the external relay read is pending',
      () async {
        final indexed = _IndexedRepository();
        final waiting = Completer<List<Nip58BadgeDefinition>>();
        final video = (
          id: 'a' * 64,
          pubkey: 'b' * 64,
          title: 'Clip',
          thumbnail: '',
          createdAt: 1700000000,
          kind: 34236,
          moderationLabels: const <String>[],
          verifiedArchive: false,
          archiveProvenanceAvailable: true,
          tags: const [
            ['d', 'clip'],
            ['url', 'https://media.divine.video/clip.mp4'],
          ],
        );
        when(
          () => indexed.loadIndexedDiscovery(isActive: any(named: 'isActive')),
        ).thenAnswer(
          (_) async => [
            (definition: _definition, videos: [video]),
          ],
        );
        when(indexed.loadFederatedDiscovery).thenAnswer((_) => waiting.future);
        final cubit = ExploreBadgesCubit(repository: indexed);
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, ExploreBadgesStatus.loaded);
        expect(cubit.state.videoPreviews[_definition.coordinate], [video]);
        verify(indexed.loadFederatedDiscovery).called(1);
        verifyNever(indexed.loadPublicDefinitions);
        waiting.complete([_definition]);
        await pumpEventQueue();
        expect(cubit.state.definitions, [_definition]);
      },
    );

    test(
      'caps duplicate issuers and retains relay cards during refresh',
      () async {
        final indexed = _IndexedRepository();
        final definitions = List.generate(
          4,
          (index) => Nip58BadgeDefinition(
            event: _definition.event,
            coordinate: '30009:$_issuer:badge-$index',
            dTag: 'badge-$index',
          ),
        );
        final next = Completer<List<Nip58BadgeDefinition>>();
        var relayReads = 0;
        when(
          () => indexed.loadIndexedDiscovery(isActive: any(named: 'isActive')),
        ).thenAnswer(
          (_) async => [(definition: definitions.first, videos: [])],
        );
        when(indexed.loadFederatedDiscovery).thenAnswer(
          (_) => relayReads++ == 0 ? Future.value(definitions) : next.future,
        );
        final cubit = ExploreBadgesCubit(repository: indexed);
        addTearDown(cubit.close);
        await cubit.load();
        await pumpEventQueue();
        expect(cubit.state.definitions, definitions.take(3));

        await cubit.refresh();
        expect(cubit.state.definitions, definitions.take(3));
        next.complete([]);
        await pumpEventQueue();
        expect(cubit.state.definitions, [definitions.first]);
      },
    );

    test('keeps external cards through a failed indexed refresh', () async {
      final indexed = _IndexedRepository();
      final relay = Nip58BadgeDefinition(
        event: _definition.event,
        coordinate: '30009:$_issuer:external',
        dTag: 'external',
      );
      var relayReads = 0;
      final nextRelayRead = Completer<List<Nip58BadgeDefinition>>();
      when(() => indexed.loadIndexedDiscovery(isActive: any(named: 'isActive')))
          .thenAnswer((_) async {
            return [(definition: _definition, videos: [])];
          });
      when(indexed.loadPublicDefinitions)
          .thenAnswer((_) async => [_definition]);
      when(indexed.loadFederatedDiscovery).thenAnswer(
        (_) => relayReads++ == 0 ? Future.value([relay]) : nextRelayRead.future,
      );
      final cubit = ExploreBadgesCubit(repository: indexed);
      addTearDown(cubit.close);
      await cubit.load();
      await pumpEventQueue();
      expect(cubit.state.definitions, [_definition, relay]);

      await cubit.refresh();
      expect(cubit.state.definitions, [_definition, relay]);
      nextRelayRead.complete([]);
      await pumpEventQueue();
      expect(cubit.state.definitions, [_definition]);
    });

    test('empty indexed clips still load accepted member previews', () async {
      final indexed = _IndexedRepository();
      when(() => indexed.loadIndexedDiscovery(isActive: any(named: 'isActive')))
          .thenAnswer((_) async => [(definition: _definition, videos: [])]);
      when(indexed.loadFederatedDiscovery).thenAnswer((_) async => []);
      when(() => indexed.loadHolderPreview(any()))
          .thenAnswer((_) async => [_issuer]);
      final cubit = ExploreBadgesCubit(repository: indexed);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.loadPreview(_definition.coordinate);
      await pumpEventQueue();
      expect(cubit.state.previews[_definition.coordinate], [_issuer]);
    });

    final federatedError = StateError('superseded external relay');
    late Completer<List<Nip58BadgeDefinition>> oldFederated;
    blocTest<ExploreBadgesCubit, ExploreBadgesState>(
      'superseded federated failures still reach diagnostics',
      build: () {
        oldFederated = Completer<List<Nip58BadgeDefinition>>();
        final indexed = _IndexedRepository();
        var reads = 0;
        when(
          () => indexed.loadIndexedDiscovery(isActive: any(named: 'isActive')),
        ).thenAnswer((_) async => [(definition: _definition, videos: [])]);
        when(indexed.loadFederatedDiscovery).thenAnswer(
          (_) => reads++ == 0 ? oldFederated.future : Future.value([]),
        );
        return ExploreBadgesCubit(repository: indexed);
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.refresh();
        oldFederated.completeError(federatedError);
        await pumpEventQueue();
      },
      errors: () => [same(federatedError)],
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

    test(
      'an old preview cannot overwrite newer people for a changed definition',
      () async {
        final old = Completer<List<String>>();
        final changed = Nip58BadgeDefinition(
          event: Event.fromJson({
            ..._definition.event.toJson(),
            'id': '2'.padLeft(64, '0'),
          }),
          coordinate: _definition.coordinate,
          dTag: _definition.dTag,
        );
        final currentHolder = '4'.padLeft(64, '0');
        var loads = 0;
        var previewCalls = 0;
        when(repository.loadPublicDefinitions).thenAnswer(
          (_) async => loads++ == 0 ? [_definition] : [changed],
        );
        when(() => repository.loadHolderPreview(any())).thenAnswer(
          (_) =>
              previewCalls++ == 0 ? old.future : Future.value([currentHolder]),
        );
        final cubit = ExploreBadgesCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();
        cubit.loadPreview(_definition.coordinate);
        await cubit.refresh();
        cubit.loadPreview(changed.coordinate);
        await pumpEventQueue();
        expect(cubit.state.previews[changed.coordinate], [currentHolder]);

        old.complete(['3'.padLeft(64, '0')]);
        await pumpEventQueue();

        expect(cubit.state.previews[changed.coordinate], [currentHolder]);
        verify(() => repository.loadHolderPreview(any())).called(2);
      },
    );

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

    test(
      'hides issuers before paging and restores them without a read',
      () async {
        final otherIssuer = '4'.padLeft(64, '0');
        final definitions = [
          _definition,
          ...List.generate(
            25,
            (i) => Nip58BadgeDefinition(
              event: Event.fromJson({
                ..._definition.event.toJson(),
                'pubkey': otherIssuer,
              }),
              coordinate: '30009:$otherIssuer:group-$i',
              dTag: 'group-$i',
            ),
          ),
        ];
        when(repository.loadPublicDefinitions)
            .thenAnswer((_) async => definitions);
        when(() => repository.loadHolderPreview(any()))
            .thenAnswer((_) async => []);
        final cubit = ExploreBadgesCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.visibleDefinitions.first, _definition);

        cubit.updateHiddenIssuers({_issuer});

        expect(cubit.state.visibleDefinitions, definitions.skip(1).take(24));
        expect(cubit.state.hasMore, isTrue);
        cubit.loadPreview(_definition.coordinate);
        verifyNever(() => repository.loadHolderPreview(any()));
        cubit.showMore();
        expect(cubit.state.visibleDefinitions, definitions.skip(1));
        expect(cubit.state.hasMore, isFalse);

        cubit.updateHiddenIssuers({});
        expect(cubit.state.visibleDefinitions, definitions);
        verify(repository.loadPublicDefinitions).called(1);
      },
    );

    test(
      'successful refresh does not release physically busy preview slots',
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
        addTearDown(cubit.close);
        await cubit.load();
        for (final definition in definitions.take(5)) {
          cubit.loadPreview(definition.coordinate);
        }
        expect(pending, hasLength(4));

        await cubit.refresh();
        cubit.loadPreview(definitions.last.coordinate);
        expect(pending, hasLength(4));
        pending.first.complete(['3'.padLeft(64, '0')]);
        await pumpEventQueue();
        expect(pending, hasLength(5));
        expect(cubit.state.previews, isEmpty);
        for (final result in pending.skip(1)) {
          result.complete([]);
        }
        await pumpEventQueue();
        expect(cubit.state.previews, {definitions.last.coordinate: <String>[]});
        verifyNever(
          () => repository.loadHolderPreview(
            BadgeCoordinate(pubkey: _issuer, identifier: definitions[4].dTag),
          ),
        );
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
        verify: (cubit) {
          expect(cubit.state.status, ExploreBadgesStatus.loaded);
          expect(cubit.state.definitions, hasLength(5));
          expect(cubit.state.activePreviews, 0);
          expect(cubit.state.previews, {
            definitions.last.coordinate: [holder],
          });
        },
        errors: () => List.filled(4, isA<Exception>()),
      );

      test('requests each coordinate once per discovery', () async {
        when(
          repository.loadPublicDefinitions,
        ).thenAnswer((_) async => [_definition]);
        when(
          () => repository.loadHolderPreview(any()),
        ).thenAnswer((_) async => [holder]);
        final cubit = ExploreBadgesCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();

        cubit.loadPreview(_definition.coordinate);
        await pumpEventQueue();
        cubit.loadPreview(_definition.coordinate);
        await pumpEventQueue();

        expect(cubit.state.previews[_definition.coordinate], [holder]);
        verify(() => repository.loadHolderPreview(any())).called(1);
      });

      test('waits for an in-flight refresh before requesting', () async {
        final refreshed = Completer<List<Nip58BadgeDefinition>>();
        var loads = 0;
        when(repository.loadPublicDefinitions).thenAnswer(
          (_) => loads++ == 0 ? Future.value([_definition]) : refreshed.future,
        );
        when(
          () => repository.loadHolderPreview(any()),
        ).thenAnswer((_) async => [holder]);
        final cubit = ExploreBadgesCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();

        final refresh = cubit.refresh();
        cubit.loadPreview(_definition.coordinate);
        await pumpEventQueue();
        verifyNever(() => repository.loadHolderPreview(any()));

        refreshed.complete([_definition]);
        await refresh;
        cubit.loadPreview(_definition.coordinate);
        await pumpEventQueue();
        expect(cubit.state.previews[_definition.coordinate], [holder]);
        verify(() => repository.loadHolderPreview(any())).called(1);
      });

      test('ignores a coordinate outside the revealed page', () async {
        final page = List.generate(
          30,
          (i) => Nip58BadgeDefinition(
            event: _definition.event,
            coordinate: '30009:$_issuer:page-$i',
            dTag: 'page-$i',
          ),
        );
        when(repository.loadPublicDefinitions).thenAnswer((_) async => page);
        when(
          () => repository.loadHolderPreview(any()),
        ).thenAnswer((_) async => [holder]);
        final cubit = ExploreBadgesCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();

        cubit.loadPreview(page.last.coordinate);
        await pumpEventQueue();

        expect(cubit.state.previews, isEmpty);
        verifyNever(() => repository.loadHolderPreview(any()));
      });
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
          const ExploreBadgesState(
            status: ExploreBadgesStatus.loading,
            isRefreshing: true,
            refreshGeneration: 1,
          ),
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
            refreshGeneration: 1,
            previewGeneration: 1,
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
          ExploreBadgesState(
            status: ExploreBadgesStatus.loading,
            isRefreshing: true,
            refreshGeneration: 1,
          ),
          ExploreBadgesState(
            status: ExploreBadgesStatus.failure,
            refreshGeneration: 1,
          ),
        ],
      );
    });

    group('refresh', () {
      test(
        'retains revealed cards and previews for unchanged definitions',
        () async {
          final definitions = List.generate(
            30,
            (i) => Nip58BadgeDefinition(
              event: _definition.event,
              coordinate: '30009:$_issuer:group-$i',
              dTag: 'group-$i',
            ),
          );
          final changed = Nip58BadgeDefinition(
            event: Event.fromJson({
              ..._definition.event.toJson(),
              'id': '2'.padLeft(64, '0'),
            }),
            coordinate: definitions[1].coordinate,
            dTag: definitions[1].dTag,
          );
          var loads = 0;
          when(repository.loadPublicDefinitions).thenAnswer(
            (_) async => loads++ == 0
                ? definitions
                : [definitions.first, changed, ...definitions.skip(3)],
          );
          final holder = '3'.padLeft(64, '0');
          when(() => repository.loadHolderPreview(any())).thenAnswer(
            (_) async => [holder],
          );
          final cubit = ExploreBadgesCubit(repository: repository);
          addTearDown(cubit.close);
          await cubit.load();
          cubit.showMore();
          for (final definition in definitions.take(3)) {
            cubit.loadPreview(definition.coordinate);
          }
          await pumpEventQueue();
          expect(cubit.state.previews, hasLength(3));

          await cubit.refresh();

          expect(cubit.state.visibleDefinitions, hasLength(29));
          expect(cubit.state.previews, {
            definitions.first.coordinate: [holder],
          });
          cubit.loadPreview(definitions.first.coordinate);
          await pumpEventQueue();
          verify(() => repository.loadHolderPreview(any())).called(3);
        },
      );

      test(
        'failed refresh keeps loaded previews and attempted reads deduplicated',
        () async {
          final second = Nip58BadgeDefinition(
            event: _definition.event,
            coordinate: '30009:$_issuer:second',
            dTag: 'second',
          );
          final holder = '3'.padLeft(64, '0');
          var loads = 0;
          when(repository.loadPublicDefinitions).thenAnswer((_) async {
            if (loads++ == 0) return [_definition, second];
            throw const BadgeReadIncompleteException('incomplete read');
          });
          when(() => repository.loadHolderPreview(any())).thenAnswer(
            (invocation) async {
              final coordinate =
                  invocation.positionalArguments.single as BadgeCoordinate;
              if (coordinate.identifier == 'second') {
                throw Exception('holder index unavailable');
              }
              return [holder];
            },
          );
          final cubit = ExploreBadgesCubit(repository: repository);
          addTearDown(cubit.close);
          await cubit.load();
          cubit.loadPreview(_definition.coordinate);
          cubit.loadPreview(second.coordinate);
          await pumpEventQueue();
          expect(cubit.state.previews, {
            _definition.coordinate: [holder],
          });
          await cubit.refresh();
          expect(cubit.state.refreshFailures, 1);

          cubit.loadPreview(_definition.coordinate);
          cubit.loadPreview(second.coordinate);
          await pumpEventQueue();

          expect(cubit.state.previews, {
            _definition.coordinate: [holder],
          });
          verify(() => repository.loadHolderPreview(any())).called(2);
        },
      );

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
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
            refreshGeneration: 1,
            isRefreshing: true,
          ),
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
            refreshGeneration: 1,
            refreshFailures: 1,
          ),
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
          const ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            refreshGeneration: 1,
            isRefreshing: true,
          ),
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
            refreshGeneration: 1,
            previewGeneration: 1,
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
