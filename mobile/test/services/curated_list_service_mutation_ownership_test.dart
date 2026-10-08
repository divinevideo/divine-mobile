// ABOUTME: Cache mutation authorization is bound to the resolved list owner.
// ABOUTME: Foreign coordinates and uncertain legacy rows cannot write or sign.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

class _TestPreferences extends Fake implements SharedPreferences {
  _TestPreferences(
    this.backing, {
    this.rejectLists = false,
    this.gateNextListWrite = false,
  });
  final SharedPreferences backing;
  final bool rejectLists;
  final bool gateNextListWrite;
  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();
  int listWrites = 0;
  @override
  Set<String> getKeys() => backing.getKeys();
  @override
  bool containsKey(String key) => backing.containsKey(key);
  @override
  String? getString(String key) => backing.getString(key);
  @override
  List<String>? getStringList(String key) => backing.getStringList(key);
  @override
  bool? getBool(String key) => backing.getBool(key);
  @override
  Future<bool> setString(String key, String value) async {
    if (key == CuratedListService.listsStorageKey) {
      listWrites++;
      if (gateNextListWrite && listWrites == 1) {
        writeStarted.complete();
        await releaseWrite.future;
      }
      if (rejectLists) return false;
    }
    return backing.setString(key, value);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      backing.setStringList(key, value);
  @override
  Future<bool> setBool(String key, bool value) => backing.setBool(key, value);
  @override
  Future<bool> remove(String key) => backing.remove(key);
}

void main() {
  const owner =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const stranger =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const collaborator =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const first =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const second =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const added =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const id = 'crew';
  late _Auth auth;
  late _Client client;
  late SharedPreferences prefs;
  late CuratedListService service;

  CuratedList row({String? pubkey, String? eventId}) => CuratedList(
    id: id,
    name: 'List',
    pubkey: pubkey,
    nostrEventId: eventId,
    isCollaborative: true,
    allowedCollaborators: const [collaborator],
    videoEventIds: const [first, second],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  Future<void> load(
    List<CuratedList> rows, {
    Object? follows,
    bool signedIn = true,
    bool rejectWrites = false,
    bool gateWrites = false,
    CuratedListCacheWriteCoordinator? coordinator,
  }) async {
    SharedPreferences.setMockInitialValues({
      CuratedListService.listsStorageKey: jsonEncode(
        rows.map((r) => r.toJson()).toList(),
      ),
      CuratedListService.subscribedListsStorageKey: ?follows,
    });
    final backing = await SharedPreferences.getInstance();
    prefs = rejectWrites || gateWrites
        ? _TestPreferences(
            backing,
            rejectLists: rejectWrites,
            gateNextListWrite: gateWrites,
          )
        : backing;
    auth = _Auth();
    client = _Client();
    when(() => auth.isAuthenticated).thenReturn(signedIn);
    when(() => auth.currentPublicKeyHex).thenReturn(owner);
    stubListPublishing(client: client, auth: auth, pubkey: owner);
    service = CuratedListService(
      nostrService: client,
      authService: auth,
      prefs: prefs,
      cacheWriteCoordinator: coordinator,
    );
    addTearDown(service.dispose);
  }

  final writes = <String, Future<bool> Function(String)>{
    'add video': (key) => service.addVideoToList(key, added),
    'duplicate video': (key) => service.addVideoToList(key, first),
    'remove video': (key) => service.removeVideoFromList(key, first),
    'reorder videos': (key) => service.reorderVideos(key, [second, first]),
    'update metadata': (key) =>
        service.updateList(listId: key, name: 'Changed'),
    'add collaborator': (key) => service.addCollaborator(key, owner),
    'duplicate collaborator': (key) =>
        service.addCollaborator(key, collaborator),
    'remove collaborator': (key) =>
        service.removeCollaborator(key, collaborator),
  };

  void expectNoPublication() {
    verifyNever(
      () => auth.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    );
    verifyNever(() => client.publishEvent(any()));
    verifyNever(() => client.publishEventAwaitOk(any()));
  }

  group('mutation authorization', () {
    for (final entry in writes.entries) {
      for (final collision in [false, true]) {
        test(
          '${entry.key} rejects ${collision ? 'foreign coordinate with colliding own row' : 'foreign-only raw lookup'} without side effects',
          () async {
            final foreign = row(pubkey: stranger);
            await load([foreign, if (collision) row(pubkey: owner)]);
            final originalRows = service.lists;
            final originalDisk = prefs.getString(
              CuratedListService.listsStorageKey,
            );
            final originalFollows = prefs.getString(
              CuratedListService.subscribedListsStorageKey,
            );
            var notifications = 0;
            service.addListener(() => notifications++);
            expect(
              service.getListById(collision ? foreign.authorScopedId : id),
              foreign,
            );
            expect(
              await entry.value(collision ? foreign.authorScopedId : id),
              isFalse,
            );
            expect(service.lists, originalRows);
            expect(
              prefs.getString(CuratedListService.listsStorageKey),
              originalDisk,
            );
            expect(
              prefs.getString(CuratedListService.subscribedListsStorageKey),
              originalFollows,
            );
            expect(notifications, 0);
            expectNoPublication();
          },
        );
      }
      for (final scoped in [false, true]) {
        test(
          '${entry.key} accepts the ${scoped ? 'scoped' : 'raw'} owned coordinate despite a foreign-first collision',
          () async {
            final foreign = row(pubkey: stranger);
            await load([foreign, row(pubkey: owner)]);
            expect(await entry.value(scoped ? '$owner:$id' : id), isTrue);
            expect(service.getListById(foreign.authorScopedId), foreign);
            final stored = (jsonDecode(
              prefs.getString(CuratedListService.listsStorageKey)!,
            ) as List).cast<Map<String, dynamic>>();
            expect(CuratedList.fromJson(stored.first), foreign);
            expect(service.getListById('$owner:$id')?.pubkey, owner);
          },
        );
      }
    }
  });

  group('ownerless rows', () {
    for (final follows in [
      jsonEncode([id]),
      jsonEncode([':$id']),
      'unreadable',
    ]) {
      test(
        'ownerless row with follow metadata $follows is never claimed',
        () async {
          final local = row();
          await load([local], follows: follows);
          final disk = prefs.getString(CuratedListService.listsStorageKey);
          expect(await service.addVideoToList(id, added), isFalse);
          expect(
            await service.updateList(listId: id, name: 'Changed'),
            isFalse,
          );
          expect(service.getListById(id), local);
          expect(prefs.getString(CuratedListService.listsStorageKey), disk);
          expect(
            prefs.getString(CuratedListService.subscribedListsStorageKey),
            follows,
          );
          expectNoPublication();
        },
      );
    }

    test('published ownerless row cannot be adopted', () async {
      final local = row(eventId: first);
      await load([local]);
      final disk = prefs.getString(CuratedListService.listsStorageKey);
      expect(await service.addVideoToList(id, added), isFalse);
      expect(await service.updateList(listId: id, name: 'Changed'), isFalse);
      expect(service.getListById(id), local);
      expect(prefs.getString(CuratedListService.listsStorageKey), disk);
      expectNoPublication();
    });
  });

  group('legacy local drafts', () {
    test(
      'guest unpublished edits persist through restart without signing',
      () async {
        await load([row()], signedIn: false);
        when(() => auth.currentPublicKeyHex).thenReturn(null);
        expect(await service.addVideoToList(id, added), isTrue);
        expect(
          await service.updateList(listId: id, name: 'Guest edited'),
          isTrue,
        );
        final restored = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
        );
        addTearDown(restored.dispose);
        expect(restored.getListById(id)?.name, 'Guest edited');
        expect(restored.getListById(id)?.videoEventIds, [first, second, added]);
        expect(restored.getListById(id)?.pubkey, isNull);
        expectNoPublication();
      },
    );

    test(
      'signed-out remembered owner can edit only its stamped cached row',
      () async {
        final foreign = row(pubkey: stranger);
        await load([foreign, row(pubkey: owner)], signedIn: false);
        expect(await service.addVideoToList('$owner:$id', added), isTrue);
        expect(
          await service.updateList(listId: '$owner:$id', name: 'Offline edit'),
          isTrue,
        );
        expect(
          await service.addVideoToList(foreign.authorScopedId, added),
          isFalse,
        );
        expect(service.getListById(foreign.authorScopedId), foreign);
        expectNoPublication();
      },
    );

    test(
      'authenticated legacy local edit stamps owner before publication',
      () async {
        await load([row()]);
        expect(await service.addVideoToList(id, added), isTrue);
        expect(service.getListById('$owner:$id')?.videoEventIds, [
          first,
          second,
          added,
        ]);
        expect(service.getListById('$owner:$id')?.pubkey, owner);
        expect(service.getListById('$owner:$id')?.nostrEventId, isNotNull);
        final stored = CuratedList.fromJson(
          (jsonDecode(
                prefs.getString(CuratedListService.listsStorageKey)!,
              ) as List).single
              as Map<String, dynamic>,
        );
        expect(stored.pubkey, owner);
        verify(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).called(1);
      },
    );
    test(
      'refused legacy owner stamp never signs and restores pending local work',
      () async {
        final local = row().copyWith(pendingRepublish: true);
        await load([local], rejectWrites: true);
        final disk = prefs.getString(CuratedListService.listsStorageKey);
        expect(await service.addVideoToList(id, added), isFalse);
        expect(service.getListById(id), local);
        expect(prefs.getString(CuratedListService.listsStorageKey), disk);
        expectNoPublication();
      },
    );
  });

  group('relay backfill and owned coordinates', () {
    for (final follows in [
      jsonEncode([id]),
      jsonEncode([':$id']),
      'unreadable',
    ]) {
      test(
        'relay backfill cannot claim ownerless row with follow metadata $follows',
        () async {
          final local = row();
          await load([local], follows: follows);
          when(
            () =>
                client.subscribe(any(), closeOnEose: any(named: 'closeOnEose')),
          ).thenAnswer((_) => const Stream<Event>.empty());
          final disk = prefs.getString(CuratedListService.listsStorageKey);
          await service.fetchUserListsFromRelays();
          expect(service.getListById(id), local);
          expect(prefs.getString(CuratedListService.listsStorageKey), disk);
          expectNoPublication();
        },
      );
    }

    test(
      'relay backfill cannot adopt a published ownerless row marked for retry',
      () async {
        final local = row(eventId: first).copyWith(pendingRepublish: true);
        await load([local]);
        when(
          () => client.subscribe(any(), closeOnEose: any(named: 'closeOnEose')),
        ).thenAnswer((_) => const Stream<Event>.empty());
        final disk = prefs.getString(CuratedListService.listsStorageKey);
        await service.fetchUserListsFromRelays();
        expect(service.getListById(id), local);
        expect(prefs.getString(CuratedListService.listsStorageKey), disk);
        expectNoPublication();
      },
    );
    for (final legacyFirst in [false, true]) {
      test(
        'owner-stamp mutation rejects an existing owned coordinate (${legacyFirst ? 'legacy' : 'owned'} first)',
        () async {
          final legacy = row();
          final owned = row(pubkey: owner, eventId: first);
          await load(legacyFirst ? [legacy, owned] : [owned, legacy]);
          final rows = service.lists;
          final disk = prefs.getString(CuratedListService.listsStorageKey);
          expect(service.getListById(':$id'), legacy);
          expect(await service.addVideoToList(':$id', added), isFalse);
          expect(
            await service.updateList(listId: ':$id', name: 'Ambiguous edit'),
            isFalse,
          );
          expect(service.lists, rows);
          expect(prefs.getString(CuratedListService.listsStorageKey), disk);
          expectNoPublication();
        },
      );
      test(
        'relay backfill rejects an existing owned coordinate (${legacyFirst ? 'legacy' : 'owned'} first)',
        () async {
          final legacy = row();
          final owned = row(pubkey: owner, eventId: first);
          await load(legacyFirst ? [legacy, owned] : [owned, legacy]);
          when(
            () =>
                client.subscribe(any(), closeOnEose: any(named: 'closeOnEose')),
          ).thenAnswer((_) => const Stream<Event>.empty());
          final rows = service.lists;
          final disk = prefs.getString(CuratedListService.listsStorageKey);
          expect(rows, hasLength(2));
          expect(disk, isNotNull);
          final expectedRows = legacyFirst ? [legacy, owned] : [owned, legacy];
          expect(rows, expectedRows);
          expect(
            disk,
            jsonEncode(expectedRows.map((row) => row.toJson()).toList()),
          );
          await service.fetchUserListsFromRelays();
          expect(service.lists, rows);
          expect(prefs.getString(CuratedListService.listsStorageKey), disk);
          expectNoPublication();
        },
      );
      test(
        'scoped owned mutation remains available alongside an ambiguous null row (${legacyFirst ? 'legacy' : 'owned'} first)',
        () async {
          final legacy = row();
          final owned = row(pubkey: owner, eventId: first);
          await load(legacyFirst ? [legacy, owned] : [owned, legacy]);
          // Preserve legacy read resolution: a first null draft wins an
          // unscoped lookup. It cannot be claimed over the authored row.
          expect(service.getListById(id), legacyFirst ? legacy : owned);
          expect(await service.addVideoToList(id, added), !legacyFirst);
          expect(await service.addVideoToList('$owner:$id', added), isTrue);
          expect(service.getListById(':$id'), legacy);
          expect(service.getListById('$owner:$id')?.videoEventIds, [
            first,
            second,
            added,
          ]);
        },
      );
    }
  });

  group('null drafts beside authored rows', () {
    test('duplicate unknown local coordinates cannot be adopted', () async {
      final firstLegacy = row();
      final secondLegacy = row().copyWith(name: 'Other local draft');
      await load([firstLegacy, secondLegacy]);
      final rows = service.lists;
      final disk = prefs.getString(CuratedListService.listsStorageKey);
      expect(await service.addVideoToList(':$id', added), isFalse);
      expect(
        await service.updateList(listId: ':$id', name: 'Ambiguous edit'),
        isFalse,
      );
      expect(service.lists, rows);
      expect(prefs.getString(CuratedListService.listsStorageKey), disk);
      expectNoPublication();
    });

    test('true guest may keep its unique null draft beside an explicitly authored row', () async {
      final owned = row(pubkey: owner, eventId: first);
      await load([owned, row()], signedIn: false);
      when(() => auth.currentPublicKeyHex).thenReturn(null);
      expect(await service.addVideoToList(':$id', added), isTrue);
      expect(service.getListById('$owner:$id'), owned);
      expect(service.getListById(':$id')?.videoEventIds, [
        first,
        second,
        added,
      ]);
      expect(service.getListById(':$id')?.pubkey, isNull);
      expectNoPublication();
    });
    test('signed-out remembered account may edit its distinct null draft without adopting it', () async {
      final owned = row(pubkey: owner, eventId: first);
      await load([owned, row()], signedIn: false);
      expect(await service.addVideoToList(':$id', added), isTrue);
      expect(service.getListById('$owner:$id'), owned);
      expect(service.getListById(':$id')?.videoEventIds, [
        first,
        second,
        added,
      ]);
      expect(service.getListById(':$id')?.pubkey, isNull);
      expectNoPublication();
    });
    for (final legacyFirst in [false, true]) {
      test(
        'backfill targets the pending authored row despite a same-id null draft (${legacyFirst ? 'legacy' : 'owned'} first)',
        () async {
          final legacy = row();
          final owned = row(
            pubkey: owner,
            eventId: first,
          ).copyWith(pendingRepublish: true);
          await load(legacyFirst ? [legacy, owned] : [owned, legacy]);
          when(
            () =>
                client.subscribe(any(), closeOnEose: any(named: 'closeOnEose')),
          ).thenAnswer((_) => const Stream<Event>.empty());
          await service.fetchUserListsFromRelays();
          expect(service.getListById(':$id'), legacy);
          expect(service.getListById('$owner:$id')?.pendingRepublish, isFalse);
          final event =
              verify(() => client.publishEventAwaitOk(captureAny()))
                      .captured
                      .single
                  as Event;
          expect(event.pubkey, owner);
          expect(event.tags, contains(equals(['d', id])));
        },
      );
    }
  });
  PrefsCuratedListStore anotherStore(
    CuratedListCacheWriteCoordinator coordinator,
  ) {
    return PrefsCuratedListStore(
      prefs: prefs,
      writeCoordinator: coordinator,
      listsStorageKey: CuratedListService.listsStorageKey,
      subscriptionsStorageKey: CuratedListService.subscribedListsStorageKey,
      defaultListDeletedStorageKey:
          CuratedListService.defaultListDeletedStorageKey,
    )..listsLoaded(service.lists);
  }

  group('queued ownership claims', () {
    for (final newer in [false, true]) {
      final ownedDate = newer ? DateTime.utc(2040) : DateTime.utc(2000);
      for (final method in ['add', 'update', 'backfill']) {
        test(
          'stale $method cannot adopt a coordinate acknowledged with ${newer ? 'newer' : 'older'} authored data after load',
          () async {
            final local = row();
            final owned = row(
              pubkey: owner,
              eventId: first,
            ).copyWith(name: 'Another writer', updatedAt: ownedDate);
            final coordinator = CuratedListCacheWriteCoordinator();
            await load([local], coordinator: coordinator, gateWrites: true);
            final controlled = prefs as _TestPreferences;
            controlled.releaseWrite.complete();
            final other = anotherStore(coordinator);
            expect(await other.saveLists([local, owned]), isTrue);
            expect(service.lists, [local]);
            final acknowledged = prefs.getString(
              CuratedListService.listsStorageKey,
            );
            final writeCount = controlled.listWrites;
            if (method == 'backfill') {
              when(
                () => client.subscribe(
                  any(),
                  closeOnEose: any(named: 'closeOnEose'),
                ),
              ).thenAnswer((_) => const Stream<Event>.empty());
              await service.fetchUserListsFromRelays();
            } else if (method == 'add') {
              expect(await service.addVideoToList(':$id', added), isFalse);
            } else {
              expect(
                await service.updateList(
                  listId: ':$id',
                  name: 'Claim attempted',
                ),
                isFalse,
              );
            }
            expect(
              prefs.getString(CuratedListService.listsStorageKey),
              acknowledged,
            );
            expect(controlled.listWrites, writeCount);
            expect(service.getListById(':$id'), local);
            expectNoPublication();
          },
        );
      }
      test(
        'claim commit waits for ${newer ? 'newer' : 'older'} authored writer acknowledgement and rejects it at the shared barrier',
        () async {
          final local = row();
          final owned = row(
            pubkey: owner,
            eventId: first,
          ).copyWith(name: 'Queued authored writer', updatedAt: ownedDate);
          final coordinator = CuratedListCacheWriteCoordinator();
          await load([local], coordinator: coordinator, gateWrites: true);
          final controlled = prefs as _TestPreferences;
          final other = anotherStore(coordinator);
          final acknowledgedWrite = other.saveLists([local, owned]);
          await controlled.writeStarted.future;
          final mutationReachedSave = Completer<void>();
          service.addListener(() {
            if (service.lists.any((r) => r.pubkey == owner) &&
                !mutationReachedSave.isCompleted) {
              mutationReachedSave.complete();
            }
          });
          final pendingClaim = service.addVideoToList(':$id', added);
          await mutationReachedSave.future;
          controlled.releaseWrite.complete();
          expect(await acknowledgedWrite, isTrue);
          expect(await pendingClaim, isFalse);
          expect(controlled.listWrites, 1);
          final restored =
              (jsonDecode(prefs.getString(CuratedListService.listsStorageKey)!)
                      as List)
                  .map((r) => CuratedList.fromJson(r as Map<String, dynamic>))
                  .toList();
          expect(restored, [local, owned]);
          expect(service.getListById(':$id'), local);
          expectNoPublication();
        },
      );
    }
    for (final newer in [false, true]) {
      for (final duplicate in ['video', 'collaborator']) {
        test(
          'duplicate $duplicate refuses a stale claim after an ${newer ? 'newer' : 'older'} authored row is acknowledged',
          () async {
            final local = row();
            final owned = row(pubkey: owner, eventId: first).copyWith(
              updatedAt: newer ? DateTime.utc(2040) : DateTime.utc(2000),
            );
            final coordinator = CuratedListCacheWriteCoordinator();
            await load([local], coordinator: coordinator);
            expect(
              await anotherStore(coordinator).saveLists([local, owned]),
              isTrue,
            );
            final disk = prefs.getString(CuratedListService.listsStorageKey);
            expect(
              await (duplicate == 'video'
                  ? service.addVideoToList(':$id', first)
                  : service.addCollaborator(':$id', collaborator)),
              isFalse,
            );
            expect(service.lists, [local]);
            expect(prefs.getString(CuratedListService.listsStorageKey), disk);
            expectNoPublication();
          },
        );
      }
    }

    for (final followRecord in [
      jsonEncode([id]),
      jsonEncode([':$id']),
      'unreadable',
    ]) {
      test(
        'queued local claim checks the authoritative follow record $followRecord at commit',
        () async {
          final local = row();
          final coordinator = CuratedListCacheWriteCoordinator();
          await load([local], coordinator: coordinator);
          final entered = Completer<void>();
          final release = Completer<void>();
          final auxiliary = coordinator.runExclusive(() async {
            entered.complete();
            await release.future;
            await prefs.setString(
              CuratedListService.subscribedListsStorageKey,
              followRecord,
            );
          });
          await entered.future;
          final mutationReachedSave = Completer<void>();
          service.addListener(() {
            if (service.lists.any((r) => r.pubkey == owner) &&
                !mutationReachedSave.isCompleted) {
              mutationReachedSave.complete();
            }
          });
          final pendingClaim = service.addVideoToList(':$id', added);
          await mutationReachedSave.future;
          release.complete();
          await auxiliary;
          expect(await pendingClaim, isFalse);
          expect(service.getListById(':$id'), local);
          expect(
            prefs.getString(CuratedListService.listsStorageKey),
            jsonEncode([local.toJson()]),
          );
          expect(
            prefs.getString(CuratedListService.subscribedListsStorageKey),
            followRecord,
          );
          expectNoPublication();
        },
      );
    }

    for (final stored in ['unreadable', jsonEncode([])]) {
      test(
        'missing or unreadable acknowledged draft cannot authorize an owner claim ($stored)',
        () async {
          final local = row();
          await load([local]);
          await prefs.setString(CuratedListService.listsStorageKey, stored);
          expect(await service.addVideoToList(':$id', added), isFalse);
          expect(
            await service.updateList(listId: ':$id', name: 'Unverified claim'),
            isFalse,
          );
          expect(service.lists, [local]);
          expect(prefs.getString(CuratedListService.listsStorageKey), stored);
          expectNoPublication();
        },
      );
    }
    for (final newer in [false, true]) {
      test(
        'a queued edit cannot escape an unacknowledged owner claim after the ${newer ? 'newer' : 'older'} writer wins',
        () async {
          final local = row();
          final owned = row(pubkey: owner, eventId: first).copyWith(
            name: 'Acknowledged writer',
            updatedAt: newer ? DateTime.utc(2040) : DateTime.utc(2000),
          );
          final coordinator = CuratedListCacheWriteCoordinator();
          await load([local], coordinator: coordinator, gateWrites: true);
          final controlled = prefs as _TestPreferences;
          final otherWrite = anotherStore(coordinator)
              .saveLists([local, owned]);
          await controlled.writeStarted.future;
          final firstReached = Completer<void>();
          final secondReached = Completer<void>();
          service.addListener(() {
            final candidate = service.getListById('$owner:$id');
            if (candidate != null && !firstReached.isCompleted) {
              firstReached.complete();
            }
            if (candidate?.name == 'Queued edit' &&
                !secondReached.isCompleted) {
              secondReached.complete();
            }
          });
          final firstClaim = service.addVideoToList(':$id', added);
          await firstReached.future;
          final secondEdit = service.updateList(
            listId: '$owner:$id',
            name: 'Queued edit',
          );
          await secondReached.future;
          controlled.releaseWrite.complete();
          expect(await otherWrite, isTrue);
          expect(await firstClaim, isFalse);
          expect(await secondEdit, isFalse);
          expect(controlled.listWrites, 1);
          final stored =
              (jsonDecode(prefs.getString(CuratedListService.listsStorageKey)!)
                      as List)
                  .map((r) => CuratedList.fromJson(r as Map<String, dynamic>))
                  .toList();
          expect(stored, [local, owned]);
          expectNoPublication();
        },
      );
    }
    test(
      'a queued edit becomes valid once the originating claim is acknowledged',
      () async {
        final local = row();
        final coordinator = CuratedListCacheWriteCoordinator();
        await load([local], coordinator: coordinator, gateWrites: true);
        final controlled = prefs as _TestPreferences;
        final store = anotherStore(coordinator);
        final claimed = local.copyWith(pubkey: owner);
        final edited = claimed.copyWith(
          name: 'Acknowledged edit',
          updatedAt: DateTime.utc(2026, 1, 2),
        );
        final firstSave = store.saveListsWithResult(
          [claimed],
          ownershipClaims: {claimed.authorScopedId: local},
        );
        await controlled.writeStarted.future;
        final nextSave = store.saveListsWithResult([edited]);
        controlled.releaseWrite.complete();
        expect((await firstSave).succeeded, isTrue);
        expect((await nextSave).succeeded, isTrue);
        expect(controlled.listWrites, 2);
        final stored =
            (jsonDecode(prefs.getString(CuratedListService.listsStorageKey)!)
                    as List)
                .map((r) => CuratedList.fromJson(r as Map<String, dynamic>))
                .toList();
        expect(stored, [edited]);
        expectNoPublication();
      },
    );
    test('a missing follow key retires refused empty overlays before a genuine local claim', () async {
      final local = row();
      final coordinator = CuratedListCacheWriteCoordinator();
      await load([local], follows: jsonEncode([id]), coordinator: coordinator);
      final rejected = await coordinator.saveSubscriptionsWithResult(
        baseline: {id},
        current: const {},
        cacheKey: CuratedListService.subscribedListsStorageKey,
        read: () => {id},
        write: (ids) async {
          await prefs.setString(
            CuratedListService.subscribedListsStorageKey,
            jsonEncode(ids.toList()),
          );
          return false;
        },
      );
      expect(rejected.status, CuratedCacheWriteStatus.storageRejected);
      await prefs.remove(CuratedListService.subscribedListsStorageKey);
      final next = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
        cacheWriteCoordinator: coordinator,
      );
      addTearDown(next.dispose);
      expect(await next.addVideoToList(':$id', added), isTrue);
      expect(next.getListById('$owner:$id')?.videoEventIds, [
        first,
        second,
        added,
      ]);
    });
  });
}
