// ABOUTME: Unit tests for Nip98AuthService
// ABOUTME: Tests URL normalization, query param preservation, caching, and
// token creation

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

/// Sets up the mock to return an event whose tags match the requested
/// URL and method, so `_validateAuthEvent` passes inside the service.
void _stubSignEvent(MockAuthService mock) {
  when(
    () => mock.createAndSignEvent(
      kind: any(named: 'kind'),
      content: any(named: 'content'),
      tags: any(named: 'tags'),
    ),
  ).thenAnswer((invocation) async {
    final tags = invocation.namedArguments[#tags] as List<List<String>>? ?? [];
    return _createMockEvent(tags: tags);
  });
}

void main() {
  group(Nip98AuthService, () {
    late MockAuthService mockAuthService;
    late Nip98AuthService service;

    setUp(() {
      mockAuthService = MockAuthService();
      service = Nip98AuthService(authService: mockAuthService);
    });

    tearDown(() {
      service.dispose();
    });

    group('URL normalization', () {
      test('includes query parameters in auth token URL tag', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        final token = await service.createAuthToken(
          url: 'https://relay.example.com/api/notifications?limit=50&types=reaction',
          method: HttpMethod.get,
        );

        expect(token, isNotNull);

        // NIP-98 requires u tag WITH full URL including query params
        final captured =
            verify(
                  () => mockAuthService.createAndSignEvent(
                    kind: any(named: 'kind'),
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;

        final urlTag = captured.firstWhere((tag) => tag[0] == 'u');
        expect(
          urlTag[1],
          equals(
            'https://relay.example.com/api/notifications'
            '?limit=50&types=reaction',
          ),
        );
      });

      test('works correctly without query parameters', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        final token = await service.createAuthToken(
          url: 'https://relay.example.com/api/users/pubkey123/notifications/read',
          method: HttpMethod.post,
        );

        expect(token, isNotNull);

        final captured =
            verify(
                  () => mockAuthService.createAndSignEvent(
                    kind: any(named: 'kind'),
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;

        final urlTag = captured.firstWhere((tag) => tag[0] == 'u');
        expect(
          urlTag[1],
          equals(
            'https://relay.example.com/api/users/'
            'pubkey123/notifications/read',
          ),
        );
      });

      test('strips fragment identifiers from URL', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint#section',
          method: HttpMethod.get,
        );

        final captured =
            verify(
                  () => mockAuthService.createAndSignEvent(
                    kind: any(named: 'kind'),
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;

        final urlTag = captured.firstWhere((tag) => tag[0] == 'u');
        // Fragment should not be included (it's not part of HTTP requests)
        expect(urlTag[1], isNot(contains('#')));
        expect(urlTag[1], equals('https://relay.example.com/api/endpoint'));
      });

      test('preserves port and query in URL normalization', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        await service.createAuthToken(
          url: 'https://relay.example.com:8080/api/endpoint?limit=10',
          method: HttpMethod.get,
        );

        final captured =
            verify(
                  () => mockAuthService.createAndSignEvent(
                    kind: any(named: 'kind'),
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;

        final urlTag = captured.firstWhere((tag) => tag[0] == 'u');
        expect(
          urlTag[1],
          equals('https://relay.example.com:8080/api/endpoint?limit=10'),
        );
      });
    });

    group('token creation', () {
      test('returns null when not authenticated', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);

        final token = await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.get,
        );

        expect(token, isNull);
      });

      test('returns null when event signing fails', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final token = await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.get,
        );

        expect(token, isNull);
      });

      test('includes method tag in auth event', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.post,
        );

        final captured =
            verify(
                  () => mockAuthService.createAndSignEvent(
                    kind: any(named: 'kind'),
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;

        final methodTag = captured.firstWhere((tag) => tag[0] == 'method');
        expect(methodTag[1], equals('POST'));
      });

      test('uses kind 27235 for NIP-98 auth events', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.get,
        );

        verify(
          () => mockAuthService.createAndSignEvent(
            kind: 27235,
            content: '',
            tags: any(named: 'tags'),
          ),
        ).called(1);
      });

      test('base64 encodes the signed event as token', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        final token = await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.get,
        );

        expect(token, isNotNull);
        // The token should be valid base64
        final decoded = utf8.decode(base64Decode(token!.token));
        final decodedJson = jsonDecode(decoded) as Map<String, dynamic>;
        expect(decodedJson, isA<Map<String, dynamic>>());
      });
    });

    group('token caching', () {
      test('returns cached token for identical requests', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        final token1 = await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint?limit=50',
          method: HttpMethod.get,
        );

        final token2 = await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint?limit=50',
          method: HttpMethod.get,
        );

        expect(token1, isNotNull);
        expect(token2, isNotNull);
        expect(token1!.token, equals(token2!.token));

        // createAndSignEvent should only be called once (second uses cache)
        verify(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).called(1);
      });

      test('creates separate tokens for different query params', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);

        var callCount = 0;
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          callCount++;
          final tags =
              invocation.namedArguments[#tags] as List<List<String>>? ?? [];
          return _createMockEvent(tags: tags, idSuffix: callCount.toString());
        });

        final token1 = await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint?limit=50',
          method: HttpMethod.get,
        );

        final token2 = await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint?limit=25',
          method: HttpMethod.get,
        );

        expect(token1, isNotNull);
        expect(token2, isNotNull);
        // Different query params should produce different tokens
        expect(token1!.token, isNot(equals(token2!.token)));

        // Both calls should result in signing (no cache hit)
        verify(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).called(2);
      });

      test(
        'does not reuse a cached token after the active account changes',
        () async {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          var activePubkey =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
          when(() => mockAuthService.currentPublicKeyHex).thenAnswer(
            (_) => activePubkey,
          );

          var callCount = 0;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((invocation) async {
            callCount++;
            final tags =
                invocation.namedArguments[#tags] as List<List<String>>? ?? [];
            return _createMockEvent(tags: tags, idSuffix: callCount.toString());
          });

          final accountAToken = await service.createAuthToken(
            url: 'https://invites.divine.video/v1/invite-status',
            method: HttpMethod.get,
          );

          activePubkey = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          final accountBToken = await service.createAuthToken(
            url: 'https://invites.divine.video/v1/invite-status',
            method: HttpMethod.get,
          );

          expect(accountAToken, isNotNull);
          expect(accountBToken, isNotNull);
          expect(accountBToken!.token, isNot(equals(accountAToken!.token)));
          verify(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).called(2);
        },
      );

      test('clearTokenCache empties the cache', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.get,
        );

        service.clearTokenCache();

        await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.get,
        );

        // After clearing cache, a second call should sign again
        verify(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).called(2);
      });

      test(
        'does not reuse cached token after NIP-98 freshness window',
        () async {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);

          var callCount = 0;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((invocation) async {
            callCount++;
            final tags =
                invocation.namedArguments[#tags] as List<List<String>>? ?? [];
            return _createMockEvent(tags: tags, idSuffix: callCount.toString());
          });

          var now = DateTime.now();
          await withClock(Clock(() => now), () async {
            final token1 = await service.createAuthToken(
              url: 'https://relay.example.com/api/endpoint?cursor=first',
              method: HttpMethod.get,
            );

            now = now.add(const Duration(seconds: 61));

            final token2 = await service.createAuthToken(
              url: 'https://relay.example.com/api/endpoint?cursor=first',
              method: HttpMethod.get,
            );

            expect(token1, isNotNull);
            expect(token2, isNotNull);
            expect(token1!.token, isNot(equals(token2!.token)));
          });

          verify(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).called(2);
        },
      );
    });

    group('payload hashing', () {
      test('includes payload hash when payload is provided', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.post,
          payload: '{"key": "value"}',
        );

        final captured =
            verify(
                  () => mockAuthService.createAndSignEvent(
                    kind: any(named: 'kind'),
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;

        final payloadTag = captured.where((tag) => tag[0] == 'payload');
        expect(payloadTag, isNotEmpty);
        expect(payloadTag.first[1], isNotEmpty);
      });

      test('omits payload tag for GET requests', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.get,
        );

        final captured =
            verify(
                  () => mockAuthService.createAndSignEvent(
                    kind: any(named: 'kind'),
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;

        final payloadTag = captured.where((tag) => tag[0] == 'payload');
        expect(payloadTag, isEmpty);
      });

      test('omits payload tag for DELETE requests', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        _stubSignEvent(mockAuthService);

        await service.createAuthToken(
          url: 'https://relay.example.com/api/endpoint',
          method: HttpMethod.delete,
        );

        final captured =
            verify(
                  () => mockAuthService.createAndSignEvent(
                    kind: any(named: 'kind'),
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;

        final payloadTag = captured.where((tag) => tag[0] == 'payload');
        expect(payloadTag, isEmpty);
      });
    });

    group('$Nip98Token', () {
      test('isExpired returns true for past expiry', () {
        final token = Nip98Token(
          token: 'test',
          signedEvent: _createMockEvent(),
          createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
          expiresAt: DateTime.now().subtract(const Duration(minutes: 10)),
        );

        expect(token.isExpired, isTrue);
      });

      test('isExpired returns false for future expiry', () {
        final token = Nip98Token(
          token: 'test',
          signedEvent: _createMockEvent(),
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        );

        expect(token.isExpired, isFalse);
      });

      test('authorizationHeader has Nostr prefix', () {
        final token = Nip98Token(
          token: 'test_token_value',
          signedEvent: _createMockEvent(),
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        );

        expect(token.authorizationHeader, equals('Nostr test_token_value'));
      });
    });

    group('$Nip98AuthException', () {
      test('toString includes message', () {
        const exception = Nip98AuthException('test error');
        expect(exception.toString(), equals('Nip98AuthException: test error'));
      });

      test('stores code when provided', () {
        const exception = Nip98AuthException('test', code: 'ERR_001');
        expect(exception.code, equals('ERR_001'));
      });
    });

    group('canCreateTokens', () {
      test('returns true when authenticated', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        expect(service.canCreateTokens, isTrue);
      });

      test('returns false when not authenticated', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        expect(service.canCreateTokens, isFalse);
      });
    });
  });
}

/// Creates a mock Event for testing.
/// When [tags] are provided, they are used as the event's tags so that
/// the service's internal `_validateAuthEvent` check passes.
Event _createMockEvent({List<List<String>>? tags, String idSuffix = ''}) {
  final id =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef012345$idSuffix'
          .padRight(64, '0')
          .substring(0, 64);
  final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
  final eventTags =
      tags ??
      <List<String>>[
        ['u', 'https://relay.example.com/api/endpoint'],
        ['method', 'GET'],
        ['created_at', timestamp.toString()],
      ];
  return Event.fromJson({
    'id': id,
    'kind': 27235,
    'pubkey':
        'aabbccdd0123456789abcdef0123456789abcdef0123456789abcdef01234567',
    'created_at': timestamp,
    'content': '',
    'tags': eventTags,
    'sig':
        'deadbeef0123456789abcdef0123456789abcdef0123456789abcdef01234567'
        '89abcdef0123456789abcdef0123456789abcdef0123456789abcdef01234567'
        '89ab',
  });
}
