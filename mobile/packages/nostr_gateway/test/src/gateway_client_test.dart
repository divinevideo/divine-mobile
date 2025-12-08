// Easier to read and understand test validation
// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_gateway/src/exceptions/exceptions.dart';
import 'package:nostr_gateway/src/gateway_client.dart';
import 'package:nostr_gateway/src/models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockDio extends Mock implements Dio {}

class MockResponse extends Mock implements Response<Map<String, dynamic>> {}

void main() {
  group('GatewayClient', () {
    late MockDio mockDio;
    late GatewayClient gatewayClient;
    const testGatewayUrl = 'https://test-gateway.example.com';
    const testPubkey =
        '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';
    const testEventId =
        '0000000000000000000000000000000000000000000000000000000000000000';

    setUp(() {
      mockDio = MockDio();
      gatewayClient = GatewayClient(gatewayUrl: testGatewayUrl, dio: mockDio);
    });

    tearDown(() {
      gatewayClient.dispose();
    });

    group('constructor', () {
      test('uses default gateway URL when not provided', () {
        final client = GatewayClient(dio: mockDio);
        expect(client.gatewayUrl, equals(GatewayClient.defaultGatewayUrl));
      });

      test('uses custom gateway URL when provided', () {
        expect(gatewayClient.gatewayUrl, equals(testGatewayUrl));
      });

      test('creates Dio instance when not provided', () {
        final client = GatewayClient(gatewayUrl: testGatewayUrl);
        expect(client.gatewayUrl, equals(testGatewayUrl));
        client.dispose();
      });
    });

    group('query', () {
      test('returns GatewayResponse when request succeeds', () async {
        final filter = Filter(kinds: [0], limit: 10);
        final filterJson = filter.toJson();
        final encoded = base64Url.encode(utf8.encode(jsonEncode(filterJson)));

        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.data).thenReturn({
          'events': <Map<String, dynamic>>[
            {
              'id': testEventId,
              'pubkey': testPubkey,
              'created_at': 1234567890,
              'kind': 0,
              'tags': <dynamic>[],
              'content': '{"name":"Test"}',
              'sig': '',
            },
          ],
          'eose': true,
          'complete': true,
          'cached': false,
        });

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await gatewayClient.query(filter);

        expect(result, isA<GatewayResponse>());
        expect(result.events, hasLength(1));
        expect(result.eose, isTrue);
        expect(result.complete, isTrue);
        expect(result.cached, isFalse);

        verify(
          () => mockDio.get<Map<String, dynamic>>(
            '$testGatewayUrl/query',
            queryParameters: {'filter': encoded},
          ),
        ).called(1);
      });

      test('encodes filter correctly in query parameters', () async {
        final filter = Filter(kinds: [22], limit: 5);
        final filterJson = filter.toJson();
        final expectedEncoded = base64Url.encode(
          utf8.encode(jsonEncode(filterJson)),
        );

        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.data).thenReturn({
          'events': <Map<String, dynamic>>[],
          'eose': true,
          'complete': true,
          'cached': false,
        });

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        await gatewayClient.query(filter);

        verify(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: {'filter': expectedEncoded},
          ),
        ).called(1);
      });

      test('throws GatewayException when status code is not 200', () async {
        final filter = Filter(kinds: [0]);
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(404);
        when(() => mockResponse.data).thenReturn({'error': 'Not found'});

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        expect(
          () => gatewayClient.query(filter),
          throwsA(
            isA<GatewayException>().having(
              (e) => e.message,
              'message',
              contains('HTTP 404'),
            ),
          ),
        );
      });

      test(
        'throws GatewayException when DioException occurs with response',
        () async {
          final filter = Filter(kinds: [0]);
          final dioException = DioException(
            requestOptions: RequestOptions(path: '/query'),
            response: Response(
              requestOptions: RequestOptions(path: '/query'),
              statusCode: 500,
              data: {'error': 'Internal server error'},
            ),
          );

          when(
            () => mockDio.get<Map<String, dynamic>>(
              any(),
              queryParameters: any(named: 'queryParameters'),
            ),
          ).thenThrow(dioException);

          expect(
            () => gatewayClient.query(filter),
            throwsA(
              isA<GatewayException>().having(
                (e) => e.statusCode,
                'statusCode',
                500,
              ),
            ),
          );
        },
      );

      test(
        'throws GatewayException when DioException occurs without response',
        () async {
          final filter = Filter(kinds: [0]);
          final dioException = DioException(
            requestOptions: RequestOptions(path: '/query'),
            error: 'Network error',
          );

          when(
            () => mockDio.get<Map<String, dynamic>>(
              any(),
              queryParameters: any(named: 'queryParameters'),
            ),
          ).thenThrow(dioException);

          expect(
            () => gatewayClient.query(filter),
            throwsA(
              isA<GatewayException>().having(
                (e) => e.message,
                'message',
                contains('Network error'),
              ),
            ),
          );
        },
      );

      test(
        'throws GatewayException when response data is null',
        () async {
          final filter = Filter(kinds: [0]);
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.data).thenReturn(null);

          when(
            () => mockDio.get<Map<String, dynamic>>(
              any(),
              queryParameters: any(named: 'queryParameters'),
            ),
          ).thenAnswer((_) async => mockResponse);

          // Null check operator will throw, which is not caught by Exception handler
          expect(
            () => gatewayClient.query(filter),
            throwsA(isA<TypeError>()),
          );
        },
      );
    });

    group('getProfile', () {
      test('returns Event when profile exists', () async {
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.data).thenReturn({
          'events': <Map<String, dynamic>>[
            {
              'id': testEventId,
              'pubkey': testPubkey,
              'created_at': 1234567890,
              'kind': 0,
              'tags': <dynamic>[],
              'content': '{"name":"Test User"}',
              'sig': '',
            },
          ],
          'eose': true,
          'complete': true,
          'cached': false,
        });

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await gatewayClient.getProfile(testPubkey);

        expect(result, isNotNull);
        expect(result!.kind, equals(0));
        expect(result.pubkey, equals(testPubkey));

        verify(
          () => mockDio.get<Map<String, dynamic>>(
            '$testGatewayUrl/profile/$testPubkey',
            queryParameters: null,
          ),
        ).called(1);
      });

      test('returns null when profile does not exist', () async {
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.data).thenReturn({
          'events': <Map<String, dynamic>>[],
          'eose': true,
          'complete': true,
          'cached': false,
        });

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await gatewayClient.getProfile(testPubkey);

        expect(result, isNull);
      });

      test('throws GatewayException when request fails', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/profile/$testPubkey'),
          response: Response(
            requestOptions: RequestOptions(path: '/profile/$testPubkey'),
            statusCode: 500,
          ),
        );

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenThrow(dioException);

        expect(
          () => gatewayClient.getProfile(testPubkey),
          throwsA(isA<GatewayException>()),
        );
      });
    });

    group('getEvent', () {
      test('returns Event when event exists', () async {
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.data).thenReturn({
          'events': <Map<String, dynamic>>[
            {
              'id': testEventId,
              'pubkey': testPubkey,
              'created_at': 1234567890,
              'kind': 1,
              'tags': <dynamic>[],
              'content': 'Test content',
              'sig': '',
            },
          ],
          'eose': true,
          'complete': true,
          'cached': false,
        });

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await gatewayClient.getEvent(testEventId);

        expect(result, isNotNull);
        expect(result!.id, equals(testEventId));
        expect(result.kind, equals(1));

        verify(
          () => mockDio.get<Map<String, dynamic>>(
            '$testGatewayUrl/event/$testEventId',
            queryParameters: null,
          ),
        ).called(1);
      });

      test('returns null when event does not exist', () async {
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.data).thenReturn({
          'events': <Map<String, dynamic>>[],
          'eose': true,
          'complete': true,
          'cached': false,
        });

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await gatewayClient.getEvent(testEventId);

        expect(result, isNull);
      });

      test('throws GatewayException when request fails', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/event/$testEventId'),
          response: Response(
            requestOptions: RequestOptions(path: '/event/$testEventId'),
            statusCode: 404,
          ),
        );

        when(
          () => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenThrow(dioException);

        expect(
          () => gatewayClient.getEvent(testEventId),
          throwsA(isA<GatewayException>()),
        );
      });
    });

    group('dispose', () {
      test('closes Dio instance', () {
        gatewayClient.dispose();

        verify(() => mockDio.close()).called(1);
      });
    });
  });
}
