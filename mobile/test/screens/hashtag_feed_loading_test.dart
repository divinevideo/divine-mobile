// ABOUTME: Tests for hashtag feed loading states and per-subscription loading behavior
// ABOUTME: Verifies that hashtag feeds use per-subscription loading state, not global state

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/providers/app_providers.dart';

import 'hashtag_feed_loading_test.mocks.dart';

@GenerateMocks([VideoEventService, HashtagService])
void main() {
  group('HashtagFeedScreen Per-Subscription Loading States', () {
    late MockVideoEventService mockVideoEventService;
    late MockHashtagService mockHashtagService;

    setUp(() {
      mockVideoEventService = MockVideoEventService();
      mockHashtagService = MockHashtagService();

      // Setup default mock behavior
      when(mockVideoEventService.isLoading).thenReturn(false);
      when(
        mockVideoEventService.isLoadingForSubscription(any),
      ).thenReturn(false);
      when(mockHashtagService.getVideosByHashtags(any)).thenReturn([]);
      when(
        mockHashtagService.subscribeToHashtagVideos(any),
      ).thenAnswer((_) async {});
    });

    Widget buildTestWidget(String hashtag) {
      return ProviderScope(
        overrides: [
          videoEventServiceProvider.overrideWith(
            (ref) => mockVideoEventService,
          ),
          hashtagServiceProvider.overrideWith((ref) => mockHashtagService),
        ],
        child: MaterialApp(home: HashtagFeedScreen(hashtag: hashtag)),
      );
    }

    testWidgets(
      'shows loading indicator when per-subscription state is loading and cache is empty',
      (tester) async {
        const testHashtag = 'nostr';

        // Mock per-subscription loading state (to be implemented)
        when(
          mockVideoEventService.isLoadingForSubscription(
            SubscriptionType.hashtag,
          ),
        ).thenReturn(true);
        when(
          mockVideoEventService.isLoading,
        ).thenReturn(false); // Global state not loading
        when(mockHashtagService.getVideosByHashtags(['nostr'])).thenReturn([]);

        await tester.pumpWidget(buildTestWidget(testHashtag));
        await tester.pump(); // Let initState run

        // Should show loading indicator based on per-subscription state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.text('Loading videos about #$testHashtag...'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'does NOT show loading when global isLoading=true but per-subscription is false',
      (tester) async {
        const testHashtag = 'bitcoin';

        // Global loading is true (other subscriptions loading)
        when(mockVideoEventService.isLoading).thenReturn(true);
        // But per-subscription loading is false (hashtag subscription complete)
        when(
          mockVideoEventService.isLoadingForSubscription(
            SubscriptionType.hashtag,
          ),
        ).thenReturn(false);
        when(
          mockHashtagService.getVideosByHashtags(['bitcoin']),
        ).thenReturn([]);

        await tester.pumpWidget(buildTestWidget(testHashtag));
        await tester.pump();

        // Should NOT show loading indicator (proves using per-subscription state)
        expect(
          find.text('Loading videos about #$testHashtag...'),
          findsNothing,
        );
        // Should show empty state instead
        expect(find.text('No videos found for #$testHashtag'), findsOneWidget);
      },
    );

    testWidgets('subscribes to hashtag videos on screen initialization', (
      tester,
    ) async {
      const testHashtag = 'test';

      await tester.pumpWidget(buildTestWidget(testHashtag));
      await tester.pump(); // Let initState and postFrameCallback run

      // Should have called subscription with the hashtag
      verify(mockHashtagService.subscribeToHashtagVideos(['test'])).called(1);
    });
  });
}
