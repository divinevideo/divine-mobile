// ABOUTME: Tests for ApiService with rate limiting integration
// ABOUTME: Ensures API calls are properly rate limited

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/network/rate_limiter.dart';

void main() {
  group('ApiService with RateLimiter', () {
    late ApiService apiService;
    late RateLimiter rateLimiter;
    late http.Client mockClient;

    setUp(() {
      rateLimiter = RateLimiter();
    });

    tearDown(() {
      rateLimiter.dispose();
    });

    test('should rate limit API calls', () async {
      // Arrange
      var callCount = 0;
      mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'upload_url': 'https://example.com/upload',
            'signed_fields': {'key': 'value'},
          }),
          200,
        );
      });

      apiService = ApiService(client: mockClient, rateLimiter: rateLimiter);

      // Configure aggressive rate limit for testing
      rateLimiter.configureEndpoint(
        '/v1/media/request-upload',
        const RateLimitConfig(2, Duration(seconds: 10)),
      );

      // Act - Make 2 requests (should succeed)
      for (var i = 0; i < 2; i++) {
        await apiService.requestSignedUpload(
          nostrPubkey: 'test_pubkey',
          fileSize: 1024,
          mimeType: 'video/mp4',
        );
      }

      // Assert - should have made 2 HTTP calls
      expect(callCount, 2);

      // Additional test: 3rd request should be rate limited
      expect(
        () => apiService.requestSignedUpload(
          nostrPubkey: 'test_pubkey',
          fileSize: 1024,
          mimeType: 'video/mp4',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('should work without rate limiter (backward compatibility)', () async {
      // Arrange
      mockClient = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'upload_url': 'https://example.com/upload',
            'signed_fields': {'key': 'value'},
          }),
          200,
        ),
      );

      // Create ApiService without rate limiter
      apiService = ApiService(client: mockClient);

      // Act & Assert - Should work normally
      final result = await apiService.requestSignedUpload(
        nostrPubkey: 'test_pubkey',
        fileSize: 1024,
        mimeType: 'video/mp4',
      );

      expect(result, isA<Map<String, dynamic>>());
    });
  });
}
