// ABOUTME: Discovery list cache and subscriptions retain author-scoped identity.
// ABOUTME: Same d-tags across accounts must stay separate across persistence.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('discovered list identity', () {
    final viewer = 'a' * 64;
    final author = 'b' * 64;
    final otherAuthor = 'c' * 64;
    const id = 'my_vine_list';
    late SharedPreferences prefs;
    late _MockAuthService auth;
    late _MockNostrClient nostr;

    CuratedList list(String pubkey) => CuratedList(
      id: id,
      name: 'List',
      pubkey: pubkey,
      videoEventIds: ['$pubkey-video'],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    Future<CuratedListService> loadService() async {
      final service = CuratedListService(
        nostrService: nostr,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      await service.initialize();
      return service;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        CuratedListService.listsStorageKey: jsonEncode([list(viewer).toJson()]),
      });
      prefs = await SharedPreferences.getInstance();
      auth = _MockAuthService();
      nostr = _MockNostrClient();
      when(() => auth.isAuthenticated).thenReturn(false);
      when(() => auth.currentPublicKeyHex).thenReturn(viewer);
    });

    test(
      'a foreign coordinate never resolves the viewer default list',
      () async {
        final service = await loadService();
        expect(service.getListById(id)?.pubkey, viewer);
        expect(service.getListById('$author:$id'), isNull);
      },
    );

    test(
      'two foreign lists with one d-tag survive follow, reload and unfollow',
      () async {
        final service = await loadService();
        final first = list(author);
        final second = list(otherAuthor);
        expect(
          await service.subscribeToList(first.authorScopedId, first),
          isTrue,
        );
        expect(
          await service.subscribeToList(second.authorScopedId, second),
          isTrue,
        );
        expect(service.getListById(id)?.pubkey, viewer);
        expect(service.getListById(first.authorScopedId), first);
        expect(service.getListById(second.authorScopedId), second);
        expect(service.subscribedLists, [first, second]);

        final restored = await loadService();
        expect(restored.subscribedLists, [first, second]);
        expect(restored.isSubscribedToList('$viewer:$id'), isFalse);
        expect(
          await restored.unsubscribeFromList(first.authorScopedId),
          isTrue,
        );
        expect(restored.isSubscribedToList(first.authorScopedId), isFalse);
        expect(restored.isSubscribedToList(second.authorScopedId), isTrue);
        expect(restored.subscribedLists, [second]);
      },
    );

    test(
      'owned reads and edits remain scoped when a foreign list is first',
      () async {
        final foreign = list(author);
        final owned = list(viewer);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([
            foreign.toJson(),
            owned.toJson(),
          ]),
        );
        final service = await loadService();
        expect(service.getDefaultList(), owned);
        expect(service.getListById(id), owned);
        expect(await service.addVideoToList(id, 'owned-second-video'), isTrue);
        expect(
          service.getListById('$viewer:$id')?.videoEventIds,
          contains('owned-second-video'),
        );
        expect(service.getListById('$author:$id'), foreign);
      },
    );

    test(
      'deleting an owned list preserves followed lists with the same d-tag',
      () async {
        final foreign = list(author);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([foreign.toJson(), list(viewer).toJson()]),
        );
        await prefs.setString(
          CuratedListService.subscribedListsStorageKey,
          jsonEncode([foreign.authorScopedId]),
        );
        final service = await loadService();
        when(() => auth.isAuthenticated).thenReturn(true);
        expect(await service.deleteOwnedList(id), isTrue);
        expect(service.getListById('$viewer:$id'), isNull);
        expect(service.getListById(foreign.authorScopedId), foreign);
        expect(service.subscribedLists, [foreign]);
      },
    );

    test(
      'a foreign default list does not satisfy the viewer default list',
      () async {
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([
            list(author).toJson(),
          ]),
        );
        final service = await loadService();
        expect(service.getDefaultList(), isNull);
        expect(service.hasDefaultList(), isFalse);
      },
    );

    test('legacy subscriptions match only the cached author', () async {
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([
          list(author).toJson(),
        ]),
      );
      await prefs.setString(
        CuratedListService.subscribedListsStorageKey,
        jsonEncode([id]),
      );
      final service = await loadService();
      expect(service.isSubscribedToList('$author:$id'), isTrue);
      expect(service.isSubscribedToList('$otherAuthor:$id'), isFalse);
      expect(await service.unsubscribeFromList('$author:$id'), isTrue);
      expect(service.subscribedListIds, isEmpty);
    });
  });
}
