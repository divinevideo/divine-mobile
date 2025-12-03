// ABOUTME: Tests for extracted notification helper functions
// ABOUTME: Pure function tests for video ID extraction and actor name resolution

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:models/models.dart';
import 'package:openvine/services/notification_helpers.dart';

void main() {
  group('extractVideoEventId', () {
    test('returns first "e" tag value from event tags', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          ['e', 'video123'],
          ['p', 'user456'],
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, 'video123');
    });

    test('returns null when no "e" tags exist', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          ['p', 'user456'],
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, isNull);
    });

    test('returns null when "e" tag has no value', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          ['e'], // No value
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, isNull);
    });

    test('returns null when event has empty tags', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, isNull);
    });

    test('returns first "e" tag when multiple exist', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          ['e', 'first_video'],
          ['e', 'second_video'],
          ['e', 'third_video'],
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, 'first_video');
    });

    test('handles empty tag arrays gracefully', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          [], // Empty tag
          ['e', 'video123'],
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, 'video123');
    });
  });

  group('resolveActorName', () {
    test('returns name when available', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        name: 'Alice',
        displayName: 'Alice Wonderland',
        nip05: 'alice@nostr.com',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'Alice');
    });

    test('returns displayName when name is null', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        displayName: 'Bob Builder',
        nip05: 'bob@nostr.com',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'Bob Builder');
    });

    test('returns nip05 username when name and displayName are null', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        nip05: 'charlie@nostr.com',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'charlie');
    });

    test('extracts username from nip05 before @ symbol', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        nip05: 'username@example.org',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'username');
    });

    test('returns "Unknown user" when profile is null', () {
      // Act
      final result = resolveActorName(null);

      // Assert
      expect(result, 'Unknown user');
    });

    test('returns "Unknown user" when all name fields are null', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'event1',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'Unknown user');
    });

    test('handles nip05 without @ symbol', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        nip05: 'plainname',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'plainname');
    });
  });
}
