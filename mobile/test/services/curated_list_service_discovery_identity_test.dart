// ABOUTME: Discovery list cache and subscriptions retain author-scoped identity.
// ABOUTME: Same d-tags across accounts must stay separate across persistence.

import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/committed_list_account.dart';
import '../helpers/curated_list_publish_stubs.dart';
import '../helpers/signed_curated_list.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('discovered list identity', () {
    const viewer = signedListFixtureOwner;
    final author = 'b' * 64;
    final otherAuthor = 'c' * 64;
    const id = 'my_vine_list';
    late SharedPreferences prefs;
    late _MockAuthService auth;
    late _MockNostrClient nostr;

    CuratedList list(String pubkey) => CuratedList(
      id: id,
      name: 'List',
      description: 'List',
      pubkey: pubkey,
      videoEventIds: [pubkey],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    Event? ownedRevision;
    setUpAll(() => registerFallbackValue(<Filter>[]));

    Future<CuratedListService> loadService({bool authenticated = false}) async {
      if (authenticated) {
        when(() => auth.isAuthenticated).thenReturn(true);
        await stubCommittedListAccount(auth: auth, preferences: prefs);
        stubListPublishing(client: nostr, auth: auth, pubkey: viewer);
        final signer = LocalNostrSigner('1'.padLeft(64, '0'));
        when(() => nostr.signer).thenReturn(signer);
        when(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((invocation) async {
          final event = Event(
            viewer,
            invocation.namedArguments[#kind] as int,
            invocation.namedArguments[#tags] as List<List<String>>,
            invocation.namedArguments[#content] as String,
            createdAt: invocation.namedArguments[#createdAt] as int?,
          );
          await signer.signEvent(event);
          return event;
        });
        ownedRevision = await signedCuratedListFixture(list(viewer), signer);
        final decodedBaseline = CuratedListConverter.fromEvent(ownedRevision!)!;
        final storedRows = jsonDecode(
          prefs.getString(CuratedListService.listsStorageKey)!,
        ) as List<dynamic>;
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([
            for (final row in storedRows)
              if ((row as Map<String, dynamic>)['pubkey'] == viewer)
                decodedBaseline.toJson()
              else
                row,
          ]),
        );
        when(() => nostr.subscribe(any(), closeOnEose: true))
            .thenAnswer((_) => Stream.value(ownedRevision!));
      }
      final service = CuratedListService(
        nostrService: nostr,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      await service.initialize();
      if (authenticated) await service.fetchUserListsFromRelays(force: true);
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
        var owned = list(viewer);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([
            foreign.toJson(),
            owned.toJson(),
          ]),
        );
        final service = await loadService(authenticated: true);
        owned = CuratedListConverter.fromEvent(ownedRevision!)!;
        expect(service.getDefaultList(), owned);
        expect(service.getListById(id), owned);
        expect(await service.addVideoToList(id, 'd' * 64), isTrue);
        expect(
          service.getListById('$viewer:$id')?.videoEventIds,
          contains('d' * 64),
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
        final service = await loadService(authenticated: true);
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
