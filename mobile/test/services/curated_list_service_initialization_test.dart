// ABOUTME: Unit tests for CuratedListService local initialization readiness.
// ABOUTME: Verifies initialization completes independently of relay sync.

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('CuratedListService - Initialization Readiness', () {
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
      stubListSigner(
        mockNostr,
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      mockAuth = _MockAuthService();
      prefs = await SharedPreferences.getInstance();

      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(
        () => mockAuth.currentPublicKeyHex,
      ).thenReturn(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );

      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer(
        (invocation) async => Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          invocation.namedArguments[#kind] as int,
          invocation.namedArguments[#tags] as List<List<String>>,
          invocation.namedArguments[#content] as String,
          createdAt: invocation.namedArguments[#createdAt] as int?,
        ),
      );
      when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer(
        (invocation) async =>
            acceptedOutcome(invocation.positionalArguments.single as Event),
      );
      when(() => mockNostr.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.single as Event,
        ),
      );
    });

    test(
      'publication fixture reaches confirmed relay with the signed revision',
      () async {
        final publicationService = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        addTearDown(publicationService.dispose);
        final created = await publicationService.createList(name: 'Fixture');
        final event =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(created!.nostrEventId, event.id);
        expect(event.kind, 30005);
        expect(event.tags, contains(equals(['title', 'Fixture'])));
        expect(event.createdAt, greaterThan(0));
      },
    );

    test('edits wait for standalone recovery preparation to settle', () async {
      final service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      final entered = Completer<void>();
      final release = Completer<void>();
      final coordinator = CuratedListSessionCoordinator.forPreferences(prefs);
      final heldWrite = coordinator.writes.runExclusive(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final preparation = service.prepareRecovery();
      expect(service.isReadyForMutations, isFalse);
      expect(await service.createList(name: 'Not yet'), isNull);
      expect(prefs.get(CuratedListService.listsStorageKey), isNull);
      verifyNever(() => mockNostr.publishEventAwaitOk(any()));

      release.complete();
      await heldWrite;
      await preparation;
      expect(service.isReadyForMutations, isTrue);
      expect(await service.createList(name: 'Ready'), isNotNull);
    });

    test(
      'initialize() completes at zero virtual time while relay is blocked',
      () async {
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
        await prefs.setString(
          CuratedListService.subscribedListsStorageKey,
          '["cached_list_id"]',
        );
        fakeAsync((async) {
          final slowRelayCompleter = Completer<void>();
          var relaySubscribed = false;
          when(
            () => mockNostr.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) {
            relaySubscribed = true;
            return Stream.fromFuture(
              slowRelayCompleter.future.then((_) => null),
            ).where((_) => false).cast<Event>();
          });
          final service = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: prefs,
          );
          var completed = false;
          Object? initializationError;
          try {
            expect(service.lists.any((l) => l.name == 'Cached List'), isTrue);
            unawaited(
              service.initialize().then(
                (_) => completed = true,
                onError: (Object error) => initializationError = error,
              ),
            );
            // Drain local work without advancing virtual time. An awaited
            // relay or timer cannot complete while its response stays held.
            async.flushMicrotasks();
            expect(initializationError, isNull);
            expect(
              completed,
              isTrue,
              reason:
                  'initialize() must complete after local microtasks without '
                  'awaiting a relay or timer',
            );
            expect(async.elapsed, Duration.zero);
            expect(relaySubscribed, isTrue);
            expect(slowRelayCompleter.isCompleted, isFalse);
            expect(service.isInitialized, isTrue);
            expect(service.isReadyForMutations, isTrue);
            expect(service.getListById('cached_list_id')?.videoEventIds, [
              'video1',
              'video2',
            ]);
            expect(service.isSubscribedToList('cached_list_id'), isTrue);
            expect(service.hasLoadedSubscriptionIds, isTrue);
            verify(
              () => mockNostr.subscribe(
                any(),
                closeOnEose: true,
                onEose: any(named: 'onEose'),
              ),
            ).called(1);
          } finally {
            service.dispose();
            if (!slowRelayCompleter.isCompleted) slowRelayCompleter.complete();
            async.flushMicrotasks();
          }
        });
      },
    );

    test('notifies listeners immediately after initialization', () async {
      // Set up slow relay
      when(
        () => mockNostr.subscribe(
          any(),
          closeOnEose: true,
          onEose: any(named: 'onEose'),
        ),
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
          () => mockNostr.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
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
          () => mockNostr.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
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
          () => mockNostr.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
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
          'pubkey': '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
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
