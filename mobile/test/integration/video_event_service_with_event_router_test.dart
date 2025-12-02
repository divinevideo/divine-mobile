// ABOUTME: Integration tests for VideoEventService + EventRouter ensuring all events are cached
// ABOUTME: Verifies that events from subscriptions are automatically routed to database

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:path/path.dart' as p;

/// Mock NostrService that emits test events
class MockNostrService implements INostrService {
  final StreamController<Event> _eventController =
      StreamController<Event>.broadcast();
  final List<Filter> _subscriptionFilters = [];
  bool _isInitialized = true;

  @override
  bool get isInitialized => _isInitialized;

  @override
  int get connectedRelayCount => 1; // Pretend we have 1 relay connected

  @override
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  }) {
    _subscriptionFilters.addAll(filters);

    // Call onEose immediately for testing
    if (onEose != null) {
      Future.microtask(() => onEose());
    }

    return _eventController.stream;
  }

  /// Emit a test event to all subscribers
  void emitEvent(Event event) {
    _eventController.add(event);
  }

  /// Get the filters used in subscriptions (for verification)
  List<Filter> get subscriptionFilters =>
      List.unmodifiable(_subscriptionFilters);

  @override
  Future<void> dispose() async {
    await _eventController.close();
  }

  // Stub methods (not used in these tests)
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('VideoEventService + EventRouter Integration', () {
    late AppDatabase db;
    late EventRouter eventRouter;
    late MockNostrService mockNostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late String testDbPath;

    setUp(() async {
      // Create temporary database for testing
      final tempDir = Directory.systemTemp.createTempSync(
        'openvine_integration_test_',
      );
      testDbPath = p.join(tempDir.path, 'test.db');
      db = AppDatabase.test(testDbPath);

      // Create EventRouter
      eventRouter = EventRouter(db);

      // Create mock NostrService
      mockNostrService = MockNostrService();

      // Create SubscriptionManager
      subscriptionManager = SubscriptionManager(mockNostrService);

      // Create VideoEventService with EventRouter
      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        eventRouter: eventRouter, // NEW: Pass EventRouter to VideoEventService
      );
    });

    tearDown(() async {
      videoEventService.dispose();
      await db.close();

      // Clean up test database
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('Video events (kind 34236) are cached to NostrEvents table', () async {
      // Create test video event
      final videoEvent = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['title', 'Test Video'],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      videoEvent.id =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      videoEvent.sig =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Emit event via mock NostrService
      mockNostrService.emitEvent(videoEvent);

      // Wait for event processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify event was cached to database via EventRouter
      final cachedEvent = await db.nostrEventsDao.getEvent(
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.kind, equals(34236));
      expect(
        cachedEvent.pubkey,
        equals(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );
    });

    test(
      'Profile events (kind 0) are cached to both NostrEvents and UserProfiles tables',
      () async {
        // Create test profile event
        final profileEvent = Event(
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          0,
          [],
          '{"name":"testuser","display_name":"Test User","about":"Test bio","picture":"https://example.com/avatar.jpg"}',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        profileEvent.id =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        profileEvent.sig =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

        // Subscribe to discovery feed
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );

        // Emit profile event via mock NostrService
        mockNostrService.emitEvent(profileEvent);

        // Wait for event processing
        await Future.delayed(Duration(milliseconds: 100));

        // Verify event was cached to NostrEvents table
        final cachedEvent = await db.nostrEventsDao.getEvent(
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        );
        expect(cachedEvent, isNotNull);
        expect(cachedEvent!.kind, equals(0));

        // Verify profile was extracted to UserProfiles table
        final cachedProfile = await db.userProfilesDao.getProfile(
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        );
        expect(cachedProfile, isNotNull);
        expect(cachedProfile!.name, equals('testuser'));
        expect(cachedProfile.displayName, equals('Test User'));
        expect(cachedProfile.about, equals('Test bio'));
        expect(cachedProfile.picture, equals('https://example.com/avatar.jpg'));
      },
    );

    test('Contact events (kind 3) are cached to NostrEvents table', () async {
      // Create test contacts event
      final contactsEvent = Event(
        '1111111111111111111111111111111111111111111111111111111111111111',
        3,
        [
          [
            'p',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ],
          [
            'p',
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          ],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      contactsEvent.id =
          '2222222222222222222222222222222222222222222222222222222222222222';
      contactsEvent.sig =
          '3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333';

      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Emit contacts event via mock NostrService
      mockNostrService.emitEvent(contactsEvent);

      // Wait for event processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify event was cached to database
      final cachedEvent = await db.nostrEventsDao.getEvent(
        '2222222222222222222222222222222222222222222222222222222222222222',
      );
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.kind, equals(3));
      expect(cachedEvent.tags.length, equals(2));
    });

    test('Reaction events (kind 7) are cached to NostrEvents table', () async {
      // Create test reaction event
      final reactionEvent = Event(
        '4444444444444444444444444444444444444444444444444444444444444444',
        7,
        [
          [
            'e',
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          ], // Event being reacted to
        ],
        '+',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reactionEvent.id =
          '5555555555555555555555555555555555555555555555555555555555555555';
      reactionEvent.sig =
          '6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666';

      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Emit reaction event via mock NostrService
      mockNostrService.emitEvent(reactionEvent);

      // Wait for event processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify event was cached to database
      final cachedEvent = await db.nostrEventsDao.getEvent(
        '5555555555555555555555555555555555555555555555555555555555555555',
      );
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.kind, equals(7));
      expect(cachedEvent.content, equals('+'));
    });

    test('Unknown event kinds are cached to NostrEvents table', () async {
      // Create test event with unknown kind
      final unknownEvent = Event(
        '7777777777777777777777777777777777777777777777777777777777777777',
        12345, // Unknown kind
        [],
        'Unknown kind content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      unknownEvent.id =
          '8888888888888888888888888888888888888888888888888888888888888888';
      unknownEvent.sig =
          '9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999';

      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Emit unknown event via mock NostrService
      mockNostrService.emitEvent(unknownEvent);

      // Wait for event processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify event was cached to database
      final cachedEvent = await db.nostrEventsDao.getEvent(
        '8888888888888888888888888888888888888888888888888888888888888888',
      );
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.kind, equals(12345));
      expect(cachedEvent.content, equals('Unknown kind content'));
    });

    test('Multiple events from same subscription are all cached', () async {
      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Create and emit multiple test events
      final events = <Event>[];
      for (int i = 0; i < 5; i++) {
        final event = Event(
          'abababababababababababababababababababababababababababababababab',
          34236,
          [
            ['url', 'https://example.com/video$i.mp4'],
            ['title', 'Test Video $i'],
          ],
          'Test video content $i',
          createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + i,
        );
        event.id =
            'event${i}00000000000000000000000000000000000000000000000000000000000';
        event.sig =
            'signature${i}000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';
        events.add(event);

        mockNostrService.emitEvent(event);
      }

      // Wait for all events to process
      await Future.delayed(Duration(milliseconds: 200));

      // Verify all events were cached
      for (int i = 0; i < 5; i++) {
        final cachedEvent = await db.nostrEventsDao.getEvent(
          'event${i}00000000000000000000000000000000000000000000000000000000000',
        );
        expect(cachedEvent, isNotNull, reason: 'Event $i should be cached');
        expect(cachedEvent!.kind, equals(34236));
      }
    });
  });
}
