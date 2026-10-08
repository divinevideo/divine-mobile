import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';
import 'package:openvine/services/curated_lists/curated_list_relay_merger.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';

class _MockStore extends Mock implements PrefsCuratedListStore {}

void main() {
  group('CuratedListRelayMerger', () {
    final owner = 'a' * 64;
    final localVideo = 'b' * 64;
    final relayVideo = 'c' * 64;
    late _MockStore store;
    late List<CuratedList> lists;
    late CuratedListRelayMerger merger;

    Event relayEvent() => Event.fromJson({
      'id': 'd' * 64,
      'pubkey': owner,
      'created_at': 200,
      'kind': 30005,
      'tags': [
        ['d', 'collection'],
        ['title', 'Relay title'],
        ['e', relayVideo],
      ],
      'content': '',
      'sig': 'e' * 128,
    });

    setUp(() {
      store = _MockStore();
      when(() => store.wasListDeleted(owner, 'collection')).thenReturn(false);
      lists = [
        CuratedList(
          id: 'collection',
          name: 'Local title',
          videoEventIds: [localVideo],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(100000),
          pubkey: owner,
        ),
      ];
      merger = CuratedListRelayMerger(
        lists: lists,
        store: store,
        subscribedListIds: {},
        isSubscribedToList: (_) => false,
        defaultListId: 'default',
      );
    });

    test('failed unseal preserves cached private items', () {
      final original = lists.single;
      expect(original.videoEventIds, [localVideo]);
      merger.merge(
        relayEvent(),
        const UnsealedItemTags.failed(),
        ownerPubkey: owner,
      );
      expect(lists.single, same(original));
    });

    test('unpublished local items survive a newer relay revision', () {
      final createdAt = lists.single.createdAt;
      merger.merge(
        relayEvent(),
        const UnsealedItemTags.notSealed(),
        ownerPubkey: owner,
      );
      expect(lists.single.videoEventIds, [relayVideo, localVideo]);
      expect(lists.single.name, 'Relay title');
      expect(lists.single.createdAt, createdAt);
      expect(lists.single.nostrEventId, isNull);
    });

    test('published rows replace rather than union stale local items', () {
      lists[0] = lists.single.copyWith(nostrEventId: 'f' * 64);
      merger.merge(
        relayEvent(),
        const UnsealedItemTags.notSealed(),
        ownerPubkey: owner,
      );
      expect(lists.single.videoEventIds, [relayVideo]);
      expect(lists.single.nostrEventId, 'd' * 64);
    });

    test('deletion record blocks resurrection but not existing row sync', () {
      when(() => store.wasListDeleted(owner, 'collection')).thenReturn(true);
      lists[0] = lists.single.copyWith(nostrEventId: 'f' * 64);
      merger.merge(
        relayEvent(),
        const UnsealedItemTags.notSealed(),
        ownerPubkey: owner,
      );
      expect(lists.single.nostrEventId, 'd' * 64);
      lists.clear();
      merger.merge(
        relayEvent(),
        const UnsealedItemTags.notSealed(),
        ownerPubkey: owner,
      );
      expect(lists, isEmpty);
    });
  });
}
