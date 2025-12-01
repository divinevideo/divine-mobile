// ABOUTME: Integration tests for new analytics API endpoints
// ABOUTME: Tests real API endpoints for trending, hashtags, creators, and related videos

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/utils/unified_logger.dart';

void main() {
  group('Analytics API New Endpoints Integration Tests', () {
    const baseUrl = 'https://api.openvine.co';
    const userAgent = 'OpenVine-Mobile-Test/1.0';
    const timeout = Duration(seconds: 10);

    setUpAll(() {
      Log.info('🧪 Starting Analytics API integration tests');
    });

    group('Trending Videos Endpoint', () {
      test(
        'GET /analytics/trending/vines - returns valid trending data',
        () async {
          final response = await http
              .get(
                Uri.parse(
                  '$baseUrl/analytics/trending/vines?window=24h&limit=10',
                ),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': userAgent,
                },
              )
              .timeout(timeout);

          expect(response.statusCode, 200);

          final data = jsonDecode(response.body);
          expect(data, isA<Map<String, dynamic>>());
          expect(data['vines'], isA<List>());

          final vines = data['vines'] as List;
          Log.info(
            '✅ Trending videos endpoint: ${vines.length} videos returned',
          );

          if (vines.isNotEmpty) {
            final firstVine = vines.first;
            expect(firstVine['eventId'], isA<String>());
            expect(firstVine['views'], isA<num>());
            expect(firstVine['score'], isA<num>());

            // Verify viral score is reasonable
            final score = firstVine['score'] as num;
            expect(score, greaterThanOrEqualTo(0));

            Log.info(
              '   Top video: ${firstVine['views']} views, score: ${score.toStringAsFixed(2)}',
            );
          }
        },
      );

      test('GET /analytics/trending/vines - supports time windows', () async {
        final timeWindows = ['1h', '24h', '7d'];

        for (final window in timeWindows) {
          final response = await http
              .get(
                Uri.parse(
                  '$baseUrl/analytics/trending/vines?window=$window&limit=5',
                ),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': userAgent,
                },
              )
              .timeout(timeout);

          expect(response.statusCode, 200);

          final data = jsonDecode(response.body);
          expect(data['period'], window);

          Log.info(
            '✅ Time window $window: ${(data['vines'] as List).length} videos',
          );
        }
      });

      test(
        'GET /analytics/trending/vines - respects limit parameter',
        () async {
          final limits = [5, 10, 20];

          for (final limit in limits) {
            final response = await http
                .get(
                  Uri.parse(
                    '$baseUrl/analytics/trending/vines?window=24h&limit=$limit',
                  ),
                  headers: {
                    'Accept': 'application/json',
                    'User-Agent': userAgent,
                  },
                )
                .timeout(timeout);

            expect(response.statusCode, 200);

            final data = jsonDecode(response.body);
            final vines = data['vines'] as List;
            expect(vines.length, lessThanOrEqualTo(limit));

            Log.info('✅ Limit $limit: returned ${vines.length} videos');
          }
        },
      );

      test('GET /analytics/trending/vines - performance check', () async {
        final stopwatch = Stopwatch()..start();

        final response = await http
            .get(
              Uri.parse(
                '$baseUrl/analytics/trending/vines?window=24h&limit=100',
              ),
              headers: {'Accept': 'application/json', 'User-Agent': userAgent},
            )
            .timeout(timeout);

        stopwatch.stop();

        expect(response.statusCode, 200);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
        ); // Should be under 5s

        Log.info(
          '✅ Performance: ${stopwatch.elapsedMilliseconds}ms for 100 videos',
        );
      });
    });

    group('Trending Hashtags Endpoint', () {
      test(
        'GET /analytics/trending/hashtags - returns valid hashtag data',
        () async {
          final response = await http
              .get(
                Uri.parse(
                  '$baseUrl/analytics/trending/hashtags?window=24h&limit=20',
                ),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': userAgent,
                },
              )
              .timeout(timeout);

          // May return 404 if not implemented yet
          if (response.statusCode == 404) {
            Log.warning('⚠️ Trending hashtags endpoint not yet implemented');
            return;
          }

          expect(response.statusCode, 200);

          final data = jsonDecode(response.body);
          expect(data, isA<Map<String, dynamic>>());
          expect(data['hashtags'], isA<List>());

          final hashtags = data['hashtags'] as List;
          Log.info('✅ Trending hashtags: ${hashtags.length} hashtags returned');

          if (hashtags.isNotEmpty) {
            final firstTag = hashtags.first;
            expect(firstTag['tag'], isA<String>());
            expect(firstTag['views'], isA<num>());
            expect(firstTag['videoCount'], isA<num>());

            Log.info(
              '   Top hashtag: #${firstTag['tag']} (${firstTag['views']} views, ${firstTag['videoCount']} videos)',
            );
          }
        },
      );
    });

    group('Top Creators Endpoint', () {
      test(
        'GET /analytics/trending/creators - returns valid creator data',
        () async {
          final response = await http
              .get(
                Uri.parse(
                  '$baseUrl/analytics/trending/creators?window=7d&limit=20',
                ),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': userAgent,
                },
              )
              .timeout(timeout);

          // May return 404 if not implemented yet
          if (response.statusCode == 404) {
            Log.warning('⚠️ Top creators endpoint not yet implemented');
            return;
          }

          expect(response.statusCode, 200);

          final data = jsonDecode(response.body);
          expect(data, isA<Map<String, dynamic>>());
          expect(data['creators'], isA<List>());

          final creators = data['creators'] as List;
          Log.info('✅ Top creators: ${creators.length} creators returned');

          if (creators.isNotEmpty) {
            final topCreator = creators.first;
            expect(topCreator['pubkey'], isA<String>());
            expect(topCreator['totalViews'], isA<num>());
            expect(topCreator['videoCount'], isA<num>());

            Log.info(
              '   Top creator: ${topCreator['totalViews']} views, ${topCreator['videoCount']} videos',
            );
          }
        },
      );
    });

    group('Related Videos Endpoint', () {
      test('GET /analytics/vines/{id}/related - returns related videos', () async {
        // First get a trending video to use as reference
        final trendingResponse = await http
            .get(
              Uri.parse('$baseUrl/analytics/trending/vines?window=24h&limit=1'),
              headers: {'Accept': 'application/json', 'User-Agent': userAgent},
            )
            .timeout(timeout);

        if (trendingResponse.statusCode != 200) {
          Log.warning(
            '⚠️ Cannot test related videos - trending endpoint failed',
          );
          return;
        }

        final trendingData = jsonDecode(trendingResponse.body);
        final vines = trendingData['vines'] as List;

        if (vines.isEmpty) {
          Log.warning(
            '⚠️ Cannot test related videos - no trending videos available',
          );
          return;
        }

        final videoId = vines.first['eventId'] as String;

        // Test hashtag-based related videos
        final hashtagResponse = await http
            .get(
              Uri.parse(
                '$baseUrl/analytics/vines/$videoId/related?algorithm=hashtag&limit=10',
              ),
              headers: {'Accept': 'application/json', 'User-Agent': userAgent},
            )
            .timeout(timeout);

        // May return 404 if not implemented yet
        if (hashtagResponse.statusCode == 404) {
          Log.warning('⚠️ Related videos endpoint not yet implemented');
          return;
        }

        expect(hashtagResponse.statusCode, 200);

        final hashtagData = jsonDecode(hashtagResponse.body);
        expect(hashtagData['vines'], isA<List>());

        final relatedVines = hashtagData['vines'] as List;
        Log.info(
          '✅ Related videos (hashtag): ${relatedVines.length} videos returned',
        );

        // Test co-watch algorithm
        final cowatchResponse = await http
            .get(
              Uri.parse(
                '$baseUrl/analytics/vines/$videoId/related?algorithm=cowatch&limit=10',
              ),
              headers: {'Accept': 'application/json', 'User-Agent': userAgent},
            )
            .timeout(timeout);

        if (cowatchResponse.statusCode == 200) {
          final cowatchData = jsonDecode(cowatchResponse.body);
          final cowatchVines = cowatchData['vines'] as List;
          Log.info(
            '✅ Related videos (co-watch): ${cowatchVines.length} videos returned',
          );
        }
      });
    });

    group('Platform Metrics Endpoint', () {
      test('GET /analytics/platform - returns platform statistics', () async {
        final response = await http
            .get(
              Uri.parse('$baseUrl/analytics/platform'),
              headers: {'Accept': 'application/json', 'User-Agent': userAgent},
            )
            .timeout(timeout);

        // May return 404 if not implemented yet
        if (response.statusCode == 404) {
          Log.warning('⚠️ Platform metrics endpoint not yet implemented');
          return;
        }

        expect(response.statusCode, 200);

        final data = jsonDecode(response.body);
        expect(data, isA<Map<String, dynamic>>());

        Log.info('✅ Platform metrics retrieved successfully');

        // Check for expected metrics
        if (data.containsKey('totalViews')) {
          expect(data['totalViews'], isA<num>());
          Log.info('   Total views: ${data['totalViews']}');
        }
        if (data.containsKey('totalVideos')) {
          expect(data['totalVideos'], isA<num>());
          Log.info('   Total videos: ${data['totalVideos']}');
        }
        if (data.containsKey('activeUsers')) {
          expect(data['activeUsers'], isA<num>());
          Log.info('   Active users: ${data['activeUsers']}');
        }
      });
    });

    group('Error Handling', () {
      test('handles invalid video ID for related videos', () async {
        final response = await http
            .get(
              Uri.parse('$baseUrl/analytics/vines/invalid-video-id/related'),
              headers: {'Accept': 'application/json', 'User-Agent': userAgent},
            )
            .timeout(timeout);

        // Should return 404 or 400 for invalid ID
        expect([400, 404].contains(response.statusCode), isTrue);

        Log.info(
          '✅ Invalid video ID handled correctly: ${response.statusCode}',
        );
      });

      test('handles invalid time window parameter', () async {
        final response = await http
            .get(
              Uri.parse(
                '$baseUrl/analytics/trending/vines?window=invalid&limit=10',
              ),
              headers: {'Accept': 'application/json', 'User-Agent': userAgent},
            )
            .timeout(timeout);

        // Should either handle gracefully or return error
        expect([200, 400].contains(response.statusCode), isTrue);

        if (response.statusCode == 200) {
          // Should fall back to default window
          final data = jsonDecode(response.body);
          expect(data['vines'], isA<List>());
          Log.info('✅ Invalid window handled with fallback');
        } else {
          Log.info('✅ Invalid window rejected: ${response.statusCode}');
        }
      });

      test('handles excessive limit parameter', () async {
        final response = await http
            .get(
              Uri.parse(
                '$baseUrl/analytics/trending/vines?window=24h&limit=10000',
              ),
              headers: {'Accept': 'application/json', 'User-Agent': userAgent},
            )
            .timeout(timeout);

        expect(response.statusCode, 200);

        final data = jsonDecode(response.body);
        final vines = data['vines'] as List;

        // Should cap at reasonable limit
        expect(vines.length, lessThanOrEqualTo(1000));

        Log.info('✅ Excessive limit capped at: ${vines.length}');
      });
    });

    group('Caching and Performance', () {
      test('validates caching headers', () async {
        final response = await http
            .get(
              Uri.parse(
                '$baseUrl/analytics/trending/vines?window=24h&limit=10',
              ),
              headers: {'Accept': 'application/json', 'User-Agent': userAgent},
            )
            .timeout(timeout);

        expect(response.statusCode, 200);

        // Check for cache control headers
        final cacheControl = response.headers['cache-control'];
        if (cacheControl != null) {
          Log.info('✅ Cache-Control header: $cacheControl');
          expect(cacheControl, contains(RegExp(r'max-age=\d+')));
        }

        // Check for edge caching
        final cfCache = response.headers['cf-cache-status'];
        if (cfCache != null) {
          Log.info('✅ Cloudflare cache status: $cfCache');
        }
      });

      test('concurrent requests performance', () async {
        final stopwatch = Stopwatch()..start();

        // Make 5 concurrent requests
        final futures = List.generate(
          5,
          (i) => http
              .get(
                Uri.parse(
                  '$baseUrl/analytics/trending/vines?window=24h&limit=10',
                ),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': userAgent,
                },
              )
              .timeout(timeout),
        );

        final responses = await Future.wait(futures);
        stopwatch.stop();

        // All should succeed
        for (final response in responses) {
          expect(response.statusCode, 200);
        }

        // Should handle concurrent requests efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));

        Log.info(
          '✅ Concurrent requests (5): ${stopwatch.elapsedMilliseconds}ms total',
        );
        Log.info(
          '   Average per request: ${(stopwatch.elapsedMilliseconds / 5).toStringAsFixed(0)}ms',
        );
      });
    });
  });
}
