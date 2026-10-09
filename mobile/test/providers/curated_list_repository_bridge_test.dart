// ABOUTME: Regression tests for the curated-list repository provider bridge.
// ABOUTME: Keeps Home feed list selection scoped to subscribed lists and feeds
// ABOUTME: the list search the viewer's own lists.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

const _viewer =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  group('curated list repository bridge', () {
    test('selects subscribed lists instead of all service lists', () {
      final service = _MockCuratedListService();
      final subscribedList = _curatedList(id: 'subscribed-list');
      final discoveredList = _curatedList(id: 'discovered-list');

      when(() => service.lists).thenReturn([subscribedList, discoveredList]);
      when(() => service.subscribedLists).thenReturn([subscribedList]);

      expect(
        subscribedListsForHomeBridge(service),
        [subscribedList],
      );
    });

    test("hands the list search the viewer's own lists", () {
      final service = _MockCuratedListService();
      final ownList = _curatedList(id: 'own-list', pubkey: _viewer);
      final subscribedList = _curatedList(id: 'subscribed-list');

      when(() => service.myLists).thenReturn([ownList]);
      when(() => service.subscribedLists).thenReturn([subscribedList]);

      expect(
        ownListsForSearchBridge(service, viewerPubkey: _viewer),
        [ownList],
      );
    });

    test('files an own list without an author under the viewer', () {
      // The repository keys lists by author, so a draft without one would sit
      // beside its own relay copy instead of replacing it.
      final service = _MockCuratedListService();
      final draft = _curatedList(id: 'draft');

      when(() => service.myLists).thenReturn([draft]);

      final [stamped] = ownListsForSearchBridge(
        service,
        viewerPubkey: _viewer,
      );

      expect(stamped.pubkey, _viewer);
      expect(stamped.authorScopedId, '$_viewer:draft');
    });

    test('leaves an authorless own list alone while signed out', () {
      final service = _MockCuratedListService();
      final draft = _curatedList(id: 'draft');

      when(() => service.myLists).thenReturn([draft]);

      expect(ownListsForSearchBridge(service, viewerPubkey: null), [draft]);
    });
  });
}

CuratedList _curatedList({required String id, String? pubkey}) {
  final now = DateTime(2026, 5, 19);
  return CuratedList(
    id: id,
    name: id,
    pubkey: pubkey,
    videoEventIds: const [],
    createdAt: now,
    updatedAt: now,
  );
}
