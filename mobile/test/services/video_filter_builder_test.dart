// ABOUTME: Test for VideoFilterBuilder - validates filter construction with relay capability detection
// ABOUTME: Covers server-side sorting when supported and graceful fallback to standard filters

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/divine_filter.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/video_filter_builder.dart';

@GenerateMocks([RelayCapabilityService])
import 'video_filter_builder_test.mocks.dart';

void main() {
  group('VideoFilterBuilder', () {
    late VideoFilterBuilder builder;
    late MockRelayCapabilityService mockCapabilityService;

    const testRelayUrl = 'wss://staging-relay.divine.video';

    setUp(() {
      mockCapabilityService = MockRelayCapabilityService();
      builder = VideoFilterBuilder(mockCapabilityService);
    });

    group('Relay with Divine Extensions', () {
      setUp(() {
        // Mock divine relay capabilities
        final divineCapabilities = RelayCapabilities(
          relayUrl: testRelayUrl,
          name: 'Divine Relay',
          rawData: {},
          hasDivineExtensions: true,
          sortFields: ['loop_count', 'likes', 'views', 'created_at'],
          intFilterFields: ['loop_count', 'likes', 'views'],
          maxLimit: 200,
        );

        when(
          mockCapabilityService.getRelayCapabilities(testRelayUrl),
        ).thenAnswer((_) async => divineCapabilities);
      });

      test('builds trending filter with server-side sorting', () async {
        final baseFilter = Filter(kinds: [34236], limit: 50);

        final result = await builder.buildTrendingFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
        );

        final json = result.toJson();
        expect(json['kinds'], [34236]);
        expect(json['limit'], 50);
        expect(json['sort'], {'field': 'loop_count', 'dir': 'desc'});
      });

      test('builds trending filter with min loops threshold', () async {
        final baseFilter = Filter(kinds: [34236], limit: 50);

        final result = await builder.buildTrendingFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
          minLoops: 1000,
        );

        final json = result.toJson();
        expect(json['sort']['field'], 'loop_count');
        expect(json['int#loop_count'], {'gte': 1000});
      });

      test('builds most liked filter with server-side sorting', () async {
        final baseFilter = Filter(kinds: [34236], limit: 50);

        final result = await builder.buildMostLikedFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
          minLikes: 100,
        );

        final json = result.toJson();
        expect(json['sort'], {'field': 'likes', 'dir': 'desc'});
        expect(json['int#likes'], {'gte': 100});
      });

      test('builds most viewed filter with server-side sorting', () async {
        final baseFilter = Filter(kinds: [34236], limit: 50);

        final result = await builder.buildMostViewedFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
          minViews: 500,
        );

        final json = result.toJson();
        expect(json['sort'], {'field': 'views', 'dir': 'desc'});
        expect(json['int#views'], {'gte': 500});
      });

      test('builds newest filter with server-side sorting', () async {
        final baseFilter = Filter(kinds: [34236], limit: 50);

        final result = await builder.buildNewestFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
        );

        final json = result.toJson();
        expect(json['sort'], {'field': 'created_at', 'dir': 'desc'});
      });

      test('preserves base filter properties', () async {
        final baseFilter = Filter(
          kinds: [34236],
          authors: ['pubkey1', 'pubkey2'],
          t: ['music'],
          limit: 50,
        );

        final result = await builder.buildTrendingFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
        );

        final json = result.toJson();
        expect(json['kinds'], [34236]);
        expect(json['authors'], ['pubkey1', 'pubkey2']);
        expect(json['#t'], ['music']);
        expect(json['limit'], 50);
        expect(json['sort']['field'], 'loop_count');
      });

      test('supports custom sort direction', () async {
        final baseFilter = Filter(kinds: [34236]);

        final result = await builder.buildFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
          sortBy: VideoSortField.createdAt,
          sortDirection: SortDirection.asc, // Ascending instead of descending
        );

        final json = result.toJson();
        expect(json['sort'], {'field': 'created_at', 'dir': 'asc'});
      });

      test('supports custom int filters', () async {
        final baseFilter = Filter(kinds: [34236]);

        final result = await builder.buildFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
          sortBy: VideoSortField.likes,
          intFilters: {
            'likes': IntRangeFilter(gte: 50, lte: 500),
            'loop_count': IntRangeFilter(gte: 1000),
          },
        );

        final json = result.toJson();
        expect(json['int#likes'], {'gte': 50, 'lte': 500});
        expect(json['int#loop_count'], {'gte': 1000});
      });
    });

    group('Relay without Divine Extensions', () {
      setUp(() {
        // Mock standard relay without divine extensions
        final standardCapabilities = RelayCapabilities(
          relayUrl: testRelayUrl,
          name: 'Standard Relay',
          rawData: {},
          hasDivineExtensions: false,
        );

        when(
          mockCapabilityService.getRelayCapabilities(testRelayUrl),
        ).thenAnswer((_) async => standardCapabilities);
      });

      test('falls back to standard filter for trending', () async {
        final baseFilter = Filter(kinds: [34236], limit: 50);

        final result = await builder.buildTrendingFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
        );

        final json = result.toJson();
        expect(json.containsKey('sort'), false);
        expect(json.keys.any((k) => k.startsWith('int#')), false);
        expect(json['kinds'], [34236]);
        expect(json['limit'], 50);
      });

      test('falls back to standard filter for most liked', () async {
        final baseFilter = Filter(kinds: [34236]);

        final result = await builder.buildMostLikedFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
          minLikes: 100,
        );

        final json = result.toJson();
        expect(json.containsKey('sort'), false);
        expect(json.keys.any((k) => k.startsWith('int#')), false);
      });

      test('returns standard filter unchanged', () async {
        final baseFilter = Filter(
          kinds: [34236],
          authors: ['pubkey1'],
          limit: 50,
        );

        final result = await builder.buildTrendingFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
        );

        final json = result.toJson();
        expect(json['kinds'], [34236]);
        expect(json['authors'], ['pubkey1']);
        expect(json['limit'], 50);
      });
    });

    group('Partial Divine Extension Support', () {
      test('falls back when requested sort field not supported', () async {
        // Relay supports sorting but not by 'avg_completion'
        final partialCapabilities = RelayCapabilities(
          relayUrl: testRelayUrl,
          name: 'Partial Divine Relay',
          rawData: {},
          hasDivineExtensions: true,
          sortFields: ['loop_count', 'likes'], // No 'avg_completion'
          intFilterFields: ['loop_count', 'likes'],
        );

        when(
          mockCapabilityService.getRelayCapabilities(testRelayUrl),
        ).thenAnswer((_) async => partialCapabilities);

        final baseFilter = Filter(kinds: [34236]);

        final result = await builder.buildFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
          sortBy: VideoSortField.avgCompletion, // Not supported!
        );

        final json = result.toJson();
        expect(
          json.containsKey('sort'),
          false,
          reason: 'Should fall back when sort field not supported',
        );
      });

      test('falls back when requested int filter not supported', () async {
        final partialCapabilities = RelayCapabilities(
          relayUrl: testRelayUrl,
          name: 'Partial Divine Relay',
          rawData: {},
          hasDivineExtensions: true,
          sortFields: ['loop_count'],
          intFilterFields: ['loop_count'], // No 'views'
        );

        when(
          mockCapabilityService.getRelayCapabilities(testRelayUrl),
        ).thenAnswer((_) async => partialCapabilities);

        final baseFilter = Filter(kinds: [34236]);

        final result = await builder.buildFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
          sortBy: VideoSortField.loopCount,
          intFilters: {
            'views': IntRangeFilter(gte: 500), // Not supported!
          },
        );

        final json = result.toJson();
        expect(
          json.containsKey('sort'),
          false,
          reason: 'Should fall back when int filter not supported',
        );
      });
    });

    group('Error Handling', () {
      test(
        'falls back to standard filter when capability check fails',
        () async {
          when(
            mockCapabilityService.getRelayCapabilities(testRelayUrl),
          ).thenThrow(RelayCapabilityException('Network error', testRelayUrl));

          final baseFilter = Filter(kinds: [34236], limit: 50);

          final result = await builder.buildTrendingFilter(
            baseFilter: baseFilter,
            relayUrl: testRelayUrl,
          );

          final json = result.toJson();
          expect(
            json.containsKey('sort'),
            false,
            reason: 'Should fall back on error',
          );
          expect(json['kinds'], [34236]);
          expect(json['limit'], 50);
        },
      );

      test('falls back gracefully when capability service throws', () async {
        when(
          mockCapabilityService.getRelayCapabilities(testRelayUrl),
        ).thenThrow(Exception('Unexpected error'));

        final baseFilter = Filter(kinds: [34236]);

        // Should not throw, should return standard filter
        final result = await builder.buildMostLikedFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
        );

        final json = result.toJson();
        expect(json.containsKey('sort'), false);
      });
    });

    group('No Sorting Requested', () {
      test('returns standard filter when no sort specified', () async {
        // Even if relay supports divine extensions
        final divineCapabilities = RelayCapabilities(
          relayUrl: testRelayUrl,
          name: 'Divine Relay',
          rawData: {},
          hasDivineExtensions: true,
          sortFields: ['loop_count'],
          intFilterFields: ['loop_count'],
        );

        when(
          mockCapabilityService.getRelayCapabilities(testRelayUrl),
        ).thenAnswer((_) async => divineCapabilities);

        final baseFilter = Filter(kinds: [34236], limit: 50);

        final result = await builder.buildFilter(
          baseFilter: baseFilter,
          relayUrl: testRelayUrl,
          // No sortBy parameter!
        );

        final json = result.toJson();
        expect(json.containsKey('sort'), false);
        expect(json['kinds'], [34236]);
        expect(json['limit'], 50);
      });
    });
  });
}
