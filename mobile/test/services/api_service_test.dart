// ABOUTME: Unit tests for ApiService to verify backend communication functionality
// ABOUTME: Tests HTTP requests, error handling, and response parsing for API endpoints

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/api_service.dart';

// Mock classes
class MockHttpClient extends Mock implements http.Client {}

class MockResponse extends Mock implements http.Response {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  group('ApiService', () {
    late ApiService apiService;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      apiService = ApiService(client: mockClient);
    });

    group('requestSignedUpload', () {
      test('should return signed upload parameters on success', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.body).thenReturn(
          jsonEncode({
            'upload_url': 'https://example.com/upload',
            'signed_fields': {'key': 'value'},
          }),
        );

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.requestSignedUpload(
          nostrPubkey: 'test_pubkey',
          fileSize: 1024,
          mimeType: 'video/mp4',
        );

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result['upload_url'], equals('https://example.com/upload'));
        expect(result['signed_fields'], isA<Map<String, dynamic>>());
      });

      test('should handle API error responses', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(400);
        when(() => mockResponse.body).thenReturn('Bad Request');

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => apiService.requestSignedUpload(
            nostrPubkey: 'test_pubkey',
            fileSize: 1024,
            mimeType: 'video/mp4',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(400),
            ),
          ),
        );
      });

      test('should handle network timeout', () async {
        // Arrange
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('timeout'));

        // Act & Assert
        expect(
          () => apiService.requestSignedUpload(
            nostrPubkey: 'test_pubkey',
            fileSize: 1024,
            mimeType: 'video/mp4',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              contains('Network error'),
            ),
          ),
        );
      });
    });

    group('ApiException', () {
      test('should format error message correctly', () {
        // Act
        const exception = ApiException('Test error', statusCode: 404);

        // Assert
        expect(exception.toString(), 'ApiException: Test error (404)');
      });

      test('should handle missing status code', () {
        // Act
        const exception = ApiException('Test error');

        // Assert
        expect(exception.toString(), 'ApiException: Test error (no status)');
      });
    });
  });
}
