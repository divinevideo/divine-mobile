// ABOUTME: Raw owner labels cannot authorize adoption or vanish during a save.
// ABOUTME: Exclusive preflight rechecks evidence after preceding cache writers.

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
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../helpers/committed_list_account.dart';
import '../helpers/curated_list_publish_stubs.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

const _alice =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bob = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _video =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _added =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _collaborator =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _pending =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _id = 'secondary-owner';

void main() {
  late SharedPreferencesStorePlatform previous;
  late SharedPreferences prefs;
  late _Auth auth;
  late _Client client;
  late CuratedListService service;

  CuratedList row({String id = _id, String? pubkey}) => CuratedList(
    id: id,
    name: 'Retained local privacy work',
    pubkey: pubkey,
    isPublic: false,
    isCollaborative: true,
    allowedCollaborators: const [_collaborator],
    videoEventIds: const [_video],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  Map<String, dynamic> rawRow(CuratedList list) =>
      list.toJson()..['pendingPlaintextEventIds'] = const [_pending];

  Future<String> load(
    List<Map<String, dynamic>> rows, {
    String role = 'authenticated',
    CuratedListCacheWriteCoordinator? coordinator,
  }) async {
    final raw = jsonEncode(rows);
    SharedPreferences.setMockInitialValues({
      CuratedListService.listsStorageKey: raw,
      if (role != 'guest') 'current_user_pubkey_hex': _alice,
    });
    prefs = await SharedPreferences.getInstance();
    auth = _Auth();
    client = _Client();
    when(() => auth.isAuthenticated).thenReturn(role == 'authenticated');
    when(() => auth.currentPublicKeyHex)
        .thenReturn(role == 'guest' ? null : _alice);
    stubListPublishing(client: client, auth: auth, pubkey: _alice);
    if (role == 'authenticated') {
      await stubCommittedListAccount(auth: auth, preferences: prefs);
    }
    service = CuratedListService(
      nostrService: client,
      authService: auth,
      prefs: prefs,
      cacheWriteCoordinator: coordinator,
    );
    addTearDown(service.dispose);
    return raw;
  }

  setUp(() => previous = SharedPreferencesStorePlatform.instance);
  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
  });

  void noSigning() {
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

  PrefsCuratedListStore store(CuratedListCacheWriteCoordinator coordinator) {
    final adapter = PrefsCuratedListStore(
      prefs: prefs,
      writeCoordinator: coordinator,
      listsStorageKey: CuratedListService.listsStorageKey,
      subscriptionsStorageKey: CuratedListService.subscribedListsStorageKey,
      defaultListDeletedStorageKey:
          CuratedListService.defaultListDeletedStorageKey,
    );
    // The recovery-held service deliberately hides uncertain live rows. The
    // adapter still needs its own decoded disk baseline to retain those rows
    // byte-for-byte while an unrelated coordinate is saved.
    return adapter..listsLoaded(adapter.loadLists());
  }

  group('raw owner evidence', () {
    for (final label in ['ownerPubkey', 'authorPubkey']) {
      for (final role in ['authenticated', 'remembered', 'guest']) {
        test('$role cannot mutate a null-primary $label record', () async {
          final source = row();
          final raw = await load([rawRow(source)..[label] = _bob], role: role);
          final mutations = <Future<bool> Function()>[
            () => service.addVideoToList(':$_id', _added),
            () => service.addVideoToList(':$_id', _video),
            () => service.removeVideoFromList(':$_id', _video),
            () => service.reorderVideos(':$_id', const [_video]),
            () => service.updateList(listId: ':$_id', name: 'Uncertain edit'),
            () => service.addCollaborator(':$_id', _alice),
            () => service.addCollaborator(':$_id', _collaborator),
            () => service.removeCollaborator(':$_id', _collaborator),
          ];
          for (final mutate in mutations) {
            expect(await mutate(), isFalse);
            expect(service.getListById(':$_id'), isNull);
            expect(service.lists, isEmpty);
            expect(service.recoveryNeedsRepair, isTrue);
            expect(prefs.getString(CuratedListService.listsStorageKey), raw);
          }
          noSigning();
        });
      }

      test(
        'backfill preserves uncertain $label without publishing it',
        () async {
          final raw = await load([rawRow(row())..[label] = _bob]);
          when(
            () =>
                client.subscribe(any(), closeOnEose: any(named: 'closeOnEose')),
          ).thenAnswer((_) => const Stream<Event>.empty());
          await service.fetchUserListsFromRelays();
          expect(prefs.getString(CuratedListService.listsStorageKey), raw);
          expect((jsonDecode(raw) as List).single['pendingPlaintextEventIds'], [
            _pending,
          ]);
          noSigning();
        },
      );

      test('adapter claim cannot consume raw $label evidence', () async {
        final coordinator = CuratedListCacheWriteCoordinator();
        final source = row();
        final raw = await load([
          rawRow(source)..[label] = _bob,
        ], coordinator: coordinator);
        final claimed = source.copyWith(pubkey: _alice);
        final result = await store(coordinator).saveListsWithResult(
          [claimed],
          ownershipClaims: {claimed.authorScopedId: source},
        );
        expect(result.status, CuratedCacheWriteStatus.conflict);
        expect(prefs.getString(CuratedListService.listsStorageKey), raw);
        noSigning();
      });

      for (final role in ['authenticated', 'guest']) {
        test('queued $role mutation rechecks later $label evidence', () async {
          final coordinator = CuratedListCacheWriteCoordinator();
          final source = row();
          // A guest's unattributed pending privacy work is already held. Start
          // with a genuine clean draft so this case reaches the queued save.
          await load([source.toJson()], role: role, coordinator: coordinator);
          final entered = Completer<void>();
          final release = Completer<void>();
          final laterRaw = jsonEncode([rawRow(source)..[label] = _bob]);
          final writer = coordinator.runExclusive(() async {
            entered.complete();
            await release.future;
            await prefs.setString(CuratedListService.listsStorageKey, laterRaw);
          });
          await entered.future;
          final reachedSave = Completer<void>();
          service.addListener(() {
            if (service.lists.any((r) => r.videoEventIds.contains(_added)) &&
                !reachedSave.isCompleted) {
              reachedSave.complete();
            }
          });
          final mutation = service.addVideoToList(':$_id', _added);
          final enteredSave = await Future.any([
            reachedSave.future.then((_) => true),
            mutation.then((_) => false),
          ]);
          release.complete();
          await writer;
          expect(enteredSave, isTrue);
          expect(await mutation, isFalse);
          expect(prefs.getString(CuratedListService.listsStorageKey), laterRaw);
          expect(
            service.getListById(':$_id'),
            source.copyWith(pendingPlaintextEventIds: const [_pending]),
          );
          noSigning();
        });
      }

      test(
        'unrelated save retains raw $label and pending privacy work',
        () async {
          final coordinator = CuratedListCacheWriteCoordinator();
          final unknown = CuratedList.fromJson(rawRow(row()));
          final healthy = CuratedList.fromJson(
            rawRow(row(id: 'healthy', pubkey: _alice)),
          );
          final unknownRaw = rawRow(unknown)..[label] = _bob;
          await load([unknownRaw, rawRow(healthy)], coordinator: coordinator);
          expect(
            await store(coordinator)
                .saveLists([unknown, healthy.copyWith(name: 'Healthy edit')]),
            isTrue,
          );
          final persisted = jsonDecode(
            prefs.getString(CuratedListService.listsStorageKey)!,
          ) as List;
          expect(persisted.first, unknownRaw);
          expect(persisted.last['name'], 'Healthy edit');
          expect(await service.addVideoToList(':$_id', _added), isFalse);
          noSigning();
        },
      );

      test(
        'unloaded malformed row refuses saves and retains raw $label evidence',
        () async {
          final coordinator = CuratedListCacheWriteCoordinator();
          final damaged = rawRow(row())
            ..[label] = _bob
            ..['createdAt'] = 'invalid-date';
          final raw = await load([damaged], coordinator: coordinator);
          expect(service.lists, isEmpty);
          final healthy = row(id: 'healthy', pubkey: _alice);
          final result = await store(coordinator)
              .saveListsWithResult([healthy]);
          expect(result.status, CuratedCacheWriteStatus.storageRejected);
          expect(result.succeeded, isFalse);
          expect(result.persisted, isNull);
          expect(result.acknowledgedBeforeWrite, isNull);
          expect(prefs.getString(CuratedListService.listsStorageKey), raw);
          final persisted = jsonDecode(
            prefs.getString(CuratedListService.listsStorageKey)!,
          ) as List;
          expect(persisted, hasLength(1));
          expect(persisted.singleWhere((row) => row['id'] == _id), damaged);
          expect(persisted.any((row) => row['id'] == 'healthy'), isFalse);

          final repaired = rawRow(row())..[label] = _bob;
          expect(
            await prefs.setString(
              CuratedListService.listsStorageKey,
              jsonEncode([repaired]),
            ),
            isTrue,
          );
          final acknowledged = CuratedList.fromJson(repaired);
          final restarted = store(coordinator)..listsLoaded([acknowledged]);
          expect(await restarted.saveLists([acknowledged, healthy]), isTrue);
          final afterRepair = jsonDecode(
            prefs.getString(CuratedListService.listsStorageKey)!,
          ) as List;
          expect(afterRepair, hasLength(2));
          expect(afterRepair.singleWhere((row) => row['id'] == _id), repaired);
          expect(
            afterRepair.singleWhere((row) => row['id'] == 'healthy'),
            healthy.toJson(),
          );
          noSigning();
        },
      );

      test(
        'queued guest edit cannot erase malformed raw $label evidence',
        () async {
          final coordinator = CuratedListCacheWriteCoordinator();
          final source = row();
          await load(
            [source.toJson()],
            role: 'guest',
            coordinator: coordinator,
          );
          final damaged = rawRow(source)
            ..[label] = _bob
            ..['createdAt'] = 'invalid-date';
          final laterRaw = jsonEncode([damaged]);
          final entered = Completer<void>();
          final release = Completer<void>();
          final writer = coordinator.runExclusive(() async {
            entered.complete();
            await release.future;
            await prefs.setString(CuratedListService.listsStorageKey, laterRaw);
          });
          await entered.future;
          final reachedSave = Completer<void>();
          service.addListener(() {
            if (service.lists.any((r) => r.videoEventIds.contains(_added)) &&
                !reachedSave.isCompleted) {
              reachedSave.complete();
            }
          });
          final mutation = service.addVideoToList(':$_id', _added);
          final enteredSave = await Future.any([
            reachedSave.future.then((_) => true),
            mutation.then((_) => false),
          ]);
          release.complete();
          await writer;
          expect(enteredSave, isTrue);
          expect(await mutation, isFalse);
          expect(prefs.getString(CuratedListService.listsStorageKey), laterRaw);
          expect(service.getListById(':$_id'), source);
          noSigning();
        },
      );

      test(
        'a contradictory $label cannot authorize an explicit primary',
        () async {
          final owned = row(pubkey: _alice).copyWith(nostrEventId: _pending);
          final raw = await load([rawRow(owned)..[label] = _bob]);
          expect(await service.addVideoToList('$_alice:$_id', _added), isFalse);
          expect(await service.deleteOwnedList('$_alice:$_id'), isFalse);
          expect(prefs.getString(CuratedListService.listsStorageKey), raw);
          expect(
            prefs.getStringList(
              PrefsCuratedListStore.deletedCoordinatesStorageKey,
            ),
            isNull,
          );
          noSigning();
        },
      );

      for (final value in [_alice, null, 'invalid-owner']) {
        test('secondary $label $value never proves a primary author', () async {
          final raw = await load([rawRow(row())..[label] = value]);
          expect(await service.addVideoToList(':$_id', _added), isFalse);
          expect(prefs.getString(CuratedListService.listsStorageKey), raw);
          noSigning();
        });
      }

      test(
        'raw $label verdict follows exact current preference value',
        () async {
          final source = row();
          final original = await load([rawRow(source)]);
          final withEvidence = jsonEncode([rawRow(source)..[label] = _bob]);
          await prefs.setString(
            CuratedListService.listsStorageKey,
            withEvidence,
          );
          expect(await service.addVideoToList(':$_id', _added), isFalse);
          expect(
            prefs.getString(CuratedListService.listsStorageKey),
            withEvidence,
          );
          await prefs.setString(CuratedListService.listsStorageKey, original);
          expect(await service.addVideoToList(':$_id', _added), isTrue);
          expect(service.getListById('$_alice:$_id')?.videoEventIds, [
            _video,
            _added,
          ]);
        },
      );
    }
  });

  group('genuine draft compatibility', () {
    for (final role in ['authenticated', 'remembered', 'guest']) {
      test('$role keeps genuine unlabelled draft compatibility', () async {
        await load([row().toJson()], role: role);
        expect(await service.addVideoToList(':$_id', _added), isTrue);
        final key = role == 'authenticated' ? '$_alice:$_id' : ':$_id';
        expect(service.getListById(key)?.videoEventIds, [_video, _added]);
        if (role != 'authenticated') noSigning();
      });
    }

    test(
      'guest retains unattributed pending privacy work under a shared hold',
      () async {
        final source = row();
        final raw = await load([rawRow(source)], role: 'guest');
        expect(service.recoveryNeedsRepair, isTrue);
        expect(
          await service.addVideoToList(source.authorScopedId, _added),
          isFalse,
        );
        expect(
          service.getListById(source.authorScopedId),
          source.copyWith(
            pendingPlaintextEventIds: const [_pending],
          ),
        );
        expect(prefs.getString(CuratedListService.listsStorageKey), raw);
        noSigning();
      },
    );
  });

  group('authored mutation commit', () {
    test(
      'consistent full primary identity preserves secondary label on edit',
      () async {
        final owned = row(pubkey: _alice);
        await load([rawRow(owned)..['ownerPubkey'] = _alice.toUpperCase()]);
        expect(await service.addVideoToList('$_alice:$_id', _added), isTrue);
        final persisted = jsonDecode(
          prefs.getString(CuratedListService.listsStorageKey)!,
        ) as List;
        expect(persisted.single['ownerPubkey'], _alice.toUpperCase());
        expect(service.getListById('$_alice:$_id')?.videoEventIds, [
          _video,
          _added,
        ]);
      },
    );
    for (final corruptedField in ['pubkey', 'id']) {
      test(
        'queued owned mutation retains late invalid $corruptedField evidence',
        () async {
          final coordinator = CuratedListCacheWriteCoordinator();
          final source = row(pubkey: _alice).copyWith(
            isPublic: true,
            isCollaborative: false,
            allowedCollaborators: const [],
          );
          await load([rawRow(source)], coordinator: coordinator);
          final damaged = rawRow(source)
            ..['ownerPubkey'] = _bob
            ..[corruptedField] = 42;
          final laterRaw = jsonEncode([damaged]);
          final entered = Completer<void>();
          final release = Completer<void>();
          final writer = coordinator.runExclusive(() async {
            entered.complete();
            await release.future;
            await prefs.setString(CuratedListService.listsStorageKey, laterRaw);
          });
          await entered.future;
          final reachedSave = Completer<void>();
          service.addListener(() {
            if (service.lists.any((r) => r.videoEventIds.contains(_added)) &&
                !reachedSave.isCompleted) {
              reachedSave.complete();
            }
          });
          final mutation = service.addVideoToList('$_alice:$_id', _added);
          await reachedSave.future;
          release.complete();
          await writer;
          final accepted = await mutation;
          expect(
            accepted,
            isFalse,
            reason: 'An unclassifiable latest owner identity cannot authorize rewriting raw evidence',
          );
          expect(prefs.getString(CuratedListService.listsStorageKey), laterRaw);
          noSigning();
        },
      );
    }
  });
}
