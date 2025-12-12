import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';

// Generate mocks
@GenerateMocks([NostrClient])
import 'subscription_manager_filter_test.mocks.dart';

void main() {
  group('SubscriptionManager Filter Preservation', () {
    late MockNostrClient mockNostrService;
    late SubscriptionManager subscriptionManager;
    late List<List<Filter>> capturedFiltersList;

    setUp(() {
      mockNostrService = MockNostrClient();
      subscriptionManager = SubscriptionManager(mockNostrService);
      capturedFiltersList = [];

      // Setup default mock behavior with capture
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((invocation) {
        capturedFiltersList.add(
          invocation.positionalArguments[0] as List<Filter>,
        );
        return const Stream<Event>.empty();
      });
    });

    test('should preserve hashtag filters when optimizing', () async {
      // Create a filter with hashtags
      final originalFilter = Filter(
        kinds: [22],
        t: ['vine', 'trending', 'funny'],
        limit: 200,
      );

      // Create subscription
      await subscriptionManager.createSubscription(
        name: 'test_hashtag',
        filters: [originalFilter],
        onEvent: (event) {},
      );

      // Verify the filter passed to NostrService preserved hashtags
      final capturedCalls = verify(
        mockNostrService.subscribe(captureAny()),
      ).captured;

      expect(capturedCalls.isNotEmpty, isTrue);
      final passedFilters = capturedCalls.first as List<Filter>;
      expect(passedFilters.length, 1);

      final optimizedFilter = passedFilters.first;
      expect(optimizedFilter.t, equals(['vine', 'trending', 'funny']));
      expect(optimizedFilter.kinds, equals([22]));
      expect(
        optimizedFilter.limit,
        lessThanOrEqualTo(100),
      ); // Should be optimized
    });

    test('should preserve group (h) filters when optimizing', () async {
      // Create a filter with group
      final originalFilter = Filter(kinds: [22], h: ['vine'], limit: 150);

      // Create subscription
      await subscriptionManager.createSubscription(
        name: 'test_group',
        filters: [originalFilter],
        onEvent: (event) {},
      );

      // Verify the filter passed to NostrService preserved group
      final capturedCalls = verify(
        mockNostrService.subscribe(captureAny()),
      ).captured;

      expect(capturedCalls.isNotEmpty, isTrue);
      final passedFilters = capturedCalls.first as List<Filter>;
      expect(passedFilters.length, 1);

      final optimizedFilter = passedFilters.first;
      expect(optimizedFilter.h, equals(['vine']));
      expect(optimizedFilter.kinds, equals([22]));
    });

    test('should preserve both hashtag and group filters', () async {
      // Create a filter with both hashtags and group
      final originalFilter = Filter(
        kinds: [22],
        t: ['funny', 'viral'],
        h: ['vine'],
        authors: [
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
          'npub2qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
        ],
        limit: 250,
      );

      // Create subscription
      await subscriptionManager.createSubscription(
        name: 'test_combined',
        filters: [originalFilter],
        onEvent: (event) {},
      );

      // Verify all filter parameters are preserved
      final capturedCalls = verify(
        mockNostrService.subscribe(captureAny()),
      ).captured;

      expect(capturedCalls.isNotEmpty, isTrue);
      final passedFilters = capturedCalls.first as List<Filter>;
      expect(passedFilters.length, 1);

      final optimizedFilter = passedFilters.first;
      expect(optimizedFilter.t, equals(['funny', 'viral']));
      expect(optimizedFilter.h, equals(['vine']));
      expect(
        optimizedFilter.authors,
        equals([
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
          'npub2qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
        ]),
      );
      expect(optimizedFilter.kinds, equals([22]));
      expect(optimizedFilter.limit, equals(100)); // Should be capped at 100
    });

    test('should handle null hashtag and group filters', () async {
      // Create a filter without hashtags or groups
      final originalFilter = Filter(
        kinds: [22],
        authors: [
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
        ],
        limit: 50,
      );

      // Create subscription
      await subscriptionManager.createSubscription(
        name: 'test_null_filters',
        filters: [originalFilter],
        onEvent: (event) {},
      );

      // Verify the filter passed to NostrService
      final capturedCalls = verify(
        mockNostrService.subscribe(captureAny()),
      ).captured;

      expect(capturedCalls.isNotEmpty, isTrue);
      final passedFilters = capturedCalls.first as List<Filter>;
      expect(passedFilters.length, 1);

      final optimizedFilter = passedFilters.first;
      expect(optimizedFilter.t, isNull);
      expect(optimizedFilter.h, isNull);
      expect(
        optimizedFilter.authors,
        equals([
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
        ]),
      );
      expect(optimizedFilter.kinds, equals([22]));
    });

    test('should optimize multiple filters independently', () async {
      // Create multiple filters with different parameters
      final filters = [
        Filter(kinds: [22], t: ['vine'], limit: 200),
        Filter(kinds: [16], h: ['vine'], limit: 150),
      ];

      // Create subscription
      await subscriptionManager.createSubscription(
        name: 'test_multiple',
        filters: filters,
        onEvent: (event) {},
      );

      // Verify both filters are optimized correctly
      final capturedCalls = verify(
        mockNostrService.subscribe(captureAny()),
      ).captured;

      expect(capturedCalls.isNotEmpty, isTrue);
      final passedFilters = capturedCalls.first as List<Filter>;
      expect(passedFilters.length, 2);

      // Check first filter
      final filter1 = passedFilters[0];
      expect(filter1.t, equals(['vine']));
      expect(filter1.h, isNull);
      expect(filter1.kinds, equals([22]));
      expect(filter1.limit, equals(100));

      // Check second filter
      final filter2 = passedFilters[1];
      expect(filter2.t, isNull);
      expect(filter2.h, equals(['vine']));
      expect(filter2.kinds, equals([16]));
      expect(filter2.limit, equals(100));
    });

    test('should not modify limits under 100', () async {
      // Create a filter with limit under 100
      final originalFilter = Filter(kinds: [22], t: ['test'], limit: 50);

      // Create subscription
      await subscriptionManager.createSubscription(
        name: 'test_small_limit',
        filters: [originalFilter],
        onEvent: (event) {},
      );

      // Verify the limit is not changed
      final capturedCalls = verify(
        mockNostrService.subscribe(captureAny()),
      ).captured;

      expect(capturedCalls.isNotEmpty, isTrue);
      final passedFilters = capturedCalls.first as List<Filter>;
      expect(passedFilters.length, 1);

      final optimizedFilter = passedFilters.first;
      expect(optimizedFilter.limit, equals(50));
    });
  });
}
