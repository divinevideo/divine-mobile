// ABOUTME: Integration tests for cache-first query strategy
// ABOUTME: Verifies that cached events are returned instantly before relay queries

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

/// Mock NostrService that tracks event delivery order
class MockNostrServiceWithDelay implements INostrService {
  final StreamController<Event> _eventController =
      StreamController<Event>.broadcast();
  final List<String> _eventDeliveryOrder = []; // Track when events arrive
  bool _isInitialized = true;
  bool _eoseCalled = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  int get connectedRelayCount => 1;

  List<String> get eventDeliveryOrder => List.unmodifiable(_eventDeliveryOrder);
  bool get eoseCalled => _eoseCalled;

  @override
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  }) {
    // Simulate relay delay: call onEose after 100ms
    if (onEose != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _eoseCalled = true;
        onEose();
      });
    }

    return _eventController.stream;
  }

  /// Emit event from "relay" (simulating network delay)
  void emitRelayEvent(Event event) {
    _eventDeliveryOrder.add('relay:${event.id}');
    _eventController.add(event);
  }

  /// Track when cached events are delivered (called by test)
  void trackCachedEvent(String eventId) {
    _eventDeliveryOrder.add('cache:$eventId');
  }

  @override
  Future<void> dispose() async {
    await _eventController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Helper to create valid 64-character hex ID from test string
/// Simply repeats the input string's hex encoding to fill 64 characters
String toHex64(String input) {
  // Convert string to hex
  final hex = input.codeUnits
      .map((c) => c.toRadixString(16).padLeft(2, '0'))
      .join();
  // Repeat to fill 64 chars (or truncate if too long)
  final repeated = (hex * ((64 / hex.length).ceil() + 1)).substring(0, 64);
  return repeated;
}

/// Helper to create test video events
Event createTestVideoEvent({
  required String id,
  required String pubkey,
  required int createdAt,
  List<String>? hashtags,
  String content = 'test video',
}) {
  final tags = <List<String>>[];

  // CRITICAL: Add URL tag so VideoEvent.hasVideo returns true
  // Without this, events will be filtered out by _handleNewVideoEvent() at line 1111
  tags.add(['url', 'https://example.com/test-video-$id.mp4']);

  // Add expiration tag for NIP-40 (1 hour from now)
  tags.add([
    'expiration',
    '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
  ]);

  // Add hashtag tags
  if (hashtags != null) {
    for (final tag in hashtags) {
      tags.add(['t', tag.toLowerCase()]);
    }
  }

  final event = Event(
    toHex64(pubkey), // Convert to valid hex pubkey
    34236, // NIP-71 video event
    tags,
    content,
    createdAt: createdAt,
  );

  // Set id and sig manually for testing
  event.id = toHex64(id); // Convert to valid hex event ID
  event.sig = toHex64('sig_$id'); // Convert to valid hex signature

  return event;
}

void main() {
  group('NostrEventsDao.getVideoEventsByFilter()', () {
    late AppDatabase db;
    late EventRouter eventRouter;
    late String testDbPath;

    setUp(() async {
      final tempDir = Directory.systemTemp.createTempSync(
        'cache_first_dao_test_',
      );
      testDbPath = p.join(tempDir.path, 'test.db');
      db = AppDatabase.test(testDbPath);
      eventRouter = EventRouter(db);
    });

    tearDown(() async {
      await db.close();
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('filters by kinds', () async {
      // Insert events of different kinds
      final video1 = createTestVideoEvent(
        id: 'video1',
        pubkey: 'user1',
        createdAt: 100,
      );
      final video2 = createTestVideoEvent(
        id: 'video2',
        pubkey: 'user1',
        createdAt: 200,
      );

      // Insert a profile event (kind 0)
      final profileEvent = Event(
        toHex64('user1'),
        0,
        [
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        '{"name":"Test User"}',
        createdAt: 50,
      );
      profileEvent.id = toHex64('profile1');
      profileEvent.sig = toHex64('sig_profile1');

      await eventRouter.handleEvent(video1);
      await eventRouter.handleEvent(video2);
      await eventRouter.handleEvent(profileEvent);

      // Query for video events only (kind 34236)
      final results = await db.nostrEventsDao.getVideoEventsByFilter(
        kinds: [34236],
        limit: 100,
      );

      expect(results.length, 2);
      expect(
        results.map((e) => e.id),
        containsAll([toHex64('video1'), toHex64('video2')]),
      );
      expect(results.every((e) => e.kind == 34236), true);
    });

    test('filters by authors', () async {
      final user1Video = createTestVideoEvent(
        id: 'user1_video',
        pubkey: 'user1_pubkey',
        createdAt: 100,
      );
      final user2Video = createTestVideoEvent(
        id: 'user2_video',
        pubkey: 'user2_pubkey',
        createdAt: 200,
      );
      final user3Video = createTestVideoEvent(
        id: 'user3_video',
        pubkey: 'user3_pubkey',
        createdAt: 300,
      );

      await eventRouter.handleEvent(user1Video);
      await eventRouter.handleEvent(user2Video);
      await eventRouter.handleEvent(user3Video);

      // Query for user1 and user2 only
      final results = await db.nostrEventsDao.getVideoEventsByFilter(
        authors: [toHex64('user1_pubkey'), toHex64('user2_pubkey')],
        limit: 100,
      );

      expect(results.length, 2);
      expect(
        results.map((e) => e.id),
        containsAll([toHex64('user1_video'), toHex64('user2_video')]),
      );
      expect(
        results.map((e) => e.pubkey),
        containsAll([toHex64('user1_pubkey'), toHex64('user2_pubkey')]),
      );
    });

    test('filters by hashtags', () async {
      final catVideo = createTestVideoEvent(
        id: 'cat_video',
        pubkey: 'user1',
        createdAt: 100,
        hashtags: ['cats', 'funny'],
      );
      final dogVideo = createTestVideoEvent(
        id: 'dog_video',
        pubkey: 'user1',
        createdAt: 200,
        hashtags: ['dogs', 'cute'],
      );
      final noHashtagVideo = createTestVideoEvent(
        id: 'no_hashtag',
        pubkey: 'user1',
        createdAt: 300,
      );

      await eventRouter.handleEvent(catVideo);
      await eventRouter.handleEvent(dogVideo);
      await eventRouter.handleEvent(noHashtagVideo);

      // Query for #cats hashtag
      final results = await db.nostrEventsDao.getVideoEventsByFilter(
        hashtags: ['cats'],
        limit: 100,
      );

      expect(results.length, 1);
      expect(results.first.id, toHex64('cat_video'));
    });

    test('filters by time range (since/until)', () async {
      final oldVideo = createTestVideoEvent(
        id: 'old_video',
        pubkey: 'user1',
        createdAt: 100,
      );
      final middleVideo = createTestVideoEvent(
        id: 'middle_video',
        pubkey: 'user1',
        createdAt: 500,
      );
      final newVideo = createTestVideoEvent(
        id: 'new_video',
        pubkey: 'user1',
        createdAt: 1000,
      );

      await eventRouter.handleEvent(oldVideo);
      await eventRouter.handleEvent(middleVideo);
      await eventRouter.handleEvent(newVideo);

      // Query for events between 200 and 800
      final results = await db.nostrEventsDao.getVideoEventsByFilter(
        since: 200,
        until: 800,
        limit: 100,
      );

      expect(results.length, 1);
      expect(results.first.id, toHex64('middle_video'));
    });

    test('combines multiple filters', () async {
      // Create events with different combinations
      final matchingEvent = createTestVideoEvent(
        id: 'match',
        pubkey: 'target_user',
        createdAt: 500,
        hashtags: ['target_tag'],
      );
      final wrongAuthor = createTestVideoEvent(
        id: 'wrong_author',
        pubkey: 'other_user',
        createdAt: 500,
        hashtags: ['target_tag'],
      );
      final wrongHashtag = createTestVideoEvent(
        id: 'wrong_hashtag',
        pubkey: 'target_user',
        createdAt: 500,
        hashtags: ['other_tag'],
      );
      final wrongTime = createTestVideoEvent(
        id: 'wrong_time',
        pubkey: 'target_user',
        createdAt: 100,
        hashtags: ['target_tag'],
      );

      await eventRouter.handleEvent(matchingEvent);
      await eventRouter.handleEvent(wrongAuthor);
      await eventRouter.handleEvent(wrongHashtag);
      await eventRouter.handleEvent(wrongTime);

      // Query with ALL filters
      final results = await db.nostrEventsDao.getVideoEventsByFilter(
        authors: [toHex64('target_user')],
        hashtags: ['target_tag'],
        since: 200,
        until: 800,
        limit: 100,
      );

      // Only the fully matching event should be returned
      expect(results.length, 1);
      expect(results.first.id, toHex64('match'));
    });

    test('respects limit parameter', () async {
      // Insert 10 events
      for (int i = 0; i < 10; i++) {
        await eventRouter.handleEvent(
          createTestVideoEvent(
            id: 'video_$i',
            pubkey: 'user1',
            createdAt: i * 100,
          ),
        );
      }

      // Query with limit of 5
      final results = await db.nostrEventsDao.getVideoEventsByFilter(limit: 5);

      expect(results.length, 5);
    });

    test('returns events in descending order by created_at', () async {
      final old = createTestVideoEvent(
        id: 'old',
        pubkey: 'user1',
        createdAt: 100,
      );
      final middle = createTestVideoEvent(
        id: 'middle',
        pubkey: 'user1',
        createdAt: 500,
      );
      final recent = createTestVideoEvent(
        id: 'recent',
        pubkey: 'user1',
        createdAt: 1000,
      );

      // Insert in random order
      await eventRouter.handleEvent(middle);
      await eventRouter.handleEvent(recent);
      await eventRouter.handleEvent(old);

      final results = await db.nostrEventsDao.getVideoEventsByFilter(limit: 10);

      // Should be ordered by created_at DESC (newest first)
      expect(results.length, 3);
      expect(results[0].id, toHex64('recent'));
      expect(results[1].id, toHex64('middle'));
      expect(results[2].id, toHex64('old'));
    });
  });

  group('Cache-First Integration with VideoEventService', () {
    late AppDatabase db;
    late EventRouter eventRouter;
    late MockNostrServiceWithDelay mockNostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late String testDbPath;

    setUp(() async {
      final tempDir = Directory.systemTemp.createTempSync(
        'cache_first_integration_test_',
      );
      testDbPath = p.join(tempDir.path, 'test.db');
      db = AppDatabase.test(testDbPath);
      eventRouter = EventRouter(db);
      mockNostrService = MockNostrServiceWithDelay();
      subscriptionManager = SubscriptionManager(mockNostrService);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        eventRouter: eventRouter,
      );
    });

    tearDown(() async {
      videoEventService.dispose();
      await db.close();
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('cached events are delivered BEFORE relay EOSE', () async {
      // Pre-populate database with cached events
      final cachedEvent1 = createTestVideoEvent(
        id: 'cached1',
        pubkey: 'user1',
        createdAt: 100,
      );
      final cachedEvent2 = createTestVideoEvent(
        id: 'cached2',
        pubkey: 'user1',
        createdAt: 200,
      );

      await eventRouter.handleEvent(cachedEvent1);
      await eventRouter.handleEvent(cachedEvent2);

      // Track when events arrive
      final receivedEvents = <String>[];

      videoEventService.addListener(() {
        final events = videoEventService.getVideos(SubscriptionType.discovery);
        for (final event in events) {
          if (!receivedEvents.contains(event.id)) {
            receivedEvents.add(event.id);
            mockNostrService.trackCachedEvent(event.id);
          }
        }
      });

      // Subscribe to feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 100,
      );

      // Give cached events time to arrive (they should be instant)
      await Future.delayed(const Duration(milliseconds: 50));

      // Cached events should already be available
      expect(receivedEvents.length, 2);
      expect(
        receivedEvents,
        containsAll([toHex64('cached1'), toHex64('cached2')]),
      );

      // But EOSE should NOT have been called yet (100ms delay)
      expect(mockNostrService.eoseCalled, false);

      // Wait for EOSE
      await Future.delayed(const Duration(milliseconds: 100));
      expect(mockNostrService.eoseCalled, true);
    });

    test('relay events merge with cached events without duplicates', () async {
      // Pre-populate with some cached events
      final cachedEvent = createTestVideoEvent(
        id: 'cached_event',
        pubkey: 'user1',
        createdAt: 100,
      );
      await eventRouter.handleEvent(cachedEvent);

      // Subscribe
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 100,
      );

      // Wait for cached events to load
      await Future.delayed(const Duration(milliseconds: 50));

      // Now emit SAME event from relay (should be deduplicated)
      mockNostrService.emitRelayEvent(cachedEvent);

      // Also emit a new event from relay
      final relayOnlyEvent = createTestVideoEvent(
        id: 'relay_only',
        pubkey: 'user1',
        createdAt: 200,
      );
      mockNostrService.emitRelayEvent(relayOnlyEvent);

      // Wait for relay events to process
      await Future.delayed(const Duration(milliseconds: 50));

      final allEvents = videoEventService.getVideos(SubscriptionType.discovery);

      // Should have both events but NO duplicates
      expect(allEvents.length, 2);
      expect(
        allEvents.map((e) => e.id),
        containsAll([toHex64('cached_event'), toHex64('relay_only')]),
      );

      // Verify no duplicate IDs
      final ids = allEvents.map((e) => e.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'Should have no duplicate event IDs',
      );
    });

    test('cache-first works with author filter', () async {
      // Pre-populate with events from different authors
      final user1Event = createTestVideoEvent(
        id: 'user1_video',
        pubkey: 'user1_pubkey',
        createdAt: 100,
      );
      final user2Event = createTestVideoEvent(
        id: 'user2_video',
        pubkey: 'user2_pubkey',
        createdAt: 200,
      );

      await eventRouter.handleEvent(user1Event);
      await eventRouter.handleEvent(user2Event);

      // Subscribe with author filter for user1 only
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
        authors: [toHex64('user1_pubkey')],
        limit: 100,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final events = videoEventService.getVideos(SubscriptionType.homeFeed);

      // Should only get user1's cached event
      expect(events.length, 1);
      expect(events.first.pubkey, toHex64('user1_pubkey'));
    });

    test('cache-first works with hashtag filter', () async {
      // Pre-populate with events with different hashtags
      final catVideo = createTestVideoEvent(
        id: 'cat_video',
        pubkey: 'user1',
        createdAt: 100,
        hashtags: ['cats'],
      );
      final dogVideo = createTestVideoEvent(
        id: 'dog_video',
        pubkey: 'user1',
        createdAt: 200,
        hashtags: ['dogs'],
      );

      await eventRouter.handleEvent(catVideo);
      await eventRouter.handleEvent(dogVideo);

      // Subscribe with hashtag filter
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.hashtag,
        hashtags: ['cats'],
        limit: 100,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      final events = videoEventService.getVideos(SubscriptionType.hashtag);

      // Should only get cat video
      expect(events.length, 1);
      expect(events.first.id, toHex64('cat_video'));
    });

    test('empty cache does not break relay subscription', () async {
      // Subscribe to feed with empty cache
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 100,
      );

      // Should have zero cached events
      await Future.delayed(const Duration(milliseconds: 50));
      expect(videoEventService.getVideos(SubscriptionType.discovery).length, 0);

      // Now emit relay event
      final relayEvent = createTestVideoEvent(
        id: 'relay_event',
        pubkey: 'user1',
        createdAt: 100,
      );
      mockNostrService.emitRelayEvent(relayEvent);

      await Future.delayed(const Duration(milliseconds: 50));

      // Relay event should be received normally
      final events = videoEventService.getVideos(SubscriptionType.discovery);
      expect(events.length, 1);
      expect(events.first.id, toHex64('relay_event'));
    });
  });
}
