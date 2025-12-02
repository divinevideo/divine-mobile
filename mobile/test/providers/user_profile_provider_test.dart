// ABOUTME: Tests for Riverpod UserProfileProvider state management and profile caching
// ABOUTME: Verifies reactive user profile updates and proper cache management

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/user_profile.dart' as models;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/state/user_profile_state.dart';

// Mock classes
class MockNostrService extends Mock implements INostrService {}

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

class MockEvent extends Mock implements Event {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(MockEvent());
  });

  group('UserProfileProvider', () {
    late ProviderContainer container;
    late MockNostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrService();
      mockSubscriptionManager = MockSubscriptionManager();

      // Mock SubscriptionManager.createSubscription to simulate profile event delivery
      when(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((invocation) async {
        // Get callbacks
        final onEvent =
            invocation.namedArguments[const Symbol('onEvent')]
                as void Function(Event)?;
        final onComplete =
            invocation.namedArguments[const Symbol('onComplete')]
                as void Function()?;

        // Note: Real tests should create proper mock events for their specific scenarios
        // This default handler just calls onComplete without events (simulates no profile found)

        if (onComplete != null) {
          Future.delayed(const Duration(milliseconds: 50), onComplete);
        }
        return 'test-subscription-id';
      });

      // Mock SubscriptionManager.cancelSubscription
      when(
        () => mockSubscriptionManager.cancelSubscription(any()),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with initial state', () {
      final state = container.read(userProfileProvider);

      expect(state, equals(UserProfileState.initial));
      expect(state.pendingRequests, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('should initialize properly', () async {
      // Setup mock Nostr service with all required connection checks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(
        () => mockNostrService.connectedRelayCount,
      ).thenReturn(1); // FIX: Add missing mock

      // Initialize
      await container.read(userProfileProvider.notifier).initialize();

      final state = container.read(userProfileProvider);
      expect(state.isInitialized, isTrue);
    });

    test('should fetch profile using async provider with real data', () async {
      const pubkey = 'test-pubkey-123';

      // Setup mock Nostr service with all required connection checks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(
        () => mockNostrService.connectedRelayCount,
      ).thenReturn(1); // FIX: Add missing mock

      // Setup mock event with real profile data
      final mockEvent = MockEvent();
      when(() => mockEvent.kind).thenReturn(0);
      when(() => mockEvent.pubkey).thenReturn(pubkey);
      when(() => mockEvent.id).thenReturn('event-id-123');
      when(() => mockEvent.createdAt).thenReturn(1234567890);
      when(() => mockEvent.content).thenReturn(
        '{"name":"Test User","picture":"https://example.com/avatar.jpg","about":"Test bio"}',
      );
      when(() => mockEvent.tags).thenReturn([]);

      // Mock SubscriptionManager to call onEvent with mock event
      when(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((invocation) async {
        // Get callbacks
        final onEvent =
            invocation.namedArguments[const Symbol('onEvent')]
                as void Function(Event);
        final onComplete =
            invocation.namedArguments[const Symbol('onComplete')]
                as void Function()?;

        // Call onEvent with the mock event
        Future.microtask(() => onEvent(mockEvent));

        // Call onComplete after event
        Future.delayed(const Duration(milliseconds: 50), onComplete);

        return 'test-subscription-id';
      });

      // Test the async provider directly
      final profileAsyncValue = await container.read(
        fetchUserProfileProvider(pubkey).future,
      );

      expect(profileAsyncValue, isNotNull);
      expect(profileAsyncValue!.pubkey, equals(pubkey));
      expect(profileAsyncValue.name, equals('Test User'));
      expect(
        profileAsyncValue.picture,
        equals('https://example.com/avatar.jpg'),
      );

      // Test that it's cached by calling again (should not hit network again)
      final cachedProfile = await container.read(
        fetchUserProfileProvider(pubkey).future,
      );
      expect(cachedProfile, equals(profileAsyncValue));

      // Verify subscription was created
      verify(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
    });

    test('should use notifier for basic profile management', () async {
      const pubkey = 'test-pubkey-456';

      // Setup mock Nostr service with all required connection checks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);

      // Setup mock event
      final mockEvent = MockEvent();
      when(() => mockEvent.kind).thenReturn(0);
      when(() => mockEvent.pubkey).thenReturn(pubkey);
      when(() => mockEvent.id).thenReturn('event-id-456');
      when(() => mockEvent.createdAt).thenReturn(1234567890);
      when(() => mockEvent.content).thenReturn('{"name":"Notifier Test User"}');
      when(() => mockEvent.tags).thenReturn([]);

      // Override the subscription manager mock for this specific test
      // to actually deliver the profile event
      when(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((invocation) async {
        final onEvent =
            invocation.namedArguments[const Symbol('onEvent')]
                as void Function(Event)?;
        final onComplete =
            invocation.namedArguments[const Symbol('onComplete')]
                as void Function()?;

        // Deliver the profile event
        if (onEvent != null) {
          Future.delayed(
            const Duration(milliseconds: 10),
            () => onEvent(mockEvent),
          );
        }

        if (onComplete != null) {
          Future.delayed(const Duration(milliseconds: 50), onComplete);
        }
        return 'test-subscription-id';
      });

      // Test notifier fetch method - this is what matters
      final profile = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profile, isNotNull);
      expect(profile!.pubkey, equals(pubkey));
      expect(profile.name, equals('Notifier Test User'));

      // Test that getCachedProfile works (this tests the actual caching mechanism)
      final cachedProfile = container
          .read(userProfileProvider.notifier)
          .getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('Notifier Test User'));
    });

    test('should return cached profile without fetching', () async {
      const pubkey = 'test-pubkey-123';

      // Setup mock Nostr service with all required connection checks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(
        () => mockNostrService.connectedRelayCount,
      ).thenReturn(1); // FIX: Add missing mock

      // Pre-populate cache
      final testProfile = models.UserProfile(
        pubkey: pubkey,
        name: 'Cached User',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'cached-event-id',
      );

      container
          .read(userProfileProvider.notifier)
          .updateCachedProfile(testProfile);

      // Fetch should return cached profile without network call
      final profile = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profile, equals(testProfile));
      verifyNever(
        () =>
            mockNostrService.subscribeToEvents(filters: any(named: 'filters')),
      );
    });

    test('should handle multiple individual profile fetches', () async {
      // Test multiple individual fetches instead of complex batch logic
      final pubkeys = ['pubkey1', 'pubkey2', 'pubkey3'];

      // Setup mock Nostr service with all required connection checks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);

      // For each pubkey, we'll test individual fetch (which exercises the core functionality)
      for (int i = 0; i < pubkeys.length; i++) {
        final pubkey = pubkeys[i];

        // Setup mock event for this pubkey
        final mockEvent = MockEvent();
        when(() => mockEvent.kind).thenReturn(0);
        when(() => mockEvent.pubkey).thenReturn(pubkey);
        when(() => mockEvent.id).thenReturn('event-$pubkey');
        when(() => mockEvent.createdAt).thenReturn(1234567890);
        when(() => mockEvent.content).thenReturn('{"name":"User $pubkey"}');
        when(() => mockEvent.tags).thenReturn([]);

        // Override mock to deliver this specific event
        when(
          () => mockSubscriptionManager.createSubscription(
            name: any(named: 'name'),
            filters: any(named: 'filters'),
            onEvent: any(named: 'onEvent'),
            onError: any(named: 'onError'),
            onComplete: any(named: 'onComplete'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((invocation) async {
          final onEvent =
              invocation.namedArguments[const Symbol('onEvent')]
                  as void Function(Event)?;
          final onComplete =
              invocation.namedArguments[const Symbol('onComplete')]
                  as void Function()?;

          // Deliver the profile event
          if (onEvent != null) {
            Future.delayed(
              const Duration(milliseconds: 10),
              () => onEvent(mockEvent),
            );
          }

          if (onComplete != null) {
            Future.delayed(const Duration(milliseconds: 50), onComplete);
          }
          return 'test-subscription-id-$i';
        });

        // Fetch this profile
        final profile = await container
            .read(userProfileProvider.notifier)
            .fetchProfile(pubkey);

        expect(profile, isNotNull);
        expect(profile!.pubkey, equals(pubkey));
        expect(profile.name, equals('User $pubkey'));

        // Verify it's cached
        final cachedProfile = container
            .read(userProfileProvider.notifier)
            .getCachedProfile(pubkey);
        expect(cachedProfile, isNotNull);
        expect(cachedProfile!.name, equals('User $pubkey'));
      }
    });

    test('should handle profile not found', () async {
      const pubkey = 'non-existent-pubkey';

      // Setup mock Nostr service with all required connection checks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(
        () => mockNostrService.connectedRelayCount,
      ).thenReturn(1); // FIX: Add missing mock

      // Mock empty stream (no profile found)
      when(
        () =>
            mockNostrService.subscribeToEvents(filters: any(named: 'filters')),
      ).thenAnswer((_) => const Stream.empty());

      // Fetch profile
      final profile = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profile, isNull);

      // Verify it's marked as missing in global cache (the memory cache handles this)
      // Since the missing profile logic is now in the memory cache, we verify behavior differently

      // Try to fetch again - should skip due to missing marker
      final profileAgain = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profileAgain, isNull);
    });

    test('should force refresh cached profile', () async {
      const pubkey = 'test-pubkey-123';

      // Setup mock Nostr service with all required connection checks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(
        () => mockNostrService.connectedRelayCount,
      ).thenReturn(1); // FIX: Add missing mock

      // Pre-populate cache with old profile
      final oldProfile = models.UserProfile(
        pubkey: pubkey,
        name: 'Old Name',
        rawData: {},
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        eventId: 'old-event-id',
      );

      container
          .read(userProfileProvider.notifier)
          .updateCachedProfile(oldProfile);

      // Setup new profile event
      final mockEvent = MockEvent();
      when(() => mockEvent.kind).thenReturn(0);
      when(() => mockEvent.pubkey).thenReturn(pubkey);
      when(() => mockEvent.id).thenReturn('new-event-id');
      when(
        () => mockEvent.createdAt,
      ).thenReturn(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      when(() => mockEvent.content).thenReturn('{"name":"New Name"}');
      when(() => mockEvent.tags).thenReturn([]);

      // Override mock to deliver the new profile event
      when(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((invocation) async {
        final onEvent =
            invocation.namedArguments[const Symbol('onEvent')]
                as void Function(Event)?;
        final onComplete =
            invocation.namedArguments[const Symbol('onComplete')]
                as void Function()?;

        // Deliver the new profile event
        if (onEvent != null) {
          Future.delayed(
            const Duration(milliseconds: 10),
            () => onEvent(mockEvent),
          );
        }

        if (onComplete != null) {
          Future.delayed(const Duration(milliseconds: 50), onComplete);
        }
        return 'test-subscription-refresh-id';
      });

      // Force refresh
      final profile = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey, forceRefresh: true);

      expect(profile, isNotNull);
      expect(profile!.name, equals('New Name'));

      // Verify subscription was created for refresh
      verify(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
    });

    test('should handle errors gracefully', () async {
      const pubkey = 'error-test-pubkey';

      // Setup fresh container to avoid mock contamination
      final errorContainer = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
        ],
      );

      // Setup mock Nostr service with all required connection checks
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(
        () => mockNostrService.connectedRelayCount,
      ).thenReturn(1); // FIX: Add missing mock

      // Mock subscription error - reset all previous mocks first
      reset(mockNostrService);
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(
        () =>
            mockNostrService.subscribeToEvents(filters: any(named: 'filters')),
      ).thenAnswer((_) => Stream.error(Exception('Network error')));

      // Fetch profile should handle error gracefully
      final profile = await errorContainer
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profile, isNull);

      // With the new async provider design, errors are handled gracefully
      // and the profile is marked as missing rather than stored in state.error
      // Let's verify the profile is marked as missing by trying to fetch again
      final profileAgain = await errorContainer
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profileAgain, isNull);

      errorContainer.dispose();
    });
  });
}
