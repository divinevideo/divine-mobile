// ABOUTME: Tests for the list providers: member videos, video events by id,
// ABOUTME: curated list videos and the public people and curated list reads.

import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/features/people_lists/bloc/people_list_info_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../packages/people_lists_repository/test/helpers/in_memory_followed_people_lists_store.dart';

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

/// A feed pool holding [videos], standing in for the live discovery stream.
class _VideoEventsPool extends VideoEvents {
  _VideoEventsPool(this.videos);

  final List<VideoEvent> videos;

  @override
  Stream<List<VideoEvent>> build() async* {
    yield videos;
  }
}

/// Holds the repository a test's container serves, so the test can replace it
/// the way a filter change or an account switch rebuilds it.
class _ActiveRepository extends Notifier<VideosRepository> {
  _ActiveRepository(this._initial);

  final VideosRepository _initial;

  @override
  VideosRepository build() => _initial;

  void replace(VideosRepository repository) => state = repository;
}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

// Full-length 64-char Nostr pubkeys — never truncate.
const String _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _blockedAuthor =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
// Full-length 64-char hex event ids — the plain-event-ID branch requires them.
const String _blockedVideoId =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const String _allowedVideoId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

final DateTime _frozenNow = DateTime.utc(2026, 4, 20, 12);

VideoEvent _video({
  required String id,
  required String pubkey,
  String? dTag,
  int? createdAt,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt ?? _frozenNow.millisecondsSinceEpoch ~/ 1000,
    content: '',
    timestamp: _frozenNow,
    title: id,
    videoUrl: 'https://example.com/$id.mp4',
    rawTags: dTag == null ? const {} : {'d': dTag},
  );
}

void main() {
  group(userListMemberVideosProvider, () {
    const fetchedId =
        '0000000000000000000000000000000000000000000000000000000000000bb8';
    const pooledId =
        '0000000000000000000000000000000000000000000000000000000000000bb9';
    const strangerId =
        '0000000000000000000000000000000000000000000000000000000000000bba';
    late _MockVideosRepository videosRepository;

    List<VideoEvent> passThrough(Invocation invocation) =>
        invocation.positionalArguments.single as List<VideoEvent>;

    setUp(() {
      videosRepository = _MockVideosRepository();
      when(
        () => videosRepository.applyContentPreferences(any()),
      ).thenAnswer(passThrough);
    });

    ProviderContainer buildContainer({List<VideoEvent> pooled = const []}) {
      final container = ProviderContainer(
        overrides: [
          videosRepositoryProvider.overrideWithValue(videosRepository),
          videoEventsProvider.overrideWith(() => _VideoEventsPool(pooled)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// Lets the pool emit, then collects every state the provider emits for
    /// [members]. Returns once the event queue drains; the list keeps
    /// collecting until the test ends.
    Future<List<AsyncValue<List<VideoEvent>>>> collect(
      ProviderContainer container,
      List<String> members,
    ) async {
      final pool = container.listen(videoEventsProvider, (_, _) {});
      addTearDown(pool.close);
      await container.read(videoEventsProvider.future);

      final states = <AsyncValue<List<VideoEvent>>>[];
      final subscription = container.listen(
        userListMemberVideosProvider(members),
        (_, next) => states.add(next),
      );
      addTearDown(subscription.close);
      await pumpEventQueue();
      return states;
    }

    List<List<String>> idsOf(List<AsyncValue<List<VideoEvent>>> states) => [
      for (final state in states)
        if (state.hasValue) [for (final video in state.value!) video.id],
    ];

    test('real info cubit rename cache add remove delete shares roster feeds '
        'and preserves source under a fixed clock', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 10, 4)), () async {
        final dir = await Directory.systemTemp.createTemp('review-roster-');
        Box<dynamic>? box;
        addTearDown(() async {
          await box?.close();
          await dir.delete(recursive: true);
        });
        registerFallbackValue(<Filter>[]);
        registerFallbackValue(Duration.zero);
        registerFallbackValue(Event(_ownerA, 1, [], ''));
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerA);
        final stamp = DateTime.utc(2026, 10, 4).millisecondsSinceEpoch ~/ 1000;
        var remote = Event(
          _ownerA,
          30000,
          [
            ['d', 'crew'],
            ['title', 'Old name'],
            ['p', _ownerB, 'wss://one.example', 'friend'],
            ['p', _ownerB, 'wss://two.example', 'hint'],
            ['expiration', '2000000000'],
          ],
          'foreign-ciphertext',
          createdAt: stamp,
        );
        final sent = <Event>[];
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: [remote], timedOut: false, noRelays: false),
        );
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.first as Event;
          sent.add(event);
          if (event.kind == 30000 &&
              (event.createdAt > remote.createdAt ||
                  (event.createdAt == remote.createdAt &&
                      event.id.compareTo(remote.id) < 0))) {
            remote = event;
          }
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });
        final repository = PeopleListsRepositoryImpl(
          nostrClient: client,
          cache: LocalPeopleListsCache(
            openBox: () async =>
                box ??= await Hive.openBox<dynamic>('roster', path: dir.path),
          ),
          followedListsStore: InMemoryFollowedPeopleListsStore(),
        );
        final queries = <List<String>>[];
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenAnswer((i) async {
          final authors = i.namedArguments[#authorPubkeys] as List<String>;
          queries.add(List.of(authors));
          return [
            for (final author in authors)
              _video(
                id: author == _ownerB ? fetchedId : strangerId,
                pubkey: author,
              ),
          ];
        });
        final container = buildContainer();
        await repository.syncOwner(ownerPubkey: _ownerA);
        final initial = (await repository.readLists(ownerPubkey: _ownerA))
            .single;
        expect(initial.pubkeys, [_ownerB]);
        await collect(container, initial.pubkeys);
        final mutations = PeopleListsBloc(
          repository: repository,
          ownerPubkeyStream: const Stream.empty(),
          repositoryStream: const Stream.empty(),
          enabledStream: const Stream.empty(),
          initialOwnerPubkey: _ownerA,
          clock: () => DateTime.utc(2026, 10, 4),
        );
        addTearDown(mutations.close);
        final openingEpoch = mutations.mutationSessionEpoch;
        final cubit = PeopleListInfoCubit(
          submitMutation: mutations.submit,
          ownerPubkey: _ownerA,
          list: initial,
          currentOwnerPubkey: () =>
              !mutations.isClosed &&
                  mutations.mutationSessionEpoch == openingEpoch
              ? mutations.state.activeOwnerPubkey
              : null,
        );
        addTearDown(cubit.close);
        cubit.nameChanged('New name');
        expect(await cubit.submitted(), PeopleListInfoStatus.saved);
        final renamed = (await repository.readLists(ownerPubkey: _ownerA))
            .single;
        expect(renamed.name, 'New name');
        expect(identical(initial.pubkeys, renamed.pubkeys), isFalse);
        await collect(container, renamed.pubkeys);
        expect(queries, [
          [_ownerB],
        ]);
        expect(
          (await repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'crew',
            pubkey: _blockedAuthor,
          )).submitted,
          isTrue,
        );
        final expanded = (await repository.readLists(ownerPubkey: _ownerA))
            .single;
        await collect(container, expanded.pubkeys);
        expect(queries, [
          [_ownerB],
          [_ownerB, _blockedAuthor],
        ]);
        expect(
          remote.tags.where((t) => t.first == 'p' && t[1] == _ownerB),
          hasLength(2),
        );
        expect(
          (await repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'crew',
            pubkey: _ownerB,
          )).submitted,
          isTrue,
        );
        final reduced = (await repository.readLists(ownerPubkey: _ownerA))
            .single;
        await collect(container, reduced.pubkeys);
        expect(queries, [
          [_ownerB],
          [_ownerB, _blockedAuthor],
          [_blockedAuthor],
        ]);
        expect(remote.content, 'foreign-ciphertext');
        expect(remote.tags, contains(equals(['expiration', '2000000000'])));
        expect(
          (await repository.deleteList(
            ownerPubkey: _ownerA,
            listId: 'crew',
          )).submitted,
          isTrue,
        );
        expect(await repository.readLists(ownerPubkey: _ownerA), isEmpty);
        var previous = stamp;
        for (final event in sent) {
          expect(event.createdAt, greaterThan(previous));
          previous = event.createdAt;
        }
      });
    });

    test(
      'reuses the feed after unchanged members are decoded from cache',
      () async {
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenAnswer((_) async => const []);
        final initial = UserList(
          id: 'crew',
          name: 'Old name',
          pubkeys: const [_ownerA, _ownerB],
          createdAt: _frozenNow,
          updatedAt: _frozenNow,
        );
        final renamed = UserList.fromJson(
          initial.copyWith(name: 'New name').toJson(),
        );
        expect(identical(initial.pubkeys, renamed.pubkeys), isFalse);

        final container = buildContainer();
        await collect(container, initial.pubkeys);
        await collect(container, renamed.pubkeys);

        verify(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).called(1);
      },
    );

    test(
      'reuses reordered members without changing the caller roster',
      () async {
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenAnswer((_) async => const []);
        final members = [_ownerB, _ownerA, _ownerB];
        final container = buildContainer();

        await collect(container, members);
        await collect(container, [_ownerA, _ownerB]);

        expect(members, [_ownerB, _ownerA, _ownerB]);
        final queriedMembers = verify(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: captureAny(named: 'authorPubkeys'),
          ),
        ).captured;
        expect(queriedMembers, [
          equals([_ownerA, _ownerB]),
        ]);
      },
    );

    test('fetches a different feed when membership changes', () async {
      when(
        () => videosRepository.getVideosByAuthors(
          authorPubkeys: any(named: 'authorPubkeys'),
        ),
      ).thenAnswer((_) async => const []);
      final container = buildContainer();

      await collect(container, [_ownerA]);
      await collect(container, [_ownerA, _ownerB]);

      verify(
        () => videosRepository.getVideosByAuthors(
          authorPubkeys: any(named: 'authorPubkeys'),
        ),
      ).called(2);
    });

    test('keeps delimiter-containing malformed rosters separate', () async {
      when(
        () => videosRepository.getVideosByAuthors(
          authorPubkeys: any(named: 'authorPubkeys'),
        ),
      ).thenAnswer((_) async => const []);
      final container = buildContainer();

      await collect(container, [_ownerA, _ownerB]);
      await collect(container, ['$_ownerA,$_ownerB']);

      verify(
        () => videosRepository.getVideosByAuthors(
          authorPubkeys: any(named: 'authorPubkeys'),
        ),
      ).called(2);
    });

    test("fetches the members' videos through the repository", () async {
      final fetched = _video(
        id: fetchedId,
        pubkey: _ownerA,
      );
      when(
        () => videosRepository.getVideosByAuthors(
          authorPubkeys: any(named: 'authorPubkeys'),
        ),
      ).thenAnswer((_) async => [fetched]);

      final states = await collect(buildContainer(), [_ownerA, _ownerB]);

      expect(
        idsOf(states),
        equals([
          [fetchedId],
        ]),
      );
      final asked =
          verify(
                () => videosRepository.getVideosByAuthors(
                  authorPubkeys: captureAny(named: 'authorPubkeys'),
                ),
              ).captured.single
              as List<String>;
      expect(asked, equals([_ownerA, _ownerB]));
    });

    test(
      'paints pooled member videos first, then merges the fetched set',
      () async {
        final pooledMember = _video(
          id: pooledId,
          pubkey: _ownerA,
          createdAt: 100,
        );
        final stranger = _video(
          id: strangerId,
          pubkey: _blockedAuthor,
          createdAt: 300,
        );
        final fetched = _video(
          id: fetchedId,
          pubkey: _ownerB,
          createdAt: 200,
        );
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenAnswer((_) async => [fetched]);

        final states = await collect(
          buildContainer(pooled: [pooledMember, stranger]),
          [_ownerA, _ownerB],
        );

        expect(
          idsOf(states),
          equals([
            [pooledId],
            [
              fetchedId,
              pooledId,
            ],
          ]),
        );
      },
    );

    test(
      'replaces a pooled copy with the fetched video without duplicates',
      () async {
        const id =
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
        final pooled = _video(id: id, pubkey: _ownerA, createdAt: 100);
        final fetched = _video(id: id, pubkey: _ownerA, createdAt: 200);
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenAnswer((_) async => [fetched]);

        final states = await collect(buildContainer(pooled: [pooled]), [
          _ownerA,
        ]);

        expect(states.last.requireValue, [fetched]);
        expect(states.last.requireValue.single.createdAt, 200);
      },
    );

    test(
      'replaces a pooled revision of an edited video with the fetched one',
      () async {
        // An edit republishes the video under a new event id and the same
        // d-tag, and the pool can still hold the revision before it.
        final previous = _video(
          id: pooledId,
          pubkey: _ownerA,
          dTag: 'clip',
          createdAt: 100,
        ).copyWith(addressableDTag: 'clip');
        final edited = _video(
          id: fetchedId,
          pubkey: _ownerA,
          dTag: 'clip',
          createdAt: 200,
        ).copyWith(addressableDTag: 'clip');
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenAnswer((_) async => [edited]);

        final states = await collect(buildContainer(pooled: [previous]), [
          _ownerA,
        ]);

        expect(
          idsOf(states),
          equals([
            [pooledId],
            [fetchedId],
          ]),
        );
      },
    );

    test(
      'drops the videos of a member blocked while the list is open',
      () async {
        // A block only bumps the blocklist version, and the pool can still
        // hold the blocked member's videos when the list re-runs.
        final blocked = <String>{};
        bool visible(VideoEvent video) => !blocked.contains(video.pubkey);
        when(
          () => videosRepository.applyContentPreferences(any()),
        ).thenAnswer(
          (invocation) => passThrough(invocation).where(visible).toList(),
        );
        final pooledMember = _video(
          id: pooledId,
          pubkey: _ownerA,
          createdAt: 100,
        );
        final fetchedMember = _video(
          id: fetchedId,
          pubkey: _ownerB,
          createdAt: 200,
        );
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenAnswer((_) async => [fetchedMember].where(visible).toList());
        final container = buildContainer(pooled: [pooledMember]);
        final states = await collect(container, [_ownerA, _ownerB]);
        expect(idsOf(states).last, equals([fetchedId, pooledId]));

        blocked.add(_ownerA);
        container.read(blocklistVersionProvider.notifier).increment();
        await pumpEventQueue();

        expect(idsOf(states).last, equals([fetchedId]));
      },
    );

    test('refetches through the repository when it is rebuilt', () async {
      // A filter change or an account switch rebuilds the repository.
      const beforeId =
          '0000000000000000000000000000000000000000000000000000000000000bbb';
      const afterId =
          '0000000000000000000000000000000000000000000000000000000000000bbc';
      final rebuilt = _MockVideosRepository();
      when(() => rebuilt.applyContentPreferences(any()))
          .thenAnswer(passThrough);
      when(
        () => videosRepository.getVideosByAuthors(
          authorPubkeys: any(named: 'authorPubkeys'),
        ),
      ).thenAnswer((_) async => [_video(id: beforeId, pubkey: _ownerA)]);
      when(
        () => rebuilt.getVideosByAuthors(
          authorPubkeys: any(named: 'authorPubkeys'),
        ),
      ).thenAnswer((_) async => [_video(id: afterId, pubkey: _ownerA)]);
      final active = NotifierProvider<_ActiveRepository, VideosRepository>(
        () => _ActiveRepository(videosRepository),
      );
      final container = ProviderContainer(
        overrides: [
          videosRepositoryProvider.overrideWith((ref) => ref.watch(active)),
          videoEventsProvider.overrideWith(() => _VideoEventsPool(const [])),
        ],
      );
      addTearDown(container.dispose);
      final states = await collect(container, [_ownerA]);
      expect(idsOf(states).last, equals([beforeId]));

      container.read(active.notifier).replace(rebuilt);
      await pumpEventQueue();

      expect(idsOf(states).last, equals([afterId]));
    });

    test(
      'keeps the pooled videos when the fetch fails after the first paint',
      () async {
        final pooledMember = _video(
          id: pooledId,
          pubkey: _ownerA,
        );
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenThrow(Exception('relay down'));

        final states = await collect(buildContainer(pooled: [pooledMember]), [
          _ownerA,
        ]);

        expect(states.last.hasError, isFalse);
        expect(
          idsOf(states),
          equals([
            [pooledId],
          ]),
        );
      },
    );

    test('surfaces the failure when nothing is pooled', () async {
      when(
        () => videosRepository.getVideosByAuthors(
          authorPubkeys: any(named: 'authorPubkeys'),
        ),
      ).thenThrow(Exception('relay down'));

      final states = await collect(buildContainer(), [_ownerA]);

      // The state type, not `hasError`: a provider that is quietly retrying
      // is loading while carrying the error, which the screen renders as a
      // spinner rather than its retry view.
      expect(states.last, isA<AsyncError<List<VideoEvent>>>());
      expect(idsOf(states), isEmpty);
      verify(
        () => videosRepository.getVideosByAuthors(
          authorPubkeys: any(named: 'authorPubkeys'),
        ),
      ).called(1);
    });

    test(
      'lets a programming error through instead of keeping the pooled videos',
      () async {
        final pooledMember = _video(
          id: pooledId,
          pubkey: _ownerA,
        );
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenThrow(StateError('bug'));

        final states = await collect(buildContainer(pooled: [pooledMember]), [
          _ownerA,
        ]);

        expect(states.last, isA<AsyncError<List<VideoEvent>>>());
        expect(states.last.error, isA<StateError>());
      },
    );
  });

  group(videoEventsByIdsProvider, () {
    test('uses an EOSE-bounded relay read for missing videos', () async {
      final videoEventService = _MockVideoEventService();
      final nostrClient = _MockNostrClient();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(null);
      when(
        () => nostrClient.subscribe(any(), closeOnEose: true),
      ).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
          nostrServiceProvider.overrideWithValue(nostrClient),
        ],
      );
      addTearDown(container.dispose);
      final provider = videoEventsByIdsProvider([_allowedVideoId]);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await expectLater(container.read(provider.future), completion(isEmpty));
      verify(
        () => nostrClient.subscribe(any(), closeOnEose: true),
      ).called(1);
    });

    test('keeps cached videos when every relay refuses the read', () async {
      final cachedVideo = _video(id: _allowedVideoId, pubkey: _ownerA);
      final videoEventService = _MockVideoEventService();
      final nostrClient = _MockNostrClient();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(cachedVideo);
      when(
        () => videoEventService.getVideoById(_blockedVideoId),
      ).thenReturn(null);
      when(
        () => videoEventService.shouldHideVideo(cachedVideo),
      ).thenReturn(false);
      when(() => nostrClient.subscribe(any(), closeOnEose: true)).thenAnswer(
        (_) => Stream<Event>.error(
          const RelaySubscriptionRefusedException(
            'error: too many subscriptions',
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
          nostrServiceProvider.overrideWithValue(nostrClient),
        ],
      );
      addTearDown(container.dispose);
      final provider = videoEventsByIdsProvider([
        _allowedVideoId,
        _blockedVideoId,
      ]);
      final states = <AsyncValue<List<VideoEvent>>>[];
      final subscription = container.listen(
        provider,
        (_, next) => states.add(next),
      );
      addTearDown(subscription.close);

      await container.read(provider.future);
      await pumpEventQueue();

      expect(
        states.where((state) => state.hasError),
        isEmpty,
        reason: 'a refused relay read must not fail the provider',
      );
      expect(states.last.value?.map((v) => v.id), [_allowedVideoId]);
    });

    test(
      'filters hidden addressable videos found in the local cache',
      () async {
        const dTag = 'blocked-video';
        const coord = '34236:$_blockedAuthor:$dTag';
        final blockedVideo = _video(
          id: 'blocked-video-event',
          pubkey: _blockedAuthor,
          dTag: dTag,
        );
        final videoEventService = _MockVideoEventService();
        when(() => videoEventService.discoveryVideos).thenReturn(const []);
        when(() => videoEventService.homeFeedVideos).thenReturn(const []);
        when(() => videoEventService.profileVideos).thenReturn([blockedVideo]);
        when(
          () => videoEventService.shouldHideVideo(blockedVideo),
        ).thenReturn(true);

        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        );
        addTearDown(container.dispose);
        final provider = videoEventsByIdsProvider([coord]);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        await expectLater(
          container.read(provider.future),
          completion(isEmpty),
        );
        verify(() => videoEventService.shouldHideVideo(blockedVideo)).called(1);
      },
    );

    test(
      'filters hidden videos found by plain event id in the local cache',
      () async {
        final blockedVideo = _video(
          id: _blockedVideoId,
          pubkey: _blockedAuthor,
        );
        final allowedVideo = _video(id: _allowedVideoId, pubkey: _ownerA);
        final videoEventService = _MockVideoEventService();
        when(() => videoEventService.discoveryVideos).thenReturn(const []);
        when(() => videoEventService.homeFeedVideos).thenReturn(const []);
        when(() => videoEventService.profileVideos).thenReturn(const []);
        when(
          () => videoEventService.getVideoById(_blockedVideoId),
        ).thenReturn(blockedVideo);
        when(
          () => videoEventService.getVideoById(_allowedVideoId),
        ).thenReturn(allowedVideo);
        when(
          () => videoEventService.shouldHideVideo(blockedVideo),
        ).thenReturn(true);
        when(
          () => videoEventService.shouldHideVideo(allowedVideo),
        ).thenReturn(false);

        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        );
        addTearDown(container.dispose);
        final provider = videoEventsByIdsProvider([
          _blockedVideoId,
          _allowedVideoId,
        ]);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        final result = await container.read(provider.future);
        expect(result.map((v) => v.id), [_allowedVideoId]);
        verify(() => videoEventService.shouldHideVideo(blockedVideo)).called(1);
      },
    );

    test('re-runs and re-filters when the blocklist version changes', () async {
      final video = _video(id: _allowedVideoId, pubkey: _ownerA);
      final videoEventService = _MockVideoEventService();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(video);
      // Initially the author is visible.
      when(() => videoEventService.shouldHideVideo(video)).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
        ],
      );
      addTearDown(container.dispose);

      final provider = videoEventsByIdsProvider([_allowedVideoId]);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final first = await container.read(provider.future);
      expect(first.map((v) => v.id), [_allowedVideoId]);

      // Block the author and bump the blocklist version (a broad change emits
      // no removed-id signal — only the version bump).
      when(() => videoEventService.shouldHideVideo(video)).thenReturn(true);
      container.read(blocklistVersionProvider.notifier).increment();

      final second = await container.read(provider.future);
      expect(second, isEmpty);
    });
  });

  group(curatedListVideoEventsProvider, () {
    test('uses an EOSE-bounded relay read for missing videos', () async {
      const listId = 'relay-list';
      final videoEventService = _MockVideoEventService();
      final nostrClient = _MockNostrClient();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(null);
      when(
        () => nostrClient.subscribe(any(), closeOnEose: true),
      ).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
          nostrServiceProvider.overrideWithValue(nostrClient),
          curatedListVideosProvider(
            listId,
          ).overrideWith((ref) => [_allowedVideoId]),
        ],
      );
      addTearDown(container.dispose);
      final provider = curatedListVideoEventsProvider(listId);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await expectLater(container.read(provider.future), completion(isEmpty));
      verify(
        () => nostrClient.subscribe(any(), closeOnEose: true),
      ).called(1);
    });

    test(
      'filters hidden videos found by plain event id in the local cache',
      () async {
        const listId = 'curated-list-1';
        final blockedVideo = _video(
          id: _blockedVideoId,
          pubkey: _blockedAuthor,
        );
        final allowedVideo = _video(id: _allowedVideoId, pubkey: _ownerA);
        final videoEventService = _MockVideoEventService();
        when(() => videoEventService.discoveryVideos).thenReturn(const []);
        when(() => videoEventService.homeFeedVideos).thenReturn(const []);
        when(() => videoEventService.profileVideos).thenReturn(const []);
        when(
          () => videoEventService.getVideoById(_blockedVideoId),
        ).thenReturn(blockedVideo);
        when(
          () => videoEventService.getVideoById(_allowedVideoId),
        ).thenReturn(allowedVideo);
        when(
          () => videoEventService.shouldHideVideo(blockedVideo),
        ).thenReturn(true);
        when(
          () => videoEventService.shouldHideVideo(allowedVideo),
        ).thenReturn(false);

        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
            curatedListVideosProvider(
              listId,
            ).overrideWith((ref) => [_blockedVideoId, _allowedVideoId]),
          ],
        );
        addTearDown(container.dispose);
        final provider = curatedListVideoEventsProvider(listId);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        final result = await container.read(provider.future);
        expect(result.map((v) => v.id), [_allowedVideoId]);
        verify(() => videoEventService.shouldHideVideo(blockedVideo)).called(1);
      },
    );

    test('re-runs and re-filters when the blocklist version changes', () async {
      const listId = 'curated-list-2';
      final video = _video(id: _allowedVideoId, pubkey: _ownerA);
      final videoEventService = _MockVideoEventService();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(video);
      when(() => videoEventService.shouldHideVideo(video)).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
          curatedListVideosProvider(
            listId,
          ).overrideWith((ref) => [_allowedVideoId]),
        ],
      );
      addTearDown(container.dispose);

      final provider = curatedListVideoEventsProvider(listId);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final first = await container.read(provider.future);
      expect(first.map((v) => v.id), [_allowedVideoId]);

      when(() => videoEventService.shouldHideVideo(video)).thenReturn(true);
      container.read(blocklistVersionProvider.notifier).increment();

      final second = await container.read(provider.future);
      expect(second, isEmpty);
    });
  });

  // Regression: an `async*` provider body does not start until the returned
  // stream is listened to, so a provider that is invalidated (pull-to-refresh)
  // or unmounted (screen dismissed) first would reach its `ref.watch` /
  // `ref.read` on an already-disposed Ref and throw
  // "Cannot use the Ref … after it has been disposed" (#6274, #7294).
  group('Ref lifecycle on immediate disposal (#7294)', () {
    _MockVideoEventService buildVideoEventService() {
      final video = _video(id: _allowedVideoId, pubkey: _ownerA);
      final videoEventService = _MockVideoEventService();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(video);
      when(() => videoEventService.shouldHideVideo(video)).thenReturn(false);
      return videoEventService;
    }

    test(
      '$videoEventsByIdsProvider abandons its fetch without touching Ref',
      () async {
        final videoEventService = buildVideoEventService();
        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        );
        addTearDown(container.dispose);

        final provider = videoEventsByIdsProvider([_allowedVideoId]);

        final uncaughtErrors = await _captureUncaughtErrors(() async {
          final subscription = container.listen(provider, (_, _) {});
          container.invalidate(provider);
          subscription.close();
          await Future<void>.delayed(Duration.zero);
        });

        expect(uncaughtErrors, isEmpty);
        // The work is abandoned, not merely silent: nothing reads the cache
        // on behalf of a provider that no longer exists.
        verifyNever(() => videoEventService.getVideoById(any()));
      },
    );

    test(
      '$curatedListVideoEventsProvider abandons its fetch without touching Ref',
      () async {
        const listId = 'curated-list-disposed';
        final videoEventService = buildVideoEventService();
        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
            curatedListVideosProvider(
              listId,
            ).overrideWith((ref) => [_allowedVideoId]),
          ],
        );
        addTearDown(container.dispose);

        final provider = curatedListVideoEventsProvider(listId);

        final uncaughtErrors = await _captureUncaughtErrors(() async {
          final subscription = container.listen(provider, (_, _) {});
          container.invalidate(provider);
          subscription.close();
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        });

        expect(uncaughtErrors, isEmpty);
        verifyNever(() => videoEventService.getVideoById(any()));
      },
    );
  });

  group(publicPeopleListProvider, () {
    test('resolves through the people repository', () async {
      final repository = _MockPeopleListsRepository();
      final crew = UserList(
        id: 'crew',
        name: 'Crew',
        pubkeys: const [_ownerB],
        createdAt: _frozenNow,
        updatedAt: _frozenNow,
        isEditable: false,
      );
      when(
        () => repository.fetchPublicList(
          ownerPubkey: any(named: 'ownerPubkey'),
          listId: any(named: 'listId'),
        ),
      ).thenAnswer((_) async => crew);

      final container = ProviderContainer(
        overrides: [
          peopleListsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final list = await container.read(
        publicPeopleListProvider(
          ownerPubkey: _ownerA,
          listId: 'crew',
        ).future,
      );

      expect(list, same(crew));
      verify(
        () => repository.fetchPublicList(ownerPubkey: _ownerA, listId: 'crew'),
      ).called(1);
    });

    test(
      'surfaces a failed read at once instead of retrying behind a spinner',
      () async {
        final repository = _MockPeopleListsRepository();
        when(
          () => repository.fetchPublicList(
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
          ),
        ).thenThrow(Exception('relay timed out'));
        final container = ProviderContainer(
          overrides: [
            peopleListsRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final states = <AsyncValue<UserList?>>[];
        container.listen(
          publicPeopleListProvider(ownerPubkey: _ownerA, listId: 'crew'),
          (_, next) => states.add(next),
          fireImmediately: true,
        );

        await pumpEventQueue();

        // The state type, not `hasError`: a provider that is quietly retrying
        // is loading while carrying the error, which the screen renders as a
        // spinner rather than its retry view.
        expect(states.last, isA<AsyncError<UserList?>>());
        verify(
          () =>
              repository.fetchPublicList(ownerPubkey: _ownerA, listId: 'crew'),
        ).called(1);
      },
    );
  });

  group(publicCuratedListProvider, () {
    test(
      'fetches once and does not re-run when the lists state re-emits',
      () async {
        final mockService = _MockCuratedListService();
        when(
          () => mockService.fetchPublicList(
            authorPubkey: any(named: 'authorPubkey'),
            listId: any(named: 'listId'),
          ),
        ).thenAnswer((_) async => null);

        late _StubCuratedListsState notifier;
        final container = ProviderContainer(
          overrides: [
            curatedListsStateProvider.overrideWith(
              () => notifier = _StubCuratedListsState(mockService),
            ),
          ],
        );
        addTearDown(container.dispose);

        final provider = publicCuratedListProvider(
          authorPubkey: _ownerA,
          listId: 'my-vines',
        );
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        await container.read(provider.future);
        verify(
          () => mockService.fetchPublicList(
            authorPubkey: _ownerA,
            listId: 'my-vines',
          ),
        ).called(1);

        // Background relay sync and list add/remove fire
        // CuratedListService.notifyListeners, which re-emits the lists
        // state. The deep-link fetch must not re-run (and reset its screen
        // to loading) on those emissions.
        notifier.reEmit();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockService.fetchPublicList(
            authorPubkey: _ownerA,
            listId: 'my-vines',
          ),
        );
      },
    );
  });
}

class _MockCuratedListService extends Mock implements CuratedListService {}

class _StubCuratedListsState extends CuratedListsState {
  _StubCuratedListsState(this._mockService);

  final CuratedListService? _mockService;

  @override
  CuratedListService? get service => _mockService;

  @override
  Future<List<CuratedList>> build() async => [];

  void reEmit() => state = const AsyncValue.data(<CuratedList>[]);
}

/// Collects everything that escapes [body] as an unhandled error — both
/// zone-level async errors and `FlutterError.onError` reports.
///
/// A disposed-Ref access surfaces this way rather than as a thrown exception
/// at the call site, so an `expect(..., isEmpty)` on the result is what makes
/// the lifecycle regression above visible.
Future<List<Object>> _captureUncaughtErrors(
  Future<void> Function() body,
) async {
  final errors = <Object>[];
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exception);
  };

  try {
    await runZonedGuarded(body, (error, _) {
      errors.add(error);
    });
  } finally {
    FlutterError.onError = previousFlutterError;
  }

  return errors;
}
