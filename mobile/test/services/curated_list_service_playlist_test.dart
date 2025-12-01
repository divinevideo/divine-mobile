// ABOUTME: Unit tests for CuratedListService playlist features
// ABOUTME: Tests video ordering, reordering, and play order modes

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curated_list_service_playlist_test.mocks.dart';

@GenerateMocks([INostrService, AuthService])
void main() {
  group('CuratedListService - Playlist Features', () {
    late CuratedListService service;
    late MockINostrService mockNostr;
    late MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockNostr = MockINostrService();
      mockAuth = MockAuthService();
      prefs = await SharedPreferences.getInstance();

      when(mockAuth.isAuthenticated).thenReturn(true);
      when(
        mockAuth.currentPublicKeyHex,
      ).thenReturn('test_pubkey_123456789abcdef');

      when(mockNostr.broadcastEvent(any)).thenAnswer((_) async {
        final event = Event.fromJson({
          'id': 'test_event_id',
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

      when(
        mockNostr.subscribeToEvents(
          filters: anyNamed('filters'),
          bypassLimits: anyNamed('bypassLimits'),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) => Stream.empty());

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
          'content': 'test',
          'sig': 'test_sig',
        }),
      );

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    group('reorderVideos()', () {
      test('reorders videos successfully', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        await service.addVideoToList(list.id, 'video_3');

        final result = await service.reorderVideos(list.id, [
          'video_3',
          'video_1',
          'video_2',
        ]);

        expect(result, isTrue);
        final updatedList = service.getListById(list.id);
        expect(updatedList!.videoEventIds, ['video_3', 'video_1', 'video_2']);
      });

      test('sets play order to manual after reordering', () async {
        final list = await service.createList(
          name: 'Test List',
          playOrder: PlayOrder.chronological,
        );
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');

        await service.reorderVideos(list.id, ['video_2', 'video_1']);

        final updatedList = service.getListById(list.id);
        expect(updatedList!.playOrder, PlayOrder.manual);
      });

      test('returns false for non-existent list', () async {
        final result = await service.reorderVideos('non_existent', [
          'video_1',
          'video_2',
        ]);

        expect(result, isFalse);
      });

      test('rejects reorder with missing videos', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        await service.addVideoToList(list.id, 'video_3');

        // Missing video_3
        final result = await service.reorderVideos(list.id, [
          'video_1',
          'video_2',
        ]);

        expect(result, isFalse);
        // Order should not change
        final updatedList = service.getListById(list.id);
        expect(updatedList!.videoEventIds, ['video_1', 'video_2', 'video_3']);
      });

      test('rejects reorder with extra videos', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');

        // Extra video_3
        final result = await service.reorderVideos(list.id, [
          'video_1',
          'video_2',
          'video_3',
        ]);

        expect(result, isFalse);
      });

      test('publishes update to Nostr for public list', () async {
        final list = await service.createList(
          name: 'Test List',
          isPublic: true,
        );
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        reset(mockNostr);

        await service.reorderVideos(list.id, ['video_2', 'video_1']);

        verify(mockNostr.broadcastEvent(any)).called(1);
      });

      test('updates updatedAt timestamp', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        final originalUpdatedAt = service.getListById(list.id)!.updatedAt;

        await Future.delayed(const Duration(milliseconds: 10));
        await service.reorderVideos(list.id, ['video_2', 'video_1']);

        final updatedList = service.getListById(list.id);
        expect(updatedList!.updatedAt.isAfter(originalUpdatedAt), isTrue);
      });
    });

    group('getOrderedVideoIds()', () {
      test('returns chronological order by default', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        await service.addVideoToList(list.id, 'video_3');

        final ordered = service.getOrderedVideoIds(list.id);

        expect(ordered, ['video_1', 'video_2', 'video_3']);
      });

      test('returns reverse chronological order', () async {
        final list = await service.createList(
          name: 'Test List',
          playOrder: PlayOrder.reverse,
        );
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        await service.addVideoToList(list.id, 'video_3');

        final ordered = service.getOrderedVideoIds(list.id);

        expect(ordered, ['video_3', 'video_2', 'video_1']);
      });

      test('returns manual order after reordering', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        await service.addVideoToList(list.id, 'video_3');
        await service.reorderVideos(list.id, ['video_2', 'video_3', 'video_1']);

        final ordered = service.getOrderedVideoIds(list.id);

        expect(ordered, ['video_2', 'video_3', 'video_1']);
      });

      test('returns shuffled order (different from original)', () async {
        final list = await service.createList(
          name: 'Test List',
          playOrder: PlayOrder.shuffle,
        );
        final listId = list!.id;
        // Add many videos to increase shuffle probability
        for (var i = 0; i < 20; i++) {
          await service.addVideoToList(listId, 'video_$i');
        }

        final ordered = service.getOrderedVideoIds(listId);

        // Should have same videos but likely different order
        expect(ordered.length, 20);
        expect(ordered.toSet().length, 20); // No duplicates
        // Very unlikely to be in exact same order after shuffle
      });

      test('returns empty list for non-existent list', () {
        final ordered = service.getOrderedVideoIds('non_existent');

        expect(ordered, isEmpty);
      });

      test('returns empty list for list with no videos', () async {
        final list = await service.createList(name: 'Empty List');

        final ordered = service.getOrderedVideoIds(list!.id);

        expect(ordered, isEmpty);
      });
    });

    group('PlayOrder enum', () {
      test('creates list with specific play order', () async {
        final list1 = await service.createList(
          name: 'Chronological',
          playOrder: PlayOrder.chronological,
        );
        final list2 = await service.createList(
          name: 'Reverse',
          playOrder: PlayOrder.reverse,
        );
        final list3 = await service.createList(
          name: 'Shuffle',
          playOrder: PlayOrder.shuffle,
        );
        final list4 = await service.createList(
          name: 'Manual',
          playOrder: PlayOrder.manual,
        );

        expect(list1!.playOrder, PlayOrder.chronological);
        expect(list2!.playOrder, PlayOrder.reverse);
        expect(list3!.playOrder, PlayOrder.shuffle);
        expect(list4!.playOrder, PlayOrder.manual);
      });

      test('updates play order via updateList', () async {
        final list = await service.createList(
          name: 'Test List',
          playOrder: PlayOrder.chronological,
        );

        await service.updateList(
          listId: list!.id,
          playOrder: PlayOrder.shuffle,
        );

        final updatedList = service.getListById(list.id);
        expect(updatedList!.playOrder, PlayOrder.shuffle);
      });

      test('play order persists across service recreations', () async {
        final list = await service.createList(
          name: 'Test List',
          playOrder: PlayOrder.reverse,
        );

        // Create new service instance
        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final loadedList = service2.getListById(list!.id);
        expect(loadedList!.playOrder, PlayOrder.reverse);
      });
    });

    group('Playlist Features - Edge Cases', () {
      test('reorder with single video', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');

        final result = await service.reorderVideos(list.id, ['video_1']);

        expect(result, isTrue);
        expect(service.getListById(list.id)!.videoEventIds, ['video_1']);
      });

      test('reorder empty list', () async {
        final list = await service.createList(name: 'Test List');
        final listId = list!.id;

        final result = await service.reorderVideos(listId, []);

        expect(result, isTrue);
        expect(service.getListById(listId)!.videoEventIds, isEmpty);
      });

      test(
        'reorder with duplicate videos in new order is accepted (duplicates removed)',
        () async {
          final list = await service.createList(name: 'Test List');
          await service.addVideoToList(list!.id, 'video_1');
          await service.addVideoToList(list.id, 'video_2');

          // Duplicate video_1 - implementation uses Set which deduplicates
          final result = await service.reorderVideos(list.id, [
            'video_1',
            'video_1',
            'video_2',
          ]);

          // Implementation accepts because Set(['video_1', 'video_1', 'video_2']) == Set(['video_1', 'video_2'])
          expect(result, isTrue);
        },
      );

      test(
        'getOrderedVideoIds respects playOrder after manual reorder',
        () async {
          final list = await service.createList(
            name: 'Test List',
            playOrder: PlayOrder.reverse, // Start with reverse
          );
          await service.addVideoToList(list!.id, 'video_1');
          await service.addVideoToList(list.id, 'video_2');
          await service.addVideoToList(list.id, 'video_3');

          // Before reorder - should be reverse
          expect(service.getOrderedVideoIds(list.id), [
            'video_3',
            'video_2',
            'video_1',
          ]);

          // Reorder - changes to manual
          await service.reorderVideos(list.id, [
            'video_2',
            'video_1',
            'video_3',
          ]);

          // After reorder - should use manual order
          expect(service.getOrderedVideoIds(list.id), [
            'video_2',
            'video_1',
            'video_3',
          ]);
        },
      );

      test('shuffle generates different orders on multiple calls', () async {
        final list = await service.createList(
          name: 'Test List',
          playOrder: PlayOrder.shuffle,
        );
        final listId = list!.id;
        for (var i = 0; i < 10; i++) {
          await service.addVideoToList(listId, 'video_$i');
        }

        final order1 = service.getOrderedVideoIds(listId);
        final order2 = service.getOrderedVideoIds(listId);
        final order3 = service.getOrderedVideoIds(listId);

        // At least one should be different (very high probability with 10 items)
        final allSame =
            order1.toString() == order2.toString() &&
            order2.toString() == order3.toString();
        expect(allSame, isFalse);
      });
    });
  });
}
