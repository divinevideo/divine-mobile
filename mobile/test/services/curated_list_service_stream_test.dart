// ABOUTME: Unit tests for CuratedListService streaming operations
// ABOUTME: Tests streamPublicListsFromRelays with excludeIds and pagination

import 'dart:async';

import 'package:fake_async/fake_async.dart';
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
  group('CuratedListService - Stream Operations', () {
    late CuratedListService service;
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late SharedPreferences prefs;
    late StreamController<Event> eventController;

    /// Creates a mock kind 30005 list event with video references
    /// The fixture author for [dTag], the same value every list event carries.
    String authorPubkeyFor(String dTag) =>
        'author_pubkey_${dTag.hashCode.abs()}';

    Event createListEvent({
      required String dTag,
      required String name,
      required List<String> videoIds,
      int? createdAt,
    }) {
      final tags = <List<String>>[
        ['d', dTag],
        ['title', name],
        ...videoIds.map((id) => ['a', '34236:pubkey123:$id']),
      ];

      return Event.fromJson({
        'id': 'event_$dTag',
        'pubkey': authorPubkeyFor(dTag),
        'created_at':
            createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 30005,
        'tags': tags,
        'content': '',
        'sig': 'test_signature',
      });
    }

    /// Creates a mock kind 30005 list event WITHOUT video references
    Event createEmptyListEvent({required String dTag, required String name}) {
      return Event.fromJson({
        'id': 'event_$dTag',
        'pubkey': authorPubkeyFor(dTag),
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 30005,
        'tags': [
          ['d', dTag],
          ['title', name],
        ],
        'content': '',
        'sig': 'test_signature',
      });
    }

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

      stubListSigner(mockNostr, 'test_pubkey');
      mockAuth = _MockAuthService();
      prefs = await SharedPreferences.getInstance();
      eventController = StreamController<Event>.broadcast();

      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.currentPublicKeyHex).thenReturn('test_pubkey');

      // Mock subscribe to return our controlled stream
      when(
        () => mockNostr.subscribe(
          any(),
          onEose: any(named: 'onEose'),
          closeOnEose: true,
        ),
      ).thenAnswer((_) => eventController.stream);

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    tearDown(() async {
      // Controller may already be closed by the test
      if (!eventController.isClosed) {
        await eventController.close();
      }
    });

    group('streamPublicListsFromRelays()', () {
      test('yields lists progressively as events arrive', () async {
        final receivedLists = <List<CuratedList>>[];

        // Start listening to the stream
        final subscription = service.streamPublicListsFromRelays().listen(
          (lists) => receivedLists.add(List.from(lists)),
        );

        // Wait for the async generator to reach the await for loop
        await pumpEventQueue();

        // Emit list events one at a time
        eventController.add(
          createListEvent(
            dTag: 'list1',
            name: 'First List',
            videoIds: ['video1'],
          ),
        );

        await pumpEventQueue();

        eventController.add(
          createListEvent(
            dTag: 'list2',
            name: 'Second List',
            videoIds: ['video2', 'video3'],
          ),
        );

        await pumpEventQueue();

        eventController.add(
          createListEvent(
            dTag: 'list3',
            name: 'Third List',
            videoIds: ['video4'],
          ),
        );

        await pumpEventQueue();

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Should have received 3 progressive updates
        expect(receivedLists.length, 3);
        expect(receivedLists[0].length, 1); // First yield: 1 list
        expect(receivedLists[1].length, 2); // Second yield: 2 lists
        expect(receivedLists[2].length, 3); // Third yield: 3 lists
      });

      test('filters out lists without video references', () async {
        final receivedLists = <List<CuratedList>>[];

        final subscription = service.streamPublicListsFromRelays().listen(
          (lists) => receivedLists.add(List.from(lists)),
        );

        // Wait for the async generator to reach the await for loop
        await pumpEventQueue();

        // Emit a list WITH videos
        eventController.add(
          createListEvent(
            dTag: 'list_with_videos',
            name: 'List With Videos',
            videoIds: ['video1'],
          ),
        );

        await pumpEventQueue();

        // Emit a list WITHOUT videos
        eventController.add(
          createEmptyListEvent(dTag: 'list_without_videos', name: 'Empty List'),
        );

        await pumpEventQueue();

        // Emit another list WITH videos
        eventController.add(
          createListEvent(
            dTag: 'list_with_more_videos',
            name: 'Another List With Videos',
            videoIds: ['video2'],
          ),
        );

        await pumpEventQueue();

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Should have received 2 yields (empty list was filtered)
        expect(receivedLists.length, 2);
        expect(receivedLists[0].length, 1);
        expect(receivedLists[1].length, 2);

        // Verify the empty list was not included
        final allListNames = receivedLists.last.map((l) => l.name).toSet();
        expect(allListNames, contains('List With Videos'));
        expect(allListNames, contains('Another List With Videos'));
        expect(allListNames, isNot(contains('Empty List')));
      });

      test('excludeIds parameter skips known lists', () async {
        final receivedLists = <List<CuratedList>>[];

        // excludeIds is keyed by author and d-tag, so a bare d-tag matches
        // nothing; exclude list2 under its author.
        final subscription = service
            .streamPublicListsFromRelays(
              excludeIds: {'${authorPubkeyFor('list2')}:list2'},
            )
            .listen((lists) => receivedLists.add(List.from(lists)));

        // Wait for the async generator to reach the await for loop
        await pumpEventQueue();

        // Emit list1 - should be yielded
        eventController.add(
          createListEvent(
            dTag: 'list1',
            name: 'First List',
            videoIds: ['video1'],
          ),
        );

        await pumpEventQueue();

        // Emit list2 - should be SKIPPED (in excludeIds)
        eventController.add(
          createListEvent(
            dTag: 'list2',
            name: 'Second List',
            videoIds: ['video2'],
          ),
        );

        await pumpEventQueue();

        // Emit list3 - should be yielded
        eventController.add(
          createListEvent(
            dTag: 'list3',
            name: 'Third List',
            videoIds: ['video3'],
          ),
        );

        await pumpEventQueue();

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Should have received 2 yields (list2 was skipped)
        expect(receivedLists.length, 2);
        expect(receivedLists[0].length, 1);
        expect(receivedLists[1].length, 2);

        // Verify list2 was not included
        final allListIds = receivedLists.last.map((l) => l.id).toSet();
        expect(allListIds, contains('list1'));
        expect(allListIds, contains('list3'));
        expect(allListIds, isNot(contains('list2')));
      });

      test('deduplicates by d-tag, keeping newest version', () async {
        final receivedLists = <List<CuratedList>>[];

        final subscription = service.streamPublicListsFromRelays().listen(
          (lists) => receivedLists.add(List.from(lists)),
        );

        // Wait for the async generator to reach the await for loop
        await pumpEventQueue();

        // Emit older version of list1
        eventController.add(
          createListEvent(
            dTag: 'list1',
            name: 'Old Name',
            videoIds: ['video1'],
            createdAt: 1000,
          ),
        );

        await pumpEventQueue();

        // Emit newer version of same list1
        eventController.add(
          createListEvent(
            dTag: 'list1',
            name: 'New Name',
            videoIds: ['video1', 'video2'],
            createdAt: 2000,
          ),
        );

        await pumpEventQueue();

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Should have received 2 yields (both versions triggered
        // yield)
        expect(receivedLists.length, 2);

        // But final list should only have 1 unique list with newer
        // data
        expect(receivedLists.last.length, 1);
        expect(receivedLists.last.first.name, 'New Name');
        expect(receivedLists.last.first.videoEventIds.length, 2);
      });

      test('passes limit parameter to filter', () async {
        // Capture the filter passed to subscribe
        Filter? capturedFilter;
        when(
          () => mockNostr.subscribe(
            any(),
            onEose: any(named: 'onEose'),
            closeOnEose: true,
          ),
        ).thenAnswer((invocation) {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          capturedFilter = filters.first;
          return eventController.stream;
        });

        // Start stream with custom limit
        final subscription = service
            .streamPublicListsFromRelays(limit: 200)
            .listen((_) {});

        await pumpEventQueue();

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        expect(capturedFilter, isNotNull);
        expect(capturedFilter!.limit, 200);
        expect(capturedFilter!.kinds, contains(30005));
      });

      test('sorts lists by video count (most videos first)', () async {
        final receivedLists = <List<CuratedList>>[];

        final subscription = service.streamPublicListsFromRelays().listen(
          (lists) => receivedLists.add(List.from(lists)),
        );

        // Wait for the async generator to reach the await for loop
        await pumpEventQueue();

        // Emit list with 1 video
        eventController.add(
          createListEvent(
            dTag: 'small_list',
            name: 'Small List',
            videoIds: ['video1'],
          ),
        );

        await pumpEventQueue();

        // Emit list with 5 videos
        eventController.add(
          createListEvent(
            dTag: 'large_list',
            name: 'Large List',
            videoIds: ['v1', 'v2', 'v3', 'v4', 'v5'],
          ),
        );

        await pumpEventQueue();

        // Emit list with 3 videos
        eventController.add(
          createListEvent(
            dTag: 'medium_list',
            name: 'Medium List',
            videoIds: ['a', 'b', 'c'],
          ),
        );

        await pumpEventQueue();

        // Close the event controller first to complete the stream
        await eventController.close();
        await subscription.cancel();

        // Final list should be sorted by video count descending
        final finalList = receivedLists.last;
        expect(finalList.length, 3);
        expect(finalList[0].name, 'Large List'); // 5 videos
        expect(finalList[1].name, 'Medium List'); // 3 videos
        expect(finalList[2].name, 'Small List'); // 1 video
      });

      test('completes empty when relays EOSE without events', () async {
        void Function()? onEose;
        when(
          () => mockNostr.subscribe(
            any(),
            onEose: any(named: 'onEose'),
            closeOnEose: true,
          ),
        ).thenAnswer((invocation) {
          onEose = invocation.namedArguments[#onEose] as void Function()?;
          return eventController.stream;
        });

        final updates = <List<CuratedList>>[];
        var completed = false;
        service.streamPublicListsFromRelays().listen(
          updates.add,
          onDone: () {
            completed = true;
          },
        );

        await pumpEventQueue();
        onEose!();
        await pumpEventQueue();

        expect(updates, isEmpty);
        expect(completed, isTrue);
      });

      test('completes with received events when relays EOSE', () async {
        void Function()? onEose;
        when(
          () => mockNostr.subscribe(
            any(),
            onEose: any(named: 'onEose'),
            closeOnEose: true,
          ),
        ).thenAnswer((invocation) {
          onEose = invocation.namedArguments[#onEose] as void Function()?;
          return eventController.stream;
        });

        final updates = <List<CuratedList>>[];
        var completed = false;
        service.streamPublicListsFromRelays().listen(
          updates.add,
          onDone: () {
            completed = true;
          },
        );

        await pumpEventQueue();
        eventController.add(
          createListEvent(
            dTag: 'list_with_videos',
            name: 'List With Videos',
            videoIds: ['video1'],
          ),
        );
        await pumpEventQueue();
        onEose!();
        await pumpEventQueue();

        expect(updates, hasLength(1));
        expect(updates.single.single.name, 'List With Videos');
        expect(completed, isTrue);
      });

      test('silent relay read times out and cancels subscription', () {
        fakeAsync((async) {
          var canceled = false;
          eventController = StreamController<Event>(
            onCancel: () {
              canceled = true;
            },
          );
          when(
            () => mockNostr.subscribe(
              any(),
              onEose: any(named: 'onEose'),
              closeOnEose: true,
            ),
          ).thenAnswer((_) => eventController.stream);

          Object? receivedError;
          service
              .streamPublicListsFromRelays(
                timeout: const Duration(milliseconds: 100),
              )
              .listen(
                (_) {},
                onError: (Object error) {
                  receivedError = error;
                },
              );

          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          expect(receivedError, isA<TimeoutException>());
          expect(canceled, isTrue);
        });
      });

      test('listener cancellation cleans up relay subscription', () async {
        var canceled = false;
        eventController = StreamController<Event>(
          onCancel: () {
            canceled = true;
          },
        );
        when(
          () => mockNostr.subscribe(
            any(),
            onEose: any(named: 'onEose'),
            closeOnEose: true,
          ),
        ).thenAnswer((_) => eventController.stream);

        final subscription = service.streamPublicListsFromRelays().listen(
          (_) {},
        );
        await pumpEventQueue();
        await subscription.cancel();

        expect(canceled, isTrue);
      });
    });
  });
}
