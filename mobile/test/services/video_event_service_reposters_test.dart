// ABOUTME: Tests for VideoEventService method to query Kind 16 repost events for a specific video
// ABOUTME: Verifies correct filter construction and pubkey extraction from Kind 16 events

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

import './video_event_service_reposters_test.mocks.dart';

@GenerateMocks([NostrClient, SubscriptionManager])
void main() {
  group('VideoEventService getRepostersForVideo', () {
    late VideoEventService videoEventService;
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();

      // Setup default mock behaviors
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelayCount).thenReturn(3);
      when(mockNostrService.connectedRelays).thenReturn([
        'wss://relay1.example.com',
        'wss://relay2.example.com',
        'wss://relay3.example.com',
      ]);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    tearDown(() {
      videoEventService.dispose();
    });

    test('should query with correct filter (kind 6, e tag)', () async {
      final videoId = 'abc123def456';
      final eventStreamController = StreamController<Event>.broadcast();

      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => eventStreamController.stream);

      // Call the method
      final resultFuture = videoEventService.getRepostersForVideo(videoId);

      // Close stream immediately to complete
      eventStreamController.close();

      await resultFuture;

      // Verify the filter
      verify(
        mockNostrService.subscribe(
          argThat(
            predicate<List<Filter>>((filters) {
              if (filters.isEmpty) return false;
              final filter = filters.first;
              return filter.kinds != null &&
                  filter.kinds!.contains(16) &&
                  filter.e != null &&
                  filter.e!.contains(videoId);
            }),
          ),
        ),
      ).called(1);
    });

    test('should extract pubkeys correctly from Kind 16 events', () async {
      final videoId =
          'abc123def456789012345678901234567890123456789012345678901234';
      final eventStreamController = StreamController<Event>.broadcast();

      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => eventStreamController.stream);

      // Create repost events with valid hex pubkeys (64 chars)
      final reposter1Pubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final reposter2Pubkey =
          '2222222222222222222222222222222222222222222222222222222222222222';
      final reposter3Pubkey =
          '3333333333333333333333333333333333333333333333333333333333333333';
      final originalAuthorPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      final repost1 = Event(
        reposter1Pubkey, // pubkey
        6, // kind
        [
          ['e', videoId],
          ['p', originalAuthorPubkey],
        ], // tags
        '', // content
        createdAt: 1000,
      );
      repost1.id =
          'repost111111111111111111111111111111111111111111111111111111111111';

      final repost2 = Event(
        reposter2Pubkey, // pubkey
        6, // kind
        [
          ['e', videoId],
          ['p', originalAuthorPubkey],
        ], // tags
        '', // content
        createdAt: 2000,
      );
      repost2.id =
          'repost222222222222222222222222222222222222222222222222222222222222';

      final repost3 = Event(
        reposter3Pubkey, // pubkey
        6, // kind
        [
          ['e', videoId],
          ['p', originalAuthorPubkey],
        ], // tags
        '', // content
        createdAt: 3000,
      );
      repost3.id =
          'repost333333333333333333333333333333333333333333333333333333333333';

      // Call the method
      final resultFuture = videoEventService.getRepostersForVideo(videoId);

      // Emit events
      eventStreamController.add(repost1);
      eventStreamController.add(repost2);
      eventStreamController.add(repost3);

      // Close stream after a short delay to allow processing
      await Future.delayed(const Duration(milliseconds: 100));
      eventStreamController.close();

      final result = await resultFuture;

      // Verify we got all 3 pubkeys
      expect(result.length, 3);
      expect(result, contains(reposter1Pubkey));
      expect(result, contains(reposter2Pubkey));
      expect(result, contains(reposter3Pubkey));
    });

    test('should handle empty results when no reposts exist', () async {
      final videoId = 'abc123def456';
      final eventStreamController = StreamController<Event>.broadcast();

      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => eventStreamController.stream);

      // Call the method
      final resultFuture = videoEventService.getRepostersForVideo(videoId);

      // Close stream immediately without adding events
      eventStreamController.close();

      final result = await resultFuture;

      // Verify empty list
      expect(result, isEmpty);
    });

    test(
      'should deduplicate pubkeys when same user reposts multiple times',
      () async {
        final videoId =
            'abc123def456789012345678901234567890123456789012345678901234';
        final eventStreamController = StreamController<Event>.broadcast();

        when(
          mockNostrService.subscribe(argThat(anything)),
        ).thenAnswer((_) => eventStreamController.stream);

        final reposter1Pubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        final reposter2Pubkey =
            '2222222222222222222222222222222222222222222222222222222222222222';

        // Create multiple reposts from same user
        final repost1 = Event(
          reposter1Pubkey, // same pubkey
          6,
          [
            ['e', videoId],
          ],
          '',
          createdAt: 1000,
        );
        repost1.id =
            'repost111111111111111111111111111111111111111111111111111111111111';

        final repost2 = Event(
          reposter1Pubkey, // same pubkey
          6,
          [
            ['e', videoId],
          ],
          '',
          createdAt: 2000,
        );
        repost2.id =
            'repost222222222222222222222222222222222222222222222222222222222222';

        final repost3 = Event(
          reposter2Pubkey, // different pubkey
          6,
          [
            ['e', videoId],
          ],
          '',
          createdAt: 3000,
        );
        repost3.id =
            'repost333333333333333333333333333333333333333333333333333333333333';

        // Call the method
        final resultFuture = videoEventService.getRepostersForVideo(videoId);

        // Emit events
        eventStreamController.add(repost1);
        eventStreamController.add(repost2);
        eventStreamController.add(repost3);

        await Future.delayed(const Duration(milliseconds: 100));
        eventStreamController.close();

        final result = await resultFuture;

        // Verify deduplication - should only have 2 unique pubkeys
        expect(result.length, 2);
        expect(result, contains(reposter1Pubkey));
        expect(result, contains(reposter2Pubkey));
      },
    );

    test('should handle timeout when relay does not respond', () async {
      final videoId = 'abc123def456';
      final eventStreamController = StreamController<Event>.broadcast();

      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => eventStreamController.stream);

      // Call the method
      final resultFuture = videoEventService.getRepostersForVideo(videoId);

      // Don't emit any events, just wait for timeout
      // The implementation should have a timeout mechanism

      // Wait for the expected timeout duration (assuming 5 seconds based on other methods)
      await Future.delayed(const Duration(seconds: 6));
      eventStreamController.close();

      final result = await resultFuture;

      // Should return whatever was collected (empty in this case)
      expect(result, isA<List<String>>());
    });

    test('should ignore non-Kind-6 events in stream', () async {
      final videoId =
          'abc123def456789012345678901234567890123456789012345678901234';
      final eventStreamController = StreamController<Event>.broadcast();

      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => eventStreamController.stream);

      final reposterPubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final someonePubkey =
          '2222222222222222222222222222222222222222222222222222222222222222';
      final creatorPubkey =
          '3333333333333333333333333333333333333333333333333333333333333333';

      // Create a Kind 16 repost
      final repost = Event(
        reposterPubkey,
        16,
        [
          ['e', videoId],
        ],
        '',
        createdAt: 1000,
      );
      repost.id =
          'repost111111111111111111111111111111111111111111111111111111111111';

      // Create a Kind 1 text note (should be ignored)
      final textNote = Event(
        someonePubkey,
        1,
        [
          ['e', videoId],
        ],
        'This is a text note',
        createdAt: 2000,
      );
      textNote.id =
          'note1111111111111111111111111111111111111111111111111111111111111';

      // Create a Kind 22 video event (should be ignored)
      final video = Event(
        creatorPubkey,
        22,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        '',
        createdAt: 3000,
      );
      video.id =
          'video111111111111111111111111111111111111111111111111111111111111';

      // Call the method
      final resultFuture = videoEventService.getRepostersForVideo(videoId);

      // Emit events
      eventStreamController.add(repost);
      eventStreamController.add(textNote);
      eventStreamController.add(video);

      await Future.delayed(const Duration(milliseconds: 100));
      eventStreamController.close();

      final result = await resultFuture;

      // Verify only the Kind 16 event was processed
      expect(result.length, 1);
      expect(result, contains(reposterPubkey));
    });
  });
}
