// ABOUTME: Unit tests for CuratedListService query operations
// ABOUTME: Tests searching, filtering, and retrieving lists

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curated_list_service_query_test.mocks.dart';

@GenerateMocks([INostrService, AuthService])
void main() {
  group('CuratedListService - Query Operations', () {
    late CuratedListService service;
    late MockINostrService mockNostr;
    late MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUp(() async {
      // CRITICAL: Reset SharedPreferences mock completely for each test
      SharedPreferences.setMockInitialValues({});

      mockNostr = MockINostrService();
      mockAuth = MockAuthService();
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

      // Create fresh service instance after clearing prefs
      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    group('searchLists()', () {
      test('finds lists by name', () async {
        // FIXME: Test isolation issue - passes individually, fails in batch
        await service.createList(name: 'Cooking Videos', isPublic: true);
        await service.createList(name: 'Travel Adventures', isPublic: true);
        await service.createList(name: 'Cooking Recipes', isPublic: true);

        final results = service.searchLists('cooking');

        expect(results.length, 2);
        expect(results.map((l) => l.name), contains('Cooking Videos'));
        expect(results.map((l) => l.name), contains('Cooking Recipes'));
      });

      test('finds lists by description', () async {
        await service.createList(
          name: 'Random List',
          description: 'Videos about cooking',
          isPublic: true,
        );
        await service.createList(
          name: 'Another List',
          description: 'Travel videos',
          isPublic: true,
        );

        final results = service.searchLists('cooking');

        expect(results.length, 1);
        expect(results.first.name, 'Random List');
      });

      test('finds lists by tags', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tech', 'tutorial'],
          isPublic: true,
        );
        await service.createList(
          name: 'List 2',
          tags: ['cooking', 'food'],
          isPublic: true,
        );

        final results = service.searchLists('tech');

        expect(results.length, 1);
        expect(results.first.name, 'List 1');
      });

      test('is case-insensitive', () async {
        await service.createList(name: 'Cooking Videos', isPublic: true);

        final results1 = service.searchLists('COOKING');
        final results2 = service.searchLists('cooking');
        final results3 = service.searchLists('CoOkInG');

        expect(results1.length, 1);
        expect(results2.length, 1);
        expect(results3.length, 1);
      });

      test('returns empty list for no matches', () async {
        await service.createList(name: 'Cooking Videos', isPublic: true);
        await service.createList(name: 'Travel Adventures', isPublic: true);

        final results = service.searchLists('programming');

        expect(results, isEmpty);
      });

      test('returns empty list for empty query', () async {
        await service.createList(name: 'Test List', isPublic: true);

        final results = service.searchLists('');

        expect(results, isEmpty);
      });

      test('returns empty list for whitespace-only query', () async {
        await service.createList(name: 'Test List', isPublic: true);

        final results = service.searchLists('   ');

        expect(results, isEmpty);
      });

      test('only returns public lists', () async {
        await service.createList(name: 'Public Cooking', isPublic: true);
        await service.createList(name: 'Private Cooking', isPublic: false);

        final results = service.searchLists('cooking');

        expect(results.length, 1);
        expect(results.first.name, 'Public Cooking');
      });

      test('searches across multiple fields', () async {
        await service.createList(
          name: 'Tech Videos',
          description: 'Programming tutorials',
          tags: ['coding'],
          isPublic: true,
        );

        final byName = service.searchLists('tech');
        final byDescription = service.searchLists('programming');
        final byTag = service.searchLists('coding');

        expect(byName.length, 1);
        expect(byDescription.length, 1);
        expect(byTag.length, 1);
      });
    });

    group('getListsByTag()', () {
      test('returns lists with specific tag', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tech', 'tutorial'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(
          name: 'List 2',
          tags: ['cooking', 'food'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(
          name: 'List 3',
          tags: ['tech', 'news'],
          isPublic: true,
        );

        final results = service.getListsByTag('tech');

        expect(results.length, greaterThanOrEqualTo(2));
        expect(results.map((l) => l.name), containsAll(['List 1', 'List 3']));
      });

      test('is case-insensitive', () async {
        await service.createList(
          name: 'Test List',
          tags: ['tech'], // Tags stored lowercase
          isPublic: true,
        );

        final results1 = service.getListsByTag('tech');
        final results2 = service.getListsByTag('TECH');
        final results3 = service.getListsByTag('TeCh');

        expect(results1.length, 1);
        expect(results2.length, 1);
        expect(results3.length, 1);
      });

      test('returns empty list for non-existent tag', () async {
        await service.createList(
          name: 'Test List',
          tags: ['tech'],
          isPublic: true,
        );

        final results = service.getListsByTag('cooking');

        expect(results, isEmpty);
      });

      test('only returns public lists', () async {
        await service.createList(
          name: 'Public List',
          tags: ['tech'],
          isPublic: true,
        );
        await service.createList(
          name: 'Private List',
          tags: ['tech'],
          isPublic: false,
        );

        final results = service.getListsByTag('tech');

        expect(results.length, 1);
        expect(results.first.name, 'Public List');
      });
    });

    group('getAllTags()', () {
      test('returns all unique tags across lists', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tech', 'tutorial'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(
          name: 'List 2',
          tags: ['cooking', 'food'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(
          name: 'List 3',
          tags: ['tech', 'news'],
          isPublic: true,
        );

        final tags = service.getAllTags();

        expect(tags.length, greaterThanOrEqualTo(5));
        expect(
          tags,
          containsAll(['tech', 'tutorial', 'cooking', 'food', 'news']),
        );
      });

      test('removes duplicates', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tech', 'tutorial'],
          isPublic: true,
        );
        await service.createList(
          name: 'List 2',
          tags: ['tech', 'news'],
          isPublic: true,
        );

        final tags = service.getAllTags();

        expect(tags.where((t) => t == 'tech').length, 1);
      });

      test('returns sorted list', () async {
        await service.createList(
          name: 'List 1',
          tags: ['zebra', 'alpha', 'middle'],
          isPublic: true,
        );

        final tags = service.getAllTags();

        expect(tags, ['alpha', 'middle', 'zebra']);
      });

      test('only includes tags from public lists', () async {
        await service.createList(
          name: 'Public List',
          tags: ['public_tag'],
          isPublic: true,
        );
        await service.createList(
          name: 'Private List',
          tags: ['private_tag'],
          isPublic: false,
        );

        final tags = service.getAllTags();

        expect(tags, ['public_tag']);
        expect(tags, isNot(contains('private_tag')));
      });

      test('returns empty list when no tags', () async {
        await service.createList(name: 'Test List', isPublic: true);

        final tags = service.getAllTags();

        expect(tags, isEmpty);
      });

      test('handles lists with no tags', () async {
        await service.createList(
          name: 'List 1',
          tags: ['tag1'],
          isPublic: true,
        );
        await Future.delayed(const Duration(milliseconds: 5));
        await service.createList(name: 'List 2', tags: [], isPublic: true);

        final tags = service.getAllTags();

        // Should have tag1 from List 1
        expect(tags.length, greaterThan(0));
        expect(tags, contains('tag1'));
      });
    });

    group('fetchPublicListsContainingVideo()', () {
      test('queries Nostr for lists containing specific video', () async {
        // Setup: Create mock kind 30005 events containing the target video
        final targetVideoId = 'target_video_event_id_123456789abcdef';
        final mockListEvent = Event.fromJson({
          'id': 'list_event_id_1',
          'pubkey': 'other_user_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'test-list-1'],
            ['title', 'Nature Videos'],
            ['description', 'Beautiful nature content'],
            ['e', targetVideoId],
            ['e', 'other_video_id_123'],
          ],
          'content': '',
          'sig': 'test_sig',
        });

        // Setup mock to return list events when queried with #e filter
        when(
          mockNostr.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).thenAnswer((_) => Stream.fromIterable([mockListEvent]));

        // Act
        final lists = await service.fetchPublicListsContainingVideo(
          targetVideoId,
        );

        // Assert: Verify filter includes the video ID
        final captured = verify(
          mockNostr.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;
        final filters = captured[0] as List<Filter>;
        expect(filters[0].kinds, contains(30005));
        expect(filters[0].e, contains(targetVideoId));

        // Assert: Results parsed correctly
        expect(lists.length, 1);
        expect(lists.first.name, 'Nature Videos');
        expect(lists.first.videoEventIds, contains(targetVideoId));
      });

      test('returns empty list when no public lists contain video', () async {
        final targetVideoId = 'orphan_video_id_123456789abcdef';

        // Setup mock to return empty stream
        when(
          mockNostr.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).thenAnswer((_) => Stream.empty());

        // Act
        final lists = await service.fetchPublicListsContainingVideo(
          targetVideoId,
        );

        // Assert
        expect(lists, isEmpty);
      });

      test('returns stream for progressive loading', () async {
        final targetVideoId = 'target_video_123456789abcdef';
        final mockListEvent1 = Event.fromJson({
          'id': 'list_1',
          'pubkey': 'user1_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'list-1'],
            ['title', 'First List'],
            ['e', targetVideoId],
          ],
          'content': '',
          'sig': 'sig1',
        });
        final mockListEvent2 = Event.fromJson({
          'id': 'list_2',
          'pubkey': 'user2_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'list-2'],
            ['title', 'Second List'],
            ['e', targetVideoId],
          ],
          'content': '',
          'sig': 'sig2',
        });

        // Setup mock to return events progressively
        when(
          mockNostr.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([mockListEvent1, mockListEvent2]),
        );

        // Act: Use the stream version
        final listStream = service.streamPublicListsContainingVideo(
          targetVideoId,
        );
        final lists = await listStream.toList();

        // Assert: Both lists received
        expect(lists.length, 2);
        expect(
          lists.map((l) => l.name),
          containsAll(['First List', 'Second List']),
        );
      });
    });

    group('Query Operations - Edge Cases', () {
      test('search handles special characters', () async {
        await service.createList(name: 'C++ Programming', isPublic: true);
        await service.createList(name: 'C# Development', isPublic: true);

        final results1 = service.searchLists('c++');
        final results2 = service.searchLists('c#');

        expect(results1.first.name, 'C++ Programming');
        expect(results2.first.name, 'C# Development');
      });

      test('search handles unicode characters', () async {
        await service.createList(name: 'Español Videos', isPublic: true);
        await service.createList(name: '日本語 Content', isPublic: true);

        final results1 = service.searchLists('español');
        final results2 = service.searchLists('日本語');

        expect(results1.first.name, 'Español Videos');
        expect(results2.first.name, '日本語 Content');
      });

      test('search with partial match', () async {
        await service.createList(name: 'Programming Tutorials', isPublic: true);

        final results = service.searchLists('program');

        expect(results.length, 1);
        expect(results.first.name, 'Programming Tutorials');
      });

      test('getListsByTag with tag that has spaces', () async {
        await service.createList(
          name: 'Test List',
          tags: ['with spaces'],
          isPublic: true,
        );

        final results = service.getListsByTag('with spaces');

        expect(results.length, 1);
      });

      test('getAllTags handles empty string tags', () async {
        await service.createList(
          name: 'Test List',
          tags: ['valid', '', 'another'],
          isPublic: true,
        );

        final tags = service.getAllTags();

        expect(tags.contains(''), isTrue); // Service doesn't filter empty tags
      });

      test('search performance with many lists', () async {
        // FIXME: Test isolation issue - passes individually, fails in batch
        // Create 50 lists
        for (var i = 0; i < 50; i++) {
          await service.createList(
            name: 'List $i',
            description: i % 2 == 0 ? 'even number' : 'odd number',
            tags: ['tag$i'],
            isPublic: true,
          );
        }

        final stopwatch = Stopwatch()..start();
        final results = service.searchLists('even');
        stopwatch.stop();

        expect(
          results.length,
          greaterThanOrEqualTo(25),
        ); // Should find at least 25
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      });
    });
  });
}
