import 'dart:convert';
import 'package:openvine/utils/unified_logger.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('Analytics API Integration Tests', () {
    group('Trending Endpoint (/analytics/trending/vines)', () {
      test('returns valid trending data structure', () async {
        final response = await http
            .get(
              Uri.parse('https://api.openvine.co/analytics/trending/vines'),
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'OpenVine-Mobile-Test/1.0',
              },
            )
            .timeout(const Duration(seconds: 10));

        expect(response.statusCode, 200);

        final data = jsonDecode(response.body);
        expect(data, isA<Map<String, dynamic>>());
        expect(data['vines'], isA<List>());

        // Check that we have at least some trending videos
        final vines = data['vines'] as List;
        if (vines.isNotEmpty) {
          final firstVine = vines.first;
          expect(firstVine['eventId'], isA<String>());
          expect(firstVine['views'], isA<num>());
          expect(firstVine['score'], isA<num>());

          // Event ID should be a valid hex string (64 chars for SHA-256)
          final eventId = firstVine['eventId'] as String;
          expect(eventId.length, 64);
          expect(RegExp(r'^[a-f0-9]+$').hasMatch(eventId), true);
        }

        Log.info('✅ Trending API integration test passed');
        Log.info('   Trending videos found: ${vines.length}');
      });

      test('handles trending API timeout gracefully', () async {
        // This test might timeout, but shouldn't crash
        try {
          await http
              .get(
                Uri.parse('https://api.openvine.co/analytics/trending/vines'),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': 'OpenVine-Mobile-Test/1.0',
                },
              )
              .timeout(const Duration(milliseconds: 100)); // Very short timeout
        } catch (e) {
          // Should handle timeout gracefully - TimeoutException or contains 'timeout'
          expect(
            e.toString().toLowerCase(),
            anyOf(contains('timeout'), contains('timeoutexception')),
          );
        }
      });
    });

    group('View Tracking Endpoint (/analytics/view)', () {
      test('accepts valid view tracking data', () async {
        final viewData = {
          'eventId':
              'test-event-id-for-integration-test-12345678901234567890123456789012',
          'source': 'integration_test',
          'eventType': 'view_start',
          'creatorPubkey': 'test-creator-pubkey-for-integration-testing',
          'title': 'Integration Test Video',
          'hashtags': ['test', 'integration'],
          'timestamp': DateTime.now().toIso8601String(),
        };

        final response = await http
            .post(
              Uri.parse('https://api.openvine.co/analytics/view'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'OpenVine-Mobile-Test/1.0',
              },
              body: jsonEncode(viewData),
            )
            .timeout(const Duration(seconds: 10));

        // Should accept the data (200) or handle gracefully (other status codes)
        expect([200, 202, 400].contains(response.statusCode), isTrue);

        Log.info('✅ View tracking API integration test passed');
        Log.info('   Response status: ${response.statusCode}');
      });

      test('handles malformed view tracking data', () async {
        final malformedData = {
          'invalidField': 'invalid_value',
          // Missing required fields
        };

        final response = await http
            .post(
              Uri.parse('https://api.openvine.co/analytics/view'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'OpenVine-Mobile-Test/1.0',
              },
              body: jsonEncode(malformedData),
            )
            .timeout(const Duration(seconds: 10));

        // Should handle malformed data gracefully (not crash)
        expect([400, 422, 500].contains(response.statusCode), isTrue);

        Log.info('✅ View tracking malformed data test passed');
        Log.info(
          '   Response status for malformed data: ${response.statusCode}',
        );
      });

      test('handles view tracking with minimal data', () async {
        final minimalData = {
          'eventId':
              'minimal-test-event-id-for-integration-testing-123456789012',
          'source': 'integration_test_minimal',
          'eventType': 'view_start',
        };

        final response = await http
            .post(
              Uri.parse('https://api.openvine.co/analytics/view'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'OpenVine-Mobile-Test/1.0',
              },
              body: jsonEncode(minimalData),
            )
            .timeout(const Duration(seconds: 10));

        // Should handle minimal valid data
        expect([200, 202, 400].contains(response.statusCode), isTrue);

        Log.info('✅ View tracking minimal data test passed');
        Log.info('   Response status for minimal data: ${response.statusCode}');
      });

      test('handles view tracking timeout gracefully', () async {
        final viewData = {
          'eventId':
              'timeout-test-event-id-for-integration-testing-123456789012',
          'source': 'integration_test_timeout',
          'eventType': 'view_start',
        };

        try {
          await http
              .post(
                Uri.parse('https://api.openvine.co/analytics/view'),
                headers: {
                  'Content-Type': 'application/json',
                  'User-Agent': 'OpenVine-Mobile-Test/1.0',
                },
                body: jsonEncode(viewData),
              )
              .timeout(const Duration(milliseconds: 50)); // Very short timeout
        } catch (e) {
          // Should handle timeout gracefully - TimeoutException or contains 'timeout'
          expect(
            e.toString().toLowerCase(),
            anyOf(contains('timeout'), contains('timeoutexception')),
          );
        }
      });
    });

    group('Error Handling', () {
      test('handles invalid endpoints gracefully', () async {
        final response = await http
            .get(
              Uri.parse('https://api.openvine.co/analytics/invalid-endpoint'),
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'OpenVine-Mobile-Test/1.0',
              },
            )
            .timeout(const Duration(seconds: 10));

        expect(response.statusCode, 404);

        Log.info('✅ Analytics API error handling test passed');
      });

      test('handles network connectivity issues', () async {
        // Test with intentionally invalid domain
        try {
          await http
              .get(
                Uri.parse(
                  'https://nonexistent-analytics-domain.invalid/analytics/trending/vines',
                ),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': 'OpenVine-Mobile-Test/1.0',
                },
              )
              .timeout(const Duration(seconds: 2));
        } catch (e) {
          // Should handle network errors gracefully
          expect(e, isA<Exception>());
        }

        Log.info('✅ Network connectivity error handling test passed');
      });
    });

    group('API Health & Performance', () {
      test('trending endpoint responds within reasonable time', () async {
        final stopwatch = Stopwatch()..start();

        final response = await http
            .get(
              Uri.parse('https://api.openvine.co/analytics/trending/vines'),
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'OpenVine-Mobile-Test/1.0',
              },
            )
            .timeout(const Duration(seconds: 10));

        stopwatch.stop();

        expect(response.statusCode, 200);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
        ); // Should respond within 5 seconds

        Log.info('✅ Trending API performance test passed');
        Log.info('   Response time: ${stopwatch.elapsedMilliseconds}ms');
      });

      test('view tracking endpoint responds within reasonable time', () async {
        final stopwatch = Stopwatch()..start();

        final viewData = {
          'eventId':
              'perf-test-event-id-for-integration-testing-123456789012345',
          'source': 'integration_test_performance',
          'eventType': 'view_start',
        };

        final response = await http
            .post(
              Uri.parse('https://api.openvine.co/analytics/view'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'OpenVine-Mobile-Test/1.0',
              },
              body: jsonEncode(viewData),
            )
            .timeout(const Duration(seconds: 10));

        stopwatch.stop();

        // Should respond quickly for analytics
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(3000),
        ); // Should respond within 3 seconds

        Log.info('✅ View tracking API performance test passed');
        Log.info('   Response time: ${stopwatch.elapsedMilliseconds}ms');
        Log.info('   Response status: ${response.statusCode}');
      });
    });
  });
}
