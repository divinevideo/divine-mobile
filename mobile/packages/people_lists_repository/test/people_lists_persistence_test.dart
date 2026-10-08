// ABOUTME: Ordered, acknowledged list writes and wider search regressions.
// ABOUTME: Models relay ordering independently of the repository cache.
import 'dart:async';
import 'dart:io';
import 'package:hive_ce/hive_ce.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:test/test.dart';

class _Client extends Mock implements NostrClient {}

class _Cache extends Mock implements LocalPeopleListsCache {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _alice =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _bob = '3333333333333333333333333333333333333333333333333333333333333333';
void main() {
  setUpAll(() {
    registerFallbackValue(Event(_owner, 30000, const [], ''));
    registerFallbackValue(Duration.zero);
  });
  var cacheNumber = 0;
  Future<LocalPeopleListsCache> cache() async {
    final directory = await Directory.systemTemp.createTemp('list-persistence');
    final box = await Hive.openBox<dynamic>(
      'lists${cacheNumber++}',
      path: directory.path,
    );
    addTearDown(() async {
      await box.close();
      await directory.delete(recursive: true);
    });
    return LocalPeopleListsCache(openBox: () async => box);
  }

  group('membership revision ordering', () {
    test('rapid mixed edits survive relay ordering and a cold read', () async {
      final client = _Client();
      var relay = Event(
        _owner,
        30000,
        const [
          ['d', 'crew'],
          ['title', 'Crew'],
          ['alt', 'Preserve metadata'],
        ],
        'encrypted-content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
      );
      final writes = <Event>[];
      when(
        () => client.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: true,
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => (events: [relay], timedOut: false, noRelays: false),
      );
      void accept(Event event) {
        writes.add(event);
        if (event.createdAt > relay.createdAt ||
            (event.createdAt == relay.createdAt &&
                event.id.compareTo(relay.id) < 0)) {
          relay = event;
        }
      }

      when(() => client.publishEvent(any())).thenAnswer((call) async {
        final event = call.positionalArguments.single as Event;
        accept(event);
        return PublishSuccess(event: event);
      });
      when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
        final event = call.positionalArguments.single as Event;
        accept(event);
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: const ['wss://relay.example'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });
      final repository = PeopleListsRepositoryImpl(
        nostrClient: client,
        cache: await cache(),
      );
      final results = await Future.wait([
        repository.addPubkey(
          ownerPubkey: _owner,
          listId: 'crew',
          pubkey: _alice,
        ),
        repository.addPubkey(ownerPubkey: _owner, listId: 'crew', pubkey: _bob),
        repository.removePubkey(
          ownerPubkey: _owner,
          listId: 'crew',
          pubkey: _alice,
        ),
        repository.addPubkey(
          ownerPubkey: _owner,
          listId: 'crew',
          pubkey: _alice,
        ),
      ]);
      expect(results.every((result) => result.submitted), isTrue);
      expect(writes, hasLength(4));
      for (var i = 1; i < writes.length; i++) {
        expect(writes[i].createdAt, greaterThan(writes[i - 1].createdAt));
      }
      final cold = PeopleListsRepositoryImpl(
        nostrClient: client,
        cache: await cache(),
      );
      await cold.syncOwner(ownerPubkey: _owner);
      expect(
        (await cold.readLists(ownerPubkey: _owner)).single.pubkeys,
        unorderedEquals([_alice, _bob]),
      );
      expect(relay.content, 'encrypted-content');
      expect(relay.tags, contains(equals(['alt', 'Preserve metadata'])));
    });
  });

  group('createList', () {
    test('relay rejection cannot cache a create as success', () async {
      final client = _Client();
      when(() => client.publishEvent(any())).thenAnswer(
        (call) async =>
            PublishSuccess(event: call.positionalArguments.single as Event),
      );
      when(() => client.publishEventAwaitOk(any())).thenAnswer(
        (call) async => PublishOutcome(
          eventId: (call.positionalArguments.single as Event).id,
          acceptedBy: const [],
          rejectedBy: const {'wss://relay.example': 'rejected'},
          noResponseFrom: const [],
        ),
      );
      final repository = PeopleListsRepositoryImpl(
        nostrClient: client,
        cache: await cache(),
      );
      expect(
        (await repository.createList(ownerPubkey: _owner, name: 'Crew')).status,
        PeopleListPublishStatus.failed,
      );
      expect(await repository.readLists(ownerPubkey: _owner), isEmpty);
    });
  });

  group('searchPublicLists', () {
    test(
      'search finds older candidates while respecting the result limit',
      () async {
        final client = _Client();
        final events = List.generate(
          80,
          (i) => Event(_owner, 30000, [
            ['d', 'crew-$i'],
            ['title', if (i < 55) 'Unrelated' else 'Matching'],
            ['p', _alice],
          ], ''),
        );
        when(
          () => client.queryEventsDetailed(
            any(),
            timeout: kPublicPeopleListsRelayReadTimeout,
            requireAllRelaysSettled: true,
          ),
        ).thenAnswer((call) async {
          final filter =
              (call.positionalArguments.single as List<Filter>).single;
          return (
            events: events.take(filter.limit!).toList(),
            timedOut: false,
            noRelays: false,
          );
        });
        final repository = PeopleListsRepositoryImpl(
          nostrClient: client,
          cache: await cache(),
        );
        final results = await repository
            .searchPublicLists('Matching', limit: 2)
            .toList();
        expect(results.single, hasLength(2));
        final filter =
            (verify(
                      () => client.queryEventsDetailed(
                        captureAny(),
                        timeout: kPublicPeopleListsRelayReadTimeout,
                        requireAllRelaysSettled: true,
                      ),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.limit, greaterThanOrEqualTo(500));
      },
    );

    test(
      'search keeps the newest matches whatever order relays answer',
      () async {
        final client = _Client();
        // Oldest first: cutting at the limit in arrival order would keep these.
        final events = [
          for (var i = 0; i < 4; i++)
            Event(
              _owner,
              30000,
              [
                ['d', 'crew-$i'],
                ['title', 'Matching'],
                ['p', _alice],
              ],
              '',
              createdAt: 1700000000 + i,
            ),
        ];
        when(
          () => client.queryEventsDetailed(
            any(),
            timeout: kPublicPeopleListsRelayReadTimeout,
            requireAllRelaysSettled: true,
          ),
        ).thenAnswer(
          (_) async => (events: events, timedOut: false, noRelays: false),
        );
        final repository = PeopleListsRepositoryImpl(
          nostrClient: client,
          cache: await cache(),
        );

        final results = await repository
            .searchPublicLists('Matching', limit: 2)
            .toList();

        expect(results.single.map((result) => result.list.id), [
          'crew-3',
          'crew-2',
        ]);
      },
    );

    test('public search excludes block and notify machinery sets', () async {
      final client = _Client();
      when(
        () => client.queryEventsDetailed(
          any(),
          timeout: kPublicPeopleListsRelayReadTimeout,
          requireAllRelaysSettled: true,
        ),
      ).thenAnswer(
        (_) async => (
          events: [
            for (final id in ['block', 'notify', 'crew'])
              Event(_owner, 30000, [
                ['d', id],
                ['title', 'Matching'],
                ['p', _alice],
              ], ''),
          ],
          timedOut: false,
          noRelays: false,
        ),
      );
      final repository = PeopleListsRepositoryImpl(
        nostrClient: client,
        cache: await cache(),
      );
      final results = await repository.searchPublicLists('Matching').toList();
      expect(results.single.map((result) => result.list.id), ['crew']);
      expect(
        await repository.searchPublicLists('Matching', limit: 0).toList(),
        isEmpty,
      );
    });
  });

  group('updateList', () {
    test(
      'metadata replacement preserves foreign tags, members and ciphertext',
      () async {
        final client = _Client();
        final original = Event(_owner, 30000, const [
          ['d', 'crew'],
          ['title', 'Old'],
          ['description', 'Old description'],
          ['title', 'Duplicate title'],
          ['image', 'https://example.test/image'],
          ['p', _alice, 'wss://relay.example', 'Friend'],
          ['alt', 'Preserve'],
        ], 'ciphertext');
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: [original], timedOut: false, noRelays: false),
        );
        when(() => client.publishEventAwaitOk(any())).thenAnswer(
          (call) async => PublishOutcome(
            eventId: (call.positionalArguments.single as Event).id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );
        final repository = PeopleListsRepositoryImpl(
          nostrClient: client,
          cache: await cache(),
        );
        expect(
          (await repository.updateList(
            ownerPubkey: _owner,
            listId: 'crew',
            name: 'Renamed',
            description: '',
          )).submitted,
          isTrue,
        );
        final event =
            verify(
                  () => client.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(event.tags.where((tag) => tag.first == 'title'), [
          ['title', 'Renamed'],
        ]);
        expect(event.tags.where((tag) => tag.first == 'description'), isEmpty);
        expect(
          event.tags,
          contains(equals(['p', _alice, 'wss://relay.example', 'Friend'])),
        );
        expect(
          event.tags,
          contains(equals(['image', 'https://example.test/image'])),
        );
        expect(event.tags, contains(equals(['alt', 'Preserve'])));
        expect(event.content, 'ciphertext');
        expect(event.createdAt, greaterThan(original.createdAt));
        expect(
          (await repository.readLists(ownerPubkey: _owner)).single.name,
          'Renamed',
        );
      },
    );

    test(
      'metadata update and member addition serialize over the same source',
      () async {
        final client = _Client();
        final original = Event(_owner, 30000, const [
          ['d', 'crew'],
          ['title', 'Old'],
          ['p', _alice],
        ], '');
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: [original], timedOut: false, noRelays: false),
        );
        when(() => client.publishEventAwaitOk(any())).thenAnswer(
          (call) async => PublishOutcome(
            eventId: (call.positionalArguments.single as Event).id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );
        final repository = PeopleListsRepositoryImpl(
          nostrClient: client,
          cache: await cache(),
        );
        final results = await Future.wait([
          repository.updateList(
            ownerPubkey: _owner,
            listId: 'crew',
            name: 'New',
            description: 'Description',
          ),
          repository.addPubkey(
            ownerPubkey: _owner,
            listId: 'crew',
            pubkey: _bob,
          ),
        ]);
        expect(results.every((result) => result.submitted), isTrue);
        final list = (await repository.readLists(ownerPubkey: _owner)).single;
        expect(list.name, 'New');
        expect(list.description, 'Description');
        expect(list.pubkeys, [_alice, _bob]);
        expect(
          (await repository.updateList(
            ownerPubkey: _owner,
            listId: 'crew',
            name: 'New',
            description: 'Description',
          )).status,
          PeopleListPublishStatus.noop,
        );
        expect(
          (await repository.updateList(
            ownerPubkey: _owner,
            listId: 'crew',
            name: '  ',
            description: '',
          )).status,
          PeopleListPublishStatus.failed,
        );
        expect(
          (await repository.updateList(
            ownerPubkey: _owner,
            listId: 'missing',
            name: 'New',
            description: '',
          )).status,
          PeopleListPublishStatus.failed,
        );
      },
    );
  });

  group('failed mutations', () {
    for (final action in ['add', 'remove', 'delete', 'update']) {
      for (final failure in ['rejected', 'silent', 'throw']) {
        test('$action keeps prior cache when relay is $failure', () async {
          final client = _Client();
          final original = Event(_owner, 30000, const [
            ['d', 'crew'],
            ['title', 'Crew'],
            ['p', _alice],
          ], '');
          when(
            () => client.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: true,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer(
            (_) async => (events: [original], timedOut: false, noRelays: false),
          );
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            call,
          ) async {
            if (failure == 'throw') throw StateError('Offline');
            return PublishOutcome(
              eventId: (call.positionalArguments.single as Event).id,
              acceptedBy: const [],
              rejectedBy: failure == 'rejected'
                  ? const {'wss://relay.example': 'rejected'}
                  : const {},
              noResponseFrom: failure == 'silent'
                  ? const ['wss://relay.example']
                  : const [],
            );
          });
          final repository = PeopleListsRepositoryImpl(
            nostrClient: client,
            cache: await cache(),
          );
          final result = await switch (action) {
            'add' => repository.addPubkey(
              ownerPubkey: _owner,
              listId: 'crew',
              pubkey: _bob,
            ),
            'remove' => repository.removePubkey(
              ownerPubkey: _owner,
              listId: 'crew',
              pubkey: _alice,
            ),
            'delete' => repository.deleteList(
              ownerPubkey: _owner,
              listId: 'crew',
            ),
            _ => repository.updateList(
              ownerPubkey: _owner,
              listId: 'crew',
              name: 'New',
              description: 'New description',
            ),
          };
          expect(result.status, PeopleListPublishStatus.failed);
          final retained = (await repository.readLists(
            ownerPubkey: _owner,
          )).single;
          expect(retained.nostrEventId, original.id);
          expect(retained.pubkeys, [_alice]);
          expect(retained.name, 'Crew');
          expect(
            retained.updatedAt.millisecondsSinceEpoch ~/ 1000,
            original.createdAt,
          );
        });
      }
    }
  });

  group('revision clock bounds', () {
    test(
      'far-future source fails without publishing or advancing cache',
      () async {
        final client = _Client();
        final original = Event(
          _owner,
          30000,
          const [
            ['d', 'crew'],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        );
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: [original], timedOut: false, noRelays: false),
        );
        final repository = PeopleListsRepositoryImpl(
          nostrClient: client,
          cache: await cache(),
        );
        expect(
          (await repository.addPubkey(
            ownerPubkey: _owner,
            listId: 'crew',
            pubkey: _alice,
          )).status,
          PeopleListPublishStatus.failed,
        );
        expect(
          (await repository.deleteList(
            ownerPubkey: _owner,
            listId: 'crew',
          )).status,
          PeopleListPublishStatus.failed,
        );
        verifyNever(() => client.publishEventAwaitOk(any()));
        expect(
          (await repository.readLists(ownerPubkey: _owner)).single.nostrEventId,
          original.id,
        );
      },
    );
  });

  group('deleteList', () {
    test(
      'queues after edits and cannot be resurrected by queued add',
      () async {
        final client = _Client();
        final original = Event(_owner, 30000, const [
          ['d', 'crew'],
        ], '');
        when(
          () => client.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: [original], timedOut: false, noRelays: false),
        );
        when(() => client.publishEventAwaitOk(any())).thenAnswer(
          (call) async => PublishOutcome(
            eventId: (call.positionalArguments.single as Event).id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );
        final repository = PeopleListsRepositoryImpl(
          nostrClient: client,
          cache: await cache(),
        );
        final results = await Future.wait([
          repository.addPubkey(
            ownerPubkey: _owner,
            listId: 'crew',
            pubkey: _alice,
          ),
          repository.deleteList(ownerPubkey: _owner, listId: 'crew'),
          repository.addPubkey(
            ownerPubkey: _owner,
            listId: 'crew',
            pubkey: _bob,
          ),
        ]);
        expect(results.map((result) => result.status), [
          PeopleListPublishStatus.submitted,
          PeopleListPublishStatus.submitted,
          PeopleListPublishStatus.failed,
        ]);
        final writes = verify(
          () => client.publishEventAwaitOk(captureAny()),
        ).captured.cast<Event>();
        expect(writes, hasLength(2));
        expect(writes.last.kind, 5);
        expect(writes.last.createdAt, greaterThan(writes.first.createdAt));
        expect(await repository.readLists(ownerPubkey: _owner), isEmpty);
      },
    );
  });

  group('syncOwner', () {
    test('cannot overwrite an acknowledged concurrent edit', () async {
      final client = _Client();
      final cache = _Cache();
      final original = Event(_owner, 30000, const [
        ['d', 'crew'],
      ], '');
      var record = CachedPeopleListRecord(
        list: Nip51PeopleListCodec.decode(original)!,
        sourceTags: original.tags,
        sourceContent: original.content,
      );
      registerFallbackValue(record.list);
      registerFallbackValue(DateTime.utc(2026));
      final syncRead = Completer<void>();
      final releaseSyncRead = Completer<void>();
      var firstRead = true;
      when(
        () => cache.readRecord(ownerPubkey: _owner, listId: 'crew'),
      ).thenAnswer((_) async {
        final snapshot = record;
        if (firstRead) {
          firstRead = false;
          syncRead.complete();
          await releaseSyncRead.future;
        }
        return snapshot;
      });
      when(
        () => cache.putList(
          ownerPubkey: _owner,
          list: any(named: 'list'),
          receivedAt: any(named: 'receivedAt'),
          sourceTags: any(named: 'sourceTags'),
          sourceContent: any(named: 'sourceContent'),
        ),
      ).thenAnswer((call) async {
        record = CachedPeopleListRecord(
          list: call.namedArguments[#list] as UserList,
          sourceTags: call.namedArguments[#sourceTags] as List<List<String>>,
          sourceContent: call.namedArguments[#sourceContent] as String,
        );
      });
      when(
        () => client.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: true,
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => (events: [original], timedOut: false, noRelays: false),
      );
      when(() => client.publishEventAwaitOk(any())).thenAnswer(
        (call) async => PublishOutcome(
          eventId: (call.positionalArguments.single as Event).id,
          acceptedBy: const ['wss://relay.example'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );
      final repository = PeopleListsRepositoryImpl(
        nostrClient: client,
        cache: cache,
      );
      final sync = repository.syncOwner(ownerPubkey: _owner);
      await syncRead.future;
      final edit = repository.addPubkey(
        ownerPubkey: _owner,
        listId: 'crew',
        pubkey: _alice,
      );
      // Drain the microtask-only client/cache fakes while sync holds its old
      // snapshot. Before serialization the edit finishes here, then the resumed
      // sync writes the obsolete snapshot over its acknowledged replacement.
      await Future<void>(() {});
      releaseSyncRead.complete();
      await sync;
      expect((await edit).submitted, isTrue);
      expect(record.list.pubkeys, [_alice]);
    });
  });
}
