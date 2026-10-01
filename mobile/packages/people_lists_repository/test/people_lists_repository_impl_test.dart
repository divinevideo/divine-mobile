// ABOUTME: Tests for PeopleListsRepositoryImpl relay publish and sync flow.
// ABOUTME: Covers acknowledged writes, NIP-09 delete, and echo ordering.

import 'dart:async';
import 'dart:io';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:test/test.dart';

import 'helpers/hive_test_home.dart';
import 'helpers/in_memory_followed_people_lists_store.dart';

class _MockNostrClient extends Mock implements NostrClient {
  _MockNostrClient() {
    when(() => isDisposed).thenReturn(false);
    // Self-registered so the stub below works without each file needing its
    // own `setUpAll`. Idempotent.
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<int>[]);
    // The reconcile that precedes a publish goes through `queryEventsDetailed`
    // so it can tell a relay's "I hold nothing" apart from an answer nobody
    // gave (#8273). Mirror whatever `queryEvents` is stubbed to return, as a
    // *settled* answer — the state every existing test describes. Tests about
    // the inconclusive read override this with `timedOut` or `noRelays`.
    when(
      () => queryEvents(
        any(),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        useCache: any(named: 'useCache'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) async => <Event>[]);
    when(
      () => queryEventsDetailed(
        any(),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        useCache: any(named: 'useCache'),
        requireAllRelaysSettled: true,
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((invocation) async {
      final filters = invocation.positionalArguments[0] as List<Filter>;
      return (
        events:
            invocation.namedArguments[#timeout] ==
                kPublicPeopleListsRelayReadTimeout
            ? await queryEvents(
                filters,
                tempRelays:
                    invocation.namedArguments[#tempRelays] as List<String>?,
                relayTypes: invocation.namedArguments[#relayTypes] as List<int>,
                useCache: invocation.namedArguments[#useCache] as bool,
                timeout: kPublicPeopleListsRelayReadTimeout,
              )
            : await queryEvents(filters),
        timedOut: false,
        noRelays: false,
      );
    });
  }
}

class _FakeEvent extends Fake implements Event {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _FakeFilter extends Fake implements Filter {}

/// Test constants. Full 64-char pubkeys — never truncate.
const _ownerPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _memberA =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _memberB =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _memberC =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _blockedOwnerPubkey =
    '4444444444444444444444444444444444444444444444444444444444444444';

/// A follow store whose writes fail, as a full disk would make them.
class _FailingFollowStore extends InMemoryFollowedPeopleListsStore {
  @override
  Future<void> add({
    required String viewerPubkey,
    required FollowedPeopleListRef ref,
  }) async {
    throw const FileSystemException('disk full');
  }
}

/// A cache that cannot delete a followed-list copy.
class _CopyRemovalFailingCache extends LocalPeopleListsCache {
  _CopyRemovalFailingCache({required super.openBox});

  @override
  Future<void> removeFollowedCopy({
    required String viewerPubkey,
    required String ownerPubkey,
    required String listId,
  }) async {
    throw HiveError('box is closed');
  }
}

class _PausedRefreshCache extends LocalPeopleListsCache {
  _PausedRefreshCache({required super.openBox});
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> refreshFollowedCopy({
    required String viewerPubkey,
    required String ownerPubkey,
    required UserList list,
  }) async {
    entered.complete();
    await release.future;
    await super.refreshFollowedCopy(
      viewerPubkey: viewerPubkey,
      ownerPubkey: ownerPubkey,
      list: list,
    );
  }
}

const int _peopleListKind = 30000;
const int _deletionKind = 5;

PublishOutcome _accepted({required Event event}) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const ['wss://relay.example'],
  rejectedBy: const {},
  noResponseFrom: const [],
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  group(PeopleListsRepositoryImpl, () {
    late Directory tempDir;
    late int boxCounter;

    Future<Box<dynamic>> Function() makeOpener() {
      final boxName = 'people_lists_repo_test_${boxCounter++}';
      return () async => Hive.openBox<dynamic>(boxName, path: tempDir.path);
    }

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'people_lists_repository_impl_test_',
      );
      setHiveTestHome(tempDir.path);
      boxCounter = 0;
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    PeopleListsRepositoryImpl buildRepository({
      required NostrClient nostrClient,
      LocalPeopleListsCache? cache,
      FollowedPeopleListsStore? followedListsStore,
      BlockedPeopleListOwnerFilter? blockFilter,
      FunnelcakeApiClient? funnelcakeApiClient,
      List<String> discoveryRelayUrls = const [],
      Set<String> additionalExcludedPublicDTags = const {},
    }) {
      return PeopleListsRepositoryImpl(
        nostrClient: nostrClient,
        cache: cache ?? LocalPeopleListsCache(openBox: makeOpener()),
        followedListsStore:
            followedListsStore ?? InMemoryFollowedPeopleListsStore(),
        blockFilter: blockFilter,
        funnelcakeApiClient: funnelcakeApiClient,
        discoveryRelayUrls: discoveryRelayUrls,
        additionalExcludedPublicDTags: additionalExcludedPublicDTags,
      );
    }

    /// A Funnelcake profile for [pubkey] with [videos] posted on Divine.
    UserProfileFound divineProfile(String pubkey, {required int videos}) =>
        UserProfileFound(
          profile: UserProfileData(pubkey: pubkey),
          stats: ProfileStatsData(videoCount: videos, reactionCount: 0),
        );

    Event signedEvent({
      required int kind,
      required List<List<String>> tags,
      String content = '',
      int? createdAt,
    }) {
      return Event(_ownerPubkey, kind, tags, content, createdAt: createdAt)
        // Mark as signed for callers that check sig presence.
        ..sig =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    }

    group('createList', () {
      test('returns submitted result when a relay acknowledges the '
          'event', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          return _accepted(
            event: signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            ),
          );
        });
        final repository = buildRepository(nostrClient: client);

        final result = await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          description: 'the best',
          initialPubkeys: const [_memberA],
        );

        expect(result.status, equals(PeopleListPublishStatus.submitted));
        expect(result.submitted, isTrue);
        expect(result.eventId, isNotNull);
        expect(result.eventId, isNot(isEmpty));

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored, hasLength(1));
        expect(stored.single.name, equals('Besties'));
        expect(stored.single.pubkeys, equals(const [_memberA]));
      });

      test(
        'does not write to cache when no relay acknowledges acceptance',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          when(
            () => client.publishEventAwaitOk(any()),
          ).thenAnswer(
            (_) async => const PublishOutcome(
              eventId: _ownerPubkey,
              acceptedBy: [],
              rejectedBy: {},
              noResponseFrom: [],
            ),
          );
          final repository = buildRepository(nostrClient: client);

          final result = await repository.createList(
            ownerPubkey: _ownerPubkey,
            name: 'Besties',
          );

          expect(result.status, equals(PeopleListPublishStatus.failed));
          expect(result.submitted, isFalse);

          final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(stored, isEmpty);
        },
      );

      test('returns failed when acknowledged publication throws', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(
          () => client.publishEventAwaitOk(any()),
        ).thenThrow(StateError('network down'));
        final repository = buildRepository(nostrClient: client);

        final result = await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
        );

        expect(result.status, equals(PeopleListPublishStatus.failed));
        expect(result.error, isA<StateError>());
      });

      test(
        'retains submitted status without claiming durable storage',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            final event = invocation.positionalArguments.first as Event;
            return _accepted(
              event: signedEvent(
                kind: event.kind,
                tags: event.tags,
                content: event.content,
                createdAt: event.createdAt,
              ),
            );
          });
          final repository = buildRepository(nostrClient: client);

          final result = await repository.createList(
            ownerPubkey: _ownerPubkey,
            name: 'Besties',
          );

          expect(
            PeopleListPublishStatus.values,
            isNot(
              contains(
                isA<PeopleListPublishStatus>().having(
                  (s) => s.name,
                  'name',
                  'confirmed',
                ),
              ),
            ),
          );
          expect(result.status.name, equals('submitted'));
        },
      );
    });

    group('addPubkey', () {
      test('preserves foreign tags, p-tag positions, and content', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        final remote = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'shared-list'],
            ['alt', 'Written by another client'],
            ['p', _memberA, 'wss://relay.example', 'friend'],
            ['expiration', '2000000000'],
          ],
          content: 'nip44-encrypted-private-members',
          createdAt: 1000,
        );
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: [remote], timedOut: false, noRelays: false),
        );
        when(() => client.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          return _accepted(event: event);
        });
        final repository = buildRepository(nostrClient: client);

        final result = await repository.addPubkey(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          pubkey: _memberB,
        );

        expect(result.status, PeopleListPublishStatus.submitted);
        final published =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.tags, const [
          ['d', 'shared-list'],
          ['alt', 'Written by another client'],
          ['p', _memberA, 'wss://relay.example', 'friend'],
          ['expiration', '2000000000'],
          ['p', _memberB],
        ]);
        expect(published.content, 'nip44-encrypted-private-members');
      });

      test(
        'a second edit uses the complete source published by the first',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          final staleRemote = signedEvent(
            kind: _peopleListKind,
            tags: const [
              ['d', 'shared-list'],
              ['alt', 'Keep me'],
              ['p', _memberA, 'wss://relay.example'],
            ],
            content: 'ciphertext',
            createdAt: 1000,
          );
          when(
            () => client.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: true,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (_) async =>
                (events: [staleRemote], timedOut: false, noRelays: false),
          );
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            return _accepted(
              event: invocation.positionalArguments.first as Event,
            );
          });
          final repository = buildRepository(nostrClient: client);

          expect(
            (await repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'shared-list',
              pubkey: _memberB,
            )).submitted,
            isTrue,
          );
          expect(
            (await repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'shared-list',
              pubkey: _memberC,
            )).submitted,
            isTrue,
          );

          final published = verify(
            () => client.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();
          expect(published.last.tags, const [
            ['d', 'shared-list'],
            ['alt', 'Keep me'],
            ['p', _memberA, 'wss://relay.example'],
            ['p', _memberB],
            ['p', _memberC],
          ]);
          expect(published.last.content, 'ciphertext');
        },
      );

      test(
        'caches the tags the relay actually received, not the pre-publish ones',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          final remote = signedEvent(
            kind: _peopleListKind,
            tags: const [
              ['d', 'shared-list'],
              ['alt', 'Keep me'],
              ['p', _memberA],
            ],
            content: 'ciphertext',
            createdAt: 1000,
          );
          when(
            () => client.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: true,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (_) async => (events: [remote], timedOut: false, noRelays: false),
          );
          // NostrClient appends the NIP-89 client tag during publish and
          // rebinds event.tags to a new list, so the caller's pre-publish
          // payload never observes it. Model that here.
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            final outgoing = invocation.positionalArguments.first as Event;
            final signed = signedEvent(
              kind: outgoing.kind,
              tags: [
                ...outgoing.tags,
                const ['client', 'Divine'],
              ],
              content: outgoing.content,
              createdAt: outgoing.createdAt,
            );
            outgoing
              ..tags = signed.tags
              ..id = signed.id
              ..sig = signed.sig;
            return _accepted(event: outgoing);
          });
          final repository = buildRepository(nostrClient: client);

          expect(
            (await repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'shared-list',
              pubkey: _memberB,
            )).submitted,
            isTrue,
          );
          expect(
            (await repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'shared-list',
              pubkey: _memberC,
            )).submitted,
            isTrue,
          );

          final published = verify(
            () => client.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();
          // The second edit is built from the source cached by the first. If
          // that source were the pre-publish payload, the tag the relay holds
          // would be missing here and the cached nostrEventId would belong to
          // an event the cached tags cannot reproduce.
          expect(
            published.last.tags,
            contains(equals(const ['client', 'Divine'])),
          );
        },
      );

      test(
        'publishes a kind 30000 event with a full p tag for new pubkey',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            final event = invocation.positionalArguments.first as Event;
            return _accepted(
              event: signedEvent(
                kind: event.kind,
                tags: event.tags,
                content: event.content,
                createdAt: event.createdAt,
              ),
            );
          });
          final repository = buildRepository(nostrClient: client);

          await repository.createList(
            ownerPubkey: _ownerPubkey,
            name: 'Besties',
            initialPubkeys: const [_memberA],
          );

          final result = await repository.addPubkey(
            ownerPubkey: _ownerPubkey,
            listId: (await repository.readLists(
              ownerPubkey: _ownerPubkey,
            )).single.id,
            pubkey: _memberB,
          );

          expect(result.status, equals(PeopleListPublishStatus.submitted));
          final captured = verify(
            () => client.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();

          // First publish was createList, second was addPubkey.
          expect(captured, hasLength(2));
          final addEvent = captured.last;
          expect(addEvent.kind, equals(_peopleListKind));
          final pTags = addEvent.tags
              .where((tag) => tag.isNotEmpty && tag.first == 'p')
              .map((tag) => tag[1])
              .toList();
          expect(pTags, containsAll(<String>[_memberA, _memberB]));
          // Full pubkey preserved, not truncated.
          expect(
            pTags.every((pk) => pk.length == 64),
            isTrue,
            reason: 'p tags must carry full 64-char pubkeys',
          );

          final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(stored.single.pubkeys, equals(const [_memberA, _memberB]));
        },
      );

      test('returns noop when pubkey is already in list', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          return _accepted(
            event: signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            ),
          );
        });
        final repository = buildRepository(nostrClient: client);

        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA],
        );
        final listId = (await repository.readLists(
          ownerPubkey: _ownerPubkey,
        )).single.id;

        clearInteractions(client);

        final result = await repository.addPubkey(
          ownerPubkey: _ownerPubkey,
          listId: listId,
          pubkey: _memberA,
        );

        expect(result.status, equals(PeopleListPublishStatus.noop));
        verifyNever(() => client.publishEventAwaitOk(any()));
      });
    });

    group('updateListInfo', () {
      _MockNostrClient clientHolding(Event remote) {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: [remote], timedOut: false, noRelays: false),
        );
        when(() => client.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          return _accepted(event: event);
        });
        return client;
      }

      Event sharedList({String? description}) => signedEvent(
        kind: _peopleListKind,
        tags: [
          const ['d', 'shared-list'],
          const ['title', 'Shared'],
          if (description != null) ['description', description],
          const ['alt', 'Written by another client'],
          const ['p', _memberA, 'wss://relay.example', 'friend'],
        ],
        content: 'nip44-encrypted-private-members',
        createdAt: 1000,
      );

      test('rewrites the title and description over the source event and '
          'caches the result', () async {
        final client = clientHolding(sharedList(description: 'Old words'));
        final repository = buildRepository(nostrClient: client);

        final result = await repository.updateListInfo(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          name: '  Renamed  ',
          description: ' New words ',
        );

        expect(result.status, PeopleListPublishStatus.submitted);
        final published =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.tags, const [
          ['d', 'shared-list'],
          ['title', 'Renamed'],
          ['description', 'New words'],
          ['alt', 'Written by another client'],
          ['p', _memberA, 'wss://relay.example', 'friend'],
        ]);
        expect(published.content, 'nip44-encrypted-private-members');

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored.single.name, 'Renamed');
        expect(stored.single.description, 'New words');
        expect(stored.single.pubkeys, const [_memberA]);
      });

      test('drops the description when given a blank one', () async {
        final client = clientHolding(sharedList(description: 'Old words'));
        final repository = buildRepository(nostrClient: client);

        final result = await repository.updateListInfo(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          name: 'Shared',
          description: '   ',
        );

        expect(result.status, PeopleListPublishStatus.submitted);
        final published =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(
          published.tags.any((tag) => tag.first == 'description'),
          isFalse,
        );
        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored.single.description, isNull);
      });

      test('returns noop, publishing nothing, when nothing changes', () async {
        final client = clientHolding(sharedList(description: 'Old words'));
        final repository = buildRepository(nostrClient: client);

        final result = await repository.updateListInfo(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          name: 'Shared ',
          description: ' Old words',
        );

        expect(result.status, PeopleListPublishStatus.noop);
        verifyNever(() => client.publishEventAwaitOk(any()));
      });

      test('returns failed for a list the owner does not have', () async {
        final client = clientHolding(sharedList());
        final repository = buildRepository(nostrClient: client);

        final result = await repository.updateListInfo(
          ownerPubkey: _ownerPubkey,
          listId: 'no-such-list',
          name: 'Renamed',
        );

        expect(result.status, PeopleListPublishStatus.failed);
        verifyNever(() => client.publishEventAwaitOk(any()));
      });

      test('returns failed when the relay refuses the replacement', () async {
        final client = clientHolding(sharedList());
        when(
          () => client.publishEventAwaitOk(any()),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments.single as Event).id,
            acceptedBy: const [],
            rejectedBy: const {'wss://relay.example': 'rejected'},
            noResponseFrom: const [],
          ),
        );
        final repository = buildRepository(nostrClient: client);

        final result = await repository.updateListInfo(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          name: 'Renamed',
        );

        expect(result.status, PeopleListPublishStatus.failed);
        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored.single.name, 'Shared');
      });

      test(
        'refuses an info edit when the cached list has no complete source',
        () async {
          final remote = sharedList();
          final cache = LocalPeopleListsCache(openBox: makeOpener());
          await cache.putList(
            ownerPubkey: _ownerPubkey,
            list: Nip51PeopleListCodec.decode(remote)!,
            receivedAt: DateTime.utc(2026),
          );
          final client = _MockNostrClient();
          final repository = buildRepository(nostrClient: client, cache: cache);

          final result = await repository.updateListInfo(
            ownerPubkey: _ownerPubkey,
            listId: 'shared-list',
            name: 'Renamed',
          );

          expect(result.status, PeopleListPublishStatus.failed);
          verifyNever(() => client.publishEventAwaitOk(any()));
          expect(
            (await repository.readLists(ownerPubkey: _ownerPubkey)).single.name,
            'Shared',
          );
        },
      );

      test('a thrown read releases the next queued write', () async {
        final remote = sharedList();
        final client = clientHolding(remote);
        final read =
            Completer<({List<Event> events, bool timedOut, bool noRelays})>();
        var reads = 0;
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) {
          reads++;
          if (reads == 1) return read.future;
          return Future.value((
            events: [remote],
            timedOut: false,
            noRelays: false,
          ));
        });
        final repository = buildRepository(nostrClient: client);
        final add = repository.addPubkey(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          pubkey: _memberB,
        );
        final addFails = expectLater(
          add,
          completion(
            isA<PeopleListPublishResult>()
                .having(
                  (result) => result.status,
                  'status',
                  PeopleListPublishStatus.failed,
                )
                .having((result) => result.error, 'error', isA<StateError>()),
          ),
        );
        final rename = repository.updateListInfo(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          name: 'Renamed',
        );
        await pumpEventQueue();
        expect(reads, 1);

        read.completeError(StateError('read failed'));
        await addFails;
        expect((await rename).status, PeopleListPublishStatus.submitted);
        expect(reads, 2);
        final published =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(published.tags, contains(equals(const ['title', 'Renamed'])));
      });

      test('waits for an add still publishing, so the rename carries the '
          'member', () async {
        // Without the shared owner write queue the rename read the row before
        // the add had landed, and its event reached the relay without the
        // member while the cache kept the member and the old name.
        final client = clientHolding(sharedList());
        final addPublished = Completer<PublishOutcome>();
        var publishes = 0;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((invocation) {
          final event = invocation.positionalArguments.first as Event;
          publishes++;
          if (publishes == 1) return addPublished.future;
          return Future.value(_accepted(event: event));
        });
        final repository = buildRepository(nostrClient: client);

        final add = repository.addPubkey(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          pubkey: _memberB,
        );
        // The add reads the relay and the cache before it publishes.
        for (var turns = 0; publishes == 0 && turns < 50; turns++) {
          await pumpEventQueue();
        }
        expect(publishes, 1, reason: 'the add is on the wire');
        final rename = repository.updateListInfo(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          name: 'Renamed',
        );
        await pumpEventQueue(times: 200);
        expect(publishes, 1, reason: 'the rename waits for the add');

        final addEvent =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        addPublished.complete(_accepted(event: addEvent));
        expect((await add).status, PeopleListPublishStatus.submitted);
        expect((await rename).status, PeopleListPublishStatus.submitted);

        final renameEvent =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(
          renameEvent.tags,
          containsAll(const <List<String>>[
            ['title', 'Renamed'],
            ['p', _memberB],
          ]),
        );
        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored.single.name, 'Renamed');
        expect(stored.single.pubkeys, containsAll(const [_memberA, _memberB]));
      });

      test('metadata waits for another list of the same owner to finish '
          'publishing', () async {
        final remote = sharedList();
        final other = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'other-list'],
            ['title', 'Other'],
            ['p', _memberC, 'wss://relay.example', 'friend'],
          ],
          content: 'other-private-members',
          createdAt: 1000,
        );
        final client = clientHolding(remote);
        var reads = 0;
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async {
          reads++;
          return (events: [remote, other], timedOut: false, noRelays: false);
        });
        final accepted = Completer<PublishOutcome>();
        var publishes = 0;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((call) {
          publishes++;
          if (publishes == 1) return accepted.future;
          return Future.value(
            _accepted(event: call.positionalArguments.single as Event),
          );
        });
        final repository = buildRepository(nostrClient: client);
        final add = repository.addPubkey(
          ownerPubkey: _ownerPubkey,
          listId: 'shared-list',
          pubkey: _memberB,
        );
        for (var turns = 0; publishes == 0 && turns < 50; turns++) {
          await pumpEventQueue();
        }
        expect(publishes, 1, reason: 'the member edit is awaiting relay ACK');
        final rename = repository.updateListInfo(
          ownerPubkey: _ownerPubkey,
          listId: 'other-list',
          name: 'Renamed other',
        );
        await pumpEventQueue(times: 200);
        expect(publishes, 1, reason: 'the owner queue includes both lists');
        expect(reads, 1, reason: 'the second owner-wide read must wait too');

        final addEvent =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        accepted.complete(_accepted(event: addEvent));
        expect((await add).status, PeopleListPublishStatus.submitted);
        expect((await rename).status, PeopleListPublishStatus.submitted);
        expect(reads, 2);
        final renamed =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(
          renamed.tags,
          contains(equals(const ['title', 'Renamed other'])),
        );
        expect(
          renamed.tags,
          contains(
            equals(const ['p', _memberC, 'wss://relay.example', 'friend']),
          ),
        );
        expect(renamed.content, 'other-private-members');
        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(
          stored.singleWhere((list) => list.id == 'shared-list').pubkeys,
          containsAll(const [_memberA, _memberB]),
        );
        expect(
          stored.singleWhere((list) => list.id == 'other-list').name,
          'Renamed other',
        );
      });
    });

    group('removePubkey', () {
      test(
        'returns noop and does not publish when pubkey is not in list',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            final event = invocation.positionalArguments.first as Event;
            return _accepted(
              event: signedEvent(
                kind: event.kind,
                tags: event.tags,
                content: event.content,
                createdAt: event.createdAt,
              ),
            );
          });
          final repository = buildRepository(nostrClient: client);

          await repository.createList(
            ownerPubkey: _ownerPubkey,
            name: 'Besties',
            initialPubkeys: const [_memberA],
          );
          final listId = (await repository.readLists(
            ownerPubkey: _ownerPubkey,
          )).single.id;

          clearInteractions(client);

          final result = await repository.removePubkey(
            ownerPubkey: _ownerPubkey,
            listId: listId,
            pubkey: _memberB,
          );

          expect(result.status, equals(PeopleListPublishStatus.noop));
          verifyNever(() => client.publishEventAwaitOk(any()));
        },
      );

      test('publishes replacement event without the removed pubkey', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          return _accepted(
            event: signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            ),
          );
        });
        final repository = buildRepository(nostrClient: client);

        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA, _memberB],
        );
        final listId = (await repository.readLists(
          ownerPubkey: _ownerPubkey,
        )).single.id;

        clearInteractions(client);

        final result = await repository.removePubkey(
          ownerPubkey: _ownerPubkey,
          listId: listId,
          pubkey: _memberA,
        );

        expect(result.status, equals(PeopleListPublishStatus.submitted));
        final captured = verify(
          () => client.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(captured, hasLength(1));
        final published = captured.single;
        expect(published.kind, equals(_peopleListKind));
        final remainingPTags = published.tags
            .where((tag) => tag.isNotEmpty && tag.first == 'p')
            .map((tag) => tag[1])
            .toList();
        expect(remainingPTags, equals(const [_memberB]));

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored.single.pubkeys, equals(const [_memberB]));
      });

      test(
        'preserves foreign tags, surviving p-tag fields, and content',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          final remote = signedEvent(
            kind: _peopleListKind,
            tags: const [
              ['d', 'shared-list'],
              ['alt', 'Written by another client'],
              ['p', _memberA, 'wss://relay.example', 'friend'],
              ['p', _memberB, 'wss://other.example', 'bestie'],
              ['expiration', '2000000000'],
            ],
            content: 'nip44-encrypted-private-members',
            createdAt: 1000,
          );
          when(
            () => client.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: true,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (_) async => (events: [remote], timedOut: false, noRelays: false),
          );
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            final event = invocation.positionalArguments.first as Event;
            return _accepted(event: event);
          });
          final repository = buildRepository(nostrClient: client);

          final result = await repository.removePubkey(
            ownerPubkey: _ownerPubkey,
            listId: 'shared-list',
            pubkey: _memberA,
          );

          expect(result.status, PeopleListPublishStatus.submitted);
          final published =
              verify(
                    () => client.publishEventAwaitOk(captureAny()),
                  ).captured.single
                  as Event;
          // The removed member loses every matching tag; the foreign tags and
          // the surviving member's relay hint and petname survive verbatim.
          expect(published.tags, const [
            ['d', 'shared-list'],
            ['alt', 'Written by another client'],
            ['p', _memberB, 'wss://other.example', 'bestie'],
            ['expiration', '2000000000'],
          ]);
          expect(published.content, 'nip44-encrypted-private-members');
        },
      );
    });

    group('inconclusive reconcile before a replacement (#8273)', () {
      _MockNostrClient publishingClient() {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          return _accepted(
            event: signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            ),
          );
        });
        return client;
      }

      void stubReconcile(
        _MockNostrClient client, {
        List<Event> events = const <Event>[],
        bool timedOut = false,
        bool noRelays = false,
      }) {
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
        );
      }

      const memberAddedElsewhere =
          '4444444444444444444444444444444444444444444444444444444444444444';

      Future<String> seedList(PeopleListsRepositoryImpl repository) async {
        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA],
        );
        return (await repository.readLists(
          ownerPubkey: _ownerPubkey,
        )).single.id;
      }

      test('addPubkey does not publish when the reconcile timed out', () async {
        final client = publishingClient();
        final repository = buildRepository(nostrClient: client);
        final listId = await seedList(repository);
        clearInteractions(client);
        stubReconcile(client, timedOut: true);

        final result = await repository.addPubkey(
          ownerPubkey: _ownerPubkey,
          listId: listId,
          pubkey: _memberB,
        );

        expect(result.status, equals(PeopleListPublishStatus.failed));
        verifyNever(() => client.publishEventAwaitOk(any()));
      });

      test('addPubkey does not publish when no relay took the query', () async {
        final client = publishingClient();
        final repository = buildRepository(nostrClient: client);
        final listId = await seedList(repository);
        clearInteractions(client);
        stubReconcile(client, noRelays: true);

        final result = await repository.addPubkey(
          ownerPubkey: _ownerPubkey,
          listId: listId,
          pubkey: _memberB,
        );

        expect(result.status, equals(PeopleListPublishStatus.failed));
        verifyNever(() => client.publishEventAwaitOk(any()));
      });

      test(
        'updateListInfo does not publish when the reconcile is inconclusive',
        () async {
          final client = publishingClient();
          final repository = buildRepository(nostrClient: client);
          final listId = await seedList(repository);
          clearInteractions(client);
          stubReconcile(client, timedOut: true);

          final result = await repository.updateListInfo(
            ownerPubkey: _ownerPubkey,
            listId: listId,
            name: 'Renamed',
          );

          expect(result.status, equals(PeopleListPublishStatus.failed));
          verifyNever(() => client.publishEventAwaitOk(any()));
        },
      );

      test(
        'removePubkey does not publish when the reconcile is inconclusive',
        () async {
          final client = publishingClient();
          final repository = buildRepository(nostrClient: client);
          final listId = await seedList(repository);
          clearInteractions(client);
          stubReconcile(client, timedOut: true);

          final result = await repository.removePubkey(
            ownerPubkey: _ownerPubkey,
            listId: listId,
            pubkey: _memberA,
          );

          expect(result.status, equals(PeopleListPublishStatus.failed));
          verifyNever(() => client.publishEventAwaitOk(any()));
        },
      );

      test('a settled empty reconcile still publishes', () async {
        final client = publishingClient();
        final repository = buildRepository(nostrClient: client);
        final listId = await seedList(repository);
        clearInteractions(client);
        stubReconcile(client);

        final result = await repository.addPubkey(
          ownerPubkey: _ownerPubkey,
          listId: listId,
          pubkey: _memberB,
        );

        expect(result.status, equals(PeopleListPublishStatus.submitted));
        verify(() => client.publishEventAwaitOk(any())).called(1);
        verify(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test(
        'a member added elsewhere before a local edit survives replacement',
        () async {
          final client = publishingClient();
          final repository = buildRepository(nostrClient: client);
          final listId = await seedList(repository);

          // Another client added a member since; the reconcile must learn
          // about it before this device rebuilds the replacement.
          stubReconcile(
            client,
            events: [
              signedEvent(
                kind: Nip51PeopleListCodec.kind,
                tags: [
                  ['d', listId],
                  ['title', 'Besties'],
                  ['p', _memberA],
                  ['p', memberAddedElsewhere],
                ],
                createdAt:
                    DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 1,
              ),
            ],
          );

          final result = await repository.addPubkey(
            ownerPubkey: _ownerPubkey,
            listId: listId,
            pubkey: _memberB,
          );

          expect(result.status, equals(PeopleListPublishStatus.submitted));
          final published =
              verify(
                    () => client.publishEventAwaitOk(captureAny()),
                  ).captured.last
                  as Event;
          final members = published.tags
              .where((tag) => tag.isNotEmpty && tag.first == 'p')
              .map((tag) => tag[1])
              .toSet();
          expect(
            members,
            containsAll(<String>[_memberA, _memberB, memberAddedElsewhere]),
          );
        },
      );

      test(
        'a legacy cached list without a complete source fails closed',
        () async {
          final client = publishingClient();
          final cache = LocalPeopleListsCache(openBox: makeOpener());
          final legacyEvent = signedEvent(
            kind: _peopleListKind,
            tags: const [
              ['d', 'legacy-list'],
              ['title', 'Legacy'],
              ['p', _memberA],
            ],
            createdAt: 2000,
          );
          await cache.putList(
            ownerPubkey: _ownerPubkey,
            list: Nip51PeopleListCodec.decode(legacyEvent)!,
            receivedAt: DateTime.now().toUtc(),
          );
          stubReconcile(
            client,
            events: [
              signedEvent(
                kind: _peopleListKind,
                tags: const [
                  ['d', 'legacy-list'],
                  ['title', 'Older'],
                  ['p', _memberA],
                ],
                createdAt: 1000,
              ),
            ],
          );
          final repository = buildRepository(nostrClient: client, cache: cache);

          final result = await repository.addPubkey(
            ownerPubkey: _ownerPubkey,
            listId: 'legacy-list',
            pubkey: _memberB,
          );

          expect(result.status, PeopleListPublishStatus.failed);
          verifyNever(() => client.publishEventAwaitOk(any()));
        },
      );

      test(
        'a pre-source row adopts the source of the event it already holds',
        () async {
          final client = publishingClient();
          final cache = LocalPeopleListsCache(openBox: makeOpener());
          final publishedEvent = signedEvent(
            kind: _peopleListKind,
            tags: const [
              ['d', 'legacy-list'],
              ['title', 'Legacy'],
              ['alt', 'Written by another client'],
              ['p', _memberA, 'wss://relay.example'],
            ],
            content: 'ciphertext',
            createdAt: 1700000000,
          );
          // The row a publish left behind before source preservation: the
          // same event, stamped with the millisecond `DateTime.now()` of the
          // publish, which always reads as newer than that event's
          // second-resolution created_at.
          await cache.putList(
            ownerPubkey: _ownerPubkey,
            list: Nip51PeopleListCodec.decode(publishedEvent)!.copyWith(
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                1700000000 * 1000 + 250,
                isUtc: true,
              ),
            ),
            receivedAt: DateTime.now().toUtc(),
          );
          stubReconcile(client, events: [publishedEvent]);
          final repository = buildRepository(nostrClient: client, cache: cache);

          final result = await repository.addPubkey(
            ownerPubkey: _ownerPubkey,
            listId: 'legacy-list',
            pubkey: _memberB,
          );

          expect(result.status, PeopleListPublishStatus.submitted);
          final published =
              verify(
                    () => client.publishEventAwaitOk(captureAny()),
                  ).captured.single
                  as Event;
          expect(published.tags, const [
            ['d', 'legacy-list'],
            ['title', 'Legacy'],
            ['alt', 'Written by another client'],
            ['p', _memberA, 'wss://relay.example'],
            ['p', _memberB],
          ]);
          expect(published.content, 'ciphertext');
        },
      );
    });

    group('deleteList', () {
      test('publishes NIP-09 kind 5 event with a and k tags, then tombstones '
          'locally', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          return _accepted(
            event: signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            ),
          );
        });
        final repository = buildRepository(nostrClient: client);

        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA],
        );
        final listId = (await repository.readLists(
          ownerPubkey: _ownerPubkey,
        )).single.id;

        clearInteractions(client);

        final result = await repository.deleteList(
          ownerPubkey: _ownerPubkey,
          listId: listId,
        );

        expect(result.status, equals(PeopleListPublishStatus.submitted));
        final captured = verify(
          () => client.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(captured, hasLength(1));
        final deletion = captured.single;
        expect(deletion.kind, equals(_deletionKind));
        expect(deletion.content, equals('Deleted people list $listId'));
        expect(
          deletion.tags,
          containsOnce(
            equals(<String>['a', '$_peopleListKind:$_ownerPubkey:$listId']),
          ),
        );
        expect(
          deletion.tags,
          containsOnce(equals(<String>['k', '$_peopleListKind'])),
        );

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored, isEmpty);
      });

      test(
        'does not tombstone locally when no relay accepts the publish',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);

          // First call for createList succeeds, second (deleteList) fails.
          var publishCalls = 0;
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            publishCalls++;
            if (publishCalls == 1) {
              final event = invocation.positionalArguments.first as Event;
              return _accepted(
                event: signedEvent(
                  kind: event.kind,
                  tags: event.tags,
                  content: event.content,
                  createdAt: event.createdAt,
                ),
              );
            }
            return const PublishOutcome(
              eventId: _ownerPubkey,
              acceptedBy: [],
              rejectedBy: {},
              noResponseFrom: [],
            );
          });
          final repository = buildRepository(nostrClient: client);

          await repository.createList(
            ownerPubkey: _ownerPubkey,
            name: 'Besties',
            initialPubkeys: const [_memberA],
          );
          final listId = (await repository.readLists(
            ownerPubkey: _ownerPubkey,
          )).single.id;

          final result = await repository.deleteList(
            ownerPubkey: _ownerPubkey,
            listId: listId,
          );

          expect(result.status, equals(PeopleListPublishStatus.failed));
          final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(stored, hasLength(1));
        },
      );
    });

    group('syncOwner', () {
      for (final unavailable in [(true, false), (false, true)]) {
        test(
          'owner read refuses inconclusive empty cache $unavailable',
          () async {
            final client = _MockNostrClient();
            when(
              () => client.queryEventsDetailed(
                any(),
                requireAllRelaysSettled: true,
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer(
              (_) async => (
                events: <Event>[],
                timedOut: unavailable.$1,
                noRelays: unavailable.$2,
              ),
            );
            final repository = buildRepository(nostrClient: client);
            await expectLater(
              repository.syncOwner(ownerPubkey: _ownerPubkey),
              throwsA(isA<PublicPeopleListReadUnavailableException>()),
            );
            expect(
              await repository.readLists(ownerPubkey: _ownerPubkey),
              isEmpty,
            );
          },
        );
      }
      test('settled empty owner read establishes absence', () async {
        final client = _MockNostrClient();
        final repository = buildRepository(nostrClient: client);
        await repository.syncOwner(ownerPubkey: _ownerPubkey);
        expect(await repository.readLists(ownerPubkey: _ownerPubkey), isEmpty);
      });

      test(
        'stores the newest revision regardless of relay result order',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          final newer = signedEvent(
            kind: _peopleListKind,
            tags: const [
              ['d', 'Crew'],
              ['title', 'Newer'],
              ['p', _memberA],
              ['p', _memberB],
            ],
            createdAt: 2000,
          );
          final older = signedEvent(
            kind: _peopleListKind,
            tags: const [
              ['d', 'Crew'],
              ['title', 'Older'],
              ['p', _memberA],
            ],
            createdAt: 1000,
          );
          when(
            () => client.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: true,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (_) async =>
                (events: [newer, older], timedOut: false, noRelays: false),
          );
          final repository = buildRepository(nostrClient: client);

          await repository.syncOwner(ownerPubkey: _ownerPubkey);

          final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(stored.single.name, 'Newer');
          expect(stored.single.pubkeys, const [_memberA, _memberB]);
        },
      );

      test('uses the lowest event id when revision timestamps tie', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        final higherId =
            signedEvent(
                kind: _peopleListKind,
                tags: const [
                  ['d', 'Crew'],
                  ['title', 'Higher id'],
                  ['p', _memberA],
                ],
                createdAt: 2000,
              )
              ..id =
                  'ffffffffffffffffffffffffffffffff'
                  'ffffffffffffffffffffffffffffffff';
        final lowerId =
            signedEvent(
                kind: _peopleListKind,
                tags: const [
                  ['d', 'Crew'],
                  ['title', 'Lower id'],
                  ['p', _memberB],
                ],
                createdAt: 2000,
              )
              ..id =
                  '00000000000000000000000000000000'
                  '00000000000000000000000000000000';
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async =>
              (events: [higherId, lowerId], timedOut: false, noRelays: false),
        );
        final repository = buildRepository(nostrClient: client);

        await repository.syncOwner(ownerPubkey: _ownerPubkey);

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored.single.name, 'Lower id');
        expect(stored.single.pubkeys, const [_memberB]);
      });

      test(
        'queries kind 30000 by author and writes decoded lists to cache',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);

          final remoteEvent = signedEvent(
            kind: _peopleListKind,
            tags: const [
              ['d', 'Crew'],
              ['title', 'Crew'],
              ['p', _memberA],
            ],
          );

          when(
            () => client.queryEvents(any(), useCache: any(named: 'useCache')),
          ).thenAnswer((_) async => [remoteEvent]);

          final repository = buildRepository(nostrClient: client);

          await repository.syncOwner(ownerPubkey: _ownerPubkey);

          final capturedFilters = verify(
            () => client.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured.cast<List<Filter>>();
          expect(capturedFilters, hasLength(1));
          final filter = capturedFilters.single.single;
          expect(filter.kinds, equals(const [_peopleListKind]));
          expect(filter.authors, equals(const [_ownerPubkey]));

          final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(stored, hasLength(1));
          expect(stored.single.id, equals('Crew'));
          expect(stored.single.pubkeys, equals(const [_memberA]));
        },
      );

      test('filters out app block-list events with d=block', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final crewEvent = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'Crew'],
            ['title', 'Crew'],
            ['p', _memberA],
          ],
        );
        final blockEvent = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'block'],
            ['p', _memberB],
          ],
        );

        when(
          () => client.queryEvents(any(), useCache: any(named: 'useCache')),
        ).thenAnswer((_) async => [crewEvent, blockEvent]);

        final repository = buildRepository(nostrClient: client);

        await repository.syncOwner(ownerPubkey: _ownerPubkey);

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored, hasLength(1));
        expect(stored.single.id, equals('Crew'));
      });

      test(
        'does not overwrite newer local list with stale relay echo',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);

          // Local optimistic write will be far in the future.
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            final event = invocation.positionalArguments.first as Event;
            return _accepted(
              event: signedEvent(
                kind: event.kind,
                tags: event.tags,
                content: event.content,
                createdAt: event.createdAt,
              ),
            );
          });
          final repository = buildRepository(nostrClient: client);

          await repository.createList(
            ownerPubkey: _ownerPubkey,
            name: 'Besties',
            initialPubkeys: const [_memberA, _memberB],
          );

          final listId = (await repository.readLists(
            ownerPubkey: _ownerPubkey,
          )).single.id;

          // Now simulate a stale relay echo with an older createdAt and only
          // one pubkey — must not clobber the newer local state.
          final staleCreatedAt =
              DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000;
          final staleEvent = signedEvent(
            kind: _peopleListKind,
            tags: [
              ['d', listId],
              ['title', 'Besties'],
              ['p', _memberA],
            ],
            createdAt: staleCreatedAt,
          );

          when(
            () => client.queryEvents(any(), useCache: any(named: 'useCache')),
          ).thenAnswer((_) async => [staleEvent]);

          await repository.syncOwner(ownerPubkey: _ownerPubkey);

          final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(stored, hasLength(1));
          expect(
            stored.single.pubkeys,
            equals(const [_memberA, _memberB]),
            reason: 'newer local state must not be overwritten by stale echo',
          );
        },
      );
    });

    for (final newestFirst in [false, true]) {
      for (final empty in [false, true]) {
        test('review regression hides outdated search revision '
            'empty:$empty newestFirst:$newestFirst', () async {
          final client = _MockNostrClient();
          final older = signedEvent(
            kind: 30000,
            tags: const [
              ['d', 'crew'],
              ['title', 'Skaters'],
              ['p', _memberA],
            ],
            createdAt: 100,
          );
          final newer = signedEvent(
            kind: 30000,
            tags: [
              ['d', 'crew'],
              ['title', if (empty) 'Skaters' else 'Surfers'],
              if (!empty) ['p', _memberA],
            ],
            createdAt: 200,
          );
          when(
            () => client.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer(
            (_) async => newestFirst ? [newer, older] : [older, newer],
          );
          final repository = buildRepository(nostrClient: client);
          expect(await repository.searchPublicLists('skate').toList(), isEmpty);
        });
      }
    }

    group('configured public exclusions', () {
      const tag = 'synthetic-machine-set';
      late _MockNostrClient client;
      setUp(() {
        client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        final event = signedEvent(
          kind: _peopleListKind,
          tags: [
            ['d', tag],
            ['title', 'Synthetic crew'],
            ['p', _memberA],
          ],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [event]);
      });

      test(
        'configured d-tag is omitted from search and discovery only',
        () async {
          final repository = buildRepository(
            nostrClient: client,
            additionalExcludedPublicDTags: {tag},
          );
          expect(await repository.discoverPublicLists(), isEmpty);
          expect(await repository.searchPublicLists('crew').toList(), isEmpty);
          final direct = await repository.fetchPublicList(
            ownerPubkey: _ownerPubkey,
            listId: tag,
          );
          expect(direct?.id, tag);
          expect(direct?.pubkeys, [_memberA]);
          await repository.syncOwner(ownerPubkey: _ownerPubkey);
          final owned = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(owned.single.id, tag);
          expect(owned.single.isEditable, isTrue);
        },
      );

      test(
        'unconfigured d-tag remains ordinary owner-authored curation',
        () async {
          final repository = buildRepository(nostrClient: client);
          expect((await repository.discoverPublicLists()).single.list.id, tag);
          expect(
            (await repository.searchPublicLists('crew').first).single.list.id,
            tag,
          );
        },
      );

      test(
        'copies exclusions so later caller mutations cannot change policy',
        () async {
          final exclusions = <String>{tag};
          final repository = buildRepository(
            nostrClient: client,
            additionalExcludedPublicDTags: exclusions,
          );
          exclusions.clear();
          expect(await repository.discoverPublicLists(), isEmpty);
          expect(await repository.searchPublicLists('crew').toList(), isEmpty);
        },
      );
    });

    group('discoverPublicLists', () {
      const secondOwner =
          '4444444444444444444444444444444444444444444444444444444444444444';

      Event peopleEvent({
        required String pubkey,
        required String dTag,
        required String title,
        required List<String> pubkeys,
        int? createdAt,
      }) {
        return Event(
          pubkey,
          _peopleListKind,
          [
            ['d', dTag],
            ['title', title],
            for (final pk in pubkeys) ['p', pk],
          ],
          '',
          createdAt: createdAt,
        );
      }

      const thirdOwner =
          '5555555555555555555555555555555555555555555555555555555555555555';

      test('reads the discovery relays alone, without the cache', () async {
        final client = _MockNostrClient();
        final repository = buildRepository(
          nostrClient: client,
          discoveryRelayUrls: const ['wss://relay.example'],
        );

        await repository.discoverPublicLists();

        verify(
          () => client.queryEvents(
            any(),
            tempRelays: ['wss://relay.example'],
            relayTypes: const [RelayType.temp],
            useCache: false,
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('reads the whole pool when no discovery relay is set', () async {
        final client = _MockNostrClient();
        final repository = buildRepository(nostrClient: client);

        await repository.discoverPublicLists();

        // No tempRelays, no relayTypes, the cache on: the defaults, which
        // the mock only matches when the call passed exactly those.
        verify(
          () => client.queryEvents(any(), timeout: any(named: 'timeout')),
        ).called(1);
      });

      test('keeps the lists whose author has posted on Divine', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'crew',
              title: 'Crew',
              pubkeys: const [_memberA],
            ),
            peopleEvent(
              pubkey: secondOwner,
              dTag: 'friends',
              title: 'Friends',
              pubkeys: const [_memberA],
            ),
            peopleEvent(
              pubkey: thirdOwner,
              dTag: 'strangers',
              title: 'Strangers',
              pubkeys: const [_memberA],
            ),
          ],
        );
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getBulkProfiles(any())).thenAnswer(
          (_) async => BulkProfilesResponse(
            profiles: {
              _ownerPubkey: divineProfile(_ownerPubkey, videos: 3),
              // Known to Funnelcake, never posted here.
              secondOwner: divineProfile(secondOwner, videos: 0),
              // The third owner is unknown to Funnelcake: absent.
            },
          ),
        );
        final repository = buildRepository(
          nostrClient: client,
          funnelcakeApiClient: api,
        );

        final results = await repository.discoverPublicLists();

        expect(results.map((result) => result.list.id), equals(['crew']));
        verify(
          () => api.getBulkProfiles(
            any(that: unorderedEquals([_ownerPubkey, secondOwner, thirdOwner])),
          ),
        ).called(1);
      });

      test('asks about the authors a hundred at a time', () async {
        final client = _MockNostrClient();
        final owners = [
          for (var i = 1; i <= 150; i++) i.toRadixString(16).padLeft(64, '0'),
        ];
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            for (final owner in owners)
              peopleEvent(
                pubkey: owner,
                dTag: 'crew',
                title: 'Crew',
                pubkeys: const [_memberA],
              ),
          ],
        );
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getBulkProfiles(any())).thenAnswer((invocation) async {
          final asked = invocation.positionalArguments.first as List<String>;
          return BulkProfilesResponse(
            profiles: {
              for (final pubkey in asked)
                pubkey: divineProfile(pubkey, videos: 1),
            },
          );
        });
        final repository = buildRepository(
          nostrClient: client,
          funnelcakeApiClient: api,
        );

        final results = await repository.discoverPublicLists();

        expect(results, hasLength(150));
        final pages = verify(
          () => api.getBulkProfiles(captureAny()),
        ).captured.cast<List<String>>();
        expect(pages.map((page) => page.length), equals([100, 50]));
      });

      test('keeps every list when the author check fails', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'crew',
              title: 'Crew',
              pubkeys: const [_memberA],
            ),
            peopleEvent(
              pubkey: secondOwner,
              dTag: 'friends',
              title: 'Friends',
              pubkeys: const [_memberA],
            ),
          ],
        );
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getBulkProfiles(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
          ),
        );
        final repository = buildRepository(
          nostrClient: client,
          funnelcakeApiClient: api,
        );

        final results = await repository.discoverPublicLists();

        expect(
          results.map((result) => result.list.id),
          unorderedEquals(['crew', 'friends']),
        );
      });

      test('skips the author check without Funnelcake', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'crew',
              title: 'Crew',
              pubkeys: const [_memberA],
            ),
          ],
        );
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(false);
        final repository = buildRepository(
          nostrClient: client,
          funnelcakeApiClient: api,
        );

        final results = await repository.discoverPublicLists();

        expect(results.map((result) => result.list.id), equals(['crew']));
        verifyNever(() => api.getBulkProfiles(any()));
      });

      test('reads with the shared public-lists budget', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        final repository = buildRepository(nostrClient: client);

        await repository.discoverPublicLists();

        verify(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: kPublicPeopleListsRelayReadTimeout,
          ),
        ).called(1);
      });

      test("skips other clients' machinery sets", () async {
        // A titled mute set is still a mute set: nothing to browse.
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'mute',
              title: 'Mute',
              pubkeys: const [_memberA],
            ),
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'dm-contacts',
              title: 'dm-contacts',
              pubkeys: const [_memberA],
            ),
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'crew',
              title: 'Crew',
              pubkeys: const [_memberA],
            ),
          ],
        );

        final repository = buildRepository(nostrClient: client);

        final results = await repository.discoverPublicLists();

        expect(results.map((r) => r.list.id), equals(['crew']));
      });

      test('returns lists newest first without a text filter', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'older',
              title: 'Older crew',
              pubkeys: [secondOwner],
              createdAt: 1000,
            ),
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'newer',
              title: 'Newer crew',
              pubkeys: [secondOwner],
              createdAt: 2000,
            ),
          ],
        );

        final repository = buildRepository(nostrClient: client);

        final results = await repository.discoverPublicLists();

        expect(results, hasLength(2));
        expect(results.first.list.name, equals('Newer crew'));
        expect(results.last.list.name, equals('Older crew'));
      });

      test('drops lists authored by excludeAuthor', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'mine',
              title: 'My own list',
              pubkeys: [secondOwner],
            ),
            peopleEvent(
              pubkey: secondOwner,
              dTag: 'theirs',
              title: 'Someone else',
              pubkeys: [_ownerPubkey],
            ),
          ],
        );

        final repository = buildRepository(nostrClient: client);

        final results = await repository.discoverPublicLists(
          excludeAuthor: _ownerPubkey,
        );

        expect(results, hasLength(1));
        expect(results.single.ownerPubkey, equals(secondOwner));
      });

      test('keeps the newest event per addressable coordinate', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'crew',
              title: 'Stale name',
              pubkeys: [secondOwner],
              createdAt: 1000,
            ),
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'crew',
              title: 'Fresh name',
              pubkeys: [secondOwner],
              createdAt: 2000,
            ),
          ],
        );

        final repository = buildRepository(nostrClient: client);

        final results = await repository.discoverPublicLists();

        expect(results, hasLength(1));
        expect(results.single.list.name, equals('Fresh name'));
      });

      test('returns empty when the relay has nothing', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const []);

        final repository = buildRepository(nostrClient: client);

        expect(await repository.discoverPublicLists(), isEmpty);
      });
    });

    for (final newestFirst in [false, true]) {
      test('discovery keeps an empty latest revision hidden '
          '(newestFirst: $newestFirst)', () async {
        final client = _MockNostrClient();
        final older = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'crew'],
            ['title', 'Crew'],
            ['p', _memberA],
          ],
          createdAt: 100,
        );
        final newer = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'crew'],
            ['title', 'Crew'],
          ],
          createdAt: 200,
        );
        when(
          () => client.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => newestFirst ? [newer, older] : [older, newer],
        );
        final repository = buildRepository(nostrClient: client);
        expect(await repository.discoverPublicLists(), isEmpty);
      });

      test('search does not revive a matching old name after rename '
          '(newestFirst: $newestFirst)', () async {
        final client = _MockNostrClient();
        final older = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'crew'],
            ['title', 'Skaters'],
            ['p', _memberA],
          ],
          createdAt: 100,
        );
        final newer = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'crew'],
            ['title', 'Surfers'],
            ['p', _memberA],
          ],
          createdAt: 200,
        );
        when(
          () => client.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => newestFirst ? [newer, older] : [older, newer],
        );
        final repository = buildRepository(nostrClient: client);
        expect(await repository.searchPublicLists('skate').toList(), isEmpty);
        final matches = await repository.searchPublicLists('surf').toList();
        expect(matches.single.single.list.name, 'Surfers');
      });
    }

    group('fetchPublicList', () {
      const secondOwner =
          '4444444444444444444444444444444444444444444444444444444444444444';

      for (final noRelays in [false, true]) {
        test(
          'unavailable public read is not absence (noRelays: $noRelays)',
          () async {
            final client = _MockNostrClient();
            when(
              () => client.queryEventsDetailed(
                any(),
                requireAllRelaysSettled: true,
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer(
              (_) async =>
                  (events: <Event>[], timedOut: !noRelays, noRelays: noRelays),
            );
            final repository = buildRepository(nostrClient: client);
            await expectLater(
              repository.fetchPublicList(
                ownerPubkey: _ownerPubkey,
                listId: 'crew',
              ),
              throwsA(isA<PublicPeopleListReadUnavailableException>()),
            );
          },
        );
      }

      Event peopleEvent({
        required String pubkey,
        required String dTag,
        required String title,
        int? createdAt,
      }) {
        return Event(
          pubkey,
          _peopleListKind,
          [
            ['d', dTag],
            ['title', title],
            ['p', secondOwner],
          ],
          '',
          createdAt: createdAt,
        );
      }

      for (final newestFirst in [false, true]) {
        test(
          'latest empty public list replaces stale members ($newestFirst)',
          () async {
            final older = peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'crew',
              title: 'Crew',
              createdAt: 1,
            );
            final latest = Event(
              _ownerPubkey,
              _peopleListKind,
              [
                ['d', 'crew'],
                ['title', 'Crew'],
              ],
              '',
              createdAt: 2,
            );
            final client = _MockNostrClient();
            when(
              () => client.queryEvents(any(), timeout: any(named: 'timeout')),
            ).thenAnswer(
              (_) async => newestFirst ? [latest, older] : [older, latest],
            );
            final repository = buildRepository(nostrClient: client);
            final list = await repository.fetchPublicList(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
            );
            expect(list, isNotNull);
            expect(list!.pubkeys, isEmpty);
            expect(list.isEditable, isFalse);
            expect(
              list.updatedAt,
              DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
            );
          },
        );
      }

      test('reads every relay and skips the author check', () async {
        // A list named by coordinate cannot be noise: a deep link or a shared
        // link may name one only a public relay holds.
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(pubkey: _ownerPubkey, dTag: 'crew', title: 'Crew'),
          ],
        );
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(true);
        final repository = buildRepository(
          nostrClient: client,
          funnelcakeApiClient: api,
          discoveryRelayUrls: const ['wss://relay.example'],
        );

        final list = await repository.fetchPublicList(
          ownerPubkey: _ownerPubkey,
          listId: 'crew',
        );

        expect(list?.name, equals('Crew'));
        // No tempRelays, no relayTypes, the cache on: the defaults, which
        // the mock only matches when the call passed exactly those.
        verify(
          () => client.queryEvents(any(), timeout: any(named: 'timeout')),
        ).called(1);
        verifyNever(() => api.getBulkProfiles(any()));
      });

      test('queries by author and d tag and returns the match', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(pubkey: _ownerPubkey, dTag: 'crew', title: 'Crew'),
          ],
        );

        final repository = buildRepository(nostrClient: client);

        final list = await repository.fetchPublicList(
          ownerPubkey: _ownerPubkey,
          listId: 'crew',
        );

        expect(list, isNotNull);
        expect(list!.name, equals('Crew'));
        // Someone else's list must not surface owner affordances.
        expect(list.isEditable, isFalse);

        final capturedFilters = verify(
          () => client.queryEvents(
            captureAny(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).captured.cast<List<Filter>>();
        final filter = capturedFilters.single.single;
        expect(filter.authors, equals([_ownerPubkey]));
        expect(filter.d, equals(['crew']));
      });

      test('ignores a same-d list from another author', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(pubkey: secondOwner, dTag: 'crew', title: 'Impostor'),
          ],
        );

        final repository = buildRepository(nostrClient: client);

        final list = await repository.fetchPublicList(
          ownerPubkey: _ownerPubkey,
          listId: 'crew',
        );

        expect(list, isNull);
      });

      test("treats a blocked author's list as absent", () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(pubkey: secondOwner, dTag: 'crew', title: 'Crew'),
          ],
        );

        final unblocked = await buildRepository(
          nostrClient: client,
        ).fetchPublicList(ownerPubkey: secondOwner, listId: 'crew');
        final blocked = await buildRepository(
          nostrClient: client,
          blockFilter: (pubkey) => pubkey == secondOwner,
        ).fetchPublicList(ownerPubkey: secondOwner, listId: 'crew');

        expect(unblocked, isNotNull);
        expect(blocked, isNull);
      });

      test('returns null when relays hold nothing', () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const []);

        final repository = buildRepository(nostrClient: client);

        expect(
          await repository.fetchPublicList(
            ownerPubkey: _ownerPubkey,
            listId: 'crew',
          ),
          isNull,
        );
      });
    });

    group('searchPublicLists', () {
      // Second owner pubkey for multi-owner deduplication tests.
      const secondOwner =
          '4444444444444444444444444444444444444444444444444444444444444444';

      Event peopleEvent({
        required String pubkey,
        required String dTag,
        required String title,
        required List<String> pubkeys,
        String? description,
        int? createdAt,
      }) {
        return Event(
          pubkey,
          _peopleListKind,
          [
            ['d', dTag],
            ['title', title],
            if (description != null) ['description', description],
            for (final pk in pubkeys) ['p', pk],
          ],
          '',
          createdAt: createdAt,
        );
      }

      test('reads the discovery relays alone', () async {
        final client = _MockNostrClient();
        final repository = buildRepository(
          nostrClient: client,
          discoveryRelayUrls: const ['wss://relay.example'],
        );

        await repository.searchPublicLists('crew').toList();

        verify(
          () => client.queryEvents(
            any(),
            tempRelays: ['wss://relay.example'],
            relayTypes: const [RelayType.temp],
            useCache: false,
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test("keeps the viewer's own list whatever Funnelcake says", () async {
        final client = _MockNostrClient();
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'crew',
              title: 'Crew',
              pubkeys: const [_memberA],
            ),
            peopleEvent(
              pubkey: secondOwner,
              dTag: 'crew',
              title: 'Crew too',
              pubkeys: const [_memberA],
            ),
          ],
        );
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(true);
        // Neither owner has posted; only the viewer's own list is kept, and
        // the viewer is not even asked about.
        when(
          () => api.getBulkProfiles(any()),
        ).thenAnswer((_) async => const BulkProfilesResponse(profiles: {}));
        final repository = buildRepository(
          nostrClient: client,
          funnelcakeApiClient: api,
        );

        final results = await repository
            .searchPublicLists('crew', viewerPubkey: _ownerPubkey)
            .toList();

        expect(
          results.single.map((r) => r.ownerPubkey),
          equals([_ownerPubkey]),
        );
        verify(() => api.getBulkProfiles([secondOwner])).called(1);
      });

      test("skips other clients' machinery sets", () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => [
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'dm-archive',
              title: 'Archive crew',
              pubkeys: const [_memberA],
            ),
            peopleEvent(
              pubkey: secondOwner,
              dTag: 'synthetic-machine-set',
              title: 'Health crew',
              pubkeys: const [_memberA],
            ),
          ],
        );

        final repository = buildRepository(
          nostrClient: client,
          additionalExcludedPublicDTags: {'synthetic-machine-set'},
        );

        final emissions = await repository.searchPublicLists('crew').toList();

        expect(emissions, isEmpty);
      });

      test(
        'queries 500 candidates independently of the result limit',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          when(
            () => client.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => const []);

          final repository = buildRepository(nostrClient: client);

          await repository.searchPublicLists('anything', limit: 25).toList();

          final capturedFilters = verify(
            () => client.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
              timeout: any(named: 'timeout'),
            ),
          ).captured.cast<List<Filter>>();
          expect(capturedFilters, hasLength(1));
          final filter = capturedFilters.single.single;
          expect(filter.kinds, equals(const [_peopleListKind]));
          expect(filter.limit, equals(500));
        },
      );

      test('keeps the candidate window through discovery filtering and '
          'cuts final search results deterministically', () async {
        final client = _MockNostrClient();
        final candidates = <Event>[
          for (var index = 0; index < 50; index++)
            peopleEvent(
              pubkey: _ownerPubkey,
              dTag: 'unrelated-$index',
              title: 'Not the requested group',
              pubkeys: const [_memberA],
              createdAt: 1710000200 - index,
            ),
          peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'b-matching',
            title: 'Crew B',
            pubkeys: const [_memberA],
            createdAt: 1710000000,
          ),
          peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'a-matching',
            title: 'Crew A',
            pubkeys: const [_memberB],
            createdAt: 1710000000,
          ),
        ];
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) async {
          final filters = invocation.positionalArguments.single as List<Filter>;
          return candidates.take(filters.single.limit!).toList();
        });
        final repository = buildRepository(nostrClient: client);

        final emissions = await repository
            .searchPublicLists('crew', limit: 1)
            .toList();

        expect(emissions, hasLength(1));
        expect(emissions.single, hasLength(1));
        expect(emissions.single.single.list.id, 'a-matching');
        expect(emissions.single.single.ownerPubkey, _ownerPubkey);
      });

      test('emits empty stream for a blank query', () async {
        final client = _MockNostrClient();
        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('').toList();

        expect(emissions, isEmpty);
        verifyNever(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        );
      });

      test('emits empty stream for a whitespace-only query', () async {
        final client = _MockNostrClient();
        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('   ').toList();

        expect(emissions, isEmpty);
      });

      test('emits a single match with the owner pubkey preserved', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final event = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'punk-friends',
          title: 'Punk Friends',
          pubkeys: const [_memberA, _memberB],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [event]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('punk').toList();

        expect(emissions, hasLength(1));
        final results = emissions.single;
        expect(results, hasLength(1));
        final result = results.single;
        expect(result.ownerPubkey, equals(_ownerPubkey));
        expect(result.ownerPubkey, hasLength(64));
        expect(result.list.id, equals('punk-friends'));
        expect(result.list.name, equals('Punk Friends'));
        expect(result.list.pubkeys, equals(const [_memberA, _memberB]));
        expect(
          result.addressableId,
          equals('$_peopleListKind:$_ownerPubkey:punk-friends'),
        );
      });

      test('filters out lists with no pubkeys', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final empty = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'empty',
          title: 'Empty Crew',
          pubkeys: const [],
        );
        final full = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'full',
          title: 'Crew',
          pubkeys: const [_memberA],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [empty, full]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('crew').toList();

        expect(emissions, hasLength(1));
        expect(emissions.single, hasLength(1));
        expect(emissions.single.single.list.id, equals('full'));
      });

      test('filters out the app block list (d=block)', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final block = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'block',
          title: 'Crew',
          pubkeys: const [_memberA],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [block]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('crew').toList();

        expect(emissions, isEmpty);
      });

      test('filters out blocked list owners', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final blocked = peopleEvent(
          pubkey: _blockedOwnerPubkey,
          dTag: 'blocked',
          title: 'Crew',
          pubkeys: const [_memberA],
        );
        final allowed = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'allowed',
          title: 'Crew',
          pubkeys: const [_memberB],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [blocked, allowed]);

        final repository = buildRepository(
          nostrClient: client,
          blockFilter: (pubkey) => pubkey == _blockedOwnerPubkey,
        );

        final emissions = await repository.searchPublicLists('crew').toList();

        expect(emissions, hasLength(1));
        expect(emissions.single, hasLength(1));
        expect(emissions.single.single.ownerPubkey, equals(_ownerPubkey));
      });

      test(
        'matches the query case-insensitively against name and description',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);

          final byName = peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'by-name',
            title: 'Punk Legends',
            pubkeys: const [_memberA],
          );
          final byDescription = peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'by-desc',
            title: 'Crew',
            description: 'All the PUNK heroes',
            pubkeys: const [_memberA],
          );
          final nonMatching = peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'other',
            title: 'Jazz Friends',
            pubkeys: const [_memberA],
          );
          when(
            () => client.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => [byName, byDescription, nonMatching]);

          final repository = buildRepository(nostrClient: client);

          final emissions = await repository.searchPublicLists('PuNk').toList();

          expect(emissions, hasLength(1));
          final ids = emissions.single.map((r) => r.list.id).toList();
          expect(ids, containsAll(<String>['by-name', 'by-desc']));
          expect(ids, isNot(contains('other')));
        },
      );

      test('deduplicates by addressable coordinate, not d tag alone', () async {
        // Two different owners both publish `d=friends` — these are
        // distinct addressable events and must both survive.
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final fromOwner = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'friends',
          title: 'Owner Friends',
          pubkeys: const [_memberA],
        );
        final fromSecondOwner = peopleEvent(
          pubkey: secondOwner,
          dTag: 'friends',
          title: 'Second Friends',
          pubkeys: const [_memberB],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [fromOwner, fromSecondOwner]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository
            .searchPublicLists('friends')
            .toList();

        expect(emissions, hasLength(1));
        final results = emissions.single;
        expect(results, hasLength(2));
        final owners = results.map((r) => r.ownerPubkey).toSet();
        expect(owners, equals({_ownerPubkey, secondOwner}));
        final coordinates = results.map((r) => r.addressableId).toSet();
        expect(
          coordinates,
          equals({
            '$_peopleListKind:$_ownerPubkey:friends',
            '$_peopleListKind:$secondOwner:friends',
          }),
        );
      });

      test('keeps the newest event when duplicates share an addressable '
          'coordinate', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final older = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'crew',
          title: 'Crew',
          pubkeys: const [_memberA],
          createdAt: 1710000000,
        );
        final newer = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'crew',
          title: 'Crew Updated',
          pubkeys: const [_memberA, _memberB],
          createdAt: 1710000500,
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [older, newer]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('crew').toList();

        expect(emissions, hasLength(1));
        expect(emissions.single, hasLength(1));
        expect(emissions.single.single.list.name, equals('Crew Updated'));
        expect(
          emissions.single.single.list.pubkeys,
          equals(const [_memberA, _memberB]),
        );
      });

      test('uses the lowest event id when duplicate revisions tie', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final higherId =
            peopleEvent(
                pubkey: _ownerPubkey,
                dTag: 'crew',
                title: 'Crew Higher id',
                pubkeys: const [_memberA],
                createdAt: 1710000000,
              )
              ..id =
                  'ffffffffffffffffffffffffffffffff'
                  'ffffffffffffffffffffffffffffffff';
        final lowerId =
            peopleEvent(
                pubkey: _ownerPubkey,
                dTag: 'crew',
                title: 'Crew Lower id',
                pubkeys: const [_memberB],
                createdAt: 1710000000,
              )
              ..id =
                  '00000000000000000000000000000000'
                  '00000000000000000000000000000000';
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [lowerId, higherId]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('crew').toList();

        expect(emissions, hasLength(1));
        expect(emissions.single, hasLength(1));
        expect(emissions.single.single.list.name, equals('Crew Lower id'));
      });

      test('keeps the newest event when the newer one arrives first', () async {
        // Relay/cache merge order is not guaranteed (queryEvents builds
        // an EventMemBox with sortAfterAdd: false), and the cache holding
        // the newer version while a lagging relay serves the older one
        // produces exactly this order. Fed oldest-first only, the dedup
        // guard can be deleted outright and the sibling test stays green.
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final older = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'crew',
          title: 'Crew',
          pubkeys: const [_memberA],
          createdAt: 1710000000,
        );
        final newer = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'crew',
          title: 'Crew Updated',
          pubkeys: const [_memberA, _memberB],
          createdAt: 1710000500,
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [newer, older]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('crew').toList();

        expect(emissions, hasLength(1));
        expect(emissions.single, hasLength(1));
        expect(emissions.single.single.list.name, equals('Crew Updated'));
        expect(
          emissions.single.single.list.pubkeys,
          equals(const [_memberA, _memberB]),
        );
      });

      test('does not yield when no events match the query', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final event = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'jazz',
          title: 'Jazz',
          pubkeys: const [_memberA],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [event]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('polka').toList();

        expect(emissions, isEmpty);
      });
    });

    group('watchLists', () {
      test('emits cached lists on subscribe and after createList', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          return _accepted(
            event: signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            ),
          );
        });
        final repository = buildRepository(nostrClient: client);

        // Take the first two emissions: the initial empty snapshot on
        // subscribe, and the post-createList snapshot driven by the cache's
        // box watch. Using `take(2).toList()` lets the stream drive timing
        // instead of timed waits.
        final emissionsFuture = repository
            .watchLists(ownerPubkey: _ownerPubkey)
            .take(2)
            .toList();

        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA],
        );

        final emissions = await emissionsFuture;

        expect(emissions, hasLength(2));
        expect(emissions.first, isEmpty);
        expect(emissions.last, hasLength(1));
        expect(emissions.last.single.pubkeys, equals(const [_memberA]));
      });
    });
    group('followed lists', () {
      const viewer =
          '6666666666666666666666666666666666666666666666666666666666666666';
      const otherOwner =
          '7777777777777777777777777777777777777777777777777777777777777777';

      UserList listOf(
        String id, {
        String name = 'Crew',
        List<String> pubkeys = const [_memberA],
        DateTime? updatedAt,
        bool isEditable = true,
      }) {
        final stamp = updatedAt ?? DateTime.utc(2026);
        return UserList(
          id: id,
          name: name,
          pubkeys: pubkeys,
          createdAt: stamp,
          updatedAt: stamp,
          isEditable: isEditable,
        );
      }

      Event peopleEvent({
        required String pubkey,
        required String dTag,
        required List<String> members,
        required int createdAt,
        String title = 'Crew',
      }) {
        return Event(
          pubkey,
          _peopleListKind,
          [
            ['d', dTag],
            ['title', title],
            for (final member in members) ['p', member],
          ],
          '',
          createdAt: createdAt,
        );
      }

      group('followList', () {
        test('keeps a read-only copy under the viewer', () async {
          final repository = buildRepository(nostrClient: _MockNostrClient());

          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );

          final followed = await repository.readFollowedLists(
            viewerPubkey: viewer,
          );
          expect(followed, hasLength(1));
          expect(followed.single.ownerPubkey, equals(_ownerPubkey));
          expect(followed.single.list.id, equals('crew'));
          expect(followed.single.list.isEditable, isFalse);
        });

        test('publishes nothing', () async {
          final client = _MockNostrClient();
          final repository = buildRepository(nostrClient: client);

          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );

          verifyNever(() => client.publishEvent(any()));
        });

        test("does not add the list to the owner's or the viewer's own "
            'lists', () async {
          final repository = buildRepository(nostrClient: _MockNostrClient());

          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );

          expect(await repository.readLists(ownerPubkey: viewer), isEmpty);
          expect(
            await repository.readLists(ownerPubkey: _ownerPubkey),
            isEmpty,
          );
        });

        test(
          'lists follows oldest first, whatever their coordinates',
          () async {
            final repository = buildRepository(nostrClient: _MockNostrClient());
            for (final id in ['zebra', 'apple']) {
              await repository.followList(
                viewerPubkey: viewer,
                ownerPubkey: _ownerPubkey,
                list: listOf(id),
              );
            }

            final followed = await repository.readFollowedLists(
              viewerPubkey: viewer,
            );

            expect(followed.map((f) => f.list.id), equals(['zebra', 'apple']));
          },
        );

        test(
          'following again keeps its place and takes the new copy',
          () async {
            final repository = buildRepository(nostrClient: _MockNostrClient());
            for (final id in ['early', 'late']) {
              await repository.followList(
                viewerPubkey: viewer,
                ownerPubkey: _ownerPubkey,
                list: listOf(id),
              );
            }

            await repository.followList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              list: listOf('early', name: 'Renamed'),
            );

            final followed = await repository.readFollowedLists(
              viewerPubkey: viewer,
            );
            expect(followed.map((f) => f.list.id), equals(['early', 'late']));
            expect(followed.first.list.name, equals('Renamed'));
          },
        );

        test('reports a follow that could not be recorded', () async {
          final cache = LocalPeopleListsCache(openBox: makeOpener());
          final repository = buildRepository(
            nostrClient: _MockNostrClient(),
            cache: cache,
            followedListsStore: _FailingFollowStore(),
          );

          await expectLater(
            repository.followList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              list: listOf('crew'),
            ),
            throwsA(isA<FileSystemException>()),
          );

          expect(
            await repository.readFollowedLists(viewerPubkey: viewer),
            isEmpty,
          );
          // The copy written ahead of the follow is taken back out.
          expect(await cache.readFollowedCopies(viewerPubkey: viewer), isEmpty);
        });
      });

      group('unfollowList', () {
        test('removes only the named follow', () async {
          final repository = buildRepository(nostrClient: _MockNostrClient());
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('keep'),
          );
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('drop'),
          );

          await repository.unfollowList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            listId: 'drop',
          );

          final followed = await repository.readFollowedLists(
            viewerPubkey: viewer,
          );
          expect(followed.map((f) => f.list.id), equals(['keep']));
        });

        test('holds even when the copy cannot be removed', () async {
          final repository = buildRepository(
            nostrClient: _MockNostrClient(),
            cache: _CopyRemovalFailingCache(openBox: makeOpener()),
          );
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );

          await expectLater(
            repository.unfollowList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
            ),
            completes,
          );

          expect(
            await repository.readFollowedLists(viewerPubkey: viewer),
            isEmpty,
          );
        });
      });

      group('readFollowedLists', () {
        test('leaves out a list whose owner is blocked', () async {
          final repository = buildRepository(
            nostrClient: _MockNostrClient(),
            blockFilter: (pubkey) => pubkey == _blockedOwnerPubkey,
          );
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('fine'),
          );
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _blockedOwnerPubkey,
            list: listOf('blocked'),
          );

          final followed = await repository.readFollowedLists(
            viewerPubkey: viewer,
          );

          expect(followed.map((f) => f.list.id), equals(['fine']));
        });
      });

      group('isFollowingList', () {
        test(
          'holds for the follow itself, whatever the copy or owner',
          () async {
            final cache = LocalPeopleListsCache(openBox: makeOpener());
            final repository = buildRepository(
              nostrClient: _MockNostrClient(),
              cache: cache,
              blockFilter: (owner) => owner == _ownerPubkey,
            );
            Future<bool> following() => repository.isFollowingList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
            );

            expect(await following(), isFalse);

            await repository.followList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              list: listOf('crew'),
            );
            // Blocked owner: left out of readFollowedLists, still followed.
            expect(await following(), isTrue);
            expect(
              await repository.readFollowedLists(viewerPubkey: viewer),
              isEmpty,
            );

            // A cache reset takes the copy, not the follow.
            await cache.clearFollowedCopies(viewerPubkey: viewer);
            expect(await following(), isTrue);

            await repository.unfollowList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
            );
            expect(await following(), isFalse);
          },
        );
      });

      group('watchFollowedLists', () {
        test('emits on follow and unfollow, without blocked owners', () async {
          final repository = buildRepository(
            nostrClient: _MockNostrClient(),
            blockFilter: (pubkey) => pubkey == _blockedOwnerPubkey,
          );
          final emissions = <List<String>>[];
          final subscription = repository
              .watchFollowedLists(viewerPubkey: viewer)
              .listen((lists) {
                emissions.add([for (final f in lists) f.list.id]);
              });
          addTearDown(subscription.cancel);
          await pumpEventQueue();

          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );
          await pumpEventQueue();
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _blockedOwnerPubkey,
            list: listOf('blocked'),
          );
          await pumpEventQueue();
          await repository.unfollowList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            listId: 'crew',
          );
          await pumpEventQueue();

          expect(emissions.first, isEmpty);
          expect(emissions, contains(equals(['crew'])));
          expect(emissions.last, isEmpty);
          expect(
            emissions.expand((ids) => ids),
            isNot(contains('blocked')),
          );
        });

        test('reaches a listener holding another repository instance over '
            'the same store and box', () async {
          final opener = makeOpener();
          final store = InMemoryFollowedPeopleListsStore();
          final listening = buildRepository(
            nostrClient: _MockNostrClient(),
            cache: LocalPeopleListsCache(openBox: opener),
            followedListsStore: store,
          );
          final writing = buildRepository(
            nostrClient: _MockNostrClient(),
            cache: LocalPeopleListsCache(openBox: opener),
            followedListsStore: store,
          );
          final emissions = <List<String>>[];
          final subscription = listening
              .watchFollowedLists(viewerPubkey: viewer)
              .listen((lists) {
                emissions.add([for (final f in lists) f.list.id]);
              });
          addTearDown(subscription.cancel);
          await pumpEventQueue();

          await writing.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );
          await pumpEventQueue();

          expect(emissions.last, equals(['crew']));
        });
      });

      group('syncFollowedLists', () {
        test(
          'canceled relay completion keeps the previous followed copy',
          () async {
            final read = Completer<List<Event>>();
            final entered = Completer<void>();
            final client = _MockNostrClient();
            when(
              () => client.queryEvents(any(), timeout: any(named: 'timeout')),
            ).thenAnswer((_) {
              entered.complete();
              return read.future;
            });
            final repository = buildRepository(nostrClient: client);
            await repository.followList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              list: listOf('crew'),
            );
            var canceled = false;
            final sync = repository.syncFollowedLists(
              viewerPubkey: viewer,
              isCancelled: () => canceled,
            );
            await entered.future;
            canceled = true;
            read.complete([
              peopleEvent(
                pubkey: _ownerPubkey,
                dTag: 'crew',
                members: const [_memberA, _memberB],
                createdAt: 1800000100,
              ),
            ]);
            await sync;
            expect(
              (await repository.readFollowedLists(
                viewerPubkey: viewer,
              )).single.list.pubkeys,
              [_memberA],
            );
          },
        );

        test(
          'unfollow after follow recheck leaves no late copy',
          () async {
            final client = _MockNostrClient();
            when(
              () => client.queryEvents(any(), timeout: any(named: 'timeout')),
            ).thenAnswer(
              (_) async => [
                peopleEvent(
                  pubkey: _ownerPubkey,
                  dTag: 'crew',
                  members: const [_memberA, _memberB],
                  createdAt: 1800000100,
                ),
              ],
            );
            final cache = _PausedRefreshCache(openBox: makeOpener());
            final repository = buildRepository(
              nostrClient: client,
              cache: cache,
            );
            await repository.followList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              list: listOf('crew'),
            );
            final sync = repository.syncFollowedLists(viewerPubkey: viewer);
            await cache.entered.future;
            final unfollow = repository.unfollowList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
            );
            await pumpEventQueue();
            cache.release.complete();
            await sync;
            await unfollow;
            expect(
              await cache.readFollowedCopies(viewerPubkey: viewer),
              isEmpty,
            );
          },
        );

        test('asks relays nothing when nothing is followed', () async {
          final client = _MockNostrClient();
          final repository = buildRepository(nostrClient: client);

          await repository.syncFollowedLists(viewerPubkey: viewer);

          verifyNever(
            () => client.queryEvents(any(), timeout: any(named: 'timeout')),
          );
        });

        test('asks for the followed coordinates in one filter', () async {
          final client = _MockNostrClient();
          when(
            () => client.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer((_) async => <Event>[]);
          final repository = buildRepository(nostrClient: client);
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: otherOwner,
            list: listOf('friends'),
          );

          await repository.syncFollowedLists(viewerPubkey: viewer);

          final filter =
              (verify(
                        () => client.queryEvents(
                          captureAny(),
                          timeout: kPublicPeopleListsRelayReadTimeout,
                        ),
                      ).captured.single
                      as List<Filter>)
                  .single;
          expect(filter.kinds, equals([_peopleListKind]));
          expect(filter.authors, unorderedEquals([_ownerPubkey, otherOwner]));
          expect(filter.d, unorderedEquals(['crew', 'friends']));
        });

        test("takes the owner's newer revision, read-only", () async {
          final client = _MockNostrClient();
          when(
            () => client.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer(
            (_) async => [
              peopleEvent(
                pubkey: _ownerPubkey,
                dTag: 'crew',
                members: const [_memberA],
                createdAt: 1800000000,
              ),
              peopleEvent(
                pubkey: _ownerPubkey,
                dTag: 'crew',
                members: const [_memberA, _memberB],
                createdAt: 1800000100,
                title: 'Crew, grown',
              ),
            ],
          );
          final repository = buildRepository(nostrClient: client);
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );

          await repository.syncFollowedLists(viewerPubkey: viewer);

          final followed = await repository.readFollowedLists(
            viewerPubkey: viewer,
          );
          expect(followed.single.list.name, equals('Crew, grown'));
          expect(followed.single.list.pubkeys, equals([_memberA, _memberB]));
          expect(followed.single.list.isEditable, isFalse);
        });

        test("ignores another owner's list that shares a followed d tag "
            'and events that do not decode', () async {
          final client = _MockNostrClient();
          when(
            () => client.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer(
            (_) async => [
              // `otherOwner` is followed for `friends`, not for `crew`.
              peopleEvent(
                pubkey: otherOwner,
                dTag: 'crew',
                members: const [_memberC],
                createdAt: 1800000100,
              ),
              Event(otherOwner, _peopleListKind, const [], ''),
            ],
          );
          final repository = buildRepository(nostrClient: client);
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: otherOwner,
            list: listOf('friends'),
          );

          await repository.syncFollowedLists(viewerPubkey: viewer);

          final followed = await repository.readFollowedLists(
            viewerPubkey: viewer,
          );
          expect(
            followed.map((f) => f.addressableId),
            equals([
              '$_peopleListKind:$_ownerPubkey:crew',
              '$_peopleListKind:$otherOwner:friends',
            ]),
          );
          expect(followed.first.list.pubkeys, equals([_memberA]));
        });

        test('a follow outlives a wiped cache, and the sync brings its copy '
            'back in place', () async {
          final client = _MockNostrClient();
          when(
            () => client.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer(
            (_) async => [
              peopleEvent(
                pubkey: _ownerPubkey,
                dTag: 'first',
                members: const [_memberA],
                createdAt: 1800000000,
              ),
              peopleEvent(
                pubkey: _ownerPubkey,
                dTag: 'second',
                members: const [_memberB],
                createdAt: 1800000000,
              ),
            ],
          );
          final cache = LocalPeopleListsCache(openBox: makeOpener());
          final repository = buildRepository(nostrClient: client, cache: cache);
          for (final id in ['second', 'first']) {
            await repository.followList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              list: listOf(id),
            );
          }

          // What "Reset app data" does to this box: every copy is gone.
          await cache.clearFollowedCopies(viewerPubkey: viewer);
          expect(
            await repository.readFollowedLists(viewerPubkey: viewer),
            isEmpty,
          );

          await repository.syncFollowedLists(viewerPubkey: viewer);

          final followed = await repository.readFollowedLists(
            viewerPubkey: viewer,
          );
          expect(followed.map((f) => f.list.id), equals(['second', 'first']));
          expect(followed.first.list.pubkeys, equals([_memberB]));
          expect(followed.first.list.isEditable, isFalse);
        });

        test('keeps the stored copies when the relay read fails', () async {
          final client = _MockNostrClient();
          when(
            () => client.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenThrow(Exception('relay down'));
          final repository = buildRepository(nostrClient: client);
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );

          await expectLater(
            repository.syncFollowedLists(viewerPubkey: viewer),
            completes,
          );

          final followed = await repository.readFollowedLists(
            viewerPubkey: viewer,
          );
          expect(followed.single.list.pubkeys, equals([_memberA]));
        });

        test('does not bring back a list unfollowed during the read', () async {
          final client = _MockNostrClient();
          late PeopleListsRepositoryImpl repository;
          when(
            () => client.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer((_) async {
            await repository.unfollowList(
              viewerPubkey: viewer,
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
            );
            return [
              peopleEvent(
                pubkey: _ownerPubkey,
                dTag: 'crew',
                members: const [_memberA, _memberB],
                createdAt: 1800000100,
              ),
            ];
          });
          final cache = LocalPeopleListsCache(openBox: makeOpener());
          repository = buildRepository(nostrClient: client, cache: cache);
          await repository.followList(
            viewerPubkey: viewer,
            ownerPubkey: _ownerPubkey,
            list: listOf('crew'),
          );

          await repository.syncFollowedLists(viewerPubkey: viewer);

          expect(
            await repository.readFollowedLists(viewerPubkey: viewer),
            isEmpty,
          );
          expect(await cache.readFollowedCopies(viewerPubkey: viewer), isEmpty);
        });
      });
    });
  });
}
