// ABOUTME: Unit tests for CuratedListService video management operations
// ABOUTME: Tests adding, removing, and querying videos in lists

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curated_list_service_video_management_test.mocks.dart';

@GenerateMocks([INostrService, AuthService])
void main() {
  group('CuratedListService - Video Management', () {
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

    group('addVideoToList()', () {
      test('adds video to list successfully', () async {
        final list = await service.createList(name: 'Test List');

        final result = await service.addVideoToList(
          list!.id,
          'video_event_123',
        );

        expect(result, isTrue);
        expect(service.isVideoInList(list.id, 'video_event_123'), isTrue);
        final updatedList = service.getListById(list.id);
        expect(updatedList!.videoEventIds, contains('video_event_123'));
      });

      test('adds multiple videos to same list', () async {
        final list = await service.createList(name: 'Test List');

        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        await service.addVideoToList(list.id, 'video_3');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.videoEventIds.length, 3);
        expect(updatedList.videoEventIds, contains('video_1'));
        expect(updatedList.videoEventIds, contains('video_2'));
        expect(updatedList.videoEventIds, contains('video_3'));
      });

      test('prevents duplicate video additions', () async {
        final list = await service.createList(name: 'Test List');

        await service.addVideoToList(list!.id, 'video_event_123');
        await service.addVideoToList(list.id, 'video_event_123');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.videoEventIds.length, 1);
      });

      test('returns true when video already in list', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_event_123');

        final result = await service.addVideoToList(list.id, 'video_event_123');

        expect(result, isTrue); // Should return true, not false
      });

      test('returns false for non-existent list', () async {
        final result = await service.addVideoToList(
          'non_existent_list',
          'video_123',
        );

        expect(result, isFalse);
      });

      test('updates list updatedAt timestamp', () async {
        final list = await service.createList(name: 'Test List');
        final originalUpdatedAt = list!.updatedAt;

        await Future.delayed(const Duration(milliseconds: 10));
        await service.addVideoToList(list.id, 'video_event_123');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.updatedAt.isAfter(originalUpdatedAt), isTrue);
      });

      test('publishes update to Nostr for public list', () async {
        final list = await service.createList(
          name: 'Test List',
          isPublic: true,
        );
        reset(mockNostr); // Clear previous invocations

        await service.addVideoToList(list!.id, 'video_event_123');

        verify(mockNostr.broadcastEvent(any)).called(1);
      });

      test('does not publish update for private list', () async {
        final list = await service.createList(
          name: 'Test List',
          isPublic: false,
        );
        reset(mockNostr); // Clear previous invocations

        await service.addVideoToList(list!.id, 'video_event_123');

        verifyNever(mockNostr.broadcastEvent(any));
      });

      test('saves to SharedPreferences after adding', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_event_123');

        final savedLists = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedLists, isNotNull);
        expect(savedLists, contains('video_event_123'));
      });

      test('maintains video order (chronological by default)', () async {
        final list = await service.createList(name: 'Test List');

        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        await service.addVideoToList(list.id, 'video_3');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.videoEventIds, ['video_1', 'video_2', 'video_3']);
      });
    });

    group('removeVideoFromList()', () {
      test('removes video from list successfully', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_event_123');

        final result = await service.removeVideoFromList(
          list.id,
          'video_event_123',
        );

        expect(result, isTrue);
        expect(service.isVideoInList(list.id, 'video_event_123'), isFalse);
        final updatedList = service.getListById(list.id);
        expect(updatedList!.videoEventIds, isEmpty);
      });

      test('removes specific video from list with multiple videos', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        await service.addVideoToList(list.id, 'video_3');

        await service.removeVideoFromList(list.id, 'video_2');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.videoEventIds.length, 2);
        expect(updatedList.videoEventIds, ['video_1', 'video_3']);
      });

      test('returns false for non-existent list', () async {
        final result = await service.removeVideoFromList(
          'non_existent_list',
          'video_123',
        );

        expect(result, isFalse);
      });

      test('handles removing non-existent video gracefully', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');

        final result = await service.removeVideoFromList(list.id, 'video_2');

        expect(result, isTrue); // Should succeed (no-op)
        expect(service.getListById(list.id)!.videoEventIds, ['video_1']);
      });

      test('updates list updatedAt timestamp', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_event_123');
        final originalUpdatedAt = service.getListById(list.id)!.updatedAt;

        await Future.delayed(const Duration(milliseconds: 10));
        await service.removeVideoFromList(list.id, 'video_event_123');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.updatedAt.isAfter(originalUpdatedAt), isTrue);
      });

      test('publishes update to Nostr for public list', () async {
        final list = await service.createList(
          name: 'Test List',
          isPublic: true,
        );
        await service.addVideoToList(list!.id, 'video_event_123');
        reset(mockNostr); // Clear previous invocations

        await service.removeVideoFromList(list.id, 'video_event_123');

        verify(mockNostr.broadcastEvent(any)).called(1);
      });

      test('does not publish update for private list', () async {
        final list = await service.createList(
          name: 'Test List',
          isPublic: false,
        );
        await service.addVideoToList(list!.id, 'video_event_123');
        reset(mockNostr); // Clear previous invocations

        await service.removeVideoFromList(list.id, 'video_event_123');

        verifyNever(mockNostr.broadcastEvent(any));
      });

      test('saves to SharedPreferences after removing', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_event_123');
        await service.removeVideoFromList(list.id, 'video_event_123');

        final savedLists = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedLists, isNotNull);
        expect(savedLists, isNot(contains('video_event_123')));
      });
    });

    group('isVideoInList()', () {
      test('returns true when video is in list', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_event_123');

        expect(service.isVideoInList(list.id, 'video_event_123'), isTrue);
      });

      test('returns false when video is not in list', () async {
        final list = await service.createList(name: 'Test List');

        expect(service.isVideoInList(list!.id, 'video_event_123'), isFalse);
      });

      test('returns false for non-existent list', () {
        expect(
          service.isVideoInList('non_existent_list', 'video_123'),
          isFalse,
        );
      });

      test('returns false after video is removed', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_event_123');
        await service.removeVideoFromList(list.id, 'video_event_123');

        expect(service.isVideoInList(list.id, 'video_event_123'), isFalse);
      });
    });

    group('isVideoInDefaultList()', () {
      test('returns true when video is in default list', () async {
        await service.initialize();
        final defaultList = service.getDefaultList();

        await service.addVideoToList(defaultList!.id, 'video_event_123');

        expect(service.isVideoInDefaultList('video_event_123'), isTrue);
      });

      test('returns false when video is not in default list', () async {
        await service.initialize();

        expect(service.isVideoInDefaultList('video_event_123'), isFalse);
      });

      test('uses defaultListId constant', () async {
        await service.initialize();

        await service.addVideoToList(
          CuratedListService.defaultListId,
          'video_event_123',
        );

        expect(service.isVideoInDefaultList('video_event_123'), isTrue);
      });
    });

    group('getListsContainingVideo()', () {
      test('returns all lists containing video', () async {
        final list1 = await service.createList(name: 'List 1');
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(name: 'List 2');
        await Future.delayed(const Duration(milliseconds: 5));
        final list3 = await service.createList(name: 'List 3');

        await service.addVideoToList(list1!.id, 'video_123');
        await service.addVideoToList(list3!.id, 'video_123');

        final containingLists = service.getListsContainingVideo('video_123');

        expect(containingLists.length, 2);
        expect(
          containingLists.map((l) => l.id),
          containsAll([list1.id, list3.id]),
        );
      });

      test('returns empty list when video not in any list', () async {
        await service.createList(name: 'List 1');
        await service.createList(name: 'List 2');

        final containingLists = service.getListsContainingVideo('video_123');

        expect(containingLists, isEmpty);
      });

      test('returns single list when video only in one list', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_123');

        final containingLists = service.getListsContainingVideo('video_123');

        expect(containingLists.length, 1);
        expect(containingLists.first.id, list.id);
      });

      test('updates after adding video to another list', () async {
        final list1 = await service.createList(name: 'List 1');
        await Future.delayed(const Duration(milliseconds: 5));
        final list2 = await service.createList(name: 'List 2');

        await service.addVideoToList(list1!.id, 'video_123');
        expect(service.getListsContainingVideo('video_123').length, 1);

        await service.addVideoToList(list2!.id, 'video_123');
        expect(service.getListsContainingVideo('video_123').length, 2);
      });

      test('updates after removing video from list', () async {
        final list1 = await service.createList(name: 'List 1');
        await Future.delayed(const Duration(milliseconds: 5));
        final list2 = await service.createList(name: 'List 2');

        await service.addVideoToList(list1!.id, 'video_123');
        await service.addVideoToList(list2!.id, 'video_123');
        expect(service.getListsContainingVideo('video_123').length, 2);

        await service.removeVideoFromList(list1.id, 'video_123');
        final remainingLists = service.getListsContainingVideo('video_123');
        expect(remainingLists.length, 1);
        expect(remainingLists.first.id, list2.id);
      });
    });

    group('getVideoListSummary()', () {
      test('returns "Not in any lists" when video not in lists', () async {
        await service.createList(name: 'Test List');

        final summary = service.getVideoListSummary('video_123');

        expect(summary, 'Not in any lists');
      });

      test('returns list name when video in single list', () async {
        final list = await service.createList(name: 'My Favorites');
        await service.addVideoToList(list!.id, 'video_123');

        final summary = service.getVideoListSummary('video_123');

        expect(summary, 'In "My Favorites"');
      });

      test('returns all list names when video in 2-3 lists', () async {
        final list1 = await service.createList(name: 'Favorites');
        await Future.delayed(const Duration(milliseconds: 5));
        final list2 = await service.createList(name: 'Watch Later');

        await service.addVideoToList(list1!.id, 'video_123');
        await service.addVideoToList(list2!.id, 'video_123');

        final summary = service.getVideoListSummary('video_123');

        expect(summary, 'In "Favorites", "Watch Later"');
      });

      test('returns count when video in many lists', () async {
        for (var i = 1; i <= 5; i++) {
          final list = await service.createList(name: 'List $i');
          await service.addVideoToList(list!.id, 'video_123');
          await Future.delayed(const Duration(milliseconds: 5));
        }

        final summary = service.getVideoListSummary('video_123');

        expect(summary, 'In 5 lists');
      });
    });

    group('Video Management - Edge Cases', () {
      test(
        'handles adding same video to multiple lists simultaneously',
        () async {
          final list1 = await service.createList(name: 'List 1');
          await Future.delayed(const Duration(milliseconds: 5));
          final list2 = await service.createList(name: 'List 2');
          await Future.delayed(const Duration(milliseconds: 5));
          final list3 = await service.createList(name: 'List 3');

          // Add same video to all lists
          await Future.wait([
            service.addVideoToList(list1!.id, 'video_123'),
            service.addVideoToList(list2!.id, 'video_123'),
            service.addVideoToList(list3!.id, 'video_123'),
          ]);

          expect(service.isVideoInList(list1.id, 'video_123'), isTrue);
          expect(service.isVideoInList(list2.id, 'video_123'), isTrue);
          expect(service.isVideoInList(list3.id, 'video_123'), isTrue);
          expect(service.getListsContainingVideo('video_123').length, 3);
        },
      );

      test('handles empty video event ID', () async {
        final list = await service.createList(name: 'Test List');

        final result = await service.addVideoToList(list!.id, '');

        expect(result, isTrue); // Service allows empty strings
        expect(service.isVideoInList(list.id, ''), isTrue);
      });

      test('preserves order when removing videos from middle', () async {
        final list = await service.createList(name: 'Test List');

        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        await service.addVideoToList(list.id, 'video_3');
        await service.addVideoToList(list.id, 'video_4');

        await service.removeVideoFromList(list.id, 'video_2');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.videoEventIds, ['video_1', 'video_3', 'video_4']);
      });

      test('handles large number of videos in list', () async {
        final list = await service.createList(name: 'Test List');
        final listId = list!.id;

        // Add 100 videos
        for (var i = 0; i < 100; i++) {
          await service.addVideoToList(listId, 'video_$i');
        }

        final updatedList = service.getListById(listId);
        expect(updatedList!.videoEventIds.length, 100);
        expect(service.isVideoInList(listId, 'video_50'), isTrue);
      });
    });
  });
}
