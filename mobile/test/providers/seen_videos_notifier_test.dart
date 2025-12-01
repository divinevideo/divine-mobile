// ABOUTME: Tests for SeenVideosNotifier Riverpod state management
// ABOUTME: Validates reactive state updates and provider integration

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SeenVideosNotifier', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes with empty state', () async {
      final container = ProviderContainer();

      final initialState = container.read(seenVideosProvider);

      expect(initialState.seenVideoIds, isEmpty);
      expect(initialState.isInitialized, isFalse);

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(seenVideosProvider);
      expect(state.isInitialized, isTrue);

      container.dispose();
    });

    test('marks video as seen and updates state', () async {
      final container = ProviderContainer();

      final notifier = container.read(seenVideosProvider.notifier);

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      const videoId = 'test_video_123';
      await notifier.markVideoAsSeen(videoId);

      final state = container.read(seenVideosProvider);
      expect(state.seenVideoIds, contains(videoId));

      container.dispose();
    });

    test('hasSeenVideo returns correct state', () async {
      final container = ProviderContainer();

      final notifier = container.read(seenVideosProvider.notifier);

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      const videoId = 'test_video_456';

      expect(notifier.hasSeenVideo(videoId), isFalse);

      await notifier.markVideoAsSeen(videoId);

      expect(notifier.hasSeenVideo(videoId), isTrue);

      container.dispose();
    });

    test('records video view with metrics', () async {
      final container = ProviderContainer();

      final notifier = container.read(seenVideosProvider.notifier);

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      const videoId = 'test_video_789';

      await notifier.recordVideoView(
        videoId,
        loopCount: 3,
        watchDuration: const Duration(seconds: 45),
      );

      expect(notifier.hasSeenVideo(videoId), isTrue);

      final state = container.read(seenVideosProvider);
      expect(state.seenVideoIds, contains(videoId));

      container.dispose();
    });

    test('does not duplicate seen videos', () async {
      final container = ProviderContainer();

      final notifier = container.read(seenVideosProvider.notifier);

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      const videoId = 'duplicate_video';

      await notifier.markVideoAsSeen(videoId);
      await notifier.markVideoAsSeen(videoId);
      await notifier.markVideoAsSeen(videoId);

      final state = container.read(seenVideosProvider);
      expect(state.seenVideoIds.where((id) => id == videoId).length, 1);

      container.dispose();
    });

    test('state updates trigger provider listeners', () async {
      final container = ProviderContainer();

      final notifier = container.read(seenVideosProvider.notifier);

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      var listenerCallCount = 0;
      container.listen(seenVideosProvider, (_, __) => listenerCallCount++);

      const videoId = 'listener_test_video';
      await notifier.markVideoAsSeen(videoId);

      expect(listenerCallCount, greaterThan(0));

      container.dispose();
    });

    test('persists state across notifier instances', () async {
      // First container
      final container1 = ProviderContainer();
      final notifier1 = container1.read(seenVideosProvider.notifier);

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      const videoId = 'persistent_video';
      await notifier1.markVideoAsSeen(videoId);

      container1.dispose();

      // Second container
      final container2 = ProviderContainer();

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      final notifier2 = container2.read(seenVideosProvider.notifier);
      expect(notifier2.hasSeenVideo(videoId), isTrue);

      container2.dispose();
    });
  });
}
