// ABOUTME: Test for search screen navigation to user profiles and hashtag feeds
// ABOUTME: Ensures users can tap search results to navigate to profiles and hashtag feeds

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

// Mock VideoEvents stream provider
class MockVideoEvents extends VideoEvents {
  MockVideoEvents(this.mockEvents);
  final List<VideoEvent> mockEvents;

  @override
  Stream<List<VideoEvent>> build() async* {
    yield mockEvents;
  }
}

void main() {
  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
  );

  String currentLocation(ProviderContainer c) {
    final router = c.read(goRouterProvider);
    return router.routeInformationProvider.value.uri.toString();
  }

  group('SearchScreenPure Navigation', () {
    late List<VideoEvent> testVideos;

    setUp(() {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;

      testVideos = [
        VideoEvent(
          id: 'video1',
          pubkey: 'user123',
          content: 'Test video about #flutter development',
          title: 'Flutter Tutorial',
          videoUrl: 'https://example.com/video1.mp4',
          createdAt: timestamp,
          timestamp: now,
          hashtags: ['flutter', 'development'],
        ),
        VideoEvent(
          id: 'video2',
          pubkey: 'user456',
          content: 'Another video about #dart programming',
          title: 'Dart Guide',
          videoUrl: 'https://example.com/video2.mp4',
          createdAt: timestamp,
          timestamp: now,
          hashtags: ['dart', 'programming'],
        ),
      ];
    });

    testWidgets('tapping user in search results navigates to profile screen', (
      WidgetTester tester,
    ) async {
      final user123Npub = NostrKeyUtils.encodePubKey('user123');

      // Arrange: Setup provider override with test videos
      final c = ProviderContainer(
        overrides: [
          videoEventsProvider.overrideWith(() => MockVideoEvents(testVideos)),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Navigate to explore (where search is accessible)
      c.read(goRouterProvider).push('/explore/0');
      await tester.pump();
      await tester.pump();

      // Wait for initial build and async data
      await tester.pumpAndSettle();

      // Act: Enter search query to find users
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'user');

      // Wait for debounce timer (300ms) + several frames for async processing
      await tester.pump(const Duration(milliseconds: 400));
      for (int i = 0; i < 10; i++) {
        await tester.pump();
      }

      // Switch to Users tab
      final usersTab = find.textContaining('Users');
      expect(usersTab, findsOneWidget, reason: 'Should find Users tab');
      await tester.tap(usersTab);
      await tester.pump();
      await tester.pump();

      // Tap on first user
      final userTile = find.byType(ListTile).first;
      await tester.tap(userTile);
      await tester.pump();
      await tester.pump();

      // Assert: Verify router navigated to profile
      expect(currentLocation(c), contains('/profile/$user123Npub'));
    });

    testWidgets('tapping hashtag in search results navigates to hashtag feed', (
      WidgetTester tester,
    ) async {
      // Arrange: Setup provider override with test videos
      final c = ProviderContainer(
        overrides: [
          videoEventsProvider.overrideWith(() => MockVideoEvents(testVideos)),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Navigate to explore (where search is accessible)
      c.read(goRouterProvider).push('/explore/0');
      await tester.pump();
      await tester.pump();

      // Wait for initial build and async data
      await tester.pumpAndSettle();

      // Act: Enter search query to find hashtags
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'flutter');

      // Wait for debounce timer (300ms) + several frames for async processing
      await tester.pump(const Duration(milliseconds: 400));
      for (int i = 0; i < 10; i++) {
        await tester.pump();
      }

      // Switch to Hashtags tab
      final hashtagsTab = find.textContaining('Hashtags');
      expect(hashtagsTab, findsOneWidget, reason: 'Should find Hashtags tab');
      await tester.tap(hashtagsTab);
      await tester.pump();
      await tester.pump();

      // Tap on first hashtag
      final hashtagTile = find.byType(ListTile).first;
      await tester.tap(hashtagTile);
      await tester.pump();
      await tester.pump();

      // Assert: Verify router navigated to hashtag feed
      expect(currentLocation(c), contains('/hashtag/flutter'));
    });
  });
}
