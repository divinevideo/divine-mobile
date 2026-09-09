// ABOUTME: Regression tests for the curated-list repository provider bridge.
// ABOUTME: Keeps Home feed list selection scoped to subscribed lists and feeds
// ABOUTME: the list search the viewer's own lists.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

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
      final ownList = _curatedList(id: 'own-list');
      final subscribedList = _curatedList(id: 'subscribed-list');

      when(() => service.myLists).thenReturn([ownList]);
      when(() => service.subscribedLists).thenReturn([subscribedList]);

      expect(ownListsForSearchBridge(service), [ownList]);
    });
  });
}

CuratedList _curatedList({required String id}) {
  final now = DateTime(2026, 5, 19);
  return CuratedList(
    id: id,
    name: id,
    videoEventIds: const [],
    createdAt: now,
    updatedAt: now,
  );
}
