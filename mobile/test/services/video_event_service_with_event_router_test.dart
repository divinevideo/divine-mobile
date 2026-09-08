// ABOUTME: Integration tests for VideoEventService + EventRouter ensuring all events are cached
// ABOUTME: Verifies that events from subscriptions are automatically routed to database
import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:path/path.dart' as p;

/// Mock NostrService that emits test events
class MockNostrService implements NostrClient {
  final StreamController<Event> _eventController =
      StreamController<Event>.broadcast();
  final List<Filter> _subscriptionFilters = [];
  final bool _isInitialized = true;

  @override
  bool get isInitialized => _isInitialized;

  @override
  int get connectedRelayCount => 1; // Pretend we have 1 relay connected

  @override
  Stream<Event> subscribe(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = const [],
    bool sendAfterAuth = false,
    void Function()? onEose,
    bool closeOnEose = false,
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
      db = AppDatabase.test(NativeDatabase(File(testDbPath)));

      // Create EventRouter (autoStart off so tests drain deterministically)
      eventRouter = EventRouter(
        db,
        config: const EventRouterConfig(autoStart: false),
      );

      // Create mock NostrService
      mockNostrService = MockNostrService();

      // Create SubscriptionManager
      subscriptionManager = SubscriptionManager(mockNostrService);

      // Create VideoEventService with EventRouter
      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        crashReporter: const SilentCrashReporter(),
        eventRouter: eventRouter, // NEW: Pass EventRouter to VideoEventService
      );
    });

    tearDown(() async {
      videoEventService.dispose();
      await db.close();

      // Clean up test database
      final file = File(testDbPath);
      if (file.existsSync()) {
        await file.delete();
      }
    });

    /// Flushes the mock event stream into the router, then drains it
    /// deterministically. Replaces wall-clock waits: [pumpEventQueue] lets the
    /// broadcast-stream listener forward the emitted event into the router's
    /// queue, then [EventRouter.drainForTesting] persists it.
    Future<void> settle() async {
      await pumpEventQueue();
      await eventRouter.drainForTesting();
    }

    test('exposes the injected EventRouter via eventRouter getter', () {
      expect(videoEventService.eventRouter, same(eventRouter));
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
      videoEvent.sig = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Emit event via mock NostrService
      mockNostrService.emitEvent(videoEvent);

      await settle();

      // Verify event was cached to database via EventRouter
      final cachedEvent = await db.nostrEventsDao.getEventById(
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
        profileEvent.sig = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

        // Subscribe to discovery feed
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );

        // Emit profile event via mock NostrService
        mockNostrService.emitEvent(profileEvent);

        await settle();

        // Verify event was cached to NostrEvents table
        final cachedEvent = await db.nostrEventsDao.getEventById(
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
      contactsEvent.sig = '3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333';

      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Emit contacts event via mock NostrService
      mockNostrService.emitEvent(contactsEvent);

      await settle();

      // Verify event was cached to database
      final cachedEvent = await db.nostrEventsDao.getEventById(
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
      reactionEvent.sig = '6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666';

      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Emit reaction event via mock NostrService
      mockNostrService.emitEvent(reactionEvent);

      await settle();

      // Verify event was cached to database
      final cachedEvent = await db.nostrEventsDao.getEventById(
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
      unknownEvent.sig = '9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999';

      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Emit unknown event via mock NostrService
      mockNostrService.emitEvent(unknownEvent);

      await settle();

      // Verify event was cached to database
      final cachedEvent = await db.nostrEventsDao.getEventById(
        '8888888888888888888888888888888888888888888888888888888888888888',
      );
      expect(cachedEvent, isNotNull);
      expect(cachedEvent!.kind, equals(12345));
      expect(cachedEvent.content, equals('Unknown kind content'));
    });

    test('caches every event from one subscription (distinct authors)', () async {
      // Subscribe to discovery feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Distinct pubkeys: one feed subscription carries videos from many
      // authors, so each event is a distinct addressable coordinate and none
      // supersede each other. (The original fixture reused a single pubkey with
      // no d-tag, collapsing all 5 to one coordinate so only the newest
      // survived the addressable upsert.)
      final events = <Event>[];
      for (var i = 0; i < 5; i++) {
        final event = Event(
          '${i + 1}'.padLeft(64, '0'),
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

      await settle();

      for (final event in events) {
        final cachedEvent = await db.nostrEventsDao.getEventById(event.id);
        expect(cachedEvent, isNotNull, reason: '${event.id} should be cached');
        expect(cachedEvent!.kind, equals(34236));
      }
    });
  });
}
