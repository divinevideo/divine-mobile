// ABOUTME: Exercises outgoing list ACKs and disk writes across real cache wipes.
// ABOUTME: Uses distinct account auth objects and verifies incoming restart data.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

class _Preferences extends Fake implements SharedPreferences {
  _Preferences(this.backing);
  final SharedPreferences backing;
  String? gateKey;
  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();
  bool _gated = false;
  bool rejectSubscriptions = false;
  bool rejectLists = false;
  bool rejectRemoval = false;
  bool rejectDefaultFlag = false;
  bool rejectDefaultRecovery = false;
  bool rejectRecoveryRemoval = false;

  @override
  Future<void> reload() => backing.reload();
  @override
  Object? get(String key) => backing.get(key);
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
  Future<bool> remove(String key) =>
      rejectRemoval ||
          (rejectRecoveryRemoval &&
              key == PrefsCuratedListStore.pendingDefaultDeletionKey(_ownerA))
      ? Future.value(false)
      : backing.remove(key);
  Future<void> _gate(String key) async {
    if (key != gateKey || _gated) return;
    _gated = true;
    writeStarted.complete();
    await releaseWrite.future;
  }

  @override
  Future<bool> setString(String key, String value) async {
    await _gate(key);
    if (key == CuratedListService.listsStorageKey && rejectLists) return false;
    if (key == CuratedListService.subscribedListsStorageKey &&
        rejectSubscriptions) {
      return false;
    }
    return backing.setString(key, value);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    await _gate(key);
    return backing.setStringList(key, value);
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    await _gate(key);
    if (key == CuratedListService.defaultListDeletedStorageKey &&
        rejectDefaultFlag) {
      return false;
    }
    if (key == PrefsCuratedListStore.pendingDefaultDeletionKey(_ownerA) &&
        rejectDefaultRecovery) {
      return false;
    }
    return backing.setBool(key, value);
  }
}

const _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

CuratedList _row(String owner, {String id = 'crew'}) => CuratedList(
  id: id,
  pubkey: owner,
  name: 'Private account row',
  isPublic: false,
  videoEventIds: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  nostrEventId:
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
);

void _actor(_Auth auth, _Client client, String owner) {
  when(() => auth.isAuthenticated).thenReturn(true);
  when(() => auth.currentPublicKeyHex).thenReturn(owner);
  stubListPublishing(client: client, auth: auth, pubkey: owner);
  when(() => client.subscribe(any())).thenAnswer((_) => const Stream.empty());
}

void main() {
  group('CuratedListService account isolation', () {
    setUpAll(() => registerFallbackValue(Duration.zero));
    late _Preferences prefs;
    late _Auth authA;
    late _Client clientA;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        CuratedListService.listsStorageKey: jsonEncode([
          _row(_ownerA).toJson(),
        ]),
        'current_user_pubkey_hex': _ownerA,
      });
      prefs = _Preferences(await SharedPreferences.getInstance());
      authA = _Auth();
      clientA = _Client();
      _actor(authA, clientA, _ownerA);
    });

    CuratedListService open(
      _Auth auth,
      _Client client, {
      OnListUnsubscribedCallback? onUnsubscribed,
    }) {
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
        onListUnsubscribed: onUnsubscribed,
      );
      addTearDown(service.dispose);
      return service;
    }

    test(
      'late outgoing ACK cannot enter B cache after wipe and startup',
      () async {
        final old = open(authA, clientA);
        final published = Completer<Event>();
        final ack = Completer<PublishOutcome>();
        when(() => clientA.publishEventAwaitOk(any())).thenAnswer((call) {
          published.complete(call.positionalArguments.first as Event);
          return ack.future;
        });
        final edit = old.updateList(listId: 'crew', isPublic: true);
        final signed = await published.future;
        final queued = old.addVideoToList('crew', 'd' * 64);
        await UserDataCleanupService(prefs).clearUserSpecificData(
          userPubkey: _ownerA,
          isIdentityChange: true,
        );
        final authB = _Auth();
        final clientB = _Client();
        _actor(authB, clientB, _ownerB);
        final incoming = open(authB, clientB);
        await incoming.initialize();
        await incoming.fetchUserListsFromRelays(force: true);
        final incomingRows = prefs.getString(
          CuratedListService.listsStorageKey,
        );
        ack.complete(acceptedOutcome(signed));
        expect(await edit, isFalse);
        expect(await queued, isFalse);
        expect(old.isCurrentSession, isFalse);
        expect(
          prefs.getString(CuratedListService.listsStorageKey),
          incomingRows,
        );
        final restarted = open(authB, clientB);
        expect(restarted.getDefaultList()?.pubkey, _ownerB);
        expect(restarted.lists.any((list) => list.pubkey == _ownerA), isFalse);
        expect(authA.currentPublicKeyHex, _ownerA);
      },
    );

    for (final key in [
      CuratedListService.listsStorageKey,
      CuratedListService.subscribedListsStorageKey,
      CuratedListService.defaultListDeletedStorageKey,
    ]) {
      test(
        'wipe waits for dispatched $key and old completion cannot refill it',
        () async {
          final old = open(authA, clientA);
          prefs.gateKey = key;
          final Future<bool> operation;
          if (key == CuratedListService.listsStorageKey) {
            operation = old.updateList(
              listId: 'crew',
              name: 'Pending old metadata',
            );
          } else if (key == CuratedListService.subscribedListsStorageKey) {
            operation = old.subscribeToList('$_ownerA:crew');
          } else {
            final defaultRow = _row(
              _ownerA,
              id: CuratedListService.defaultListId,
            );
            await prefs.backing.setString(
              CuratedListService.listsStorageKey,
              jsonEncode([defaultRow.toJson()]),
            );
            final withDefault = open(authA, clientA);
            operation = withDefault.deleteOwnedList(defaultRow.authorScopedId);
          }
          await prefs.writeStarted.future;
          var wiped = false;
          final cleaning = UserDataCleanupService(prefs)
              .clearUserSpecificData(
                userPubkey: _ownerA,
                isIdentityChange: true,
              )
              .then((_) => wiped = true);
          expect(old.isCurrentSession, isFalse);
          expect(wiped, isFalse);
          prefs.releaseWrite.complete();
          expect(await operation, isFalse);
          await cleaning;
          expect(wiped, isTrue);
          expect(prefs.containsKey(key), isFalse);
          final authB = _Auth();
          final clientB = _Client();
          _actor(authB, clientB, _ownerB);
          final incoming = open(authB, clientB);
          await incoming.initialize();
          expect(incoming.getDefaultList()?.pubkey, _ownerB);
          expect(incoming.lists.any((list) => list.pubkey == _ownerA), isFalse);
        },
      );
    }

    test(
      'late create ACK cannot return an outgoing list to the incoming UI',
      () async {
        final old = open(authA, clientA);
        final entered = Completer<Event>();
        final ack = Completer<PublishOutcome>();
        when(() => clientA.publishEventAwaitOk(any())).thenAnswer((call) {
          entered.complete(call.positionalArguments.first as Event);
          return ack.future;
        });
        final creating = old.createList(name: 'Outgoing creation');
        final signed = await entered.future;
        await UserDataCleanupService(prefs)
            .clearUserSpecificData(userPubkey: _ownerA);
        final authB = _Auth();
        final clientB = _Client();
        _actor(authB, clientB, _ownerB);
        final incoming = open(authB, clientB);
        await incoming.initialize();
        final before = prefs.getString(CuratedListService.listsStorageKey);
        ack.complete(acceptedOutcome(signed));
        expect(await creating, isNull);
        expect(prefs.getString(CuratedListService.listsStorageKey), before);
        expect(
          open(authB, clientB).lists.any((row) => row.pubkey == _ownerA),
          isFalse,
        );
      },
    );

    test(
      'failed cache removal retires outgoing work and reports failure',
      () async {
        final old = open(authA, clientA);
        prefs.rejectRemoval = true;
        await expectLater(
          UserDataCleanupService(prefs).clearUserSpecificData(
            userPubkey: _ownerA,
            isIdentityChange: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(old.isCurrentSession, isFalse);
        expect(await old.updateList(listId: 'crew', name: 'Stale'), isFalse);
        final retry = open(authA, clientA);
        prefs.rejectRemoval = false;
        expect(
          await retry.updateList(listId: 'crew', name: 'Restored account'),
          isTrue,
        );
      },
    );

    test('restart cleans a refused follow removal without recreating deleted default', () async {
      final row = _row(_ownerA, id: CuratedListService.defaultListId);
      await prefs.backing.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([row.toJson()]),
      );
      await prefs.backing.setString(
        CuratedListService.subscribedListsStorageKey,
        jsonEncode([row.authorScopedId]),
      );
      final callbacks = <String>[];
      final service = open(authA, clientA, onUnsubscribed: callbacks.add);
      prefs.rejectSubscriptions = true;
      expect(await service.deleteOwnedList(row.authorScopedId), isFalse);
      expect(service.getDefaultList(), isNull);
      expect(service.subscribedListIds, contains(row.authorScopedId));
      expect(callbacks, isEmpty);
      expect(
        prefs.getBool(CuratedListService.defaultListDeletedStorageKey),
        isTrue,
      );
      prefs.rejectSubscriptions = false;
      final restarted = open(authA, clientA, onUnsubscribed: callbacks.add);
      await restarted.initialize();
      expect(restarted.getDefaultList(), isNull);
      expect(restarted.subscribedListIds, isEmpty);
      expect(callbacks, [row.authorScopedId]);
      expect(open(authA, clientA).subscribedListIds, isEmpty);
      expect(await restarted.deleteOwnedList(row.authorScopedId), isTrue);
      expect(callbacks, [row.authorScopedId]);
    });

    test(
      'public list reads stay available while initialization awaits the '
      'default list publish',
      () async {
        final published = Completer<Event>();
        final ack = Completer<PublishOutcome>();
        when(() => clientA.publishEventAwaitOk(any())).thenAnswer((call) {
          published.complete(call.positionalArguments.first as Event);
          return ack.future;
        });
        final service = open(authA, clientA);

        final initialization = service.initialize();
        final signed = await published.future;
        expect(service.isReadyForMutations, isFalse);
        expect(service.initializationError, isNull);
        when(
          () => clientA.subscribe(
            any(),
            closeOnEose: any(named: 'closeOnEose'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => const Stream.empty());

        await service.streamPublicListsFromRelays().toList();

        verify(
          () => clientA.subscribe(
            any(),
            closeOnEose: any(named: 'closeOnEose'),
            onEose: any(named: 'onEose'),
          ),
        ).called(1);
        ack.complete(acceptedOutcome(signed));
        await initialization;
        expect(service.isInitialized, isTrue);
      },
    );

    test('refused subscription recovery is observable and a same-service retry succeeds', () async {
      final row = _row(_ownerA, id: CuratedListService.defaultListId);
      await prefs.backing.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([row.toJson()]),
      );
      await prefs.backing.setString(
        CuratedListService.subscribedListsStorageKey,
        jsonEncode([row.authorScopedId]),
      );
      final original = open(authA, clientA);
      prefs.rejectSubscriptions = true;
      expect(await original.deleteOwnedList(row.authorScopedId), isFalse);
      final callbacks = <String>[];
      final blocked = open(authA, clientA, onUnsubscribed: callbacks.add);
      await blocked.initialize();
      expect(blocked.isInitialized, isFalse);
      expect(blocked.isReadyForMutations, isFalse);
      expect(blocked.initializationError, isA<CuratedCacheWriteException>());
      expect(blocked.getDefaultList(), isNull);
      expect(callbacks, isEmpty);
      clearInteractions(clientA);
      expect(await blocked.createList(name: 'Blocked'), isNull);
      expect(await blocked.subscribeToList(row.authorScopedId, row), isFalse);
      expect(await blocked.unsubscribeFromList(row.authorScopedId), isFalse);
      expect(await blocked.deleteOwnedList(row.authorScopedId), isFalse);
      await blocked.fetchUserListsFromRelays(force: true);
      expect(
        await blocked.fetchPublicList(authorPubkey: _ownerA, listId: row.id),
        isNull,
      );
      expect(await blocked.fetchPublicListsContainingVideo('f' * 64), isEmpty);
      expect(await blocked.streamPublicListsFromRelays().toList(), isEmpty);
      expect(
        await blocked.streamPublicListsContainingVideo('f' * 64).toList(),
        isEmpty,
      );
      verifyNever(() => clientA.subscribe(any()));
      verifyNever(() => clientA.publishEventAwaitOk(any()));
      expect(blocked.subscribedListIds, contains(row.authorScopedId));
      verifyNever(
        () => clientA.queryEvents(any(), timeout: any(named: 'timeout')),
      );
      prefs.rejectSubscriptions = false;
      await blocked.initialize();
      expect(blocked.isInitialized, isTrue);
      expect(blocked.isReadyForMutations, isTrue);
      expect(blocked.initializationError, isNull);
      expect(blocked.subscribedListIds, isEmpty);
      expect(blocked.getDefaultList(), isNull);
      expect(callbacks, [row.authorScopedId]);
      await blocked.initialize();
      expect(callbacks, [row.authorScopedId]);
    });

    test(
      'orphan follow recovery preserves another author and shared legacy alias',
      () async {
        final foreign = _row(_ownerB);
        final ownDefault = _row(_ownerA, id: CuratedListService.defaultListId);
        await prefs.backing.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([foreign.toJson(), ownDefault.toJson()]),
        );
        await prefs.backing.setString(
          CuratedListService.subscribedListsStorageKey,
          jsonEncode(['$_ownerA:crew', '$_ownerB:crew', 'crew']),
        );
        await prefs.backing.setStringList(
          PrefsCuratedListStore.deletedCoordinatesStorageKey,
          ['$_ownerA:crew'],
        );
        final callbacks = <String>[];
        final service = open(authA, clientA, onUnsubscribed: callbacks.add);
        await service.initialize();
        expect(service.subscribedListIds, {'$_ownerB:crew', 'crew'});
        expect(service.getListById('$_ownerB:crew'), foreign);
        expect(callbacks, ['$_ownerA:crew']);
        expect(open(authA, clientA).subscribedListIds, {
          '$_ownerB:crew',
          'crew',
        });
      },
    );

    test(
      'qualified delete retry completes only the refused follow removal',
      () async {
        final row = _row(_ownerA);
        await prefs.backing.setString(
          CuratedListService.subscribedListsStorageKey,
          jsonEncode([row.authorScopedId]),
        );
        final callbacks = <String>[];
        final service = open(authA, clientA, onUnsubscribed: callbacks.add);
        prefs.rejectSubscriptions = true;
        expect(await service.deleteOwnedList(row.authorScopedId), isFalse);
        expect(service.getListById(row.authorScopedId), isNull);
        expect(callbacks, isEmpty);
        prefs.rejectSubscriptions = false;
        expect(await service.deleteOwnedList(row.authorScopedId), isTrue);
        expect(service.subscribedListIds, isEmpty);
        expect(callbacks, [row.authorScopedId]);
        verify(() => clientA.publishEventAwaitOk(any())).called(1);
      },
    );

    test(
      'ABA with separate auth objects never revives the first A service',
      () async {
        final old = open(authA, clientA);
        final published = Completer<Event>();
        final ack = Completer<PublishOutcome>();
        when(() => clientA.publishEventAwaitOk(any())).thenAnswer((call) {
          published.complete(call.positionalArguments.first as Event);
          return ack.future;
        });
        final edit = old.updateList(listId: 'crew', isPublic: true);
        final signed = await published.future;
        await UserDataCleanupService(prefs)
            .clearUserSpecificData(userPubkey: _ownerA);
        final authB = _Auth();
        final clientB = _Client();
        _actor(authB, clientB, _ownerB);
        await open(authB, clientB).initialize();
        await UserDataCleanupService(prefs)
            .clearUserSpecificData(userPubkey: _ownerB);
        final restoredAuth = _Auth();
        final restoredClient = _Client();
        _actor(restoredAuth, restoredClient, _ownerA);
        final restored = open(restoredAuth, restoredClient);
        await restored.initialize();
        final before = prefs.getString(CuratedListService.listsStorageKey);
        ack.complete(acceptedOutcome(signed));
        expect(await edit, isFalse);
        expect(prefs.getString(CuratedListService.listsStorageKey), before);
        expect(old.isCurrentSession, isFalse);
        expect(restored.isCurrentSession, isTrue);
        expect(restored.getListById('crew'), isNull);
        expect(restored.getDefaultList()?.pubkey, _ownerA);
      },
    );

    test(
      'retirement during signer lookup prevents encryption and signing',
      () async {
        final signer = stubListSigner(clientA, _ownerA);
        final started = Completer<void>();
        final owner = Completer<String?>();
        when(signer.getPublicKey).thenAnswer((_) {
          started.complete();
          return owner.future;
        });
        final service = open(authA, clientA);
        final adding = service.addVideoToList('crew', 'd' * 64);
        await started.future;
        await UserDataCleanupService(prefs)
            .clearUserSpecificData(userPubkey: _ownerA);
        owner.complete(_ownerA);
        expect(await adding, isFalse);
        verifyNever(() => signer.nip44Encrypt(any(), any()));
        verifyNever(
          () => authA.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        );
        expect(prefs.containsKey(CuratedListService.listsStorageKey), isFalse);
      },
    );

    test('retired signing result cannot be dispatched to a relay', () async {
      final entered = Completer<void>();
      final signing = Completer<Event?>();
      when(
        () => authA.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((_) {
        entered.complete();
        return signing.future;
      });
      final service = open(authA, clientA);
      final editing = service.updateList(listId: 'crew', isPublic: true);
      await entered.future;
      await UserDataCleanupService(prefs)
          .clearUserSpecificData(userPubkey: _ownerA);
      signing.complete(Event(_ownerA, 30005, const [], 'superseded'));
      expect(await editing, isFalse);
      verifyNever(() => clientA.publishEventAwaitOk(any()));
      expect(prefs.containsKey(CuratedListService.listsStorageKey), isFalse);
    });

    test('owner recovery markers survive swap and scoped deletion removes only target', () async {
      final ownKey = PrefsCuratedListStore.pendingDefaultDeletionKey(_ownerA);
      final foreignKey = PrefsCuratedListStore.pendingDefaultDeletionKey(
        _ownerB,
      );
      await prefs.backing.setBool(ownKey, true);
      await prefs.backing.setBool(foreignKey, true);
      final cleanup = UserDataCleanupService(prefs);
      await cleanup.clearUserSpecificData(
        userPubkey: _ownerA,
        isIdentityChange: true,
      );
      expect(prefs.getBool(ownKey), isTrue);
      expect(prefs.getBool(foreignKey), isTrue);
      await cleanup.deleteAccountData(
        _ownerA,
        userNpub: 'inactive',
        preserveActiveSession: true,
      );
      expect(prefs.containsKey(ownKey), isFalse);
      expect(prefs.getBool(foreignKey), isTrue);
    });

    for (final followed in [false, true]) {
      test(
        'rejected default flag recovers durable removal, followed=$followed',
        () async {
          final row = _row(_ownerA, id: CuratedListService.defaultListId);
          await prefs.backing.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([row.toJson()]),
          );
          if (followed) {
            await prefs.backing.setString(
              CuratedListService.subscribedListsStorageKey,
              jsonEncode([row.authorScopedId]),
            );
          }
          final callbacks = <String>[];
          final service = open(authA, clientA, onUnsubscribed: callbacks.add);
          prefs.rejectDefaultFlag = true;
          expect(await service.deleteOwnedList(row.authorScopedId), isFalse);
          await prefs.backing.reload();
          expect(
            prefs.getBool(CuratedListService.defaultListDeletedStorageKey),
            isNull,
          );
          expect(
            prefs.getBool(
              PrefsCuratedListStore.pendingDefaultDeletionKey(_ownerA),
            ),
            isTrue,
          );
          expect(open(authA, clientA).getDefaultList(), isNull);
          final blocked = open(authA, clientA);
          await blocked.initialize();
          expect(blocked.isInitialized, isFalse);
          expect(blocked.getDefaultList(), isNull);
          prefs.rejectDefaultFlag = false;
          final recovered = open(authA, clientA, onUnsubscribed: callbacks.add);
          await recovered.initialize();
          await prefs.backing.reload();
          expect(recovered.isInitialized, isTrue);
          expect(recovered.getDefaultList(), isNull);
          expect(recovered.subscribedListIds, isEmpty);
          expect(callbacks, followed ? [row.authorScopedId] : isEmpty);
          expect(
            prefs.getBool(CuratedListService.defaultListDeletedStorageKey),
            isTrue,
          );
          expect(
            prefs.containsKey(
              PrefsCuratedListStore.pendingDefaultDeletionKey(_ownerA),
            ),
            isFalse,
          );
          expect(open(authA, clientA).getDefaultList(), isNull);
        },
      );
    }

    test(
      'rejected deletion recovery marker leaves the durable row and follow',
      () async {
        final row = _row(_ownerA, id: CuratedListService.defaultListId);
        await prefs.backing.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([row.toJson()]),
        );
        await prefs.backing.setString(
          CuratedListService.subscribedListsStorageKey,
          jsonEncode([row.authorScopedId]),
        );
        final service = open(authA, clientA);
        prefs.rejectDefaultRecovery = true;
        expect(await service.deleteOwnedList(row.authorScopedId), isFalse);
        await prefs.backing.reload();
        expect(open(authA, clientA).getDefaultList(), row);
        expect(
          open(authA, clientA).subscribedListIds,
          contains(row.authorScopedId),
        );
        expect(
          prefs.containsKey(
            PrefsCuratedListStore.pendingDefaultDeletionKey(_ownerA),
          ),
          isFalse,
        );
      },
    );

    test(
      'refused marker cleanup cannot lose the eventual unsubscribe callback',
      () async {
        final row = _row(_ownerA, id: CuratedListService.defaultListId);
        await prefs.backing.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([row.toJson()]),
        );
        await prefs.backing.setString(
          CuratedListService.subscribedListsStorageKey,
          jsonEncode([row.authorScopedId]),
        );
        final callbacks = <String>[];
        final service = open(authA, clientA, onUnsubscribed: callbacks.add);
        prefs.rejectRecoveryRemoval = true;
        expect(await service.deleteOwnedList(row.authorScopedId), isFalse);
        await prefs.backing.reload();
        expect(open(authA, clientA).getDefaultList(), isNull);
        expect(
          open(authA, clientA).subscribedListIds,
          contains(row.authorScopedId),
        );
        expect(callbacks, isEmpty);
        prefs.rejectRecoveryRemoval = false;
        expect(await service.deleteOwnedList(row.authorScopedId), isTrue);
        expect(open(authA, clientA).subscribedListIds, isEmpty);
        expect(callbacks, [row.authorScopedId]);
        expect(await service.deleteOwnedList(row.authorScopedId), isTrue);
        expect(callbacks, [row.authorScopedId]);
      },
    );

    test('default list write refusal is observable and retryable', () async {
      await prefs.backing.remove(CuratedListService.listsStorageKey);
      final service = open(authA, clientA);
      prefs.rejectLists = true;
      await service.initialize();
      expect(service.isInitialized, isFalse);
      expect(service.isReadyForMutations, isFalse);
      expect(service.initializationError, isA<CuratedCacheWriteException>());
      expect(service.getDefaultList(), isNull);
      verifyNever(() => clientA.publishEventAwaitOk(any()));
      prefs.rejectLists = false;
      await service.initialize();
      expect(service.isInitialized, isTrue);
      expect(service.initializationError, isNull);
      expect(service.getDefaultList(), isNotNull);
      expect(prefs.getString(CuratedListService.listsStorageKey), isNotNull);
    });

    test(
      'provider exposes recovery failure and retries after storage recovers',
      () async {
        final row = _row(_ownerA, id: CuratedListService.defaultListId);
        await prefs.backing.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([row.toJson()]),
        );
        await prefs.backing.setString(
          CuratedListService.subscribedListsStorageKey,
          jsonEncode([row.authorScopedId]),
        );
        prefs.rejectSubscriptions = true;
        expect(
          await open(authA, clientA).deleteOwnedList(row.authorScopedId),
          isFalse,
        );
        final container = ProviderContainer(
          // Exercise the explicit recovery action, independently of Riverpod's
          // automatic retry scheduling.
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authServiceProvider.overrideWithValue(authA),
            nostrServiceProvider.overrideWithValue(clientA),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          curatedListsStateProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await expectLater(
          container.read(curatedListsStateProvider.future),
          throwsA(isA<CuratedCacheWriteException>()),
        );
        expect(container.read(curatedListsStateProvider).hasError, isTrue);
        final failedService = container
            .read(curatedListsStateProvider.notifier)
            .service!;
        expect(failedService.isReadyForMutations, isFalse);
        expect(failedService.getDefaultList(), isNull);
        verifyNever(
          () => clientA.queryEvents(any(), timeout: any(named: 'timeout')),
        );

        prefs.rejectSubscriptions = false;
        container.invalidate(curatedListsStateProvider);
        expect(await container.read(curatedListsStateProvider.future), isEmpty);
        final recovered = container
            .read(curatedListsStateProvider.notifier)
            .service!;
        expect(recovered, isNot(same(failedService)));
        expect(failedService.isCurrentSession, isFalse);
        expect(recovered.isInitialized, isTrue);
        expect(recovered.isReadyForMutations, isTrue);
        expect(recovered.subscribedListIds, isEmpty);
        expect(recovered.getDefaultList(), isNull);
      },
    );

    test(
      'provider disposal retires service while shared barrier survives',
      () async {
        await prefs.backing.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([
            _row(_ownerA, id: CuratedListService.defaultListId).toJson(),
          ]),
        );
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authServiceProvider.overrideWithValue(authA),
            nostrServiceProvider.overrideWithValue(clientA),
          ],
        );
        final subscription = container.listen(
          curatedListsStateProvider,
          (_, _) {},
        );
        await container.read(curatedListsStateProvider.future);
        final service = container
            .read(curatedListsStateProvider.notifier)
            .service!;
        final writes = container.read(curatedListCacheWriteCoordinatorProvider);
        expect(service.isCurrentSession, isTrue);
        subscription.close();
        container.dispose();
        expect(service.isCurrentSession, isFalse);
        expect(
          await service.updateList(
            listId: CuratedListService.defaultListId,
            name: 'Disposed metadata',
          ),
          isFalse,
        );
        expect(
          CuratedListSessionCoordinator.forPreferences(prefs).writes,
          same(writes),
        );
      },
    );
  });
}
