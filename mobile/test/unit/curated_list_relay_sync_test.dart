// ABOUTME: Unit tests for CuratedListService relay sync functionality
// ABOUTME: Tests the relay sync implementation without requiring real relay connections

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

import 'curated_list_relay_sync_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<INostrService>(),
  MockSpec<AuthService>(),
])
void main() {
  group('CuratedListService Relay Sync Tests', () {
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;
    late SharedPreferences prefs;
    late CuratedListService curatedListService;

    setUp(() async {
      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();

      // Set up SharedPreferences with empty state for each test
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      curatedListService = CuratedListService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
      );
    });

    tearDown(() {
      // Clean up service state between tests
      // Note: CuratedListService doesn't have a dispose method
      reset(mockNostrService);
      reset(mockAuthService);
    });

    test('should handle unauthenticated state gracefully in relay sync',
        () async {
      // Setup: User is not authenticated
      when(mockAuthService.isAuthenticated).thenReturn(false);

      // Test: fetchUserListsFromRelays should return early
      await curatedListService.fetchUserListsFromRelays();

      // Verify: No relay calls should be made
      verifyNever(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')));

      // Verify: Service should handle this gracefully
      expect(curatedListService.lists.length, 0);
    });

    test('should create subscription for Kind 30005 events when authenticated',
        () async {
      // Setup: User is authenticated
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef');

      // Mock subscription stream
      final streamController = StreamController<Event>();
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => streamController.stream);

      // Test: fetchUserListsFromRelays should create subscription
      final future = curatedListService.fetchUserListsFromRelays();

      // Close stream to complete the subscription
      streamController.close();
      await future;

      // Verify: Subscription was created with correct filter
      final captured = verify(mockNostrService.subscribeToEvents(
              filters: captureAnyNamed('filters')))
          .captured;
      expect(captured.length, 1);

      final filters = captured[0] as List<Filter>;
      expect(filters.length, 1);
      expect(
          filters[0].authors,
          contains(
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'));
      expect(filters[0].kinds, contains(30005));
    });

    test('should process received Kind 30005 events correctly', () async {
      // Setup: User is authenticated
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef');

      // Create mock event
      final mockEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        30005,
        [
          ['d', 'test_list_id'],
          ['title', 'My Test List'],
          ['description', 'A test list'],
          ['t', 'test'],
          ['t', 'demo'],
          ['e', 'video1'],
          ['e', 'video2'],
          ['client', 'diVine'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Test curated list',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Mock subscription stream that emits our test event
      final streamController = StreamController<Event>();
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => streamController.stream);

      // Start the sync
      final future = curatedListService.fetchUserListsFromRelays();

      // Emit the test event
      streamController.add(mockEvent);

      // Close stream to complete
      streamController.close();
      await future;

      // Verify: List was created from the event
      final lists = curatedListService.lists;
      expect(lists.length, 1);

      final list = lists.first;
      expect(list.id, 'test_list_id');
      expect(list.name, 'My Test List');
      expect(list.description, 'A test list');
      expect(list.tags, contains('test'));
      expect(list.tags, contains('demo'));
      expect(list.videoEventIds, contains('video1'));
      expect(list.videoEventIds, contains('video2'));
      expect(list.nostrEventId, mockEvent.id);
    });

    test('should handle replaceable events correctly (keep latest)', () async {
      // Setup: User is authenticated
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef');

      // Create two events with same 'd' tag but different timestamps
      final olderEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        30005,
        [
          ['d', 'same_list_id'],
          ['title', 'Old Title'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Older version',
        createdAt: 1000, // older timestamp
      );

      final newerEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        30005,
        [
          ['d', 'same_list_id'],
          ['title', 'New Title'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Newer version',
        createdAt: 2000, // newer timestamp
      );

      // Mock subscription stream
      final streamController = StreamController<Event>();
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => streamController.stream);

      // Start the sync
      final future = curatedListService.fetchUserListsFromRelays();

      // Emit both events (older first, then newer)
      streamController.add(olderEvent);
      streamController.add(newerEvent);

      // Close stream to complete
      streamController.close();
      await future;

      // Verify: Only one list exists with the newer version
      final lists = curatedListService.lists;
      expect(lists.length, 1);

      final list = lists.first;
      expect(list.id, 'same_list_id');
      expect(list.name, 'New Title');
      expect(list.nostrEventId, newerEvent.id);
    });

    test('should not sync more than once per session', () async {
      // Setup: User is authenticated
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef');

      // Mock subscription stream
      final streamController = StreamController<Event>();
      when(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .thenAnswer((_) => streamController.stream);

      // First sync
      final future1 = curatedListService.fetchUserListsFromRelays();
      streamController.close();
      await future1;

      // Second sync should return early
      await curatedListService.fetchUserListsFromRelays();

      // Verify: Subscription was only created once
      verify(mockNostrService.subscribeToEvents(filters: anyNamed('filters')))
          .called(1);
    });
  });

  group('CuratedListService Relay Sync Isolation Tests', () {
    test('should update existing local list if relay version is newer',
        () async {
      // Create fresh service instance to avoid sync state conflicts
      final freshMockNostrService = MockINostrService();
      final freshMockAuthService = MockAuthService();
      // Use completely clean prefs to ensure no shared state
      SharedPreferences.setMockInitialValues({'_test_isolation_key_': 'fresh'});
      final freshPrefs = await SharedPreferences.getInstance();
      final freshService = CuratedListService(
        nostrService: freshMockNostrService,
        authService: freshMockAuthService,
        prefs: freshPrefs,
      );

      // Setup: User is authenticated and has an existing local list
      when(freshMockAuthService.isAuthenticated).thenReturn(true);
      when(freshMockAuthService.currentPublicKeyHex).thenReturn(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef');

      // Create local list without initializing (to avoid initial relay sync)
      final createdList = await freshService.createList(
        name: 'Local List',
        description: 'Local description',
        isPublic: false,
      );

      // Get the actual ID from the created list
      final actualListId = createdList!.id;

      // Get current timestamp and make relay event newer
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final futureTimestamp =
          currentTimestamp + 1000; // 1000 seconds in the future

      // Create newer relay event using the actual list ID
      final relayEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        30005,
        [
          [
            'd',
            actualListId
          ], // Use the actual list ID instead of hardcoded 'test_list_id'
          ['title', 'Relay List'],
          ['description', 'Relay description'],
          ['expiration', '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}'],
        ],
        'Relay version',
        createdAt: futureTimestamp, // Ensure this is newer than the local list
      );

      // Mock subscription
      final streamController = StreamController<Event>();
      when(freshMockNostrService.subscribeToEvents(
              filters: anyNamed('filters')))
          .thenAnswer((_) => streamController.stream);

      // Sync from relay
      final future = freshService.fetchUserListsFromRelays();
      streamController.add(relayEvent);
      streamController.close();
      await future;

      // Verify: Local list was updated with relay version
      final syncedList = freshService.getListById(actualListId);
      expect(syncedList, isNotNull);
      expect(syncedList!.name, 'Relay List');
      expect(syncedList.description, 'Relay description');
      expect(syncedList.nostrEventId, relayEvent.id);
    });
  });
}
