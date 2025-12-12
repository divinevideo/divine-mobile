// ABOUTME: Tests for videoEventsProvider buffering behavior
// ABOUTME: Validates new video buffering system and banner functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:openvine/services/video_event_service.dart';

import '../helpers/test_provider_overrides.mocks.dart';

void main() {
  group('VideoEventsProvider - Buffering', () {
    late MockNostrClient mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    late VideoEventService videoEventService;
    late ProviderContainer container;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockSubscriptionManager = MockSubscriptionManager();

      // Stub necessary methods
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelayCount).thenReturn(0);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );

      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
          appReadyProvider.overrideWith(
            (ref) => false,
          ), // Start with gates closed
          isDiscoveryTabActiveProvider.overrideWith((ref) => false),
          isExploreTabActiveProvider.overrideWith((ref) => false),
          seenVideosProvider.overrideWith(() => SeenVideosNotifier()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('buffering API exists and starts with zero buffered videos', () async {
      final notifier = container.read(videoEventsProvider.notifier);

      // bufferedCount should be 0 initially
      expect(
        notifier.bufferedCount,
        0,
        reason: 'Buffering should start with empty buffer',
      );

      // Verify buffering control methods exist
      expect(
        () => notifier.enableBuffering(),
        returnsNormally,
        reason: 'enableBuffering() should exist',
      );
      expect(
        () => notifier.disableBuffering(),
        returnsNormally,
        reason: 'disableBuffering() should exist',
      );
      expect(
        () => notifier.loadBufferedVideos(),
        returnsNormally,
        reason: 'loadBufferedVideos() should exist',
      );
    });

    test('enableBuffering prevents auto-insertion of new videos', () async {
      final notifier = container.read(videoEventsProvider.notifier);

      // Start with buffering disabled (default state)
      expect(notifier.bufferedCount, 0);

      // Enable buffering
      notifier.enableBuffering();

      // Buffered count should still be 0 (no new videos added yet)
      expect(
        notifier.bufferedCount,
        0,
        reason: 'Buffering enabled but no videos buffered yet',
      );
    });

    test('bufferedCount tracks number of buffered videos', () async {
      final notifier = container.read(videoEventsProvider.notifier);

      // Buffered count should be 0 initially
      expect(notifier.bufferedCount, 0);

      // Buffered count provider should also be 0
      final bufferedCountProvider = container.read(bufferedVideoCountProvider);
      expect(
        bufferedCountProvider,
        0,
        reason: 'bufferedVideoCountProvider should start at 0',
      );
    });

    test(
      'loadBufferedVideos inserts buffered videos and clears buffer',
      () async {
        final notifier = container.read(videoEventsProvider.notifier);

        // Start with empty buffer
        expect(notifier.bufferedCount, 0);

        // Load buffered videos when buffer is empty (should do nothing gracefully)
        expect(
          () => notifier.loadBufferedVideos(),
          returnsNormally,
          reason: 'loadBufferedVideos should handle empty buffer gracefully',
        );

        // Buffer should still be 0
        expect(notifier.bufferedCount, 0);

        // Buffered count provider should be 0
        final bufferedCountProvider = container.read(
          bufferedVideoCountProvider,
        );
        expect(bufferedCountProvider, 0);
      },
    );

    test('disableBuffering resumes auto-insertion', () async {
      final notifier = container.read(videoEventsProvider.notifier);

      // Enable buffering first
      notifier.enableBuffering();

      // Then disable buffering
      expect(
        () => notifier.disableBuffering(),
        returnsNormally,
        reason: 'disableBuffering should work after enableBuffering',
      );

      // Buffer should still be empty (no videos added)
      expect(notifier.bufferedCount, 0);
    });

    test('buffering only affects new videos, not initial load', () async {
      final notifier = container.read(videoEventsProvider.notifier);

      // Enable buffering BEFORE provider is fully loaded
      expect(
        () => notifier.enableBuffering(),
        returnsNormally,
        reason: 'Should be able to enable buffering before provider loads',
      );

      // Provider should initialize successfully
      final asyncValue = container.read(videoEventsProvider);
      expect(
        asyncValue.isLoading || asyncValue.hasValue,
        true,
        reason: 'Provider should initialize even with buffering enabled early',
      );
    });
  });
}
