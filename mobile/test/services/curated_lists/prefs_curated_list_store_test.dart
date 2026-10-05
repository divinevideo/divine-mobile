// ABOUTME: Tests PrefsCuratedListStore saves, baselines and deletion record.
// ABOUTME: Covers merging, rejected writes, unreadable storage and tombstones.

import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Refuses writes until [accepts] is set.
///
/// A refused write stays readable when [cachesRefusedWrites] is set, the way
/// [SharedPreferences] updates its cache before the platform write.
class _RefusingPrefs extends Fake implements SharedPreferences {
  _RefusingPrefs({this.cachesRefusedWrites = false});

  final bool cachesRefusedWrites;
  bool accepts = false;
  final _stored = <String, String>{};

  @override
  String? getString(String key) => _stored[key];

  @override
  Future<bool> setString(String key, String value) async {
    if (accepts || cachesRefusedWrites) _stored[key] = value;
    return accepts;
  }
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherOwner =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

const _storedText = 'stored-text-sentinel';

const _listsKey = 'lists';
const _subscriptionsKey = 'subscriptions';
const _defaultDeletedKey = 'default_deleted';

CuratedList _list(String id, {int revision = 1, String? name}) {
  return CuratedList(
    id: id,
    name: name ?? 'List $id',
    pubkey: _owner,
    videoEventIds: const [],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026).add(Duration(seconds: revision)),
  );
}

PrefsCuratedListStore _store(
  SharedPreferences prefs, {
  CuratedListCacheWriteCoordinator? coordinator,
}) {
  return PrefsCuratedListStore(
    prefs: prefs,
    writeCoordinator: coordinator ?? CuratedListCacheWriteCoordinator(),
    listsStorageKey: _listsKey,
    subscriptionsStorageKey: _subscriptionsKey,
    defaultListDeletedStorageKey: _defaultDeletedKey,
  );
}

List<CuratedList> _storedLists(SharedPreferences prefs) {
  return (jsonDecode(prefs.getString(_listsKey)!) as List<dynamic>)
      .map((row) => CuratedList.fromJson(row as Map<String, dynamic>))
      .toList(growable: false);
}

Set<String> _storedSubscriptions(SharedPreferences prefs) {
  return (jsonDecode(prefs.getString(_subscriptionsKey)!) as List<dynamic>)
      .cast<String>()
      .toSet();
}

/// Starts a test with an empty log capture and leaves it empty afterwards.
Future<LogCaptureService> _freshLogs() async {
  final logs = LogCaptureService();
  await logs.clearAllLogs();
  addTearDown(logs.clearAllLogs);
  return logs;
}

/// Expects one error log from the store about [what], without the stored data.
void _expectUnreadableLog(LogCaptureService logs, {required String what}) {
  final entries = logs
      .getRecentLogs()
      .where((entry) => entry.name == 'PrefsCuratedListStore')
      .toList();
  expect(entries, hasLength(1));
  final entry = entries.single;
  expect(entry.level, LogLevel.error);
  expect(entry.category, LogCategory.system);
  expect(entry.stackTrace, isNotNull);
  expect(entry.message, allOf(contains(what), contains('FormatException')));
  expect(jsonEncode(entry.toJson()), isNot(contains(_storedText)));
}

void main() {
  group(PrefsCuratedListStore, () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    group('saveLists', () {
      test('stores the lists as JSON and reports success', () async {
        final crew = _list('crew');

        final saved = await _store(prefs).saveLists([crew]);

        expect(saved, isTrue);
        expect(_storedLists(prefs), [crew]);
      });

      test('keeps a list another writer added since its last save', () async {
        final coordinator = CuratedListCacheWriteCoordinator();
        final first = _store(prefs, coordinator: coordinator);
        final second = _store(prefs, coordinator: coordinator);
        final crew = _list('crew');
        final friends = _list('friends');
        await first.saveLists([crew]);
        second.listsLoaded([crew]);
        await second.saveLists([crew, friends]);

        final renamed = _list('crew', revision: 2, name: 'Renamed');
        final saved = await first.saveLists([renamed]);

        expect(saved, isTrue);
        expect(_storedLists(prefs), unorderedEquals([renamed, friends]));
      });

      test('saves only what changed since the loaded lists', () async {
        final crew = _list('crew');
        final friends = _list('friends');
        final store = _store(prefs)..listsLoaded([crew, friends]);
        final added = _list('new');
        await prefs.setString(
          _listsKey,
          jsonEncode([crew.toJson(), friends.toJson(), added.toJson()]),
        );

        await store.saveLists([crew]);

        expect(_storedLists(prefs), unorderedEquals([crew, added]));
      });

      test('does not bring back a list the storage no longer holds', () async {
        final crew = _list('crew');
        final added = _list('added');
        final store = _store(prefs)..listsLoaded([crew]);

        await store.saveLists([crew, added]);

        expect(_storedLists(prefs), [added]);
      });

      test('removes a list dropped after an earlier save', () async {
        final store = _store(prefs);
        final crew = _list('crew');
        final friends = _list('friends');
        await store.saveLists([crew, friends]);

        await store.saveLists([crew]);

        expect(_storedLists(prefs), [crew]);
      });

      test('saves the lists as they were when called', () async {
        final store = _store(prefs);
        final crew = _list('crew');
        final friends = _list('friends');
        final lists = [crew];

        final saving = store.saveLists(lists);
        lists.add(friends);
        await saving;

        expect(_storedLists(prefs), [crew]);

        await store.saveLists(lists);

        expect(_storedLists(prefs), unorderedEquals([crew, friends]));
      });

      test('does not follow later changes to the lists it was told were '
          'loaded', () async {
        final crew = _list('crew');
        final friends = _list('friends');
        await prefs.setString(_listsKey, jsonEncode([crew.toJson()]));
        final loaded = [crew];
        final store = _store(prefs)..listsLoaded(loaded);
        loaded.add(friends);

        await store.saveLists(loaded);

        expect(_storedLists(prefs), unorderedEquals([crew, friends]));
      });

      test(
        'stores the change on the next save after a rejected write',
        () async {
          final refusing = _RefusingPrefs();
          final store = _store(refusing);
          final crew = _list('crew');
          expect(await store.saveLists([crew]), isFalse);

          refusing.accepts = true;
          await store.saveLists([crew]);

          expect(_storedLists(refusing), [crew]);
        },
      );

      group('with a list that is already stored', () {
        test('accepts overlapping saves that add the same list', () async {
          final store = _store(prefs);
          final crew = _list('crew');
          final friends = _list('friends');

          final first = store.saveLists([crew]);
          final second = store.saveLists([crew, friends]);

          expect(await first, isTrue);
          expect(await second, isTrue);
          await store.saveLists([crew]);
          expect(_storedLists(prefs), [crew]);
        });

        test('accepts the retry of a write the storage refused', () async {
          final refusing = _RefusingPrefs(cachesRefusedWrites: true);
          final store = _store(refusing);
          final crew = _list('crew');
          expect(await store.saveLists([crew]), isFalse);

          refusing.accepts = true;
          final retried = await store.saveLists([crew]);

          expect(retried, isTrue);
          await store.saveLists([]);
          expect(_storedLists(refusing), isEmpty);
        });

        test('accepts a list another writer already stored', () async {
          final coordinator = CuratedListCacheWriteCoordinator();
          final first = _store(prefs, coordinator: coordinator);
          final second = _store(prefs, coordinator: coordinator);
          final crew = _list('crew');
          await first.saveLists([crew]);

          final saved = await second.saveLists([crew]);

          expect(saved, isTrue);
          await second.saveLists([]);
          expect(_storedLists(prefs), isEmpty);
        });
      });

      group('with storage it cannot read', () {
        late LogCaptureService logs;

        setUp(() async {
          logs = await _freshLogs();
        });

        test('replaces stored lists that are not valid JSON', () async {
          await prefs.setString(_listsKey, 'invalid json {{{');
          final crew = _list('crew');

          final saved = await _store(prefs).saveLists([crew]);

          expect(saved, isTrue);
          expect(_storedLists(prefs), [crew]);
        });

        test('replaces stored lists of the wrong shape', () async {
          await prefs.setString(_listsKey, jsonEncode({'crew': 1}));
          final crew = _list('crew');

          final saved = await _store(prefs).saveLists([crew]);

          expect(saved, isTrue);
          expect(_storedLists(prefs), [crew]);
        });

        test(
          'rewrites the lists it loaded before a row it cannot decode',
          () async {
            final kept = _list('kept');
            final removed = _list('removed');
            final added = _list('added');
            await prefs.setString(
              _listsKey,
              jsonEncode([
                kept.toJson(),
                removed.toJson(),
                'not a row',
              ]),
            );
            final store = _store(prefs)..listsLoaded([kept, removed]);

            final saved = await store.saveLists([kept, added]);

            expect(saved, isTrue);
            expect(_storedLists(prefs), unorderedEquals([kept, added]));
          },
        );

        test('logs what it replaced without quoting the stored data', () async {
          await prefs.setString(_listsKey, '$_storedText {{{');

          await _store(prefs).saveLists([_list('crew')]);

          _expectUnreadableLog(logs, what: 'lists');
        });
      });
    });

    group('saveSubscriptions', () {
      test('stores the subscribed ids and reports success', () async {
        final saved = await _store(prefs).saveSubscriptions({'a', 'b'});

        expect(saved, isTrue);
        expect(_storedSubscriptions(prefs), {'a', 'b'});
      });

      test('keeps a subscription another writer added', () async {
        final coordinator = CuratedListCacheWriteCoordinator();
        final first = _store(prefs, coordinator: coordinator);
        final second = _store(prefs, coordinator: coordinator);
        await first.saveSubscriptions({'a'});
        second.subscriptionsLoaded({'a'});
        await second.saveSubscriptions({'a', 'b'});

        await first.saveSubscriptions({'a', 'c'});

        expect(_storedSubscriptions(prefs), {'a', 'b', 'c'});
      });

      test('removes only what this store unsubscribed from', () async {
        final coordinator = CuratedListCacheWriteCoordinator();
        final first = _store(prefs, coordinator: coordinator);
        final second = _store(prefs, coordinator: coordinator);
        await first.saveSubscriptions({'a', 'b'});
        second.subscriptionsLoaded({'a', 'b'});
        await second.saveSubscriptions({'a', 'b', 'c'});

        await first.saveSubscriptions({'b'});

        expect(_storedSubscriptions(prefs), {'b', 'c'});
      });

      test(
        'does not bring back a subscription the storage no longer holds',
        () async {
          final store = _store(prefs)..subscriptionsLoaded({'a'});

          await store.saveSubscriptions({'a', 'b'});

          expect(_storedSubscriptions(prefs), {'b'});
        },
      );

      test('saves the ids as they were when called', () async {
        final store = _store(prefs);
        final ids = {'a'};

        final saving = store.saveSubscriptions(ids);
        ids.add('b');
        await saving;

        expect(_storedSubscriptions(prefs), {'a'});

        await store.saveSubscriptions(ids);

        expect(_storedSubscriptions(prefs), {'a', 'b'});
      });

      test('does not follow later changes to the ids it was told were '
          'loaded', () async {
        await prefs.setString(_subscriptionsKey, jsonEncode(['a']));
        final loaded = {'a'};
        final store = _store(prefs)..subscriptionsLoaded(loaded);
        loaded.add('b');

        await store.saveSubscriptions(loaded);

        expect(_storedSubscriptions(prefs), {'a', 'b'});
      });

      test(
        'stores the change on the next save after a rejected write',
        () async {
          final refusing = _RefusingPrefs();
          final store = _store(refusing);
          expect(await store.saveSubscriptions({'a'}), isFalse);

          refusing.accepts = true;
          final retried = await store.saveSubscriptions({'a'});

          expect(retried, isTrue);
          expect(jsonDecode(refusing.getString(_subscriptionsKey)!), ['a']);
        },
      );

      group('with storage it cannot read', () {
        late LogCaptureService logs;

        setUp(() async {
          logs = await _freshLogs();
        });

        test('replaces stored subscriptions that are not valid JSON', () async {
          await prefs.setString(_subscriptionsKey, 'invalid json {{{');

          final saved = await _store(prefs).saveSubscriptions({'a'});

          expect(saved, isTrue);
          expect(_storedSubscriptions(prefs), {'a'});
        });

        test('replaces stored subscriptions of the wrong shape', () async {
          await prefs.setString(_subscriptionsKey, jsonEncode({'a': 1}));

          final saved = await _store(prefs).saveSubscriptions({'a'});

          expect(saved, isTrue);
          expect(_storedSubscriptions(prefs), {'a'});
        });

        test('rewrites the ids it loaded before one it cannot read', () async {
          await prefs.setString(_subscriptionsKey, jsonEncode(['a', 'b', 1]));
          final store = _store(prefs)..subscriptionsLoaded({'a', 'b'});

          final saved = await store.saveSubscriptions({'a', 'c'});

          expect(saved, isTrue);
          expect(_storedSubscriptions(prefs), {'a', 'c'});
        });

        test('logs what it replaced without quoting the stored data', () async {
          await prefs.setString(_subscriptionsKey, '$_storedText {{{');

          await _store(prefs).saveSubscriptions({'a'});

          _expectUnreadableLog(logs, what: 'subscriptions');
        });
      });
    });

    group('deletion record', () {
      test('remembers a deleted list against its owner', () async {
        final store = _store(prefs);
        expect(store.wasListDeleted(_owner, 'crew'), isFalse);

        await store.recordListDeletion(_owner, 'crew');

        expect(store.wasListDeleted(_owner, 'crew'), isTrue);
        expect(store.wasListDeleted(_otherOwner, 'crew'), isFalse);
        expect(store.wasListDeleted(_owner, 'friends'), isFalse);
      });

      test(
        'keeps the record for the next store over the same storage',
        () async {
          await _store(prefs).recordListDeletion(_owner, 'crew');

          expect(_store(prefs).wasListDeleted(_owner, 'crew'), isTrue);
        },
      );

      test('reads the record earlier app versions stored', () async {
        SharedPreferences.setMockInitialValues({
          'deleted_curated_list_coordinates': ['$_owner:crew'],
        });
        final upgraded = await SharedPreferences.getInstance();

        final store = _store(upgraded);

        expect(store.wasListDeleted(_owner, 'crew'), isTrue);
      });

      test('lifts only the named record', () async {
        final store = _store(prefs);
        await store.recordListDeletion(_owner, 'crew');
        await store.recordListDeletion(_otherOwner, 'crew');
        await store.recordListDeletion(_owner, 'friends');
        expect(store.wasListDeleted(_owner, 'crew'), isTrue);

        await store.forgetListDeletion(_owner, 'crew');

        expect(store.wasListDeleted(_owner, 'crew'), isFalse);
        expect(store.wasListDeleted(_otherOwner, 'crew'), isTrue);
        expect(store.wasListDeleted(_owner, 'friends'), isTrue);
      });

      test('writes nothing when the list was never deleted', () async {
        await _store(prefs).forgetListDeletion(_owner, 'crew');

        expect(prefs.getKeys(), isEmpty);
      });
    });

    group('default list flag', () {
      test('remembers that the default list was deleted', () async {
        final store = _store(prefs);
        expect(store.wasDefaultListDeleted(), isFalse);

        await store.markDefaultListDeleted();

        expect(store.wasDefaultListDeleted(), isTrue);
        expect(_store(prefs).wasDefaultListDeleted(), isTrue);
        expect(prefs.getBool(_defaultDeletedKey), isTrue);
      });
    });
  });
}
