// ABOUTME: Tests for RelayStatus class functionality including alwaysAuth configuration
// ABOUTME: Validates relay authentication settings and status tracking work correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/relay_type.dart';

void main() {
  group('RelayStatus Tests', () {
    test('RelayStatus creation with default values', () {
      final status = RelayStatus('wss://relay.example.com');

      expect(status.addr, equals('wss://relay.example.com'));
      expect(status.relayType, equals(RelayType.normal));
      expect(status.writeAccess, isTrue);
      expect(status.readAccess, isTrue);
      expect(status.alwaysAuth, isFalse);
      expect(status.authed, isFalse);
    });

    test('RelayStatus creation with custom alwaysAuth', () {
      final status = RelayStatus('wss://auth.relay.com', alwaysAuth: true);

      expect(status.addr, equals('wss://auth.relay.com'));
      expect(status.alwaysAuth, isTrue);
      expect(status.authed, isFalse); // Still not authenticated yet
    });

    test('RelayStatus with all custom parameters', () {
      final status = RelayStatus(
        'wss://custom.relay.com',
        relayType: RelayType.cache,
        writeAccess: false,
        readAccess: true,
        alwaysAuth: true,
      );

      expect(status.addr, equals('wss://custom.relay.com'));
      expect(status.relayType, equals(RelayType.cache));
      expect(status.writeAccess, isFalse);
      expect(status.readAccess, isTrue);
      expect(status.alwaysAuth, isTrue);
    });

    test('RelayStatus authentication state changes', () {
      final status = RelayStatus('wss://relay.example.com', alwaysAuth: true);

      expect(status.alwaysAuth, isTrue);
      expect(status.authed, isFalse);

      // Simulate authentication
      status.authed = true;
      expect(status.authed, isTrue);
      expect(status.alwaysAuth, isTrue); // alwaysAuth doesn't change
    });

    test('RelayStatus note receive tracking', () {
      final status = RelayStatus('wss://relay.example.com');

      expect(status.noteReceived, equals(0));

      status.noteReceive();
      expect(status.noteReceived, equals(1));
      expect(status.lastNoteTime, isNotNull);

      final firstNoteTime = status.lastNoteTime;
      status.noteReceive();
      expect(status.noteReceived, equals(2));
      expect(status.lastNoteTime!.isAfter(firstNoteTime!), isTrue);
    });

    test('RelayStatus query tracking', () {
      final status = RelayStatus('wss://relay.example.com');

      expect(status.queryNum, equals(0));

      status.onQuery();
      expect(status.queryNum, equals(1));
      expect(status.lastQueryTime, isNotNull);
    });

    test('RelayStatus error tracking', () {
      final status = RelayStatus('wss://relay.example.com');

      expect(status.error, equals(0));

      status.onError();
      expect(status.error, equals(1));
      expect(status.lastErrorTime, isNotNull);
    });
  });
}
