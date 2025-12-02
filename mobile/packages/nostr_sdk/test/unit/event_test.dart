// ABOUTME: Tests for Event class functionality including creation, validation, and signing
// ABOUTME: Validates core event operations work as expected with exported classes

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('Event Functionality Tests', () {
    const testPubkey =
        '02c7d89e6b8e6f86c0d86c15b3b8b1d1c3c4c5c6c7c8c9c0c1c2c3c4c5c6c7c8';
    const testContent = 'Hello Nostr! This is a test event.';

    test('Event creation with valid parameters', () {
      final event = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [],
        testContent,
      );

      expect(event.pubkey, equals(testPubkey));
      expect(event.kind, equals(EventKind.TEXT_NOTE));
      expect(event.content, equals(testContent));
      expect(event.tags, isEmpty);
      expect(event.id, isNotEmpty);
      expect(event.createdAt, isPositive);
      expect(event.sig, isEmpty); // Not signed yet
    });

    test('Event with custom timestamp', () {
      const customTime = 1640995200; // 2022-01-01 00:00:00 UTC
      final event = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [],
        testContent,
        createdAt: customTime,
      );

      expect(event.createdAt, equals(customTime));
    });

    test('Event with tags', () {
      final tags = [
        ['t', 'nostr'],
        ['t', 'test'],
        ['p', testPubkey, '', 'mention'],
      ];

      final event = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        tags,
        testContent,
      );

      expect(event.tags, equals(tags));
      expect(event.tags.length, equals(3));
    });

    test('Event ID generation is deterministic', () {
      final event1 = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [],
        testContent,
        createdAt: 1640995200,
      );

      final event2 = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [],
        testContent,
        createdAt: 1640995200,
      );

      expect(event1.id, equals(event2.id));
    });

    test('Event validation before signing', () {
      final event = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [],
        testContent,
      );

      expect(event.isValid, isTrue);
      expect(event.isSigned, isFalse); // No signature yet
    });

    test('Event JSON serialization', () {
      final event = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [
          ['t', 'test']
        ],
        testContent,
      );

      final json = event.toJson();

      expect(json['id'], equals(event.id));
      expect(json['pubkey'], equals(testPubkey));
      expect(json['kind'], equals(EventKind.TEXT_NOTE));
      expect(
          json['tags'],
          equals([
            ['t', 'test']
          ]));
      expect(json['content'], equals(testContent));
      expect(json['created_at'], equals(event.createdAt));
      expect(json['sig'], equals(event.sig));
    });

    test('Event creation from JSON', () {
      final originalEvent = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [
          ['t', 'test']
        ],
        testContent,
      );

      final json = originalEvent.toJson();
      final recreatedEvent = Event.fromJson(json);

      expect(recreatedEvent.id, equals(originalEvent.id));
      expect(recreatedEvent.pubkey, equals(originalEvent.pubkey));
      expect(recreatedEvent.kind, equals(originalEvent.kind));
      expect(recreatedEvent.content, equals(originalEvent.content));
      expect(recreatedEvent.createdAt, equals(originalEvent.createdAt));
    });

    test('Event kind constants are correct', () {
      expect(EventKind.METADATA, equals(0));
      expect(EventKind.TEXT_NOTE, equals(1));
      expect(EventKind.RECOMMEND_SERVER, equals(2));
      expect(EventKind.CONTACT_LIST, equals(3));
      expect(EventKind.DIRECT_MESSAGE, equals(4));
      expect(EventKind.EVENT_DELETION, equals(5));
      expect(EventKind.REPOST, equals(6));
      expect(EventKind.REACTION, equals(7));
    });

    test('Event equality based on ID', () {
      final event1 = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [],
        testContent,
        createdAt: 1640995200,
      );

      final event2 = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [],
        testContent,
        createdAt: 1640995200,
      );

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('Invalid pubkey throws error', () {
      expect(
        () => Event(
          'invalid_pubkey',
          EventKind.TEXT_NOTE,
          [],
          testContent,
        ),
        throwsArgumentError,
      );
    });

    test('Proof of work functionality', () {
      final event = Event(
        testPubkey,
        EventKind.TEXT_NOTE,
        [],
        testContent,
      );

      final originalId = event.id;

      // Add minimal proof of work (difficulty 1)
      event.doProofOfWork(1);

      expect(event.id, isNot(equals(originalId)));
      expect(event.tags.last, contains('nonce'));
      expect(event.tags.last[2], equals('1')); // difficulty
    });
  });
}
