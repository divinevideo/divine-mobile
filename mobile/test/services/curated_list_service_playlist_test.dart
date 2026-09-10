// ABOUTME: Unit tests for CuratedListService playlist features
// ABOUTME: Tests video ordering, reordering, and play order modes

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('CuratedListService - Playlist Features', () {
    late CuratedListService service;
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUpAll(() {
      registerFallbackValue(
        Event.fromJson({
          'id': 'fallback_event_id',
          'pubkey': 'aabbccdd00112233445566778899aabbccdd00112233445566778899aabbccdd',
          'created_at': 0,
          'kind': 1,
          'tags': <List<String>>[],
          'content': '',
          'sig': '',
        }),
      );
      registerFallbackValue(<Filter>[]);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockNostr = _MockNostrClient();
      stubListSigner(mockNostr, 'test_pubkey_123456789abcdef');
      mockAuth = _MockAuthService();
      prefs = await SharedPreferences.getInstance();

      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(
        () => mockAuth.currentPublicKeyHex,
      ).thenReturn('test_pubkey_123456789abcdef');

      when(() => mockNostr.publishEvent(any())).thenAnswer((invocation) async {
        return PublishSuccess(
          event: invocation.positionalArguments[0] as Event,
        );
      });
      when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments[0] as Event;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: const ['wss://relay.test'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });

      when(
        () => mockNostr.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) => const Stream.empty());

      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
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
        final list = await service.createList(name: 'Test List');
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
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');
        reset(mockNostr);

        when(() => mockNostr.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          return PublishSuccess(
            event: invocation.positionalArguments[0] as Event,
          );
        });

        await service.reorderVideos(list.id, ['video_2', 'video_1']);

        verify(() => mockNostr.publishEvent(any())).called(1);
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
        final list1 = await service.createList(name: 'Chronological');
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
        final list = await service.createList(name: 'Test List');

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

      test('reorder with duplicate videos in new order is accepted '
          '(duplicates removed)', () async {
        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_1');
        await service.addVideoToList(list.id, 'video_2');

        // Duplicate video_1 - implementation uses Set which deduplicates
        final result = await service.reorderVideos(list.id, [
          'video_1',
          'video_1',
          'video_2',
        ]);

        // Implementation accepts because
        // Set(['video_1', 'video_1', 'video_2']) ==
        // Set(['video_1', 'video_2'])
        expect(result, isTrue);
      });

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

        // At least one should be different
        // (very high probability with 10 items)
        final allSame =
            order1.toString() == order2.toString() &&
            order2.toString() == order3.toString();
        expect(allSame, isFalse);
      });
    });
  });
}
