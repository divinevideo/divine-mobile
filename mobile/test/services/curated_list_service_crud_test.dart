// ABOUTME: Unit tests for CuratedListService CRUD operations (create, update, delete lists)
// ABOUTME: Tests core list management functionality with mocked dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curated_list_service_crud_test.mocks.dart';

@GenerateMocks([INostrService, AuthService])
void main() {
  group('CuratedListService - CRUD Operations', () {
    late CuratedListService service;
    late MockINostrService mockNostr;
    late MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUp(() async {
      mockNostr = MockINostrService();
      mockAuth = MockAuthService();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // Setup common mocks
      when(mockAuth.isAuthenticated).thenReturn(true);
      when(
        mockAuth.currentPublicKeyHex,
      ).thenReturn('test_pubkey_123456789abcdef');

      // Mock successful event broadcasting
      when(mockNostr.broadcastEvent(any)).thenAnswer((_) async {
        final event = Event.fromJson({
          'id': 'broadcast_event_id',
          'pubkey': 'test_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [],
          'content': 'test',
          'sig': 'test_sig',
        });
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay.example.com': true},
          errors: {},
        );
      });

      // Mock subscribeToEvents for relay sync
      when(
        mockNostr.subscribeToEvents(
          filters: anyNamed('filters'),
          bypassLimits: anyNamed('bypassLimits'),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) => Stream.empty());

      // Mock event creation
      when(
        mockAuth.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer(
        (_) async => Event.fromJson({
          'id': 'test_event_id',
          'pubkey': 'test_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [],
          'content': 'test content',
          'sig': 'test_signature',
        }),
      );

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    group('initialize()', () {
      test('creates default list when none exists', () async {
        // Start with no lists
        expect(service.hasDefaultList(), isFalse);

        await service.initialize();

        // Should create default list
        expect(service.hasDefaultList(), isTrue);
        expect(service.isInitialized, isTrue);

        final defaultList = service.getDefaultList();
        expect(defaultList, isNotNull);
        expect(defaultList!.id, CuratedListService.defaultListId);
        expect(defaultList.name, 'My List');
      });

      test('does not create duplicate default list', () async {
        // Initialize once
        await service.initialize();
        final firstDefaultList = service.getDefaultList();

        // Initialize again
        await service.initialize();
        final secondDefaultList = service.getDefaultList();

        // Should be the same list
        expect(secondDefaultList!.id, firstDefaultList!.id);
        expect(service.lists.length, 1);
      });

      test('does nothing when user not authenticated', () async {
        when(mockAuth.isAuthenticated).thenReturn(false);

        await service.initialize();

        expect(service.isInitialized, isFalse);
        expect(service.hasDefaultList(), isFalse);
      });

      test('calls fetchUserListsFromRelays during initialization', () async {
        // Mock subscription for relay sync
        when(
          mockNostr.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer(
          (_) => Stream.value(
            Event.fromJson({
              'id': 'relay_list_event',
              'pubkey': 'test_pubkey_123456789abcdef',
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'relay_list_1'],
                ['title', 'Relay List'],
              ],
              'content': 'List from relay',
              'sig': 'test_signature',
            }),
          ),
        );

        await service.initialize();

        // Should have called subscribeToEvents
        verify(
          mockNostr.subscribeToEvents(filters: anyNamed('filters')),
        ).called(1);
      });
    });

    group('createList()', () {
      test('creates list with name only', () async {
        final list = await service.createList(name: 'My Videos');

        expect(list, isNotNull);
        expect(list!.name, 'My Videos');
        expect(list.id, startsWith('list_'));
        expect(list.videoEventIds, isEmpty);
        expect(list.isPublic, isTrue);
        expect(list.tags, isEmpty);
        expect(list.playOrder, PlayOrder.chronological);
      });

      test('creates list with all optional fields', () async {
        final list = await service.createList(
          name: 'Test List',
          description: 'A test list',
          imageUrl: 'https://example.com/image.jpg',
          isPublic: false,
          tags: ['test', 'demo'],
          isCollaborative: true,
          allowedCollaborators: ['collaborator_pubkey'],
          thumbnailEventId: 'thumbnail_event_id',
          playOrder: PlayOrder.shuffle,
        );

        expect(list, isNotNull);
        expect(list!.name, 'Test List');
        expect(list.description, 'A test list');
        expect(list.imageUrl, 'https://example.com/image.jpg');
        expect(list.isPublic, isFalse);
        expect(list.tags, ['test', 'demo']);
        expect(list.isCollaborative, isTrue);
        expect(list.allowedCollaborators, ['collaborator_pubkey']);
        expect(list.thumbnailEventId, 'thumbnail_event_id');
        expect(list.playOrder, PlayOrder.shuffle);
      });

      test('adds created list to lists collection', () async {
        expect(service.lists, isEmpty);

        await service.createList(name: 'Test List');

        expect(service.lists.length, 1);
        expect(service.lists.first.name, 'Test List');
      });

      test('publishes public list to Nostr', () async {
        await service.createList(name: 'Public List', isPublic: true);

        // Should create and sign event
        verify(
          mockAuth.createAndSignEvent(
            kind: 30005,
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).called(1);

        // Should broadcast event
        verify(mockNostr.broadcastEvent(any)).called(1);
      });

      test('does not publish private list to Nostr', () async {
        await service.createList(name: 'Private List', isPublic: false);

        // Should not create or broadcast event
        verifyNever(
          mockAuth.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        );
        verifyNever(mockNostr.broadcastEvent(any));
      });

      test('does not publish when user not authenticated', () async {
        when(mockAuth.isAuthenticated).thenReturn(false);

        await service.createList(name: 'Test List', isPublic: true);

        // Should not attempt to publish
        verifyNever(
          mockAuth.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        );
      });

      test('saves list to SharedPreferences', () async {
        await service.createList(name: 'Test List');

        // Should have saved lists to prefs
        final savedLists = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedLists, isNotNull);
        expect(savedLists, contains('Test List'));
      });

      test('assigns unique IDs to multiple lists', () async {
        final list1 = await service.createList(name: 'List 1');

        // Wait a bit to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 5));

        final list2 = await service.createList(name: 'List 2');

        expect(list1!.id, isNot(equals(list2!.id)));
      });

      test('sets createdAt and updatedAt to same time', () async {
        final list = await service.createList(name: 'Test List');

        expect(list!.createdAt, list.updatedAt);
      });
    });

    group('updateList()', () {
      test('updates list name', () async {
        final list = await service.createList(name: 'Original Name');
        final originalUpdatedAt = list!.updatedAt;

        // Wait a bit to ensure updatedAt changes
        await Future.delayed(const Duration(milliseconds: 10));

        final result = await service.updateList(
          listId: list.id,
          name: 'Updated Name',
        );

        expect(result, isTrue);

        final updatedList = service.getListById(list.id);
        expect(updatedList!.name, 'Updated Name');
        expect(updatedList.updatedAt.isAfter(originalUpdatedAt), isTrue);
      });

      test('updates list description', () async {
        final list = await service.createList(name: 'Test List');

        await service.updateList(
          listId: list!.id,
          description: 'New description',
        );

        final updatedList = service.getListById(list.id);
        expect(updatedList!.description, 'New description');
      });

      test('updates multiple fields at once', () async {
        final list = await service.createList(name: 'Test List');

        await service.updateList(
          listId: list!.id,
          name: 'Updated Name',
          description: 'Updated description',
          imageUrl: 'https://example.com/new-image.jpg',
          tags: ['updated', 'tags'],
          playOrder: PlayOrder.reverse,
        );

        final updatedList = service.getListById(list.id);
        expect(updatedList!.name, 'Updated Name');
        expect(updatedList.description, 'Updated description');
        expect(updatedList.imageUrl, 'https://example.com/new-image.jpg');
        expect(updatedList.tags, ['updated', 'tags']);
        expect(updatedList.playOrder, PlayOrder.reverse);
      });

      test('publishes update to Nostr for public list', () async {
        final list = await service.createList(
          name: 'Test List',
          isPublic: true,
        );
        reset(mockNostr); // Clear previous invocations

        await service.updateList(listId: list!.id, name: 'Updated Name');

        verify(mockNostr.broadcastEvent(any)).called(1);
      });

      test('does not publish update for private list', () async {
        final list = await service.createList(
          name: 'Test List',
          isPublic: false,
        );
        reset(mockNostr); // Clear previous invocations

        await service.updateList(listId: list!.id, name: 'Updated Name');

        verifyNever(mockNostr.broadcastEvent(any));
      });

      test('returns false for non-existent list', () async {
        final result = await service.updateList(
          listId: 'non_existent_list',
          name: 'New Name',
        );

        expect(result, isFalse);
      });

      test('saves updated list to SharedPreferences', () async {
        final list = await service.createList(name: 'Test List');

        await service.updateList(listId: list!.id, name: 'Updated Name');

        final savedLists = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedLists, isNotNull);
        expect(savedLists, contains('Updated Name'));
        expect(savedLists, isNot(contains('Test List')));
      });

      test('preserves unchanged fields', () async {
        final list = await service.createList(
          name: 'Test List',
          description: 'Original description',
          tags: ['original', 'tags'],
        );

        await service.updateList(listId: list!.id, name: 'Updated Name');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.description, 'Original description');
        expect(updatedList.tags, ['original', 'tags']);
      });
    });

    group('deleteList()', () {
      test('deletes list successfully', () async {
        final list = await service.createList(name: 'Test List');

        final result = await service.deleteList(list!.id);

        expect(result, isTrue);
        expect(service.getListById(list.id), isNull);
        expect(service.lists, isEmpty);
      });

      test('removes multiple lists independently', () async {
        final list1 = await service.createList(name: 'List 1');
        await Future.delayed(const Duration(milliseconds: 5));
        final list2 = await service.createList(name: 'List 2');
        await Future.delayed(const Duration(milliseconds: 5));
        final list3 = await service.createList(name: 'List 3');

        await service.deleteList(list2!.id);

        expect(service.lists.length, 2);
        expect(service.getListById(list1!.id), isNotNull);
        expect(service.getListById(list2.id), isNull);
        expect(service.getListById(list3!.id), isNotNull);
      });

      test('prevents deleting default list', () async {
        await service.initialize();

        final result = await service.deleteList(
          CuratedListService.defaultListId,
        );

        expect(result, isFalse);
        expect(service.hasDefaultList(), isTrue);
      });

      test('returns false for non-existent list', () async {
        final result = await service.deleteList('non_existent_list');

        expect(result, isFalse);
      });

      test('saves updated lists after deletion', () async {
        final list = await service.createList(name: 'Test List');
        await service.deleteList(list!.id);

        final savedLists = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedLists, isNotNull);
        expect(savedLists, isNot(contains('Test List')));
      });

      test('handles deleting last non-default list', () async {
        await service.initialize(); // Creates default list
        final list = await service.createList(name: 'Extra List');

        await service.deleteList(list!.id);

        expect(service.lists.length, 1);
        expect(service.hasDefaultList(), isTrue);
      });
    });

    group('getListById()', () {
      test('returns list when it exists', () async {
        final list = await service.createList(name: 'Test List');

        final retrieved = service.getListById(list!.id);

        expect(retrieved, isNotNull);
        expect(retrieved!.id, list.id);
        expect(retrieved.name, list.name);
      });

      test('returns null when list does not exist', () {
        final retrieved = service.getListById('non_existent_list');

        expect(retrieved, isNull);
      });

      test('returns correct list when multiple lists exist', () async {
        await service.createList(name: 'List 1');
        await Future.delayed(const Duration(milliseconds: 5));
        final list2 = await service.createList(name: 'List 2');
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(name: 'List 3');

        final retrieved = service.getListById(list2!.id);

        expect(retrieved, isNotNull);
        expect(retrieved!.id, list2.id);
        expect(retrieved.name, 'List 2');
      });
    });

    group('lists getter', () {
      test('returns immutable list', () async {
        await service.createList(name: 'Test List');

        final lists = service.lists;

        // Should not be able to modify the returned list
        expect(
          () => lists.add(
            CuratedList(
              id: 'fake_id',
              name: 'Fake List',
              videoEventIds: [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
          throwsUnsupportedError,
        );
      });

      test('returns all lists', () async {
        await service.createList(name: 'List 1');
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(name: 'List 2');
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(name: 'List 3');

        expect(service.lists.length, 3);
        expect(service.lists.map((l) => l.name), [
          'List 1',
          'List 2',
          'List 3',
        ]);
      });

      test('returns empty list initially', () {
        expect(service.lists, isEmpty);
      });
    });
  });
}
