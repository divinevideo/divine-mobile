// ABOUTME: Unit tests for CuratedListService ownership checks.
// ABOUTME: Verifies local list ownership is scoped to authenticated users.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('CuratedListService.isOwnedList', () {
    const currentPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    late CuratedListService service;
    late _MockAuthService mockAuth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();

      when(() => mockAuth.isAuthenticated).thenReturn(false);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(currentPubkey);
      stubListPublishing(
        client: mockNostr,
        auth: mockAuth,
        pubkey: currentPubkey,
      );

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    test('returns false for local list when not authenticated', () async {
      final list = await service.createList(name: 'Local List');

      expect(list, isNotNull);
      expect(list!.pubkey, isNull);
      expect(service.isOwnedList(list.id), isFalse);
    });

    test('returns false when list is missing', () {
      when(() => mockAuth.isAuthenticated).thenReturn(true);

      expect(service.isOwnedList('missing-list'), isFalse);
    });

    test(
      'returns true for authenticated local list created by current user',
      () async {
        when(() => mockAuth.isAuthenticated).thenReturn(true);

        final list = await service.createList(
          name: 'Local List',
          isPublic: false,
        );
        final localList = list!;

        expect(localList.pubkey, currentPubkey);
        expect(service.isOwnedList(localList.id), isTrue);
      },
    );

    test(
      'returns false for legacy local list without stored owner pubkey',
      () async {
        when(() => mockAuth.isAuthenticated).thenReturn(true);
        final now = DateTime(2026);

        await service.subscribeToList(
          'legacy-local-list',
          CuratedList(
            id: 'legacy-local-list',
            name: 'Legacy Local List',
            videoEventIds: const [],
            createdAt: now,
            updatedAt: now,
          ),
        );
        await service.unsubscribeFromList('legacy-local-list');

        expect(service.isOwnedList('legacy-local-list'), isFalse);
      },
    );

    test('returns true for authenticated current-user remote list', () async {
      when(() => mockAuth.isAuthenticated).thenReturn(true);
      final now = DateTime(2026);

      await service.subscribeToList(
        'current-user-list',
        CuratedList(
          id: 'current-user-list',
          name: 'Current User List',
          videoEventIds: const [],
          pubkey: currentPubkey,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(service.isOwnedList('current-user-list'), isTrue);
    });

    test('returns false for authenticated other-user remote list', () async {
      when(() => mockAuth.isAuthenticated).thenReturn(true);
      final now = DateTime(2026);

      await service.subscribeToList(
        'other-user-list',
        CuratedList(
          id: 'other-user-list',
          name: 'Other User List',
          videoEventIds: const [],
          pubkey: otherPubkey,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(service.isOwnedList('other-user-list'), isFalse);
    });

    test(
      'returns false for authenticated subscribed list without owner',
      () async {
        when(() => mockAuth.isAuthenticated).thenReturn(true);
        final now = DateTime(2026);

        await service.subscribeToList(
          'unknown-owner-list',
          CuratedList(
            id: 'unknown-owner-list',
            name: 'Unknown Owner List',
            videoEventIds: const [],
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(service.isOwnedList('unknown-owner-list'), isFalse);
      },
    );
  });

  group('CuratedListService.myLists', () {
    const currentPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    late CuratedListService service;
    late _MockAuthService mockAuth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();

      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(currentPubkey);
      stubListPublishing(
        client: mockNostr,
        auth: mockAuth,
        pubkey: currentPubkey,
      );

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    CuratedList remoteList({required String id, String? pubkey}) {
      final now = DateTime(2026);
      return CuratedList(
        id: id,
        name: 'List $id',
        videoEventIds: const [],
        pubkey: pubkey,
        nostrEventId: 'event_$id',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('includes a list the current user created', () async {
      final list = await service.createList(
        name: 'Local List',
        isPublic: false,
      );

      expect(service.myLists.map((l) => l.id), contains(list!.id));
    });

    test('includes published list owned by the current user', () async {
      await service.subscribeToList(
        'published-own-list',
        remoteList(id: 'published-own-list', pubkey: currentPubkey),
      );

      expect(service.myLists.map((l) => l.id), contains('published-own-list'));
    });

    test('excludes published list owned by another user', () async {
      await service.subscribeToList(
        'other-user-list',
        remoteList(id: 'other-user-list', pubkey: otherPubkey),
      );

      expect(
        service.myLists.map((l) => l.id),
        isNot(contains('other-user-list')),
      );
    });

    test('excludes other-user published list when not authenticated', () async {
      when(() => mockAuth.isAuthenticated).thenReturn(false);

      await service.subscribeToList(
        'other-user-list',
        remoteList(id: 'other-user-list', pubkey: otherPubkey),
      );

      expect(
        service.myLists.map((l) => l.id),
        isNot(contains('other-user-list')),
      );
    });
  });
}
