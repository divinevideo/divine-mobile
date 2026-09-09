// ABOUTME: Unit tests for CuratedListService initialization performance
// ABOUTME: Verifies that initialization completes quickly without blocking
// on relay sync

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('CuratedListService - Initialization Performance', () {
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
    });

    test(
      'initialize() completes quickly without waiting for relay sync',
      () async {
        // Set up a SLOW relay response (simulates 7+ second timeout)
        final slowRelayCompleter = Completer<void>();
        when(
          () => mockNostr.subscribe(any(), onEose: any(named: 'onEose')),
        ).thenAnswer((_) {
          // This stream never completes quickly - simulates slow relay
          return Stream.fromFuture(
            slowRelayCompleter.future.then((_) => null),
          ).where((_) => false).cast<Event>();
        });

        // Pre-populate with cached lists so we have data
        final cachedList = CuratedList(
          id: 'cached_list_id',
          name: 'Cached List',
          videoEventIds: const ['video1', 'video2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([cachedList.toJson()]),
        );

        // Also pre-populate subscribed list IDs
        await prefs.setString(
          CuratedListService.subscribedListsStorageKey,
          '["cached_list_id"]',
        );

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        // Verify local cache was loaded in constructor
        expect(service.lists.length, greaterThan(0));
        expect(service.lists.any((l) => l.name == 'Cached List'), isTrue);

        // Call initialize() and measure time
        final stopwatch = Stopwatch()..start();
        await service.initialize();
        stopwatch.stop();

        // CRITICAL: initialize() should complete in < 100ms, not 7+
        // seconds. The relay sync should happen in background, not
        // block initialization
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason:
              'initialize() should complete quickly without '
              'waiting for relay sync',
        );

        // isInitialized should be true IMMEDIATELY after initialize()
        // returns
        expect(service.isInitialized, isTrue);

        // Clean up - complete the slow relay so test can finish
        slowRelayCompleter.complete();
      },
    );

    test('notifies listeners immediately after initialization', () async {
      // Set up slow relay
      when(
        () => mockNostr.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) => const Stream.empty());

      final service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );

      var notificationCount = 0;
      service.addListener(() {
        notificationCount++;
      });

      await service.initialize();

      // Should have notified at least once when becoming initialized
      expect(notificationCount, greaterThan(0));
      expect(service.isInitialized, isTrue);
    });

    test(
      'local cached lists are available before relay sync completes',
      () async {
        // Set up relay that never responds
        final neverCompletes = Completer<void>();
        when(
          () => mockNostr.subscribe(any(), onEose: any(named: 'onEose')),
        ).thenAnswer((_) {
          return Stream.fromFuture(
            neverCompletes.future.then((_) => null),
          ).where((_) => false).cast<Event>();
        });

        // Pre-populate cache
        final cachedList = CuratedList(
          id: 'local_list',
          name: 'Local Cached List',
          videoEventIds: const ['v1', 'v2', 'v3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([cachedList.toJson()]),
        );

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.initialize();

        // Local lists should be available even though relay hasn't
        // responded
        expect(service.isInitialized, isTrue);
        expect(service.lists.any((l) => l.name == 'Local Cached List'), isTrue);
        expect(
          service.getListById('local_list')?.videoEventIds.length,
          equals(3),
        );

        // Clean up
        neverCompletes.complete();
      },
    );

    test(
      'subscribed lists are accessible immediately after initialization',
      () async {
        // Set up slow relay
        final slowRelay = Completer<void>();
        when(
          () => mockNostr.subscribe(any(), onEose: any(named: 'onEose')),
        ).thenAnswer((_) {
          return Stream.fromFuture(
            slowRelay.future.then((_) => null),
          ).where((_) => false).cast<Event>();
        });

        // Pre-populate with list and subscription
        final subscribedList = CuratedList(
          id: 'subscribed_list',
          name: 'My Subscribed List',
          videoEventIds: const ['video_a', 'video_b'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([subscribedList.toJson()]),
        );
        await prefs.setString(
          CuratedListService.subscribedListsStorageKey,
          '["subscribed_list"]',
        );

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.initialize();

        // Subscribed lists should be available immediately
        expect(service.isInitialized, isTrue);
        expect(service.subscribedLists.length, equals(1));
        expect(
          service.subscribedLists.first.name,
          equals('My Subscribed List'),
        );
        expect(service.isSubscribedToList('subscribed_list'), isTrue);

        slowRelay.complete();
      },
    );

    test(
      'relay sync updates lists in background after initialization',
      () async {
        // Set up relay that responds after a delay with new data
        final relayResponseCompleter = Completer<Event>();

        when(
          () => mockNostr.subscribe(any(), onEose: any(named: 'onEose')),
        ).thenAnswer((invocation) {
          // Return a stream that will emit an event after delay
          return Stream.fromFuture(relayResponseCompleter.future);
        });

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        // The property under test is that initialize() does not wait on the
        // relay. Nothing completes relayResponseCompleter until further down,
        // so a version that waited would hang here; the timeout turns that
        // into a fast, attributable failure rather than a stalled suite. It
        // is a liveness bound, not a performance budget — do not tighten it
        // toward the observed runtime.
        await service.initialize().timeout(const Duration(seconds: 5));

        expect(service.isInitialized, isTrue);

        final relayListMerged = Completer<void>();
        void completeWhenRelayListIsMerged() {
          if (!relayListMerged.isCompleted &&
              service.lists.any((list) => list.id == 'relay_list_id')) {
            relayListMerged.complete();
          }
        }

        service.addListener(completeWhenRelayListIsMerged);
        addTearDown(
          () => service.removeListener(completeWhenRelayListIsMerged),
        );

        // Now simulate relay returning a new list
        final relayEvent = Event.fromJson({
          'id': 'relay_event_id',
          'pubkey': 'test_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'relay_list_id'],
            ['title', 'List From Relay'],
          ],
          'content': '',
          'sig': 'test_sig',
        });

        relayResponseCompleter.complete(relayEvent);

        await relayListMerged.future.timeout(const Duration(seconds: 5));
        expect(
          service.lists.singleWhere((list) => list.id == 'relay_list_id').name,
          'List From Relay',
        );
      },
    );
  });
}
