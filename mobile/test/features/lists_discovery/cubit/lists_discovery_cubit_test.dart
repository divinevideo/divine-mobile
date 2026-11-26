// ABOUTME: Tests for ListsDiscoveryCubit: independent column loading,
// ABOUTME: own and blocked list exclusion, the column cap, close guard.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_cubit.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

final String _viewer = 'f' * 64;
final String _author = 'a' * 64;

CuratedListSearchResult _videoList(
  String id, {
  String? pubkey,
  List<String> thumbnailUrls = const [],
}) => CuratedListSearchResult(
  CuratedList(
    id: id,
    name: 'List $id',
    pubkey: pubkey ?? _author,
    videoEventIds: const ['v1'],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    thumbnailUrls: thumbnailUrls,
  ),
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

List<String> _ids(List<CuratedListSearchResult> results) => [
  for (final result in results) result.list.id,
];

void main() {
  group('relay read budget', () {
    test('people-list reads wait as long as video-list reads', () {
      // Both columns of the Explore Lists tab read on the first query after
      // launch, while the startup syncs hold the relay pool. One budget for
      // both, or one column times out where the other waits.
      expect(
        kPublicPeopleListsRelayReadTimeout,
        equals(kPublicCuratedListsRelayReadTimeout),
      );
    });
  });

  group(ListsDiscoveryCubit, () {
    late _MockCuratedListRepository curatedRepository;
    late _MockPeopleListsRepository peopleRepository;

    setUp(() {
      curatedRepository = _MockCuratedListRepository();
      peopleRepository = _MockPeopleListsRepository();
    });

    ListsDiscoveryCubit buildCubit({
      ListsDiscoveryState? seed,
      bool Function(String)? blockFilter,
      bool videoInitializationFailed = false,
    }) => ListsDiscoveryCubit(
      curatedListRepository: curatedRepository,
      peopleListsRepository: peopleRepository,
      viewerPubkey: _viewer,
      seed: seed,
      blockFilter: blockFilter,
      videoInitializationFailed: videoInitializationFailed,
    );

    void answerVideos(Stream<List<CuratedListSearchResult>> Function() next) {
      when(
        () => curatedRepository.discoverLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
          maxThumbnails: any(named: 'maxThumbnails'),
        ),
      ).thenAnswer((_) => next());
    }

    void answerPeople(
      Future<List<PeopleListSearchResult>> Function() next,
    ) {
      when(
        () => peopleRepository.discoverPublicLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
        ),
      ).thenAnswer((_) => next());
    }

    void verifyNoVideoDiscovery() => verifyNever(
      () => curatedRepository.discoverLists(
        limit: any(named: 'limit'),
        excludeAuthor: any(named: 'excludeAuthor'),
        maxThumbnails: any(named: 'maxThumbnails'),
      ),
    );

    group('discovery visibility policy', () {
      setUp(() {
        answerVideos(() => const Stream.empty());
        answerPeople(() async => [_peopleList('crew')]);
      });

      test('loads people and video discovery together', () async {
        answerVideos(() => Stream.value([_videoList('video')]));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();
        expect(_ids(cubit.state.videoLists), ['video']);
        expect(cubit.state.peopleLists.single.list.id, 'crew');
      });

      test(
        'failed video initialization keeps independent people query usable',
        () async {
          final cubit = buildCubit(videoInitializationFailed: true);
          addTearDown(cubit.close);
          await cubit.load();
          expect(cubit.state.videoInitializationFailed, isTrue);
          expect(cubit.state.videoStatus, ListsDiscoveryColumnStatus.failure);
          expect(cubit.state.peopleLists.single.list.id, 'crew');
          verifyNoVideoDiscovery();
        },
      );

      test('filters blocked authors before the cap', () async {
        final blocked = 'b' * 64;
        final eligible = [
          for (var i = 0; i < kListsDiscoveryColumnCap; i++)
            _videoList('eligible-$i'),
        ];
        answerVideos(
          () => Stream.value([
            _videoList('blocked', pubkey: blocked),
            ...eligible,
          ]),
        );
        final cubit = buildCubit(blockFilter: (author) => author == blocked);
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.videoLists, eligible);
      });

      test(
        'a block refresh removes cards a superseded load cannot revive',
        () async {
          var blocked = false;
          final firstLoad = StreamController<List<CuratedListSearchResult>>();
          var calls = 0;
          answerVideos(
            () => calls++ == 0
                ? firstLoad.stream
                : Stream.value([_videoList('visible')]),
          );
          final cubit = buildCubit(blockFilter: (_) => blocked);
          addTearDown(cubit.close);
          final first = cubit.load();
          firstLoad.add([_videoList('visible')]);
          await pumpEventQueue();
          expect(_ids(cubit.state.videoLists), ['visible']);

          blocked = true;
          final refreshed = cubit.load();
          expect(cubit.state.videoLists, isEmpty);
          expect(cubit.state.peopleLists, isEmpty);
          await refreshed;
          firstLoad.add([_videoList('visible')]);
          await firstLoad.close();
          await first;
          expect(cubit.state.videoLists, isEmpty);
          expect(cubit.state.peopleLists, isEmpty);

          blocked = false;
          await cubit.load();
          expect(_ids(cubit.state.videoLists), ['visible']);
          expect(cubit.state.peopleLists.single.list.id, 'crew');
        },
      );
    });

    group('seeded construction', () {
      test('starts with both columns successful without touching relays', () {
        final cubit = buildCubit(
          seed: ListsDiscoveryState(
            videoStatus: ListsDiscoveryColumnStatus.success,
            peopleStatus: ListsDiscoveryColumnStatus.success,
            videoLists: [_videoList('fixture')],
          ),
        );
        addTearDown(cubit.close);

        expect(
          cubit.state.videoStatus,
          equals(ListsDiscoveryColumnStatus.success),
        );
        expect(
          cubit.state.peopleStatus,
          equals(ListsDiscoveryColumnStatus.success),
        );
        expect(_ids(cubit.state.videoLists), equals(['fixture']));
        verifyZeroInteractions(curatedRepository);
        verifyZeroInteractions(peopleRepository);
      });

      test(
        'refresh keeps seeded fixtures without any dependency calls',
        () async {
          final videos = [_videoList('fixture')];
          final people = [_peopleList('fixture')];
          final cubit = buildCubit(
            seed: ListsDiscoveryState(
              videoStatus: ListsDiscoveryColumnStatus.success,
              peopleStatus: ListsDiscoveryColumnStatus.success,
              videoLists: videos,
              peopleLists: people,
            ),
          );
          addTearDown(cubit.close);
          final seeded = cubit.state;

          await cubit.load();
          await cubit.load();

          expect(cubit.state, seeded);
          expect(cubit.state.videoLists, videos);
          expect(cubit.state.peopleLists, people);
          verifyZeroInteractions(curatedRepository);
          verifyZeroInteractions(peopleRepository);
        },
      );
    });

    group('load', () {
      for (final oldFails in [false, true]) {
        for (final freshFails in [false, true]) {
          test(
            'ignores an older people query after refresh '
            '(old fails: $oldFails, fresh fails: $freshFails)',
            () async {
              answerVideos(() => const Stream.empty());
              final oldQuery = Completer<List<PeopleListSearchResult>>();
              final freshQuery = Completer<List<PeopleListSearchResult>>();
              var calls = 0;
              answerPeople(
                () => calls++ == 0 ? oldQuery.future : freshQuery.future,
              );
              final cubit = buildCubit();
              addTearDown(cubit.close);

              final oldLoad = cubit.load();
              final freshLoad = cubit.load();
              if (freshFails) {
                freshQuery.completeError(Exception('new request failed'));
              } else {
                freshQuery.complete([_peopleList('fresh')]);
              }
              await freshLoad;
              final refreshed = cubit.state;
              expect(
                refreshed.peopleStatus,
                freshFails
                    ? ListsDiscoveryColumnStatus.failure
                    : ListsDiscoveryColumnStatus.success,
              );
              if (!freshFails) {
                expect(refreshed.peopleLists.single.list.id, 'fresh');
              }

              if (oldFails) {
                oldQuery.completeError(Exception('old request failed'));
              } else {
                oldQuery.complete([_peopleList('stale')]);
              }
              await oldLoad;

              expect(cubit.state, refreshed);
            },
          );
        }
      }

      for (final refreshFails in [false, true]) {
        test(
          'a refresh that finds no lists '
          '${refreshFails ? 'retains useful cards on error' : 'clears old cards on success'}',
          () async {
            var calls = 0;
            answerVideos(() {
              if (calls++ == 0) return Stream.value([_videoList('old')]);
              return refreshFails
                  ? Stream.error(Exception('refresh failed'))
                  : Stream.value(const []);
            });
            answerPeople(() async => const []);
            final cubit = buildCubit();
            addTearDown(cubit.close);

            await cubit.load();
            expect(_ids(cubit.state.videoLists), ['old']);
            await cubit.load();

            expect(cubit.state.videoStatus, ListsDiscoveryColumnStatus.success);
            expect(cubit.state.videoThumbnailsPending, isFalse);
            if (refreshFails) {
              expect(_ids(cubit.state.videoLists), ['old']);
            } else {
              expect(cubit.state.videoLists, isEmpty);
              expect(cubit.state.isEmpty, isTrue);
            }
          },
        );
      }

      test('closing ignores a live people query already in flight', () async {
        final videoStream = StreamController<List<CuratedListSearchResult>>();
        answerVideos(() => videoStream.stream);
        final peopleQuery = Completer<List<PeopleListSearchResult>>();
        answerPeople(() => peopleQuery.future);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final loading = cubit.load();
        await pumpEventQueue();

        await cubit.close();
        final closed = cubit.state;
        // Still loading, so a late result would change it.
        expect(closed.peopleStatus, ListsDiscoveryColumnStatus.loading);
        expect(closed.videoLists, isEmpty);
        peopleQuery.complete([_peopleList('live')]);
        videoStream.add([_videoList('live')]);
        await videoStream.close();
        await loading;

        expect(cubit.state, closed);
      });

      test(
        "asks for a column of lists without the viewer's and caps both",
        () async {
          answerVideos(
            () => Stream.value([
              for (var i = 0; i < kListsDiscoveryColumnCap + 10; i++)
                _videoList('video-$i'),
            ]),
          );
          answerPeople(
            () async => [
              for (var i = 0; i < kListsDiscoveryColumnCap + 10; i++)
                _peopleList('people-$i'),
            ],
          );

          final cubit = buildCubit();
          addTearDown(cubit.close);

          await cubit.load();

          verify(
            () => curatedRepository.discoverLists(
              limit: kListsDiscoveryColumnCap,
              excludeAuthor: _viewer,
            ),
          ).called(1);
          verify(
            () => peopleRepository.discoverPublicLists(
              limit: kPublicListsRelayWindow,
              excludeAuthor: _viewer,
            ),
          ).called(1);
          expect(cubit.state.videoLists, hasLength(kListsDiscoveryColumnCap));
          expect(cubit.state.peopleLists, hasLength(kListsDiscoveryColumnCap));
        },
      );

      test(
        "keeps the repository's order and leaves out the viewer's lists",
        () async {
          answerVideos(
            () => Stream.value([
              _videoList('first'),
              _videoList('mine', pubkey: _viewer),
              _videoList('second'),
            ]),
          );
          answerPeople(() async => [_peopleList('crew')]);

          final cubit = buildCubit();
          addTearDown(cubit.close);

          await cubit.load();

          expect(
            cubit.state.videoStatus,
            equals(ListsDiscoveryColumnStatus.success),
          );
          expect(_ids(cubit.state.videoLists), equals(['first', 'second']));
          expect(
            cubit.state.peopleStatus,
            equals(ListsDiscoveryColumnStatus.success),
          );
          expect(cubit.state.peopleLists.single.list.name, 'People crew');
        },
      );

      test(
        'fails only the video column when its stream errors empty',
        () async {
          answerVideos(() => Stream.error(Exception('relay down')));
          answerPeople(() async => [_peopleList('crew')]);

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

      test(
        'keeps the lists and stops the shimmer when the stream errors '
        'after data',
        () async {
          final controller = StreamController<List<CuratedListSearchResult>>();
          answerVideos(() => controller.stream);
          answerPeople(() async => const []);

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
          expect(_ids(cubit.state.videoLists), equals(['kept']));
          expect(cubit.state.videoThumbnailsPending, isFalse);
        },
      );

      test('fails only the people column when its query throws', () async {
        answerVideos(() => Stream.value([_videoList('one')]));
        answerPeople(() async => throw Exception('relay down'));

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

      test('marks thumbnails pending until the stream ends', () async {
        final controller = StreamController<List<CuratedListSearchResult>>();
        answerVideos(() => controller.stream);
        answerPeople(() async => const []);

        final cubit = buildCubit();
        addTearDown(cubit.close);

        final load = cubit.load();
        controller.add([_videoList('a')]);
        await pumpEventQueue();

        expect(cubit.state.videoLists, hasLength(1));
        expect(cubit.state.videoThumbnailsPending, isTrue);

        controller.add([
          _videoList('a', thumbnailUrls: const ['https://example.com/t.jpg']),
        ]);
        await controller.close();
        await load;

        expect(cubit.state.videoThumbnailsPending, isFalse);
        expect(cubit.state.videoLists.single.list.thumbnailUrls, isNotEmpty);
      });

      test(
        'completes a superseded load future when a refresh cancels it',
        () async {
          final first = StreamController<List<CuratedListSearchResult>>();
          final second = StreamController<List<CuratedListSearchResult>>();
          var call = 0;
          answerVideos(() => call++ == 0 ? first.stream : second.stream);
          answerPeople(() async => const []);

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

      test('drops emissions after close without throwing', () async {
        final controller = StreamController<List<CuratedListSearchResult>>();
        answerVideos(() => controller.stream);
        answerPeople(() async => const []);

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
