// ABOUTME: Integration test for VideoEventService with VideoFilterBuilder for sorted queries
// ABOUTME: Tests relay capability detection and graceful fallback to standard filters

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';

@GenerateMocks([
  INostrService,
  SubscriptionManager,
  UserProfileService,
  EventRouter,
  RelayCapabilityService,
])
import 'video_event_service_sorted_queries_integration_test.mocks.dart';

void main() {
  group('VideoEventService Sorted Queries Integration', () {
    late VideoEventService service;
    late MockINostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    late MockUserProfileService mockUserProfileService;
    late MockEventRouter mockEventRouter;
    late MockRelayCapabilityService mockRelayCapabilityService;
    late VideoFilterBuilder filterBuilder;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = MockINostrService();
      mockSubscriptionManager = MockSubscriptionManager();
      mockUserProfileService = MockUserProfileService();
      mockEventRouter = MockEventRouter();
      mockRelayCapabilityService = MockRelayCapabilityService();
      eventStreamController = StreamController<Event>.broadcast();

      // Mock NostrService as initialized
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        mockNostrService.subscribeToEvents(
          filters: anyNamed('filters'),
          bypassLimits: anyNamed('bypassLimits'),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) => eventStreamController.stream);

      // Create real VideoFilterBuilder with mocked RelayCapabilityService
      filterBuilder = VideoFilterBuilder(mockRelayCapabilityService);

      // Create VideoEventService with VideoFilterBuilder
      service = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
        userProfileService: mockUserProfileService,
        eventRouter: mockEventRouter,
        videoFilterBuilder: filterBuilder,
      );
    });

    tearDown(() {
      eventStreamController.close();
      service.dispose();
    });

    group('With Relay Supporting Divine Extensions', () {
      setUp(() {
        // Mock relay that supports divine extensions
        final divineCapabilities = RelayCapabilities(
          relayUrl: AppConstants.defaultRelayUrl,
          name: 'Divine Relay',
          rawData: {},
          hasDivineExtensions: true,
          sortFields: ['loop_count', 'likes', 'views', 'created_at'],
          intFilterFields: ['loop_count', 'likes', 'views'],
          maxLimit: 200,
        );

        when(
          mockRelayCapabilityService.getRelayCapabilities(
            AppConstants.defaultRelayUrl,
          ),
        ).thenAnswer((_) async => divineCapabilities);
      });

      test('uses server-side sorting for trending (loop_count desc)', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          sortBy: VideoSortField.loopCount,
          limit: 50,
        );

        // Verify subscribeToEvents was called
        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;

        expect(captured.isNotEmpty, true);
        final filters = captured[0] as List<Filter>;
        expect(filters.length, greaterThan(0));

        // Check that filter includes sort field
        final filterJson = filters[0].toJson();
        expect(
          filterJson['sort'],
          isNotNull,
          reason: 'Filter should include sort field',
        );
        expect(filterJson['sort']['field'], 'loop_count');
        expect(filterJson['sort']['dir'], 'desc');
        expect(filterJson['limit'], 50);
      });

      test('uses server-side sorting for most liked (likes desc)', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          sortBy: VideoSortField.likes,
          limit: 50,
        );

        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;

        final filters = captured[0] as List<Filter>;
        final filterJson = filters[0].toJson();

        expect(filterJson['sort']['field'], 'likes');
        expect(filterJson['sort']['dir'], 'desc');
      });

      test('uses server-side sorting for most viewed (views desc)', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          sortBy: VideoSortField.views,
          limit: 50,
        );

        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;

        final filters = captured[0] as List<Filter>;
        final filterJson = filters[0].toJson();

        expect(filterJson['sort']['field'], 'views');
        expect(filterJson['sort']['dir'], 'desc');
      });

      test('uses server-side sorting for newest (created_at desc)', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          sortBy: VideoSortField.createdAt,
          limit: 50,
        );

        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;

        final filters = captured[0] as List<Filter>;
        final filterJson = filters[0].toJson();

        expect(filterJson['sort']['field'], 'created_at');
        expect(filterJson['sort']['dir'], 'desc');
      });

      test('preserves other filter parameters with sorting', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          sortBy: VideoSortField.loopCount,
          authors: ['pubkey123'],
          hashtags: ['music'],
          limit: 50,
        );

        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;

        final filters = captured[0] as List<Filter>;
        final filterJson = filters[0].toJson();

        // Should have sort AND other filters
        expect(filterJson['sort']['field'], 'loop_count');
        expect(filterJson['authors'], contains('pubkey123'));
        expect(filterJson['#t'], contains('music'));
        expect(filterJson['limit'], 50);
      });

      test('uses standard filter when sortBy is null', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          // No sortBy parameter
          limit: 50,
        );

        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;

        final filters = captured[0] as List<Filter>;
        final filterJson = filters[0].toJson();

        // Should NOT have sort field
        expect(
          filterJson.containsKey('sort'),
          false,
          reason: 'Standard filter should not include sort field',
        );
        expect(filterJson['limit'], 50);
      });
    });

    group('With Relay NOT Supporting Divine Extensions', () {
      setUp(() {
        // Mock relay without divine extensions
        final standardCapabilities = RelayCapabilities(
          relayUrl: AppConstants.defaultRelayUrl,
          name: 'Standard Relay',
          rawData: {},
          hasDivineExtensions: false,
        );

        when(
          mockRelayCapabilityService.getRelayCapabilities(
            AppConstants.defaultRelayUrl,
          ),
        ).thenAnswer((_) async => standardCapabilities);
      });

      test(
        'falls back to standard filter when relay does not support divine extensions',
        () async {
          await service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
            sortBy: VideoSortField.loopCount, // Request sorting
            limit: 50,
          );

          final captured = verify(
            mockNostrService.subscribeToEvents(
              filters: captureAnyNamed('filters'),
              bypassLimits: anyNamed('bypassLimits'),
              onEose: anyNamed('onEose'),
            ),
          ).captured;

          final filters = captured[0] as List<Filter>;
          final filterJson = filters[0].toJson();

          // Should NOT have sort field (fallback to standard)
          expect(
            filterJson.containsKey('sort'),
            false,
            reason:
                'Should fall back to standard filter when relay does not support divine extensions',
          );
          expect(filterJson['limit'], 50);
        },
      );

      test('still subscribes successfully with standard filter', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          sortBy: VideoSortField.loopCount,
          limit: 50,
        );

        // Should still call subscribeToEvents (with standard filter)
        verify(
          mockNostrService.subscribeToEvents(
            filters: anyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).called(1);
      });
    });

    group('Error Handling', () {
      test(
        'falls back to standard filter when capability check fails',
        () async {
          // Mock capability check failure
          when(
            mockRelayCapabilityService.getRelayCapabilities(
              AppConstants.defaultRelayUrl,
            ),
          ).thenThrow(
            RelayCapabilityException(
              'Network error',
              AppConstants.defaultRelayUrl,
            ),
          );

          await service.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
            sortBy: VideoSortField.loopCount,
            limit: 50,
          );

          final captured = verify(
            mockNostrService.subscribeToEvents(
              filters: captureAnyNamed('filters'),
              bypassLimits: anyNamed('bypassLimits'),
              onEose: anyNamed('onEose'),
            ),
          ).captured;

          final filters = captured[0] as List<Filter>;
          final filterJson = filters[0].toJson();

          // Should fall back to standard filter
          expect(filterJson.containsKey('sort'), false);
        },
      );

      test(
        'works without VideoFilterBuilder (backward compatibility)',
        () async {
          // Create service WITHOUT VideoFilterBuilder
          final serviceWithoutBuilder = VideoEventService(
            mockNostrService,
            subscriptionManager: mockSubscriptionManager,
            userProfileService: mockUserProfileService,
            eventRouter: mockEventRouter,
            // No videoFilterBuilder parameter
          );

          await serviceWithoutBuilder.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
            sortBy: VideoSortField.loopCount, // Request sorting
            limit: 50,
          );

          final captured = verify(
            mockNostrService.subscribeToEvents(
              filters: captureAnyNamed('filters'),
              bypassLimits: anyNamed('bypassLimits'),
              onEose: anyNamed('onEose'),
            ),
          ).captured;

          final filters = captured[0] as List<Filter>;
          final filterJson = filters[0].toJson();

          // Should use standard filter (builder not available)
          expect(
            filterJson.containsKey('sort'),
            false,
            reason: 'Should work without builder for backward compatibility',
          );

          serviceWithoutBuilder.dispose();
        },
      );
    });

    group('Multiple Subscription Types', () {
      setUp(() {
        final divineCapabilities = RelayCapabilities(
          relayUrl: AppConstants.defaultRelayUrl,
          name: 'Divine Relay',
          rawData: {},
          hasDivineExtensions: true,
          sortFields: ['loop_count', 'likes', 'views', 'created_at'],
          intFilterFields: ['loop_count', 'likes', 'views'],
        );

        when(
          mockRelayCapabilityService.getRelayCapabilities(
            AppConstants.defaultRelayUrl,
          ),
        ).thenAnswer((_) async => divineCapabilities);
      });

      test('works with home feed subscription', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.homeFeed,
          sortBy: VideoSortField.createdAt,
          authors: ['pubkey1', 'pubkey2'],
          limit: 50,
        );

        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;

        final filters = captured[0] as List<Filter>;
        final filterJson = filters[0].toJson();

        expect(filterJson['sort']['field'], 'created_at');
        expect(filterJson['authors'], ['pubkey1', 'pubkey2']);
      });

      test('works with hashtag feed subscription', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.hashtag,
          sortBy: VideoSortField.likes,
          hashtags: ['music'],
          limit: 50,
        );

        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;

        final filters = captured[0] as List<Filter>;
        final filterJson = filters[0].toJson();

        expect(filterJson['sort']['field'], 'likes');
        expect(filterJson['#t'], ['music']);
      });

      test('works with profile feed subscription', () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.profile,
          sortBy: VideoSortField.loopCount,
          authors: ['user_pubkey'],
          limit: 50,
        );

        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
            bypassLimits: anyNamed('bypassLimits'),
            onEose: anyNamed('onEose'),
          ),
        ).captured;

        final filters = captured[0] as List<Filter>;
        final filterJson = filters[0].toJson();

        expect(filterJson['sort']['field'], 'loop_count');
        expect(filterJson['authors'], ['user_pubkey']);
      });
    });
  });
}
