// ABOUTME: Tests for ListsDiscoveryCubit: independent column loading,
// ABOUTME: own-list exclusion, ordering, thumbnail hydration, close guard.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_cubit.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

final String _viewer = 'f' * 64;
final String _author = 'a' * 64;

CuratedList _videoList(
  String id, {
  String? pubkey,
  int createdAtYear = 2026,
  List<String> thumbnailUrls = const [],
}) => CuratedList(
  id: id,
  name: 'List $id',
  pubkey: pubkey ?? _author,
  videoEventIds: const ['v1'],
  createdAt: DateTime(createdAtYear),
  updatedAt: DateTime(createdAtYear),
  thumbnailUrls: thumbnailUrls,
);

PeopleListSearchResult _peopleList(String id) => PeopleListSearchResult(
  ownerPubkey: _author,
  list: UserList(
    id: id,
    name: 'People $id',
    pubkeys: [_author],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
);

void main() {
  group(ListsDiscoveryCubit, () {
    late _MockCuratedListService service;
    late _MockCuratedListRepository curatedRepository;
    late _MockPeopleListsRepository peopleRepository;

    setUp(() {
      service = _MockCuratedListService();
      curatedRepository = _MockCuratedListRepository();
      peopleRepository = _MockPeopleListsRepository();
    });

    ListsDiscoveryCubit buildCubit() => ListsDiscoveryCubit(
      curatedListService: service,
      curatedListRepository: curatedRepository,
      peopleListsRepository: peopleRepository,
      viewerPubkey: _viewer,
    );

    group('seedForScreenshots', () {
      test('emits both columns successful without touching relays', () {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        cubit.seedForScreenshots(videoLists: [_videoList('fixture')]);

        expect(
          cubit.state.videoStatus,
          equals(ListsDiscoveryColumnStatus.success),
        );
        expect(
          cubit.state.peopleStatus,
          equals(ListsDiscoveryColumnStatus.success),
        );
        expect(cubit.state.videoLists.single.id, equals('fixture'));
        verifyZeroInteractions(service);
        verifyZeroInteractions(peopleRepository);
      });
    });

    group('load', () {
      test('populates both columns, newest first, without own lists', () async {
        final older = _videoList('older', createdAtYear: 2024);
        final newer = _videoList('newer');
        final mine = _videoList('mine', pubkey: _viewer);
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value([older, mine, newer]));
        when(
          () => curatedRepository.resolveListThumbnails(
            any(),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
        ).thenAnswer(
          (invocation) async => [
            for (final list
                in invocation.positionalArguments.first as List<CuratedList>)
              list.copyWith(thumbnailUrls: ['https://example.com/t.jpg']),
          ],
        );
        when(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => [_peopleList('crew')]);

        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.load();

        expect(
          cubit.state.videoStatus,
          equals(ListsDiscoveryColumnStatus.success),
        );
        expect(
          cubit.state.videoLists.map((l) => l.id),
          equals(['newer', 'older']),
        );
        expect(
          cubit.state.videoLists.first.thumbnailUrls,
          equals(['https://example.com/t.jpg']),
        );
        expect(
          cubit.state.peopleStatus,
          equals(ListsDiscoveryColumnStatus.success),
        );
        expect(cubit.state.peopleLists.single.list.name, 'People crew');
        verify(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: _viewer,
          ),
        ).called(1);
      });

      test(
        'fails only the video column when its stream errors empty',
        () async {
          when(
            () =>
                service.streamPublicListsFromRelays(limit: any(named: 'limit')),
          ).thenAnswer((_) => Stream.error(Exception('relay down')));
          when(
            () => peopleRepository.discoverPublicLists(
              limit: any(named: 'limit'),
              excludeAuthor: any(named: 'excludeAuthor'),
            ),
          ).thenAnswer((_) async => [_peopleList('crew')]);

          final cubit = buildCubit();
          addTearDown(cubit.close);

          await cubit.load();

          expect(
            cubit.state.videoStatus,
            equals(ListsDiscoveryColumnStatus.failure),
          );
          expect(
            cubit.state.peopleStatus,
            equals(ListsDiscoveryColumnStatus.success),
          );
          expect(cubit.state.peopleLists, hasLength(1));
        },
      );

      test('keeps streamed lists when the stream errors after data', () async {
        final controller = StreamController<List<CuratedList>>();
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => controller.stream);
        when(
          () => curatedRepository.resolveListThumbnails(
            any(),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
        ).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as List<CuratedList>,
        );
        when(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => const []);

        final cubit = buildCubit();
        addTearDown(cubit.close);

        final load = cubit.load();
        controller.add([_videoList('kept')]);
        await pumpEventQueue();
        controller.addError(Exception('relay hiccup'));
        await controller.close();
        await load;

        expect(
          cubit.state.videoStatus,
          equals(ListsDiscoveryColumnStatus.success),
        );
        expect(cubit.state.videoLists.single.id, equals('kept'));
      });

      test('fails only the people column when its query throws', () async {
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value([_videoList('one')]));
        when(
          () => curatedRepository.resolveListThumbnails(
            any(),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
        ).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as List<CuratedList>,
        );
        when(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenThrow(Exception('relay down'));

        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.load();

        expect(
          cubit.state.videoStatus,
          equals(ListsDiscoveryColumnStatus.success),
        );
        expect(cubit.state.videoLists, hasLength(1));
        expect(
          cubit.state.peopleStatus,
          equals(ListsDiscoveryColumnStatus.failure),
        );
      });

      test('keeps placeholder lists when thumbnail hydration throws', () async {
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value([_videoList('bare')]));
        when(
          () => curatedRepository.resolveListThumbnails(
            any(),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
        ).thenThrow(Exception('funnelcake down'));
        when(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => const []);

        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.load();

        expect(
          cubit.state.videoStatus,
          equals(ListsDiscoveryColumnStatus.success),
        );
        expect(cubit.state.videoLists.single.id, equals('bare'));
        expect(cubit.state.videoLists.single.thumbnailUrls, isEmpty);
      });

      test(
        'completes a superseded load future when a refresh cancels it',
        () async {
          final first = StreamController<List<CuratedList>>();
          final second = StreamController<List<CuratedList>>();
          var call = 0;
          when(
            () =>
                service.streamPublicListsFromRelays(limit: any(named: 'limit')),
          ).thenAnswer((_) => call++ == 0 ? first.stream : second.stream);
          when(
            () => peopleRepository.discoverPublicLists(
              limit: any(named: 'limit'),
              excludeAuthor: any(named: 'excludeAuthor'),
            ),
          ).thenAnswer((_) async => const []);

          final cubit = buildCubit();
          addTearDown(cubit.close);

          // BlocProvider.create fires this one and never awaits it.
          var firstDone = false;
          unawaited(cubit.load().then((_) => firstDone = true));
          await pumpEventQueue();

          // RefreshIndicator fires this one and does await it.
          var secondDone = false;
          unawaited(cubit.load().then((_) => secondDone = true));
          await pumpEventQueue();

          second.add([_videoList('fresh')]);
          await second.close();
          await pumpEventQueue();

          expect(secondDone, isTrue);
          expect(
            firstDone,
            isTrue,
            reason:
                'cancel() fires no onDone, so the superseded latch must be '
                'released by the load that supersedes it',
          );
          await first.close();
        },
      );

      test('a superseded hydration does not overwrite a newer load', () async {
        final first = StreamController<List<CuratedList>>();
        final second = StreamController<List<CuratedList>>();
        var call = 0;
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => call++ == 0 ? first.stream : second.stream);
        when(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => const []);

        // The first resolve is still in flight when the refresh lands.
        final slowResolve = Completer<List<CuratedList>>();
        var resolves = 0;
        when(
          () => curatedRepository.resolveListThumbnails(
            any(),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
        ).thenAnswer((invocation) {
          if (resolves++ == 0) return slowResolve.future;
          return Future.value(
            invocation.positionalArguments.first as List<CuratedList>,
          );
        });

        final cubit = buildCubit();
        addTearDown(cubit.close);

        unawaited(cubit.load());
        await pumpEventQueue();
        first.add([_videoList('stale')]);
        await first.close();
        await pumpEventQueue();

        unawaited(cubit.load());
        await pumpEventQueue();
        second.add([_videoList('fresh')]);
        await second.close();
        await pumpEventQueue();
        expect(cubit.state.videoLists.single.id, equals('fresh'));

        slowResolve.complete([_videoList('stale')]);
        await pumpEventQueue();

        expect(
          cubit.state.videoLists.single.id,
          equals('fresh'),
          reason: 'the first load resolve must not revert the refreshed column',
        );
      });

      test('drops emissions after close without throwing', () async {
        final controller = StreamController<List<CuratedList>>();
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => controller.stream);
        when(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => const []);

        final cubit = buildCubit();
        final load = cubit.load();
        await pumpEventQueue();
        await cubit.close();

        controller.add([_videoList('late')]);
        await controller.close();

        await expectLater(load, completes);
        await controller.done;
      });
    });
  });
}
