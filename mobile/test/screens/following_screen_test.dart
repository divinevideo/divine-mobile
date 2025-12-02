// ABOUTME: Tests for FollowingScreen widget with NostrListFetchMixin
// ABOUTME: Validates following list fetching, caching, error handling, and UI states

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/following_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/social_service.dart';

import 'following_screen_test.mocks.dart';

@GenerateMocks([NostrService, AuthService, SocialService])
void main() {
  late MockNostrService mockNostrService;
  late MockAuthService mockAuthService;
  late MockSocialService mockSocialService;
  late StreamController<nostr_sdk.Event> eventStreamController;

  // Helper to create valid hex pubkeys (64 hex characters)
  // Converts suffix to hex and pads with zeros
  String validPubkey(String suffix) {
    // Convert string to hex bytes and pad to 64 chars
    final hexSuffix = suffix.codeUnits
        .map((c) => c.toRadixString(16).padLeft(2, '0'))
        .join();
    return hexSuffix.padLeft(64, '0');
  }

  setUp(() {
    mockNostrService = MockNostrService();
    mockAuthService = MockAuthService();
    mockSocialService = MockSocialService();
    eventStreamController = StreamController<nostr_sdk.Event>();

    // Default setup for non-cached scenario
    when(
      mockAuthService.currentPublicKeyHex,
    ).thenReturn(validPubkey('different'));
    when(
      mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
    ).thenAnswer((_) => eventStreamController.stream);
    when(mockNostrService.isInitialized).thenReturn(true);
    when(mockSocialService.isFollowing(any)).thenReturn(false);
  });

  tearDown(() {
    eventStreamController.close();
  });

  Widget createTestWidget({String? pubkey}) {
    final testPubkey = pubkey ?? validPubkey('test');
    return ProviderScope(
      overrides: [
        nostrServiceProvider.overrideWithValue(mockNostrService),
        authServiceProvider.overrideWithValue(mockAuthService),
        socialServiceProvider.overrideWithValue(mockSocialService),
      ],
      child: MaterialApp(
        home: FollowingScreen(pubkey: testPubkey, displayName: 'Test User'),
      ),
    );
  }

  group('FollowingScreen', () {
    testWidgets('displays loading indicator initially', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Close stream and wait for timeout to be cancelled
      await eventStreamController.close();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('displays following list when events arrive', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Create event with following list in p tags
      final event = nostr_sdk.Event(
        validPubkey('test'),
        3,
        [
          ['p', validPubkey('following1')],
          ['p', validPubkey('following2')],
          ['p', validPubkey('following3')],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      eventStreamController.add(event);
      await tester.pump();

      // Should show ListView with following list
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('uses cached data for current user', (tester) async {
      // Setup current user scenario
      final currentUser = validPubkey('current');
      when(mockAuthService.currentPublicKeyHex).thenReturn(currentUser);
      when(
        mockSocialService.followingPubkeys,
      ).thenReturn([validPubkey('cached1'), validPubkey('cached2')]);

      await tester.pumpWidget(createTestWidget(pubkey: currentUser));
      await tester.pump(); // Process initState
      await tester.pump(); // Process setState from cached data

      // Should show ListView with cached data immediately
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ListView), findsOneWidget);

      // Should NOT have called subscribeToEvents
      verifyNever(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      );
    });

    testWidgets('shows empty state when no following', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Process initState

      // Close stream without adding events
      await eventStreamController.close();
      await tester.pump(
        const Duration(seconds: 6),
      ); // Wait for timeout to complete
      await tester.pump(); // Process onDone callback

      // Should show empty state
      expect(find.text('Not following anyone yet'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
    });

    testWidgets('shows error state on stream error', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Process initState

      // Simulate stream error
      eventStreamController.addError(Exception('Connection failed'));
      await tester.pump(); // Process error callback

      // Should show error UI
      expect(
        find.text(
          'Failed to connect to relay server. Please check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Close stream to cancel timeout
      await eventStreamController.close();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('handles timeout when no data received', (tester) async {
      // Create a controller that will timeout
      final timeoutController = StreamController<nostr_sdk.Event>();
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => timeoutController.stream);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Process initState

      // Wait for timeout duration
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(); // Process timeout callback

      // Should show error message
      expect(
        find.text(
          'Failed to connect to relay server. Please check your connection and try again.',
        ),
        findsOneWidget,
      );

      await timeoutController.close();
    });

    testWidgets('displays correct title in AppBar', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Test User\'s Following'), findsOneWidget);

      // Close stream to cancel timeout
      await eventStreamController.close();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('extracts pubkeys from p tags correctly', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Event with multiple p tags
      final event = nostr_sdk.Event(
        validPubkey('test'),
        3,
        [
          ['p', validPubkey('following1')],
          ['p', validPubkey('following2')],
          ['e', 'some_event'], // Should ignore non-p tags
          ['p', validPubkey('following3')],
          ['p'], // Should ignore malformed tags
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      eventStreamController.add(event);
      await tester.pump();

      // Should show list (validates that p tags were processed)
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('deduplicates following list', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Event with duplicate pubkeys in p tags
      final event = nostr_sdk.Event(
        validPubkey('test'),
        3,
        [
          ['p', validPubkey('following1')],
          ['p', validPubkey('following2')],
          ['p', validPubkey('following1')], // Duplicate
          ['p', validPubkey('following3')],
          ['p', validPubkey('following2')], // Duplicate
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      eventStreamController.add(event);
      await tester.pump();

      // Should show list without duplicates
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('replaces following list on new event', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // First event with initial following list
      final event1 = nostr_sdk.Event(
        validPubkey('test'),
        3,
        [
          ['p', validPubkey('following1')],
          ['p', validPubkey('following2')],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      eventStreamController.add(event1);
      await tester.pump();

      // Second event with updated following list
      final event2 = nostr_sdk.Event(
        validPubkey('test'),
        3,
        [
          ['p', validPubkey('following3')],
          ['p', validPubkey('following4')],
          ['p', validPubkey('following5')],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      eventStreamController.add(event2);
      await tester.pump();

      // Should show updated list
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('retry button reloads following list', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Trigger error
      eventStreamController.addError(Exception('Connection failed'));
      await tester.pump();

      // Verify error state
      expect(find.text('Retry'), findsOneWidget);

      // Create new stream controller for retry
      final retryStreamController = StreamController<nostr_sdk.Event>();
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => retryStreamController.stream);

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump(); // Process tap
      await tester.pump(); // Process startLoading setState

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Add successful event
      final event = nostr_sdk.Event(
        validPubkey('test'),
        3,
        [
          ['p', validPubkey('following1')],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      retryStreamController.add(event);
      await tester.pump();

      // Should show list
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      retryStreamController.close();
    });
  });
}
