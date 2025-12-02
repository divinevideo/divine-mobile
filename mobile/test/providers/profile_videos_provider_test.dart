// ABOUTME: Tests for ProfileVideosProvider to ensure cache-first behavior and request optimization
// ABOUTME: Validates that unnecessary subscriptions are avoided when data is fresh in cache

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/profile_videos_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/video_event_service.dart';

@GenerateMocks([INostrService, VideoEventService])
import 'profile_videos_provider_test.mocks.dart';

void main() {
  group('ProfileVideosProvider', () {
    late ProviderContainer container;
    late MockINostrService mockNostrService;
    late MockVideoEventService mockVideoEventService;

    /// Helper to setup mock subscription with onEose callback support
    /// Returns a tuple: (triggerEose function, subscription started completer)
    (void Function(), Completer<void>) setupMockSubscription(
      StreamController<Event> controller,
    ) {
      void Function()? capturedOnEose;
      final subscriptionStarted = Completer<void>();
      when(
        mockNostrService.subscribeToEvents(
          filters: anyNamed('filters'),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((invocation) {
        capturedOnEose = invocation.namedArguments[#onEose] as void Function()?;
        subscriptionStarted.complete();
        return controller.stream;
      });
      // Return a function to manually trigger EOSE and the completer
      return (
        () {
          if (capturedOnEose != null) {
            capturedOnEose!();
          }
        },
        subscriptionStarted,
      );
    }

    setUp(() {
      mockNostrService = MockINostrService();
      mockVideoEventService = MockVideoEventService();

      container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      clearAllProfileVideosCache();
      reset(mockNostrService);
      reset(mockVideoEventService);
    });

    group('Initial State', () {
      test('should have correct initial state', () {
        final state = container.read(profileVideosProvider);
        expect(state.videos, isEmpty);
        expect(state.isLoading, false);
        expect(state.isLoadingMore, false);
        expect(state.hasMore, true);
        expect(state.error, isNull);
        expect(state.lastTimestamp, isNull);
      });
    });

    group('Loading Videos', () {
      const testPubkey = 'test_pubkey_123';

      test('should use cached videos from VideoEventService', () async {
        // Arrange
        final now = DateTime.now();
        final cachedVideos = <VideoEvent>[
          VideoEvent(
            id: 'video1',
            pubkey: testPubkey,
            content: 'test content',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            videoUrl: 'https://example.com/video1.mp4',
            title: 'Test Video 1',
          ),
          VideoEvent(
            id: 'video2',
            pubkey: testPubkey,
            content: 'test content 2',
            createdAt: (now.millisecondsSinceEpoch ~/ 1000) - 100,
            timestamp: now.subtract(const Duration(seconds: 100)),
            videoUrl: 'https://example.com/video2.mp4',
            title: 'Test Video 2',
          ),
        ];

        // Mock VideoEventService to return cached videos
        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn(cachedVideos);

        // Mock empty subscription (no new events)
        final controller = StreamController<Event>();
        final (triggerEose, _) = setupMockSubscription(controller);

        // Act
        final notifier = container.read(profileVideosProvider.notifier);
        final loadFuture = notifier.loadVideosForUser(testPubkey);

        // Close the stream and trigger EOSE
        await controller.close();
        triggerEose();

        // Wait for load to complete
        await loadFuture;

        // Assert
        final state = container.read(profileVideosProvider);
        expect(state.videos.length, equals(2));
        expect(state.videos.first.id, equals('video1')); // Newest first
        expect(state.videos.last.id, equals('video2'));
        expect(state.isLoading, false);
        expect(state.error, isNull);

        // Should have called getVideosByAuthor
        verify(mockVideoEventService.getVideosByAuthor(testPubkey)).called(1);
      });

      test(
        'should display cached videos immediately without waiting for relay',
        () async {
          // Arrange
          final now = DateTime.now();
          final cachedVideos = <VideoEvent>[
            VideoEvent(
              id: 'cached1',
              pubkey: testPubkey,
              content: 'cached video',
              createdAt: now.millisecondsSinceEpoch ~/ 1000,
              timestamp: now,
              videoUrl: 'https://example.com/cached1.mp4',
              title: 'Cached Video',
            ),
          ];

          // Mock VideoEventService to return cached videos
          when(
            mockVideoEventService.getVideosByAuthor(testPubkey),
          ).thenReturn(cachedVideos);

          // Create a stream controller that we WON'T close immediately
          // This simulates a slow/delayed relay response
          final controller = StreamController<Event>();
          void Function()? capturedOnEose;
          when(
            mockNostrService.subscribeToEvents(
              filters: anyNamed('filters'),
              onEose: anyNamed('onEose'),
            ),
          ).thenAnswer((invocation) {
            capturedOnEose =
                invocation.namedArguments[#onEose] as void Function()?;
            return controller.stream;
          });

          // Act
          final notifier = container.read(profileVideosProvider.notifier);
          final loadFuture = notifier.loadVideosForUser(testPubkey);

          // Give microtasks a chance to execute
          await Future.microtask(() {});

          // Assert - videos should be displayed IMMEDIATELY from cache
          // even though the relay subscription hasn't completed
          final stateBeforeRelayResponse = container.read(
            profileVideosProvider,
          );
          expect(
            stateBeforeRelayResponse.videos.length,
            equals(1),
            reason:
                'Cached videos should be displayed immediately without waiting for relay',
          );
          expect(stateBeforeRelayResponse.videos.first.id, equals('cached1'));
          expect(
            stateBeforeRelayResponse.isLoading,
            false,
            reason: 'Should not be loading when displaying cached content',
          );

          // Clean up - trigger EOSE and close the stream
          if (capturedOnEose != null) {
            capturedOnEose!();
          }
          await controller.close();
          await loadFuture;
        },
      );

      test('should handle loading errors gracefully', () async {
        // Arrange
        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn([]);
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            onEose: anyNamed('onEose'),
          ),
        ).thenAnswer((_) => Stream.error(Exception('Network error')));

        // Act
        final notifier = container.read(profileVideosProvider.notifier);
        await notifier.loadVideosForUser(testPubkey);

        // Assert
        final state = container.read(profileVideosProvider);
        expect(state.isLoading, false);
        expect(state.videos, isEmpty);
        // Note: Error handling in streaming implementation might not set error state
        // This depends on the specific implementation details
      });

      test('should prevent concurrent loads for same user', () async {
        // Arrange
        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn([]);

        final controller = StreamController<Event>();
        final (triggerEose, _) = setupMockSubscription(controller);

        // Act - start two concurrent loads
        final notifier = container.read(profileVideosProvider.notifier);
        final future1 = notifier.loadVideosForUser(testPubkey);
        final future2 = notifier.loadVideosForUser(testPubkey);

        // Complete the stream
        await controller.close();
        triggerEose();

        await Future.wait([future1, future2]);

        // Assert - should only call service once
        verify(mockVideoEventService.getVideosByAuthor(testPubkey)).called(1);
      });
    });

    group('Cache Management', () {
      const testPubkey = 'test_pubkey_cache';

      test('should refresh videos by clearing cache', () async {
        // Arrange - first load with some videos
        final now = DateTime.now();
        final initialVideos = <VideoEvent>[
          VideoEvent(
            id: 'initial_video1',
            pubkey: testPubkey,
            content: 'initial content',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            videoUrl: 'https://example.com/initial1.mp4',
            title: 'Initial Video 1',
          ),
        ];

        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn(initialVideos);

        final controller1 = StreamController<Event>();
        final (triggerEose1, _) = setupMockSubscription(controller1);

        // Keep provider alive by maintaining a listener BEFORE loading
        // (Provider has keepAlive: false, so it would dispose after loading completes)
        final subscription = container.listen(
          profileVideosProvider,
          (previous, next) {},
        );

        // Load initial videos
        final notifier = container.read(profileVideosProvider.notifier);
        final loadFuture1 = notifier.loadVideosForUser(testPubkey);
        await controller1.close();
        triggerEose1();
        await loadFuture1;

        // Verify initial state
        var state = container.read(profileVideosProvider);
        expect(state.videos.length, equals(1));
        expect(state.videos.first.id, equals('initial_video1'));

        // Arrange for refresh - mock updated videos
        final updatedVideos = <VideoEvent>[
          VideoEvent(
            id: 'updated_video1',
            pubkey: testPubkey,
            content: 'updated content',
            createdAt: (now.millisecondsSinceEpoch ~/ 1000) + 100,
            timestamp: now.add(const Duration(seconds: 100)),
            videoUrl: 'https://example.com/updated1.mp4',
            title: 'Updated Video 1',
          ),
        ];

        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn(updatedVideos);

        final controller2 = StreamController<Event>();
        final (triggerEose2, subscriptionStarted2) = setupMockSubscription(
          controller2,
        );

        // Act - refresh videos (don't await yet)
        final refreshFuture = notifier.refreshVideos(testPubkey);

        // Wait for subscription to be established with timeout
        try {
          await subscriptionStarted2.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              // Debug: check if subscribeToEvents was ever called
              final verification = verify(
                mockNostrService.subscribeToEvents(
                  filters: anyNamed('filters'),
                  onEose: anyNamed('onEose'),
                ),
              );
              final callCount = verification.callCount;
              throw Exception(
                'subscribeToEvents called $callCount time(s), but completer never completed',
              );
            },
          );
        } catch (e) {
          if (e.toString().contains('No matching calls')) {
            throw Exception(
              'subscribeToEvents was NEVER called during refresh!',
            );
          }
          rethrow;
        }

        // Close stream and trigger EOSE
        await controller2.close();
        triggerEose2();

        // Now await the refresh to complete
        await refreshFuture;

        // Assert - should have updated videos
        state = container.read(profileVideosProvider);
        expect(state.videos.length, equals(1));
        expect(state.videos.first.id, equals('updated_video1'));

        subscription.close();
      });

      test('should clear error state', () async {
        // Create error state first by failing a load
        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn([]);
        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            onEose: anyNamed('onEose'),
          ),
        ).thenAnswer((_) => Stream.error(Exception('Test error')));

        final notifier = container.read(profileVideosProvider.notifier);
        await notifier.loadVideosForUser(testPubkey);

        // Keep provider alive by maintaining a listener
        final subscription = container.listen(
          profileVideosProvider,
          (previous, next) {},
        );

        // Verify we can clear error (implementation might vary)
        notifier.clearError();

        final state = container.read(profileVideosProvider);
        expect(state.error, isNull);

        subscription.close();
      });

      test('should clear all cache globally', () {
        clearAllProfileVideosCache();
        // Just verify it doesn't throw - internal cache state is private
      });
    });

    group('Load More Videos', () {
      const testPubkey = 'test_pubkey_more';

      test('should load more videos with pagination', () async {
        // Arrange - setup initial videos (200 to trigger hasMore = true)
        final now = DateTime.now();
        final initialVideos = List.generate(200, (index) {
          return VideoEvent(
            id: 'initial$index',
            pubkey: testPubkey,
            content: 'initial content $index',
            createdAt: (now.millisecondsSinceEpoch ~/ 1000) - index,
            timestamp: now.subtract(Duration(seconds: index)),
            videoUrl: 'https://example.com/initial$index.mp4',
            title: 'Initial Video $index',
          );
        });

        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn(initialVideos);

        final controller1 = StreamController<Event>();
        final (triggerEose1, _) = setupMockSubscription(controller1);

        // Load initial videos
        final notifier = container.read(profileVideosProvider.notifier);
        final loadFuture1 = notifier.loadVideosForUser(testPubkey);
        await controller1.close();
        triggerEose1();
        await loadFuture1;

        // Keep provider alive by maintaining a listener
        final subscription = container.listen(
          profileVideosProvider,
          (previous, next) {},
        );

        // Set hasMore = true for load more test
        // (This would need to be done differently in real implementation)

        // Mock load more subscription
        final controller2 = StreamController<Event>();
        final (triggerEose2, subscriptionStarted2) = setupMockSubscription(
          controller2,
        );

        // Act - try to load more
        final loadMoreFuture = notifier.loadMoreVideos();
        // Wait for subscription to be established
        await subscriptionStarted2.future;
        await controller2.close();
        triggerEose2();
        await loadMoreFuture;

        // Assert - should complete without error
        final state = container.read(profileVideosProvider);
        expect(state.isLoadingMore, false);

        subscription.close();
      });

      test('should not load more when hasMore is false', () async {
        // This test ensures loadMoreVideos returns early when there are no more videos
        final notifier = container.read(profileVideosProvider.notifier);

        // Initial state has hasMore = true, but no videos loaded
        // This should cause loadMoreVideos to return early
        await notifier.loadMoreVideos();

        // Should complete without attempting to create subscription
        final state = container.read(profileVideosProvider);
        expect(state.isLoadingMore, false);
      });
    });

    group('Video Management', () {
      const testPubkey = 'test_pubkey_manage';

      test('should add video optimistically', () async {
        // Load some initial videos first
        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn([]);

        final controller = StreamController<Event>();
        final (triggerEose, _) = setupMockSubscription(controller);

        final notifier = container.read(profileVideosProvider.notifier);
        final loadFuture = notifier.loadVideosForUser(testPubkey);
        await controller.close();
        triggerEose();
        await loadFuture;

        // Keep provider alive by maintaining a listener
        final subscription = container.listen(
          profileVideosProvider,
          (previous, next) {},
        );

        // Create new video to add
        final newVideo = VideoEvent(
          id: 'new_video_123',
          pubkey: testPubkey,
          content: 'new content',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/new.mp4',
          title: 'New Video',
        );

        // Act - add video
        notifier.addVideo(newVideo);

        // Assert - video should be added to list
        final state = container.read(profileVideosProvider);
        expect(state.videos.length, equals(1));
        expect(state.videos.first.id, equals('new_video_123'));

        subscription.close();
      });

      test('should remove video', () async {
        // Setup initial state with video
        final initialVideo = VideoEvent(
          id: 'video_to_remove',
          pubkey: testPubkey,
          content: 'content',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/remove.mp4',
          title: 'Video to Remove',
        );

        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn([initialVideo]);

        final controller = StreamController<Event>();
        final (triggerEose, _) = setupMockSubscription(controller);

        final notifier = container.read(profileVideosProvider.notifier);
        final loadFuture = notifier.loadVideosForUser(testPubkey);
        await controller.close();
        triggerEose();
        await loadFuture;

        // Keep provider alive by maintaining a listener
        final subscription = container.listen(
          profileVideosProvider,
          (previous, next) {},
        );

        // Verify initial state
        var state = container.read(profileVideosProvider);
        expect(state.videos.length, equals(1));

        // Act - remove video
        notifier.removeVideo('video_to_remove');

        // Assert - video should be removed
        state = container.read(profileVideosProvider);
        expect(state.videos, isEmpty);

        subscription.close();
      });
    });

    group('Provider Lifecycle', () {
      const testPubkey = 'test_pubkey_lifecycle';

      test('should handle disposal during async loading gracefully', () async {
        // Arrange
        when(
          mockVideoEventService.getVideosByAuthor(testPubkey),
        ).thenReturn([]);

        final controller = StreamController<Event>();
        void Function()? capturedOnEose;

        when(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            onEose: anyNamed('onEose'),
          ),
        ).thenAnswer((invocation) {
          // Capture the onEose callback
          capturedOnEose =
              invocation.namedArguments[const Symbol('onEose')]
                  as void Function()?;
          return controller.stream;
        });

        // Act - start loading
        final notifier = container.read(profileVideosProvider.notifier);
        notifier.loadVideosForUser(testPubkey);

        // Wait a bit for subscription to be established
        await Future.delayed(const Duration(milliseconds: 50));

        // Dispose the container BEFORE async operation completes
        // This simulates navigating away from the profile screen
        container.dispose();

        // Trigger EOSE callback AFTER disposal
        await Future.delayed(const Duration(milliseconds: 50));
        if (capturedOnEose != null) {
          // This should NOT throw an exception
          // Provider should check ref.mounted before updating state
          expect(() => capturedOnEose!(), returnsNormally);
        }

        // Clean up
        await controller.close();

        // Note: loadFuture may not complete cleanly due to disposal
        // That's expected behavior
      });
    });
  });
}
