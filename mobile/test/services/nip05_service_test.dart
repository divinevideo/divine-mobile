// ABOUTME: Unit tests for NIP-05 username registration and verification service
// ABOUTME: Tests username validation, availability checking, and registration flow

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/nip05_service.dart';

@GenerateMocks([http.Client])
import 'nip05_service_test.mocks.dart';

void main() {
  group('Nip05Service', () {
    late Nip05Service service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      service = Nip05Service(httpClient: mockClient);
    });

    group('checkUsernameAvailability', () {
      test('returns true when username is available', () async {
        // Arrange
        const username = 'testuser';
        when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response(jsonEncode({'names': {}}), 200),
        );

        // Act
        final result = await service.checkUsernameAvailability(username);

        // Assert
        expect(result, true);
        expect(service.error, isNull);
      });

      test('returns false when username is taken', () async {
        // Arrange
        const username = 'taken';
        when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'names': {'taken': 'pubkey123'},
            }),
            200,
          ),
        );

        // Act
        final result = await service.checkUsernameAvailability(username);

        // Assert
        expect(result, false);
      });

      test('validates username format', () async {
        // Test invalid usernames
        expect(await service.checkUsernameAvailability(''), false);
        expect(
          await service.checkUsernameAvailability('a'),
          false,
        ); // too short
        expect(
          await service.checkUsernameAvailability('user name'),
          false,
        ); // contains space
        expect(
          await service.checkUsernameAvailability('user@name'),
          false,
        ); // invalid char
        expect(
          await service.checkUsernameAvailability('aaaaaaaaaaaaaaaaaaaaa'),
          false,
        ); // too long (21 chars)

        // Check error message is set
        expect(service.error, contains('Invalid username format'));
      });

      test('handles network errors gracefully', () async {
        // Arrange
        const username = 'testuser';
        when(mockClient.get(any)).thenThrow(Exception('Network error'));

        // Act
        final result = await service.checkUsernameAvailability(username);

        // Assert
        expect(result, false);
        expect(service.error, contains('Failed to check username'));
      });
    });

    group('registerUsername', () {
      test('successfully registers a username', () async {
        // Arrange
        const username = 'newuser';
        const pubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; // Valid 64-char hex
        final relays = ['wss://relay1.com', 'wss://relay2.com'];

        when(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'success': true}), 201),
        );

        // Act
        final result = await service.registerUsername(username, pubkey, relays);

        // Assert
        expect(result, true);
        expect(service.currentUsername, username);
        expect(service.isVerified, true);
        expect(service.error, isNull);
      });

      test('handles username already taken', () async {
        // Arrange
        const username = 'taken';
        const pubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final relays = ['wss://relay1.com'];

        when(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'error': 'Username already taken'}),
            409,
          ),
        );

        // Act
        final result = await service.registerUsername(username, pubkey, relays);

        // Assert
        expect(result, false);
        expect(service.error, 'Username already taken');
      });

      test('handles reserved username', () async {
        // Arrange
        const username = 'reserved';
        const pubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final relays = ['wss://relay1.com'];

        when(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async =>
              http.Response(jsonEncode({'error': 'Username is reserved'}), 403),
        );

        // Act
        final result = await service.registerUsername(username, pubkey, relays);

        // Assert
        expect(result, false);
        expect(service.error, contains('Username is reserved'));
      });

      test('validates pubkey format', () async {
        // Test invalid pubkeys
        expect(await service.registerUsername('user', 'invalid', []), false);
        expect(
          await service.registerUsername(
            'user',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            [],
          ),
          false,
        ); // too short (63 chars)
        expect(
          await service.registerUsername(
            'user',
            'gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg',
            [],
          ),
          false,
        ); // non-hex

        // Check error message is set
        expect(service.error, contains('Invalid public key format'));
      });
    });

    group('verifyNip05', () {
      test('successfully verifies a NIP-05 identifier', () async {
        // Arrange
        const identifier = 'alice@openvine.co';

        when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'names': {'alice': 'pubkey123'},
            }),
            200,
          ),
        );

        // Act
        final result = await service.verifyNip05(identifier);

        // Assert
        expect(result, true);
        expect(service.currentUsername, 'alice');
        expect(service.isVerified, true);
      });

      test('returns false for invalid identifier format', () async {
        // Test invalid formats
        final result1 = await service.verifyNip05('notanemail');
        expect(result1, false);
        expect(service.error, contains('Invalid NIP-05 identifier format'));

        final result2 = await service.verifyNip05('');
        expect(result2, false);

        final result3 = await service.verifyNip05('@domain.com');
        expect(result3, false);
      });

      test('returns false when username not found', () async {
        // Arrange
        const identifier = 'unknown@openvine.co';

        when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response(jsonEncode({'names': {}}), 200),
        );

        // Act
        final result = await service.verifyNip05(identifier);

        // Assert
        expect(result, false);
        expect(service.isVerified, false);
      });
    });

    group('loadNip05Status', () {
      test('loads verified status for openvine.co identifier', () {
        // Act
        service.loadNip05Status('alice@openvine.co');

        // Assert
        expect(service.currentUsername, 'alice');
        expect(service.isVerified, true);
      });

      test('sets unverified for other domains', () {
        // Act
        service.loadNip05Status('alice@example.com');

        // Assert
        expect(service.currentUsername, isNull);
        expect(service.isVerified, false);
      });

      test('handles null or empty identifier', () {
        // Act
        service.loadNip05Status(null);

        // Assert
        expect(service.currentUsername, isNull);
        expect(service.isVerified, false);

        // Test empty string
        service.loadNip05Status('');
        expect(service.currentUsername, isNull);
        expect(service.isVerified, false);
      });
    });

    group('clear', () {
      test('resets all state', () {
        // Setup some state
        service.loadNip05Status('alice@openvine.co');

        // Act
        service.clear();

        // Assert
        expect(service.currentUsername, isNull);
        expect(service.isVerified, false);
        expect(service.isChecking, false);
        expect(service.error, isNull);
      });
    });
  });
}
