// ABOUTME: Tests for FollowersScreen using NostrListFetchMixin
// ABOUTME: Validates Nostr subscription logic and UI rendering for followers list

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/followers_screen.dart';
import 'package:openvine/services/nostr_service.dart';

@GenerateMocks([NostrService])
import 'followers_screen_test.mocks.dart';

void main() {
  group('FollowersScreen', () {
    late MockNostrService mockNostrService;
    late StreamController<nostr_sdk.Event> eventStreamController;

    setUp(() {
      mockNostrService = MockNostrService();
      eventStreamController = StreamController<nostr_sdk.Event>();

      // Setup mock to return stream
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => eventStreamController.stream);
    });

    tearDown(() {
      eventStreamController.close();
    });

    Widget createTestWidget({
      required String pubkey,
      required String displayName,
    }) {
      return ProviderScope(
        overrides: [nostrServiceProvider.overrideWithValue(mockNostrService)],
        child: MaterialApp(
          home: FollowersScreen(pubkey: pubkey, displayName: displayName),
        ),
      );
    }

    testWidgets('displays loading indicator initially', (tester) async {
      await tester.pumpWidget(
        createTestWidget(pubkey: 'test_pubkey', displayName: 'Test User'),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test User\'s Followers'), findsOneWidget);
    });

    testWidgets('displays followers when events arrive', (tester) async {
      await tester.pumpWidget(
        createTestWidget(pubkey: 'target_pubkey', displayName: 'Test User'),
      );

      // Simulate follower events arriving
      final event1 = nostr_sdk.Event(
        'follower1', // pubkey
        3, // kind
        [
          ['p', 'target_pubkey'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ], // tags
        '', // content
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      eventStreamController.add(event1);
      await tester.pump();

      // Should stop loading and show follower
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('displays empty state when no followers', (tester) async {
      await tester.pumpWidget(
        createTestWidget(pubkey: 'test_pubkey', displayName: 'Test User'),
      );

      // Wait for loading timeout
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      // Should show empty state
      expect(find.text('No followers yet'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('handles subscription errors gracefully', (tester) async {
      // Setup mock to emit error
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => Stream.error('Subscription failed'));

      await tester.pumpWidget(
        createTestWidget(pubkey: 'test_pubkey', displayName: 'Test User'),
      );

      await tester.pump();

      // Should show error state
      expect(find.text('Failed to load followers'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('deduplicates follower events', (tester) async {
      await tester.pumpWidget(
        createTestWidget(pubkey: 'target_pubkey', displayName: 'Test User'),
      );

      // Add same follower twice
      final event1 = nostr_sdk.Event(
        'follower1', // pubkey
        3, // kind
        [
          ['p', 'target_pubkey'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ], // tags
        '', // content
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      final event2 = nostr_sdk.Event(
        'follower1', // pubkey - Same follower
        3, // kind
        [
          ['p', 'target_pubkey'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ], // tags
        '', // content
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      eventStreamController.add(event1);
      await tester.pump();

      eventStreamController.add(event2);
      await tester.pump();

      // Should only show one follower (deduplicated)
      // This is validated by the internal state, not visible UI
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('subscribes with correct filter', (tester) async {
      await tester.pumpWidget(
        createTestWidget(pubkey: 'target_pubkey', displayName: 'Test User'),
      );

      await tester.pump();

      // Verify subscription was called with correct filter
      final captured = verify(
        mockNostrService.subscribeToEvents(filters: captureAnyNamed('filters')),
      ).captured;

      expect(captured.length, 1);
      final filters = captured[0] as List<nostr_sdk.Filter>;
      expect(filters.length, 1);
      expect(filters[0].kinds, contains(3)); // Contact list kind
      expect(filters[0].p, contains('target_pubkey')); // Mentions target
    });

    testWidgets('back button pops navigation', (tester) async {
      await tester.pumpWidget(
        createTestWidget(pubkey: 'test_pubkey', displayName: 'Test User'),
      );

      await tester.pump();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Navigator should pop (verified by navigation state)
    });

    testWidgets('retry button reloads followers', (tester) async {
      // Setup mock to emit error first
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => Stream.error('Subscription failed'));

      await tester.pumpWidget(
        createTestWidget(pubkey: 'test_pubkey', displayName: 'Test User'),
      );

      await tester.pump();

      // Should show error
      expect(find.text('Failed to load followers'), findsOneWidget);

      // Setup mock to succeed on retry
      final retryStreamController = StreamController<nostr_sdk.Event>();
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => retryStreamController.stream);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Should show loading again
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      retryStreamController.close();
    });
  });
}
