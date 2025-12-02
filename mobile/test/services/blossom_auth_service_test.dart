// ABOUTME: Tests for Blossom BUD-01 authentication service (kind 24242)
// ABOUTME: Validates creation of signed auth events for age-restricted content access

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockEvent extends Mock implements Event {}

void main() {
  late MockAuthService mockAuthService;
  late BlossomAuthService blossomAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    blossomAuthService = BlossomAuthService(authService: mockAuthService);
  });

  tearDown(() {
    blossomAuthService.dispose();
  });

  group('BlossomAuthService - GET request auth', () {
    test(
      'createGetAuthHeader returns null when user not authenticated',
      () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(false);

        // Act
        final result = await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
          serverUrl: 'https://blossom.example.com',
        );

        // Assert
        expect(result, isNull);
      },
    );

    test(
      'createGetAuthHeader creates kind 24242 event with correct tags',
      () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);

        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn('event123');
        when(() => mockEvent.kind).thenReturn(24242);
        when(() => mockEvent.pubkey).thenReturn('pubkey123');
        when(() => mockEvent.createdAt).thenReturn(1234567890);
        when(
          () => mockEvent.content,
        ).thenReturn('Get blob from Blossom server');
        when(() => mockEvent.tags).thenReturn([
          ['t', 'get'],
          ['x', 'abc123'],
          ['expiration', '1234570000'],
        ]);
        when(() => mockEvent.sig).thenReturn('signature123');
        when(() => mockEvent.toJson()).thenReturn({
          'id': 'event123',
          'kind': 24242,
          'pubkey': 'pubkey123',
          'created_at': 1234567890,
          'content': 'Get blob from Blossom server',
          'tags': [
            ['t', 'get'],
            ['x', 'abc123'],
            ['expiration', '1234570000'],
          ],
          'sig': 'signature123',
        });

        when(
          () => mockAuthService.createAndSignEvent(
            kind: 24242,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => mockEvent);

        // Act
        final result = await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
          serverUrl: 'https://blossom.example.com',
        );

        // Assert
        expect(result, isNotNull);
        expect(result, startsWith('Nostr '));

        // Verify correct event creation
        final captured = verify(
          () => mockAuthService.createAndSignEvent(
            kind: 24242,
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        expect(captured[0], contains('Get blob'));
        final tags = captured[1] as List<List<String>>;
        expect(tags.any((tag) => tag[0] == 't' && tag[1] == 'get'), isTrue);
        expect(tags.any((tag) => tag[0] == 'x' && tag[1] == 'abc123'), isTrue);
        expect(tags.any((tag) => tag[0] == 'expiration'), isTrue);
      },
    );

    test(
      'createGetAuthHeader includes server tag when serverUrl provided',
      () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);

        final mockEvent = MockEvent();
        when(() => mockEvent.toJson()).thenReturn({
          'id': 'event123',
          'kind': 24242,
          'pubkey': 'pubkey123',
          'created_at': 1234567890,
          'content': 'Get blob from Blossom server',
          'tags': [
            ['t', 'get'],
            ['x', 'abc123'],
            ['server', 'https://blossom.example.com'],
          ],
          'sig': 'signature123',
        });

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => mockEvent);

        // Act
        await blossomAuthService.createGetAuthHeader(
          sha256Hash: 'abc123',
          serverUrl: 'https://blossom.example.com',
        );

        // Assert
        final captured = verify(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        final tags = captured[0] as List<List<String>>;
        expect(
          tags.any(
            (tag) =>
                tag[0] == 'server' && tag[1] == 'https://blossom.example.com',
          ),
          isTrue,
        );
      },
    );

    test('createGetAuthHeader caches tokens to avoid re-signing', () async {
      // Arrange
      when(() => mockAuthService.isAuthenticated).thenReturn(true);

      final mockEvent = MockEvent();
      when(() => mockEvent.id).thenReturn('event123');
      when(() => mockEvent.toJson()).thenReturn({
        'id': 'event123',
        'kind': 24242,
        'tags': [
          ['t', 'get'],
          ['x', 'abc123'],
        ],
      });

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => mockEvent);

      // Act
      final result1 = await blossomAuthService.createGetAuthHeader(
        sha256Hash: 'abc123',
      );
      final result2 = await blossomAuthService.createGetAuthHeader(
        sha256Hash: 'abc123',
      );

      // Assert
      expect(result1, equals(result2));
      verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(1); // Only called once due to caching
    });

    test('createGetAuthHeader sets expiration 1 hour in future', () async {
      // Arrange
      when(() => mockAuthService.isAuthenticated).thenReturn(true);

      final mockEvent = MockEvent();
      when(() => mockEvent.id).thenReturn('event123');
      when(() => mockEvent.toJson()).thenReturn({
        'id': 'event123',
        'kind': 24242,
        'tags': [
          ['t', 'get'],
          ['x', 'abc123'],
        ],
      });

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => mockEvent);

      // Act
      await blossomAuthService.createGetAuthHeader(sha256Hash: 'abc123');

      // Assert
      final captured = verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;

      final tags = captured[0] as List<List<String>>;
      final expirationTag = tags.firstWhere((tag) => tag[0] == 'expiration');
      final expirationTimestamp = int.parse(expirationTag[1]);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final oneHourFromNow = now + 3600;

      // Allow 5 second tolerance for test execution time
      expect(expirationTimestamp, greaterThanOrEqualTo(now + 3595));
      expect(expirationTimestamp, lessThanOrEqualTo(oneHourFromNow + 5));
    });
  });

  group('BlossomAuthService - cache management', () {
    test('clearCache removes all cached tokens', () async {
      // Arrange
      when(() => mockAuthService.isAuthenticated).thenReturn(true);

      final mockEvent = MockEvent();
      when(() => mockEvent.id).thenReturn('event123');
      when(() => mockEvent.toJson()).thenReturn({
        'id': 'event123',
        'kind': 24242,
        'tags': [
          ['t', 'get'],
        ],
      });

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => mockEvent);

      // Create cached token
      await blossomAuthService.createGetAuthHeader(sha256Hash: 'abc123');

      // Act
      blossomAuthService.clearCache();

      // Second call should create new token (not use cache)
      await blossomAuthService.createGetAuthHeader(sha256Hash: 'abc123');

      // Assert
      verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(2); // Called twice, not cached
    });
  });
}
