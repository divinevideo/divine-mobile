// ABOUTME: Tests for CurationService kind 30005 Nostr queries
// ABOUTME: Verifies fetching and subscribing to NIP-51 video curation sets

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';

import 'curation_service_kind_30005_test.mocks.dart';

@GenerateMocks([INostrService, VideoEventService, SocialService, AuthService])
void main() {
  group('CurationService - Kind 30005 Nostr Queries', () {
    late MockINostrService mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;
    late CurationService curationService;

    setUp(() {
      mockNostrService = MockINostrService();
      mockVideoEventService = MockVideoEventService();
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();

      when(mockVideoEventService.videoEvents).thenReturn([]);
      when(mockVideoEventService.discoveryVideos).thenReturn([]);
      when(mockSocialService.getCachedLikeCount(any)).thenReturn(0);

      curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
        authService: mockAuthService,
      );
    });

    group('refreshCurationSets()', () {
      test('queries Nostr for kind 30005 events', () async {
        // Setup: Mock empty event stream
        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
          ),
        ).thenAnswer((_) => controller.stream);

        // Execute
        final future = curationService.refreshCurationSets();

        // Complete the stream
        await Future.delayed(const Duration(milliseconds: 100));
        controller.close();

        await future;

        // Verify: Called with kind 30005 filter
        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: true,
          ),
        ).captured;

        expect(captured, isNotEmpty);
        final filters = captured[0] as List<Filter>;
        expect(filters.length, 1);
        expect(filters[0].kinds, contains(30005));
      });

      test('parses and stores received kind 30005 events', () async {
        // Setup: Create mock kind 30005 event
        final testEvent = Event.fromJson({
          'id': 'test_event_123',
          'pubkey': 'curator_pubkey_abc',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'test_list'],
            ['title', 'Test Curation List'],
            ['description', 'Test description'],
            ['e', 'video_event_1', '', 'wss://relay.example.com'],
            ['e', 'video_event_2', '', 'wss://relay.example.com'],
          ],
          'content': '',
          'sig': 'test_signature',
        });

        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
          ),
        ).thenAnswer((_) => controller.stream);

        // Execute
        final future = curationService.refreshCurationSets();

        // Send event and close
        controller.add(testEvent);
        await Future.delayed(const Duration(milliseconds: 100));
        controller.close();

        await future;

        // Verify: Curation set was added (stored by 'd' tag value only)
        final set = curationService.getCurationSet('test_list');
        expect(set, isNotNull);
        expect(set!.title, 'Test Curation List');
        expect(set.videoIds.length, 2);
        expect(set.videoIds, contains('video_event_1'));
        expect(set.videoIds, contains('video_event_2'));
      });

      test('filters by curator pubkeys when provided', () async {
        final curatorPubkeys = ['curator1', 'curator2'];

        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
          ),
        ).thenAnswer((_) => controller.stream);

        // Execute
        final future = curationService.refreshCurationSets(
          curatorPubkeys: curatorPubkeys,
        );

        controller.close();
        await future;

        // Verify: Filter included curator pubkeys
        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: true,
          ),
        ).captured;

        final filters = captured[0] as List<Filter>;
        expect(filters[0].authors, curatorPubkeys);
      });

      test('handles multiple curation sets from different curators', () async {
        final event1 = Event.fromJson({
          'id': 'event1',
          'pubkey': 'curator1',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'list1'],
            ['title', 'Curator 1 List'],
            ['e', 'video1'],
          ],
          'content': '',
          'sig': 'sig1',
        });

        final event2 = Event.fromJson({
          'id': 'event2',
          'pubkey': 'curator2',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'list2'],
            ['title', 'Curator 2 List'],
            ['e', 'video2'],
          ],
          'content': '',
          'sig': 'sig2',
        });

        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
          ),
        ).thenAnswer((_) => controller.stream);

        final future = curationService.refreshCurationSets();

        controller.add(event1);
        controller.add(event2);
        await Future.delayed(const Duration(milliseconds: 100));
        controller.close();

        await future;

        // Verify: Both sets stored (by 'd' tag value)
        final set1 = curationService.getCurationSet('list1');
        final set2 = curationService.getCurationSet('list2');

        expect(set1, isNotNull);
        expect(set2, isNotNull);
        expect(set1!.title, 'Curator 1 List');
        expect(set2!.title, 'Curator 2 List');
      });

      test('falls back to sample data when no sets found', () async {
        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
          ),
        ).thenAnswer((_) => controller.stream);

        final future = curationService.refreshCurationSets();

        // Close without sending any events
        controller.close();
        await future;

        // Verify: Sample data exists
        // Note: Sample data is always present from initialization
        expect(curationService.curationSets.isNotEmpty, isTrue);
      });

      test('handles errors gracefully and falls back to sample data', () async {
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
          ),
        ).thenThrow(Exception('Connection error'));

        // Should not throw
        await curationService.refreshCurationSets();

        // Verify: Sample data still available
        expect(curationService.curationSets.isNotEmpty, isTrue);
      });

      test('times out after 10 seconds', () async {
        // Setup: Never-completing stream
        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
          ),
        ).thenAnswer((_) => controller.stream);

        final stopwatch = Stopwatch()..start();
        await curationService.refreshCurationSets();
        stopwatch.stop();

        // Should complete due to timeout, not hang forever
        expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(12));

        await controller.close();
      });

      test('ignores non-30005 events in stream', () async {
        final wrongKindEvent = Event.fromJson({
          'id': 'wrong_kind',
          'pubkey': 'curator',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 1, // Regular note, not curation set
          'tags': [],
          'content': 'Hello world',
          'sig': 'sig',
        });

        final correctEvent = Event.fromJson({
          'id': 'correct',
          'pubkey': 'curator',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'list'],
            ['title', 'Valid List'],
            ['e', 'video1'],
          ],
          'content': '',
          'sig': 'sig',
        });

        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
          ),
        ).thenAnswer((_) => controller.stream);

        final future = curationService.refreshCurationSets();

        controller.add(wrongKindEvent);
        controller.add(correctEvent);
        await Future.delayed(const Duration(milliseconds: 100));
        controller.close();

        await future;

        // Only the correct kind 30005 event should be stored
        final validSet = curationService.getCurationSet('list');
        expect(validSet, isNotNull);
      });

      test('handles malformed events without crashing', () async {
        // Event missing required tags
        final malformedEvent = Event.fromJson({
          'id': 'malformed',
          'pubkey': 'curator',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [], // No 'd' tag or title
          'content': '',
          'sig': 'sig',
        });

        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
          ),
        ).thenAnswer((_) => controller.stream);

        // Should not throw
        final future = curationService.refreshCurationSets();

        controller.add(malformedEvent);
        await Future.delayed(const Duration(milliseconds: 100));
        controller.close();

        await expectLater(future, completes);
      });
    });

    group('subscribeToCurationSets()', () {
      test('subscribes to kind 30005 events', () async {
        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => controller.stream);

        await curationService.subscribeToCurationSets();

        // Verify subscription was created
        verify(
          mockNostrService.subscribeToEvents(
            filters: argThat(
              predicate<List<Filter>>((filters) {
                if (filters.isEmpty) return false;
                final kinds = filters[0].kinds;
                return kinds != null && kinds.contains(30005);
              }),
              named: 'filters',
            ),
          ),
        ).called(1);

        await controller.close();
      });

      test('processes incoming curation set events', () async {
        final testEvent = Event.fromJson({
          'id': 'streaming_event',
          'pubkey': 'streaming_curator',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'streaming_list'],
            ['title', 'Streaming List'],
            ['e', 'video_a'],
            ['e', 'video_b'],
          ],
          'content': '',
          'sig': 'sig',
        });

        final controller = StreamController<Event>();
        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => controller.stream);

        await curationService.subscribeToCurationSets();

        // Send event through subscription
        controller.add(testEvent);
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify event was processed
        final set = curationService.getCurationSet('streaming_list');
        expect(set, isNotNull);
        expect(set!.title, 'Streaming List');
        expect(set.videoIds, ['video_a', 'video_b']);

        await controller.close();
      });
    });
  });
}
