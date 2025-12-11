// ABOUTME: Tests for NostrBroadcastResult model
// ABOUTME: Validates broadcast result tracking with per-relay success/failure status

import 'package:nostr_client/src/models/nostr_broadcast_result.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

const testPublicKey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

Event _createTestEvent({String? content}) {
  return Event(
    testPublicKey,
    EventKind.textNote,
    <List<dynamic>>[],
    content ?? 'Test content',
  );
}

void main() {
  group('NostrBroadcastResult', () {
    group('constructor', () {
      test('creates result with all parameters', () {
        final event = _createTestEvent();
        final results = {
          'wss://relay1.example.com': true,
          'wss://relay2.example.com': false,
        };
        final errors = {
          'wss://relay2.example.com': 'Connection refused',
        };

        final result = NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 2,
          results: results,
          errors: errors,
        );

        expect(result.event, equals(event));
        expect(result.successCount, equals(1));
        expect(result.totalRelays, equals(2));
        expect(result.results, equals(results));
        expect(result.errors, equals(errors));
      });

      test('creates result with null event', () {
        const result = NostrBroadcastResult(
          event: null,
          successCount: 0,
          totalRelays: 2,
          results: {},
          errors: {},
        );

        expect(result.event, isNull);
        expect(result.successCount, equals(0));
      });
    });

    group('success', () {
      test('returns true when successCount > 0', () {
        final result = NostrBroadcastResult(
          event: _createTestEvent(),
          successCount: 1,
          totalRelays: 3,
          results: {'wss://relay1.example.com': true},
          errors: {},
        );

        expect(result.success, isTrue);
      });

      test('returns false when successCount is 0', () {
        const result = NostrBroadcastResult(
          event: null,
          successCount: 0,
          totalRelays: 2,
          results: {
            'wss://relay1.example.com': false,
            'wss://relay2.example.com': false,
          },
          errors: {
            'wss://relay1.example.com': 'Timeout',
            'wss://relay2.example.com': 'Connection refused',
          },
        );

        expect(result.success, isFalse);
      });
    });

    group('failedRelays', () {
      test('returns list of relays that failed', () {
        final result = NostrBroadcastResult(
          event: _createTestEvent(),
          successCount: 1,
          totalRelays: 3,
          results: {
            'wss://relay1.example.com': true,
            'wss://relay2.example.com': false,
            'wss://relay3.example.com': false,
          },
          errors: {
            'wss://relay2.example.com': 'Timeout',
            'wss://relay3.example.com': 'Auth failed',
          },
        );

        expect(
          result.failedRelays,
          containsAll([
            'wss://relay2.example.com',
            'wss://relay3.example.com',
          ]),
        );
        expect(result.failedRelays.length, equals(2));
      });

      test('returns empty list when all relays succeeded', () {
        final result = NostrBroadcastResult(
          event: _createTestEvent(),
          successCount: 2,
          totalRelays: 2,
          results: {
            'wss://relay1.example.com': true,
            'wss://relay2.example.com': true,
          },
          errors: {},
        );

        expect(result.failedRelays, isEmpty);
      });
    });

    group('successfulRelays', () {
      test('returns list of relays that succeeded', () {
        final result = NostrBroadcastResult(
          event: _createTestEvent(),
          successCount: 2,
          totalRelays: 3,
          results: {
            'wss://relay1.example.com': true,
            'wss://relay2.example.com': true,
            'wss://relay3.example.com': false,
          },
          errors: {},
        );

        expect(
          result.successfulRelays,
          containsAll([
            'wss://relay1.example.com',
            'wss://relay2.example.com',
          ]),
        );
        expect(result.successfulRelays.length, equals(2));
      });

      test('returns empty list when all relays failed', () {
        const result = NostrBroadcastResult(
          event: null,
          successCount: 0,
          totalRelays: 2,
          results: {
            'wss://relay1.example.com': false,
            'wss://relay2.example.com': false,
          },
          errors: {},
        );

        expect(result.successfulRelays, isEmpty);
      });
    });
  });
}
