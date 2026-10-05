// ABOUTME: Verifies storage failures and conflicts reach curated mutation callers.
// ABOUTME: Ensures rejected edits do not publish or erase another writer's data.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

class _ControlledPrefs extends Fake implements SharedPreferences {
  _ControlledPrefs(this.backing);
  final SharedPreferences backing;
  bool rejectLists = false;
  bool rejectSubscriptions = false;
  bool rejectDeletions = false;
  bool throwLists = false;
  bool throwSubscriptions = false;
  Completer<void>? listWriteStarted;
  Completer<bool>? firstListWrite;
  bool _gated = false;

  @override
  String? getString(String key) => backing.getString(key);

  @override
  List<String>? getStringList(String key) => backing.getStringList(key);

  @override
  bool? getBool(String key) => backing.getBool(key);

  @override
  Future<bool> setString(String key, String value) {
    if ((throwLists && key == CuratedListService.listsStorageKey) ||
        (throwSubscriptions &&
            key == CuratedListService.subscribedListsStorageKey)) {
      throw PlatformException(
        code: 'disk_write_failed',
        message: 'private-data',
      );
    }
    if (key == CuratedListService.listsStorageKey &&
        firstListWrite != null &&
        !_gated) {
      _gated = true;
      listWriteStarted?.complete();
      return firstListWrite!.future;
    }
    if ((rejectLists && key == CuratedListService.listsStorageKey) ||
        (rejectSubscriptions &&
            key == CuratedListService.subscribedListsStorageKey)) {
      return Future.value(false);
    }
    return backing.setString(key, value);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      rejectDeletions ? Future.value(false) : backing.setStringList(key, value);

  @override
  Future<bool> setBool(String key, bool value) => backing.setBool(key, value);
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

CuratedList _list({String name = 'Original', DateTime? updatedAt}) =>
    CuratedList(
      id: 'crew',
      pubkey: _owner,
      name: name,
      videoEventIds: const [],
      createdAt: DateTime.utc(2026),
      updatedAt: updatedAt ?? DateTime.utc(2026),
    );

void main() {
  group('curated mutation persistence outcomes', () {
    late _Auth auth;
    late _Client client;
    late _ControlledPrefs prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        CuratedListService.listsStorageKey: jsonEncode([_list().toJson()]),
      });
      prefs = _ControlledPrefs(await SharedPreferences.getInstance());
      auth = _Auth();
      client = _Client();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      stubListPublishing(client: client, auth: auth, pubkey: _owner);
    });

    CuratedListService open({
      CuratedListCacheWriteCoordinator? coordinator,
      Future<void> Function(String, List<String>)? onSubscribed,
    }) {
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
        cacheWriteCoordinator: coordinator,
        onListSubscribed: onSubscribed,
      );
      addTearDown(service.dispose);
      return service;
    }

    test(
      'rejected creation returns null and never signs or publishes',
      () async {
        final service = open();
        prefs.rejectLists = true;
        expect(await service.createList(name: 'Rejected'), isNull);
        expect(service.lists, [_list()]);
        verifyNever(() => client.publishEventAwaitOk(any()));
        expect(open().lists, [_list()]);
      },
    );

    test(
      'rejected rename returns false and restores the stored name',
      () async {
        final service = open();
        prefs.rejectLists = true;
        expect(
          await service.updateList(listId: 'crew', name: 'Rejected'),
          isFalse,
        );
        expect(service.getListById('crew')?.name, 'Original');
        expect(open().getListById('crew')?.name, 'Original');
        verifyNever(() => client.publishEventAwaitOk(any()));
      },
    );

    test(
      'rejected video add returns false without publishing the item',
      () async {
        final service = open();
        prefs.rejectLists = true;
        expect(await service.addVideoToList('crew', 'c' * 64), isFalse);
        expect(service.getListById('crew')?.videoEventIds, isEmpty);
        expect(open().getListById('crew')?.videoEventIds, isEmpty);
        verifyNever(() => client.publishEvent(any()));
      },
    );

    test(
      'rejected follow does not claim success or start the video callback',
      () async {
        var callbacks = 0;
        final service = open(onSubscribed: (_, _) async => callbacks++);
        prefs.rejectSubscriptions = true;
        expect(await service.subscribeToList('crew'), isFalse);
        expect(service.isSubscribedToList('crew'), isFalse);
        expect(callbacks, 0);
        expect(open().isSubscribedToList('crew'), isFalse);
      },
    );

    test('rejected deletion tombstone keeps the owned list', () async {
      final service = open();
      prefs.rejectDeletions = true;
      expect(await service.deleteOwnedList('crew'), isFalse);
      expect(service.getListById('crew'), _list());
      expect(open().getListById('crew'), _list());
    });

    test('platform exception restores a rename before another save', () async {
      final service = open();
      prefs.throwLists = true;
      expect(
        await service.updateList(listId: 'crew', name: 'Rejected'),
        isFalse,
      );
      expect(service.getListById('crew')?.name, 'Original');
      prefs.throwLists = false;
      expect(await service.createList(name: 'Unrelated'), isNotNull);
      expect(open().getListById('crew')?.name, 'Original');
    });

    test('platform exception restores a follow before another save', () async {
      final other = _list().copyWith(id: 'other', name: 'Other');
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([_list().toJson(), other.toJson()]),
      );
      final service = open();
      prefs.throwSubscriptions = true;
      expect(await service.subscribeToList('crew'), isFalse);
      expect(service.isSubscribedToList('crew'), isFalse);
      prefs.throwSubscriptions = false;
      expect(await service.subscribeToList('other'), isTrue);
      expect(open().isSubscribedToList('crew'), isFalse);
      expect(open().isSubscribedToList('other'), isTrue);
    });

    test('rejected unfollow keeps the last stored subscription', () async {
      await prefs.setString(
        CuratedListService.subscribedListsStorageKey,
        jsonEncode(['$_owner:crew']),
      );
      final service = open();
      prefs.rejectSubscriptions = true;
      expect(await service.unsubscribeFromList('crew'), isFalse);
      expect(service.isSubscribedToList('crew'), isTrue);
      expect(open().isSubscribedToList('crew'), isTrue);
    });

    test(
      'conflict reconciles only the contested row and never publishes it',
      () async {
        final service = open();
        final winner = _list(name: 'Newer', updatedAt: DateTime.utc(2100));
        final other = _list(name: 'Other account').copyWith(pubkey: 'b' * 64);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([winner.toJson(), other.toJson()]),
        );
        expect(
          await service.updateList(listId: 'crew', name: 'Stale'),
          isFalse,
        );
        expect(service.getListById('crew'), winner);
        expect(open().lists, [winner, other]);
        verifyNever(() => client.publishEventAwaitOk(any()));
      },
    );

    test(
      'failed rename is not replayed by an overlapping different-list edit',
      () async {
        final second = _list().copyWith(id: 'other', name: 'Other');
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([_list().toJson(), second.toJson()]),
        );
        final service = open();
        prefs.listWriteStarted = Completer<void>();
        prefs.firstListWrite = Completer<bool>();
        final first = service.updateList(
          listId: 'crew',
          name: 'Rejected rename',
        );
        await prefs.listWriteStarted!.future;
        final nextPublished = Completer<Event>();
        final acceptance = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((call) {
          nextPublished.complete(call.positionalArguments.first as Event);
          return acceptance.future;
        });
        final nextMutated = Completer<void>();
        service.addListener(() {
          if (service.getListById('other')?.name == 'Accepted rename' &&
              !nextMutated.isCompleted) {
            nextMutated.complete();
          }
        });
        final next = service.updateList(
          listId: 'other',
          name: 'Accepted rename',
        );
        await nextMutated.future;
        expect(service.getListById('other')?.name, 'Accepted rename');
        prefs.firstListWrite!.complete(false);
        expect(await first, isFalse);
        final sent = await nextPublished.future;
        final beforeAcceptance = open();
        acceptance.complete(acceptedOutcome(sent));
        expect(beforeAcceptance.getListById('crew')?.name, 'Original');
        expect(await next, isTrue);
        final restarted = open();
        expect(restarted.getListById('crew')?.name, 'Original');
        expect(restarted.getListById('other')?.name, 'Accepted rename');
      },
    );

    test(
      'corrupt loaders never log fragments of private cached contents',
      () async {
        const secret = 'private-content-sentinel';
        await prefs.setString(
          CuratedListService.listsStorageKey,
          '$secret {{{',
        );
        await prefs.setString(
          CuratedListService.subscribedListsStorageKey,
          '$secret {{{',
        );
        final logs = LogCaptureService();
        await logs.clearAllLogs();
        addTearDown(logs.clearAllLogs);
        open();
        final entries = logs.getRecentLogs().where(
          (entry) => entry.name == 'CuratedListService',
        );
        expect(entries, hasLength(2));
        for (final entry in entries) {
          expect(entry.stackTrace, isNotNull);
          expect(entry.message, contains('FormatException'));
          expect(jsonEncode(entry.toJson()), isNot(contains(secret)));
        }
      },
    );
  });
}
