// ABOUTME: Tests the SharedPreferences-backed followed-people-lists store.
// ABOUTME: Covers ordering, account isolation, damaged entries and watching.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/people_lists/prefs_followed_people_lists_store.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String _viewerA = 'a' * 64;
final String _viewerB = 'b' * 64;
final String _owner = 'c' * 64;

FollowedPeopleListRef _ref(String listId, {String? ownerPubkey}) =>
    FollowedPeopleListRef(ownerPubkey: ownerPubkey ?? _owner, listId: listId);

Future<SharedPreferences> _prefs([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

/// The on-disk key, spelled out: renaming it in the store would strand every
/// account's follows under the old name, so the test pins the spelling.
String _keyFor(String viewerPubkey) => 'followed_people_lists_$viewerPubkey';

void main() {
  group(PrefsFollowedPeopleListsStore, () {
    group('read', () {
      test('returns nothing for an account that follows nothing', () async {
        final store = PrefsFollowedPeopleListsStore(await _prefs());
        addTearDown(store.dispose);

        expect(await store.read(viewerPubkey: _viewerA), isEmpty);
      });

      test('skips a damaged entry and keeps the rest', () async {
        final store = PrefsFollowedPeopleListsStore(
          await _prefs({
            _keyFor(_viewerA): [
              'no-separator',
              ':no-owner',
              '$_owner:',
              '$_owner:crew',
              '$_owner:crew',
            ],
          }),
        );
        addTearDown(store.dispose);

        expect(
          await store.read(viewerPubkey: _viewerA),
          equals([_ref('crew')]),
        );
      });
    });

    group('add', () {
      test('survives a new store over the same preferences, in follow '
          'order', () async {
        final prefs = await _prefs();
        final store = PrefsFollowedPeopleListsStore(prefs);
        addTearDown(store.dispose);
        await store.add(viewerPubkey: _viewerA, ref: _ref('zebra'));
        await store.add(viewerPubkey: _viewerA, ref: _ref('apple'));

        final reopened = PrefsFollowedPeopleListsStore(prefs);
        addTearDown(reopened.dispose);

        expect(
          await reopened.read(viewerPubkey: _viewerA),
          equals([_ref('zebra'), _ref('apple')]),
        );
      });

      test('leaves a list already followed where it was', () async {
        final store = PrefsFollowedPeopleListsStore(await _prefs());
        addTearDown(store.dispose);
        await store.add(viewerPubkey: _viewerA, ref: _ref('early'));
        await store.add(viewerPubkey: _viewerA, ref: _ref('late'));

        await store.add(viewerPubkey: _viewerA, ref: _ref('early'));

        expect(
          await store.read(viewerPubkey: _viewerA),
          equals([_ref('early'), _ref('late')]),
        );
      });

      test('keeps a d tag that contains the separator whole', () async {
        final prefs = await _prefs();
        final store = PrefsFollowedPeopleListsStore(prefs);
        addTearDown(store.dispose);

        await store.add(viewerPubkey: _viewerA, ref: _ref('team:core:2026'));

        final reopened = PrefsFollowedPeopleListsStore(prefs);
        addTearDown(reopened.dispose);
        expect(
          await reopened.read(viewerPubkey: _viewerA),
          equals([_ref('team:core:2026')]),
        );
      });

      test('keeps accounts apart', () async {
        final store = PrefsFollowedPeopleListsStore(await _prefs());
        addTearDown(store.dispose);

        await store.add(viewerPubkey: _viewerA, ref: _ref('mine'));

        expect(await store.read(viewerPubkey: _viewerB), isEmpty);
      });
    });

    group('remove', () {
      test('removes only the named follow', () async {
        final store = PrefsFollowedPeopleListsStore(await _prefs());
        addTearDown(store.dispose);
        await store.add(viewerPubkey: _viewerA, ref: _ref('keep'));
        await store.add(viewerPubkey: _viewerA, ref: _ref('drop'));
        await store.add(
          viewerPubkey: _viewerA,
          ref: _ref('drop', ownerPubkey: _viewerB),
        );

        await store.remove(viewerPubkey: _viewerA, ref: _ref('drop'));

        expect(
          await store.read(viewerPubkey: _viewerA),
          equals([_ref('keep'), _ref('drop', ownerPubkey: _viewerB)]),
        );
      });
    });

    group('clear', () {
      test("removes one account's follows and nobody else's", () async {
        final prefs = await _prefs();
        final store = PrefsFollowedPeopleListsStore(prefs);
        addTearDown(store.dispose);
        await store.add(viewerPubkey: _viewerA, ref: _ref('leaving'));
        await store.add(viewerPubkey: _viewerB, ref: _ref('staying'));

        await store.clear(viewerPubkey: _viewerA);

        expect(
          prefs.containsKey(_keyFor(_viewerA)),
          isFalse,
        );
        expect(
          await store.read(viewerPubkey: _viewerB),
          equals([_ref('staying')]),
        );
      });
    });

    group('watch', () {
      test('emits the current follows, then each change', () async {
        final store = PrefsFollowedPeopleListsStore(await _prefs());
        addTearDown(store.dispose);
        await store.add(viewerPubkey: _viewerA, ref: _ref('first'));
        final emissions = <List<String>>[];
        final subscription = store.watch(viewerPubkey: _viewerA).listen((refs) {
          emissions.add([for (final ref in refs) ref.listId]);
        });
        addTearDown(subscription.cancel);
        await pumpEventQueue();

        await store.add(viewerPubkey: _viewerA, ref: _ref('second'));
        await pumpEventQueue();
        await store.remove(viewerPubkey: _viewerA, ref: _ref('first'));
        await pumpEventQueue();
        await store.clear(viewerPubkey: _viewerA);
        await pumpEventQueue();

        expect(
          emissions,
          equals([
            ['first'],
            ['first', 'second'],
            ['second'],
            <String>[],
          ]),
        );
      });

      test('stays quiet for another account and for writes that change '
          'nothing', () async {
        final store = PrefsFollowedPeopleListsStore(await _prefs());
        addTearDown(store.dispose);
        await store.add(viewerPubkey: _viewerA, ref: _ref('crew'));
        final emissions = <List<String>>[];
        final subscription = store.watch(viewerPubkey: _viewerA).listen((refs) {
          emissions.add([for (final ref in refs) ref.listId]);
        });
        addTearDown(subscription.cancel);
        await pumpEventQueue();

        await store.add(viewerPubkey: _viewerB, ref: _ref('other'));
        await store.add(viewerPubkey: _viewerA, ref: _ref('crew'));
        await store.remove(viewerPubkey: _viewerA, ref: _ref('absent'));
        await store.clear(viewerPubkey: 'd' * 64);
        await pumpEventQueue();

        expect(
          emissions,
          equals([
            ['crew'],
          ]),
        );
      });

      test('does not lose a follow made as the listener attaches', () async {
        final store = PrefsFollowedPeopleListsStore(await _prefs());
        addTearDown(store.dispose);
        final emissions = <List<String>>[];
        final subscription = store.watch(viewerPubkey: _viewerA).listen((refs) {
          emissions.add([for (final ref in refs) ref.listId]);
        });
        addTearDown(subscription.cancel);

        await store.add(viewerPubkey: _viewerA, ref: _ref('crew'));
        await pumpEventQueue();

        expect(emissions.last, equals(['crew']));
      });
    });
  });
}
