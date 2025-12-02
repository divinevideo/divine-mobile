// ABOUTME: Test to reproduce home feed empty state bug when videos are loaded
// ABOUTME: Verifies UI shows videos after contact list and home feed load

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/social_providers.dart' as social;
import 'package:openvine/screens/video_feed_screen.dart';
import 'package:openvine/state/social_state.dart';
import 'package:openvine/state/video_feed_state.dart';
import '../helpers/test_provider_overrides.dart';

void main() {
  group('Home Feed Display Bug', () {
    testWidgets(
      'FAILING: should NOT show empty state when contact list loads and videos are available',
      (tester) async {
        // Create test videos
        final now = DateTime.now();
        final testVideos = [
          VideoEvent(
            id: 'video1',
            pubkey: 'author1',
            content: 'Test video 1',
            createdAt:
                now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
            timestamp: now.subtract(const Duration(hours: 1)),
            vineId: 'd1',
            videoUrl: 'https://example.com/video1.mp4',
            thumbnailUrl: null,
          ),
          VideoEvent(
            id: 'video2',
            pubkey: 'author2',
            content: 'Test video 2',
            createdAt:
                now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/
                1000,
            timestamp: now.subtract(const Duration(hours: 2)),
            vineId: 'd2',
            videoUrl: 'https://example.com/video2.mp4',
            thumbnailUrl: null,
          ),
        ];

        // Create a container with mocked providers
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(),
            // Mock social provider with following list
            social.socialProvider.overrideWith(() {
              return _TestSocialNotifier(
                SocialState(
                  followingPubkeys: ['author1', 'author2'],
                  isInitialized: true,
                  isLoading: false,
                ),
              );
            }),
            // Mock home feed provider with videos
            homeFeedProvider.overrideWith(() {
              return _TestHomeFeedNotifier(
                AsyncData(
                  VideoFeedState(
                    videos: testVideos,
                    hasMoreContent: false,
                    isLoadingMore: false,
                    error: null,
                    lastUpdated: DateTime.now(),
                  ),
                ),
              );
            }),
          ],
        );

        // Build the widget
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: VideoFeedScreen()),
          ),
        );

        // Allow async providers to settle
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Debug: Print what's on screen
        final emptyStateText = find.text('Your Feed, Your Choice');
        final videoWidgets = find.byType(PageView);

        debugPrint(
          'Empty state found: ${emptyStateText.evaluate().isNotEmpty}',
        );
        debugPrint('PageView found: ${videoWidgets.evaluate().isNotEmpty}');

        // ASSERTION: Should show videos, NOT empty state
        expect(
          emptyStateText,
          findsNothing,
          reason:
              'Should NOT show "Your Feed, Your Choice" empty state when videos are loaded',
        );

        expect(
          videoWidgets,
          findsOneWidget,
          reason: 'Should show PageView with videos from home feed',
        );
      },
    );

    testWidgets('should show empty state when user is not following anyone', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          // Mock social provider with NO following list
          social.socialProvider.overrideWith(() {
            return _TestSocialNotifier(
              const SocialState(
                followingPubkeys: [], // Empty following list
                isInitialized: true,
                isLoading: false,
              ),
            );
          }),
          // Mock home feed provider with no videos
          homeFeedProvider.overrideWith(() {
            return _TestHomeFeedNotifier(
              AsyncData(
                VideoFeedState(
                  videos: const [],
                  hasMoreContent: false,
                  isLoadingMore: false,
                  error: null,
                  lastUpdated: DateTime.now(),
                ),
              ),
            );
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VideoFeedScreen()),
        ),
      );

      await tester.pump();

      // SHOULD show empty state when not following anyone
      expect(find.text('Your Feed, Your Choice'), findsOneWidget);
      expect(find.text('Explore Vines'), findsOneWidget);
    });
  });
}

// Test helper classes
class _TestSocialNotifier extends social.SocialNotifier {
  _TestSocialNotifier(this._initialState);

  final SocialState _initialState;

  @override
  SocialState build() => _initialState;
}

class _TestHomeFeedNotifier extends HomeFeed {
  _TestHomeFeedNotifier(this._state);

  final AsyncValue<VideoFeedState> _state;

  @override
  Future<VideoFeedState> build() async {
    return _state.when(
      data: (data) => data,
      loading: () => VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: null,
        lastUpdated: null,
      ),
      error: (error, stack) => VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: error.toString(),
        lastUpdated: null,
      ),
    );
  }
}
