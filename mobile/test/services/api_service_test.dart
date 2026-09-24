// ABOUTME: Unit tests for ApiService to verify backend communication functionality
// ABOUTME: Tests HTTP requests, error handling, and response parsing for API endpoints

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

// Mock classes
class MockHttpClient extends Mock implements http.Client {}

class MockResponse extends Mock implements http.Response {}

class MockAuthService extends Mock implements AuthService {}

Event _createMockSignedEvent(List<List<String>> tags) {
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
  return Event.fromJson({
    'id': 'ab' * 32,
    'kind': 27235,
    'pubkey':
        'aabbccdd0123456789abcdef0123456789abcdef0123456789abcdef01234567',
    'created_at': timestamp,
    'content': '',
    'tags': tags,
    'sig': 'cd' * 64,
  });
}

class MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
    registerFallbackValue(HttpMethod.get);
  });

  group('ApiService', () {
    late ApiService apiService;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      apiService = ApiService(
        client: mockClient,
        relayManagerBaseUrl: 'https://api-relay-prod.divine.video',
        appVersion: 'test',
      );
    });

    group('minor account review endpoints', () {
      test(
        'getMinorAccountReviewStatus returns parsed response on success',
        () async {
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.body).thenReturn(
            jsonEncode({
              'restriction': {'status': 'restricted_minor_review'},
            }),
          );

          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => mockResponse);

          final result = await apiService.getMinorAccountReviewStatus();

          expect(result['restriction'], isA<Map<String, dynamic>>());
        },
      );

      test(
        'bounds token creation and transport with one request deadline',
        () async {
          final authService = MockNip98AuthService();
          when(() => authService.canCreateTokens).thenReturn(true);
          when(
            () => authService.createAuthToken(
              url: any(named: 'url'),
              method: any(named: 'method'),
            ),
          ).thenAnswer((_) => Completer<Nip98Token?>().future);
          final service = ApiService(
            client: mockClient,
            authService: authService,
            relayManagerBaseUrl: 'https://api-relay-prod.divine.video',
            appVersion: 'test',
            requestTimeout: const Duration(milliseconds: 1),
          );

          await expectLater(
            service.getMinorAccountReviewStatus(),
            throwsA(isA<ApiException>()),
          );
          verifyNever(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          );
        },
      );

      test(
        'getMinorAccountReviewStatus uses the relay-manager host, '
        'not the main backend (relay-manager#108: backend 404s -> gate inert)',
        () async {
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.body).thenReturn(
            jsonEncode({
              'restriction': {'status': 'active'},
            }),
          );

          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => mockResponse);

          await apiService.getMinorAccountReviewStatus();

          final captured =
              verify(
                    () => mockClient.get(
                      captureAny(),
                      headers: any(named: 'headers'),
                    ),
                  ).captured.single
                  as Uri;

          expect(captured.host, 'api-relay-prod.divine.video');
          expect(captured.path, '/v1/account/moderation-status');
        },
      );

      test(
        'minor-review calls follow the injected relay-manager base URL '
        '(env-aware: staging builds must not hit prod)',
        () async {
          final stagingService = ApiService(
            client: mockClient,
            relayManagerBaseUrl: 'https://api-relay-staging.divine.video',
            appVersion: 'test',
          );
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.body).thenReturn(
            jsonEncode({
              'restriction': {'status': 'active'},
            }),
          );
          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => mockResponse);

          await stagingService.getMinorAccountReviewStatus();

          final captured =
              verify(
                    () => mockClient.get(
                      captureAny(),
                      headers: any(named: 'headers'),
                    ),
                  ).captured.single
                  as Uri;
          expect(captured.host, 'api-relay-staging.divine.video');

          // Both endpoints read the same injected base — pin the POST too
          when(() => mockResponse.statusCode).thenReturn(204);
          when(() => mockResponse.body).thenReturn('');
          when(
            () => mockClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => mockResponse);

          await stagingService.submitMinorAccountReviewParentContact(
            caseId: 'case-9',
            email: 'parent@example.com',
          );

          final posted =
              verify(
                    () => mockClient.post(
                      captureAny(),
                      headers: any(named: 'headers'),
                      body: any(named: 'body'),
                    ),
                  ).captured.single
                  as Uri;
          expect(posted.host, 'api-relay-staging.divine.video');
        },
      );

      test(
        'getMinorAccountReviewStatus throws ApiException on non-200',
        () async {
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(503);
          when(() => mockResponse.body).thenReturn('Unavailable');

          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => mockResponse);

          expect(
            apiService.getMinorAccountReviewStatus,
            throwsA(
              isA<ApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                503,
              ),
            ),
          );
        },
      );

      test(
        'submitMinorAccountReviewParentContact posts email payload',
        () async {
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(204);
          when(() => mockResponse.body).thenReturn('');

          when(
            () => mockClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => mockResponse);

          await apiService.submitMinorAccountReviewParentContact(
            caseId: 'case-123',
            email: 'parent@example.com',
          );

          final captured =
              verify(
                    () => mockClient.post(
                      captureAny(),
                      headers: any(named: 'headers'),
                      body: jsonEncode({'email': 'parent@example.com'}),
                    ),
                  ).captured.single
                  as Uri;

          // Same host contract as moderation-status (relay-manager#108)
          expect(captured.host, 'api-relay-prod.divine.video');
          expect(
            captured.path,
            '/v1/minor-review-cases/case-123/parent-contact',
          );
        },
      );

      test('signs the exact parent contact request bytes', () async {
        final mockAuthService = MockAuthService();
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final tags = invocation.namedArguments[#tags] as List<List<String>>;
          return _createMockSignedEvent(tags);
        });

        final nip98AuthService = Nip98AuthService(
          authService: mockAuthService,
        );
        addTearDown(nip98AuthService.dispose);

        List<int>? transmittedBodyBytes;
        Map<String, String>? transmittedHeaders;
        final capturingClient = http_testing.MockClient((request) async {
          transmittedBodyBytes = request.bodyBytes;
          transmittedHeaders = request.headers;
          return http.Response('', 204);
        });
        final authenticatedApiService = ApiService(
          client: capturingClient,
          relayManagerBaseUrl: 'https://api-relay-prod.divine.video',
          appVersion: 'test',
          authService: nip98AuthService,
        );
        addTearDown(authenticatedApiService.dispose);

        await authenticatedApiService.submitMinorAccountReviewParentContact(
          caseId: 'case-123',
          email: 'parent@example.com',
        );

        final authorization = transmittedHeaders!['Authorization']!;
        final eventJson = jsonDecode(
          utf8.decode(base64Decode(authorization.substring('Nostr '.length))),
        ) as Map<String, dynamic>;
        final tags = (eventJson['tags'] as List<dynamic>).cast<List<dynamic>>();
        final payloadTag = tags.firstWhere((tag) => tag[0] == 'payload');

        expect(transmittedBodyBytes, isNotNull);
        expect(
          sha256.convert(transmittedBodyBytes!).toString(),
          payloadTag[1],
        );
      });
    });

    group('client identity headers', () {
      test(
        'sends app version, platform, and X-Divine-Platform via injection, '
        'not the old divine-Mobile literal',
        () async {
          final injected = ApiService(
            client: mockClient,
            relayManagerBaseUrl: 'https://api-relay-prod.divine.video',
            appVersion: '1.0.20',
          );

          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.body).thenReturn('{}');

          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => mockResponse);

          await injected.getMinorAccountReviewStatus();

          final captured = verify(
            () => mockClient.get(any(), headers: captureAny(named: 'headers')),
          ).captured;
          final headers = captured.whereType<Map<String, String>>().single;
          expect(
            headers['User-Agent'],
            matches(
              RegExp(
                r'^Divine-Mobile/1\.0\.20 \((iOS|Android|macOS|Linux|Windows|Web)\)$',
              ),
            ),
          );
          expect(headers['User-Agent'], isNot('divine-Mobile/1.0'));
          expect(
            headers['X-Divine-Platform'],
            matches(RegExp(r'^(ios|android|macos|linux|windows|web)$')),
          );
        },
      );
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
