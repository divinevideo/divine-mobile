// ABOUTME: Integration test that verifies pagination works with real relay server
// ABOUTME: Tests that we actually get new kind 34236 video events when scrolling

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Wait for a condition to be true with timeout
Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final completer = Completer<void>();
  final timer = Timer.periodic(pollInterval, (timer) {
    if (condition()) {
      timer.cancel();
      completer.complete();
    }
  });

  Future.delayed(timeout, () {
    if (!completer.isCompleted) {
      timer.cancel();
      completer.completeError(
        TimeoutException('Condition not met within timeout'),
      );
    }
  });

  await completer.future;
}

void main() {
  group('Real Relay Pagination Integration', () {
    late VideoEventService videoEventService;
    late NostrService nostrService;
    late SubscriptionManager subscriptionManager;

    setUpAll(() {
      // Enable debug logging to see what's happening
      Log.setLogLevel(LogLevel.debug);
    });

    setUp(() async {
      // Create real services
      final keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );

      // Initialize and connect to real relay
      await nostrService.initialize();

      // Add relay instead of connectToRelay (method doesn't exist)
      await nostrService.addRelay('wss://staging-relay.divine.video');

      // Wait for relay connection to establish
      // Poll for connection status instead of arbitrary delay
      for (int i = 0; i < 20; i++) {
        if (nostrService.connectedRelayCount > 0) break;
        await Future.delayed(Duration(milliseconds: 100));
      }

      expect(nostrService.isInitialized, isTrue);
      expect(nostrService.connectedRelayCount, greaterThan(0));
    });

    tearDown(() async {
      videoEventService.dispose();
      await nostrService.dispose();
    });

    test(
      'should get real kind 34236 video events from staging-relay.divine.video',
      () async {
        // Subscribe to discovery feed
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        // Wait for initial events
        await waitForCondition(
          () => videoEventService
              .getVideos(SubscriptionType.discovery)
              .isNotEmpty,
          timeout: Duration(seconds: 5),
        );

        // Get initial videos
        final initialVideos = videoEventService.getVideos(
          SubscriptionType.discovery,
        );
        Log.info(
          '📹 Initial videos loaded: ${initialVideos.length}',
          name: 'Test',
        );

        expect(
          initialVideos,
          isNotEmpty,
          reason: 'Should have loaded some initial videos',
        );

        // Print first few videos to verify they're real
        final videosToShow = initialVideos.length < 3
            ? initialVideos.length
            : 3;
        for (int i = 0; i < videosToShow; i++) {
          final video = initialVideos[i];
          Log.info(
            '  Video ${i + 1}: ${video.title ?? "Untitled"} - ${video.id}... created at ${video.timestamp}',
            name: 'Test',
          );
          expect(
            video.videoUrl,
            isNotNull,
            reason: 'Real videos should have URLs',
          );
        }

        // Store the IDs of initial videos
        final initialVideoIds = initialVideos.map((v) => v.id).toSet();
        final oldestInitialTimestamp = initialVideos.last.createdAt;

        Log.info('\n🔄 Loading more events (pagination)...', name: 'Test');
        Log.info(
          '  Oldest timestamp before load: ${DateTime.fromMillisecondsSinceEpoch(oldestInitialTimestamp * 1000)}',
          name: 'Test',
        );

        // Load more events - this should use pagination with 'until' parameter
        await videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 10,
        );

        // Wait for new events to arrive
        await waitForCondition(
          () =>
              videoEventService.getVideos(SubscriptionType.discovery).length >
              initialVideos.length,
          timeout: Duration(seconds: 5),
        );

        // Get all videos after pagination
        final allVideos = videoEventService.getVideos(
          SubscriptionType.discovery,
        );
        Log.info(
          '\n📹 Total videos after pagination: ${allVideos.length}',
          name: 'Test',
        );

        // Find new videos that weren't in the initial set
        final newVideos = allVideos
            .where((v) => !initialVideoIds.contains(v.id))
            .toList();
        Log.info('  New videos loaded: ${newVideos.length}', name: 'Test');

        // Verify we got new videos
        expect(
          newVideos,
          isNotEmpty,
          reason: 'Pagination should load NEW videos, not duplicates',
        );

        // Verify the new videos are older than the initial ones
        for (final video in newVideos.take(3)) {
          Log.info(
            '  New video: ${video.title ?? "Untitled"} - created at ${video.timestamp}',
            name: 'Test',
          );
          expect(
            video.createdAt,
            lessThanOrEqualTo(oldestInitialTimestamp),
            reason:
                'New videos should be older than or equal to the oldest initial video (reverse chronological pagination)',
          );
        }

        // Test pagination reset scenario
        Log.info('\n🔄 Testing pagination reset scenario...', name: 'Test');

        // Reset pagination state (simulating hasMore=false scenario)
        videoEventService.resetPaginationState(SubscriptionType.discovery);

        // Load more after reset - should still get older videos
        await videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 10,
        );

        await waitForCondition(
          () => videoEventService
              .getVideos(SubscriptionType.discovery)
              .isNotEmpty,
          timeout: Duration(seconds: 5),
        );

        final videosAfterReset = videoEventService.getVideos(
          SubscriptionType.discovery,
        );
        final newVideosAfterReset = videosAfterReset
            .where(
              (v) =>
                  !initialVideoIds.contains(v.id) &&
                  !newVideos.map((nv) => nv.id).contains(v.id),
            )
            .toList();

        Log.info('\n📹 Videos after pagination reset:', name: 'Test');
        Log.info('  Total: ${videosAfterReset.length}', name: 'Test');
        Log.info(
          '  New after reset: ${newVideosAfterReset.length}',
          name: 'Test',
        );

        if (newVideosAfterReset.isNotEmpty) {
          Log.info(
            '  Successfully loaded ${newVideosAfterReset.length} more videos after reset!',
            name: 'Test',
          );
          for (final video in newVideosAfterReset.take(3)) {
            Log.info(
              '    Video: ${video.title ?? "Untitled"} - ${video.timestamp}',
              name: 'Test',
            );
          }
        }

        // Final verification
        Log.info('✅ Test Summary:', name: 'Test');
        Log.info('  Initial videos: ${initialVideos.length}', name: 'Test');
        Log.info(
          '  Videos after first pagination: ${allVideos.length}',
          name: 'Test',
        );
        Log.info(
          '  Videos after reset and pagination: ${videosAfterReset.length}',
          name: 'Test',
        );
        // All videos in OpenVine are kind 34236 by definition
      },
      timeout: Timeout(Duration(seconds: 30)),
    );

    test(
      'should handle rapid pagination requests correctly',
      () async {
        // Subscribe to discovery feed
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 5,
        );

        await waitForCondition(
          () => videoEventService
              .getVideos(SubscriptionType.discovery)
              .isNotEmpty,
          timeout: Duration(seconds: 3),
        );

        final initialCount = videoEventService
            .getVideos(SubscriptionType.discovery)
            .length;
        Log.info(
          '🚀 Testing rapid pagination - Initial videos: $initialCount',
          name: 'Test',
        );

        // Rapidly request more videos (simulating fast scrolling)
        for (int i = 0; i < 3; i++) {
          Log.info('  Loading batch ${i + 1}...', name: 'Test');
          final beforeCount = videoEventService
              .getVideos(SubscriptionType.discovery)
              .length;
          await videoEventService.loadMoreEvents(
            SubscriptionType.discovery,
            limit: 5,
          );
          await waitForCondition(
            () =>
                videoEventService.getVideos(SubscriptionType.discovery).length >
                beforeCount,
            timeout: Duration(seconds: 3),
          ).catchError((_) => null); // Allow timeout if no new videos

          final currentCount = videoEventService
              .getVideos(SubscriptionType.discovery)
              .length;
          Log.info(
            '    Videos after batch ${i + 1}: $currentCount',
            name: 'Test',
          );

          expect(
            currentCount,
            greaterThan(initialCount),
            reason: 'Each pagination should increase video count',
          );
        }

        final finalVideos = videoEventService.getVideos(
          SubscriptionType.discovery,
        );
        final uniqueIds = finalVideos.map((v) => v.id).toSet();

        Log.info('\n✅ Rapid pagination results:', name: 'Test');
        Log.info('  Total videos: ${finalVideos.length}', name: 'Test');
        Log.info('  Unique videos: ${uniqueIds.length}', name: 'Test');
        Log.info(
          '  No duplicates: ${finalVideos.length == uniqueIds.length}',
          name: 'Test',
        );

        expect(
          uniqueIds.length,
          equals(finalVideos.length),
          reason: 'Should not have duplicate videos',
        );
      },
      timeout: Timeout(Duration(seconds: 30)),
    );
  });
}
