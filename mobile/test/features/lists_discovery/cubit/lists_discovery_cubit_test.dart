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
  List<String> videoEventIds = const ['v1'],
  List<String> thumbnailUrls = const [],
}) => CuratedList(
  id: id,
  name: 'List $id',
  pubkey: pubkey ?? _author,
  videoEventIds: videoEventIds,
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
    late _MockCuratedListService service;
    late _MockCuratedListRepository curatedRepository;
    late _MockPeopleListsRepository peopleRepository;

    setUp(() {
      service = _MockCuratedListService();
      curatedRepository = _MockCuratedListRepository();
      peopleRepository = _MockPeopleListsRepository();
    });

    ListsDiscoveryCubit buildCubit({
      ListsDiscoveryState? seed,
      bool peopleListsEnabled = true,
      bool Function(String)? blockFilter,
      bool videoInitializationFailed = false,
    }) => ListsDiscoveryCubit(
      curatedListService: service,
      curatedListRepository: curatedRepository,
      peopleListsRepository: peopleRepository,
      viewerPubkey: _viewer,
      seed: seed,
      peopleListsEnabled: peopleListsEnabled,
      blockFilter: blockFilter,
      videoInitializationFailed: videoInitializationFailed,
    );

    group('discovery visibility policy', () {
      setUp(() {
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => [_peopleList('crew')]);
        when(
          () => curatedRepository.resolveListThumbnails(
            any(),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
        ).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as List<CuratedList>,
        );
      });

      test(
        'master off skips people query and retains video discovery',
        () async {
          when(
            () =>
                service.streamPublicListsFromRelays(limit: any(named: 'limit')),
          ).thenAnswer((_) => Stream.value([_videoList('video')]));
          final cubit = buildCubit(peopleListsEnabled: false);
          addTearDown(cubit.close);
          await cubit.load();
          expect(cubit.state.videoLists.single.id, 'video');
          expect(cubit.state.peopleListsEnabled, isFalse);
          expect(cubit.state.peopleLists, isEmpty);
          verifyNever(
            () => peopleRepository.discoverPublicLists(
              limit: any(named: 'limit'),
              excludeAuthor: any(named: 'excludeAuthor'),
            ),
          );
        },
      );

      test(
        'failed video initialization keeps independent people query usable',
        () async {
          final cubit = buildCubit(videoInitializationFailed: true);
          addTearDown(cubit.close);
          await cubit.load();
          expect(cubit.state.videoInitializationFailed, isTrue);
          expect(cubit.state.videoStatus, ListsDiscoveryColumnStatus.failure);
          expect(cubit.state.peopleLists.single.list.id, 'crew');
          verifyNever(
            () => service.streamPublicListsFromRelays(
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      test('filters blocked authors before cap and thumbnail work', () async {
        final blocked = 'b' * 64;
        final eligible = List.generate(
          kListsDiscoveryColumnCap,
          (index) => _videoList('eligible-$index'),
        );
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer(
          (_) => Stream.value([
            _videoList('blocked', pubkey: blocked, createdAtYear: 2027),
            ...eligible,
          ]),
        );
        final cubit = buildCubit(blockFilter: (author) => author == blocked);
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.videoLists, hasLength(kListsDiscoveryColumnCap));
        final hydrated =
            verify(
                  () => curatedRepository.resolveListThumbnails(
                    captureAny(),
                    maxThumbnails: any(named: 'maxThumbnails'),
                  ),
                ).captured.single
                as List<CuratedList>;
        expect(hydrated, eligible);
      });

      test('block during hydration removes cards and late results cannot revive them', () async {
        var blocked = false;
        final resolve = Completer<List<CuratedList>>();
        var resolveCalls = 0;
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value([_videoList('visible')]));
        when(
          () => curatedRepository.resolveListThumbnails(
            any(),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
        ).thenAnswer(
          (invocation) => resolveCalls++ == 0
              ? resolve.future
              : Future.value(
                  invocation.positionalArguments.first as List<CuratedList>,
                ),
        );
        final cubit = buildCubit(blockFilter: (_) => blocked);
        addTearDown(cubit.close);
        final first = cubit.load();
        await pumpEventQueue();
        expect(cubit.state.videoLists.single.id, 'visible');
        blocked = true;
        final refreshed = cubit.load();
        expect(cubit.state.videoLists, isEmpty);
        expect(cubit.state.peopleLists, isEmpty);
        await refreshed;
        resolve.complete([_videoList('visible')]);
        await first;
        expect(cubit.state.videoLists, isEmpty);
        expect(cubit.state.peopleLists, isEmpty);
        blocked = false;
        await cubit.load();
        expect(cubit.state.videoLists.single.id, 'visible');
        expect(cubit.state.peopleLists.single.list.id, 'crew');
      });
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
        expect(cubit.state.videoLists.single.id, equals('fixture'));
        verifyZeroInteractions(service);
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
          verifyZeroInteractions(service);
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
              when(
                () => service.streamPublicListsFromRelays(
                  limit: any(named: 'limit'),
                ),
              ).thenAnswer((_) => const Stream.empty());
              final oldQuery = Completer<List<PeopleListSearchResult>>();
              final freshQuery = Completer<List<PeopleListSearchResult>>();
              var calls = 0;
              when(
                () => peopleRepository.discoverPublicLists(
                  limit: any(named: 'limit'),
                  excludeAuthor: any(named: 'excludeAuthor'),
                ),
              ).thenAnswer(
                (_) => calls++ == 0 ? oldQuery.future : freshQuery.future,
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
          'refresh with no video emissions '
          '${refreshFails ? 'retains useful cards on error' : 'clears old cards on success'}',
          () async {
            var calls = 0;
            when(
              () => service.streamPublicListsFromRelays(
                limit: any(named: 'limit'),
              ),
            ).thenAnswer((_) {
              if (calls++ == 0) return Stream.value([_videoList('old')]);
              return refreshFails
                  ? Stream.error(Exception('refresh failed'))
                  : const Stream.empty();
            });
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

            await cubit.load();
            expect(cubit.state.videoLists.single.id, 'old');
            await cubit.load();

            expect(cubit.state.videoStatus, ListsDiscoveryColumnStatus.success);
            expect(cubit.state.videoThumbnailsPending, isFalse);
            if (refreshFails) {
              expect(cubit.state.videoLists.single.id, 'old');
            } else {
              expect(cubit.state.videoLists, isEmpty);
              expect(cubit.state.isEmpty, isTrue);
            }
          },
        );
      }

      test('closing ignores a live people query already in flight', () async {
        final videoStream = StreamController<List<CuratedList>>();
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => videoStream.stream);
        final peopleQuery = Completer<List<PeopleListSearchResult>>();
        when(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) => peopleQuery.future);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final loading = cubit.load();
        await pumpEventQueue();

        await cubit.close();
        final closed = cubit.state;
        peopleQuery.complete([_peopleList('live')]);
        videoStream.add([_videoList('live')]);
        await videoStream.close();
        await loading;

        expect(cubit.state, closed);
        verifyZeroInteractions(curatedRepository);
      });

      test(
        'reads the shared relay window and caps what each column shows',
        () async {
          // The window is wide so real lists surface past the empty default
          // placeholders; the cap bounds the cards built and the thumbnails
          // resolved. Sixty lists in, fifty cards out, per column.
          when(
            () =>
                service.streamPublicListsFromRelays(limit: any(named: 'limit')),
          ).thenAnswer(
            (_) => Stream.value([
              for (var i = 0; i < kListsDiscoveryColumnCap + 10; i++)
                _videoList('video-$i'),
            ]),
          );
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
          ).thenAnswer(
            (_) async => [
              for (var i = 0; i < kListsDiscoveryColumnCap + 10; i++)
                _peopleList('people-$i'),
            ],
          );

          final cubit = buildCubit();
          addTearDown(cubit.close);

          await cubit.load();

          final window = verify(
            () => service.streamPublicListsFromRelays(
              limit: captureAny(named: 'limit'),
            ),
          ).captured.single;
          expect(window, equals(kPublicListsRelayWindow));
          verify(
            () => peopleRepository.discoverPublicLists(
              limit: kPublicListsRelayWindow,
              excludeAuthor: _viewer,
            ),
          ).called(1);
          expect(cubit.state.videoLists, hasLength(kListsDiscoveryColumnCap));
          expect(cubit.state.peopleLists, hasLength(kListsDiscoveryColumnCap));
          final resolved =
              verify(
                    () => curatedRepository.resolveListThumbnails(
                      captureAny(),
                      maxThumbnails: any(named: 'maxThumbnails'),
                    ),
                  ).captured.single
                  as List<CuratedList>;
          expect(resolved, hasLength(kListsDiscoveryColumnCap));
          expect(kListsDiscoveryColumnCap, lessThan(kPublicListsRelayWindow));
        },
      );

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

      test('hides streamed lists that have no videos', () async {
        final bare = _videoList('bare', videoEventIds: const []);
        final full = _videoList('full');
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value([bare, full]));
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

        await cubit.load();

        expect(cubit.state.videoLists.map((l) => l.id), equals(['full']));
        final resolved =
            verify(
                  () => curatedRepository.resolveListThumbnails(
                    captureAny(),
                    maxThumbnails: any(named: 'maxThumbnails'),
                  ),
                ).captured.single
                as List<CuratedList>;
        expect(resolved.map((l) => l.id), equals(['full']));
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

      test('marks thumbnails pending until the resolver returns', () async {
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value([_videoList('a')]));
        final resolve = Completer<List<CuratedList>>();
        when(
          () => curatedRepository.resolveListThumbnails(
            any(),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
        ).thenAnswer((_) => resolve.future);
        when(
          () => peopleRepository.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => []);

        final cubit = buildCubit();
        addTearDown(cubit.close);

        final load = cubit.load();
        await Future<void>(() {});
        await Future<void>(() {});

        expect(cubit.state.videoLists, hasLength(1));
        expect(cubit.state.videoThumbnailsPending, isTrue);

        resolve.complete([
          _videoList('a', thumbnailUrls: const ['https://example.com/t.jpg']),
        ]);
        await load;

        expect(cubit.state.videoThumbnailsPending, isFalse);
        expect(cubit.state.videoLists.single.thumbnailUrls, isNotEmpty);
      });

      test(
        'keeps placeholder cards and stops the shimmer when hydration throws',
        () async {
          when(
            () =>
                service.streamPublicListsFromRelays(limit: any(named: 'limit')),
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
          expect(cubit.state.videoThumbnailsPending, isFalse);
        },
      );

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

      test(
        'does not resolve thumbnails for a load closed mid-stream',
        () async {
          final controller = StreamController<List<CuratedList>>();
          when(
            () =>
                service.streamPublicListsFromRelays(limit: any(named: 'limit')),
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
          final load = cubit.load();
          controller.add([_videoList('streamed')]);
          await pumpEventQueue();
          expect(cubit.state.videoLists.single.id, equals('streamed'));

          await cubit.close();
          await load;

          verifyNever(
            () => curatedRepository.resolveListThumbnails(
              any(),
              maxThumbnails: any(named: 'maxThumbnails'),
            ),
          );
          await controller.close();
        },
      );
    });
  });
}
