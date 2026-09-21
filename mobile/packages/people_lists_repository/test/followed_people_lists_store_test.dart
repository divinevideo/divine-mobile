// ABOUTME: Tests for the followed-people-lists store contract, exercised
// ABOUTME: through its in-memory implementation.

import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:test/test.dart';

const _viewerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _viewerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _owner =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

FollowedPeopleListRef _ref(String listId, {String ownerPubkey = _owner}) =>
    FollowedPeopleListRef(ownerPubkey: ownerPubkey, listId: listId);

void main() {
  group(FollowedPeopleListRef, () {
    test('names a list by owner and d tag together', () {
      expect(_ref('crew'), equals(_ref('crew')));
      expect(_ref('crew'), isNot(equals(_ref('friends'))));
      expect(_ref('crew'), isNot(equals(_ref('crew', ownerPubkey: _viewerB))));
    });
  });

  group(InMemoryFollowedPeopleListsStore, () {
    late InMemoryFollowedPeopleListsStore store;

    setUp(() {
      store = InMemoryFollowedPeopleListsStore();
    });

    group('add', () {
      test('keeps follows in the order they were made', () async {
        await store.add(viewerPubkey: _viewerA, ref: _ref('zebra'));
        await store.add(viewerPubkey: _viewerA, ref: _ref('apple'));

        expect(
          await store.read(viewerPubkey: _viewerA),
          equals([_ref('zebra'), _ref('apple')]),
        );
      });

      test('leaves a list already followed where it was', () async {
        await store.add(viewerPubkey: _viewerA, ref: _ref('early'));
        await store.add(viewerPubkey: _viewerA, ref: _ref('late'));

        await store.add(viewerPubkey: _viewerA, ref: _ref('early'));

        expect(
          await store.read(viewerPubkey: _viewerA),
          equals([_ref('early'), _ref('late')]),
        );
      });

      test('keeps each viewer apart', () async {
        await store.add(viewerPubkey: _viewerA, ref: _ref('mine'));

        expect(await store.read(viewerPubkey: _viewerB), isEmpty);
      });
    });

    group('remove', () {
      test('removes only the named follow', () async {
        await store.add(viewerPubkey: _viewerA, ref: _ref('keep'));
        await store.add(viewerPubkey: _viewerA, ref: _ref('drop'));

        await store.remove(viewerPubkey: _viewerA, ref: _ref('drop'));

        expect(
          await store.read(viewerPubkey: _viewerA),
          equals([_ref('keep')]),
        );
      });
    });

    group('clear', () {
      test("removes one viewer's follows and nobody else's", () async {
        await store.add(viewerPubkey: _viewerA, ref: _ref('leaving'));
        await store.add(viewerPubkey: _viewerB, ref: _ref('staying'));

        await store.clear(viewerPubkey: _viewerA);

        expect(await store.read(viewerPubkey: _viewerA), isEmpty);
        expect(
          await store.read(viewerPubkey: _viewerB),
          equals([_ref('staying')]),
        );
      });
    });

    group('watch', () {
      test('emits the current follows, then each change', () async {
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

      test('stays quiet for another viewer and for writes that change '
          'nothing', () async {
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
        await store.clear(viewerPubkey: 'nobody');
        await pumpEventQueue();

        expect(
          emissions,
          equals([
            ['crew'],
          ]),
        );
      });

      test('does not lose a follow made as the listener attaches', () async {
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
