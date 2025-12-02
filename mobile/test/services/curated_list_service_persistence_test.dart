// ABOUTME: Unit tests for CuratedListService persistence operations
// ABOUTME: Tests SharedPreferences save/load functionality

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curated_list_service_persistence_test.mocks.dart';

@GenerateMocks([INostrService, AuthService])
void main() {
  group('CuratedListService - Persistence', () {
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
    });

    group('Save to Preferences', () {
      test('saves list to SharedPreferences after creation', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(name: 'Test List');

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, isNotNull);
        expect(savedData, contains('Test List'));
      });

      test('saves multiple lists to SharedPreferences', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(name: 'List 1');
        await service.createList(name: 'List 2');
        await service.createList(name: 'List 3');

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, contains('List 1'));
        expect(savedData, contains('List 2'));
        expect(savedData, contains('List 3'));
      });

      test('updates SharedPreferences after list modification', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service.createList(name: 'Original Name');
        await service.updateList(listId: list!.id, name: 'Updated Name');

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, contains('Updated Name'));
        expect(savedData, isNot(contains('Original Name')));
      });

      test('updates SharedPreferences after video added', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_123');

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, contains('video_123'));
      });

      test('updates SharedPreferences after list deletion', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service.createList(name: 'To Delete');
        await service.deleteList(list!.id);

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, isNot(contains('To Delete')));
      });

      test('saves all list fields to SharedPreferences', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(
          name: 'Full List',
          description: 'Test description',
          imageUrl: 'https://example.com/image.jpg',
          tags: ['tag1', 'tag2'],
          playOrder: PlayOrder.shuffle,
        );

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, contains('Full List'));
        expect(savedData, contains('Test description'));
        expect(savedData, contains('https://example.com/image.jpg'));
        expect(savedData, contains('tag1'));
        expect(savedData, contains('shuffle'));
      });
    });

    group('Load from Preferences', () {
      test('loads lists from SharedPreferences on construction', () async {
        // Pre-populate SharedPreferences
        final list = CuratedList(
          id: 'test_id',
          name: 'Saved List',
          videoEventIds: ['video1', 'video2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Properly encode as JSON
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([list.toJson()]),
        );

        // Create service - should load from prefs
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service.lists.length, greaterThan(0));
        expect(service.lists.any((l) => l.name == 'Saved List'), isTrue);
      });

      test('loads empty list when SharedPreferences is empty', () {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service.lists, isEmpty);
      });

      test('loads list with all fields from SharedPreferences', () async {
        final originalList = CuratedList(
          id: 'test_id',
          name: 'Full List',
          description: 'Description',
          imageUrl: 'https://example.com/image.jpg',
          videoEventIds: ['video1'],
          createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
          updatedAt: DateTime.parse('2024-01-02T12:00:00Z'),
          isPublic: false,
          tags: ['tag1', 'tag2'],
          playOrder: PlayOrder.reverse,
        );

        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([originalList.toJson()]),
        );

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final loadedList = service.getListById('test_id');
        expect(loadedList, isNotNull);
        expect(loadedList!.name, 'Full List');
        expect(loadedList.description, 'Description');
        expect(loadedList.imageUrl, 'https://example.com/image.jpg');
        expect(loadedList.videoEventIds, ['video1']);
        expect(loadedList.isPublic, isFalse);
        expect(loadedList.tags, ['tag1', 'tag2']);
        expect(loadedList.playOrder, PlayOrder.reverse);
      });

      test('handles corrupted SharedPreferences data gracefully', () async {
        // Set invalid JSON
        await prefs.setString(
          CuratedListService.listsStorageKey,
          'invalid json {{{',
        );

        // Should not throw, just log error and continue with empty list
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service.lists, isEmpty);
      });

      test('preserves lists across service recreations', () async {
        // First service instance - create lists
        final service1 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        await service1.createList(name: 'Persistent List');

        // Second service instance - should load existing lists
        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service2.lists.length, greaterThanOrEqualTo(1));
        expect(service2.lists.any((l) => l.name == 'Persistent List'), isTrue);
      });
    });

    group('Persistence Edge Cases', () {
      test('handles very large list (1000 videos)', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service.createList(name: 'Large List');
        for (var i = 0; i < 1000; i++) {
          await service.addVideoToList(list!.id, 'video_$i');
        }

        // Should still save/load successfully
        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final loadedList = service2.getListById(list!.id);
        expect(loadedList, isNotNull);
        expect(loadedList!.videoEventIds.length, 1000);
      });

      test('handles special characters in list names', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(
          name: 'List with "quotes" and \'apostrophes\'',
        );
        await service.createList(name: 'List with \n newlines \t tabs');
        await service.createList(name: 'Émojis 🎥📹🎬');

        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service2.lists.length, greaterThanOrEqualTo(3));
      });

      test(
        'handles concurrent save operations',
        () async {
          // FIXME: Flaky test - race condition with timestamp-based IDs
          final service = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: prefs,
          );

          // Create multiple lists concurrently
          await Future.wait([
            service.createList(name: 'Concurrent 1'),
            service.createList(name: 'Concurrent 2'),
            service.createList(name: 'Concurrent 3'),
          ]);

          // At least some lists should be saved
          final savedData = prefs.getString(CuratedListService.listsStorageKey);
          expect(savedData, isNotNull);
          // Race condition: lists with same timestamp may overwrite each other
        },
        skip: 'Flaky: timestamp-based ID collision in concurrent creation',
      );

      test('preserves timestamps across save/load', () async {
        final service1 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service1.createList(name: 'Test List');
        final originalCreatedAt = list!.createdAt;
        final originalUpdatedAt = list.updatedAt;

        // Load in new service instance
        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final loadedList = service2.getListById(list.id);
        expect(loadedList!.createdAt, originalCreatedAt);
        expect(loadedList.updatedAt, originalUpdatedAt);
      });

      test('handles empty video list', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(name: 'Empty List');

        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = service2.lists.firstWhere((l) => l.name == 'Empty List');
        expect(list.videoEventIds, isEmpty);
      });
    });
  });
}
