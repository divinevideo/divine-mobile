import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';

// Test helper class to access private methods
class TestableRelayBase extends RelayBase {
  TestableRelayBase(super.url, super.relayStatus);

  // Expose the sanitize method for testing
  dynamic testSanitizeForJson(dynamic data) => sanitizeForJson(data);

  @override
  Future<bool> doConnect() async => false;

  @override
  Future<void> disconnect() async {}
}

void main() {
  group('Defensive JSON Serialization Tests', () {
    late TestableRelayBase relay;

    setUp(() {
      relay = TestableRelayBase('wss://test.relay', RelayStatus('wss://test.relay'));
    });

    test('handles primitive types correctly', () {
      expect(relay.testSanitizeForJson('test'), equals('test'));
      expect(relay.testSanitizeForJson(42), equals(42));
      expect(relay.testSanitizeForJson(3.14), equals(3.14));
      expect(relay.testSanitizeForJson(true), equals(true));
      expect(relay.testSanitizeForJson(null), equals(null));
    });

    test('handles lists correctly', () {
      final input = ['test', 42, true, null];
      final result = relay.testSanitizeForJson(input);
      expect(result, equals(['test', 42, true, null]));
    });

    test('handles maps correctly', () {
      final input = {
        'string': 'test',
        'number': 42,
        'boolean': true,
        'null': null,
      };
      final result = relay.testSanitizeForJson(input);
      expect(result, equals({
        'string': 'test',
        'number': 42,
        'boolean': true,
        'null': null,
      }));
    });

    test('converts non-string keys to strings', () {
      final input = {
        1: 'one',
        2.5: 'two-point-five',
        true: 'true-key',
      };
      final result = relay.testSanitizeForJson(input);
      expect(result, equals({
        '1': 'one',
        '2.5': 'two-point-five',
        'true': 'true-key',
      }));
    });

    test('handles nested structures', () {
      final input = {
        'array': [1, 2, {'nested': 'value'}],
        'object': {
          'deep': {
            'nesting': ['works', 'fine']
          }
        }
      };
      final result = relay.testSanitizeForJson(input);
      final expected = {
        'array': [1, 2, {'nested': 'value'}],
        'object': {
          'deep': {
            'nesting': ['works', 'fine']
          }
        }
      };
      expect(result, equals(expected));
    });

    test('handles objects with toJson method', () {
      final objectWithToJson = MockEventWithToJson();
      final result = relay.testSanitizeForJson(objectWithToJson);
      expect(result, equals({'id': 'test', 'data': 'mock'}));
    });

    test('handles unknown objects by converting to string', () {
      final unknownObject = MockObjectWithoutToJson();
      final result = relay.testSanitizeForJson(unknownObject);
      expect(result, equals('Instance of \'MockObjectWithoutToJson\''));
    });

    test('produces JSON-serializable output', () {
      final complexInput = {
        'event': MockEventWithToJson(),
        'list': [1, 'two', MockEventWithToJson()],
        'unknown': MockObjectWithoutToJson(),
        'mixed_keys': {
          1: 'numeric key',
          'string': 'string key'
        }
      };
      
      final sanitized = relay.testSanitizeForJson(complexInput);
      
      // Should be able to JSON encode without errors
      expect(() => jsonEncode(sanitized), returnsNormally);
      
      final jsonString = jsonEncode(sanitized);
      expect(jsonString, isA<String>());
      
      // Should be able to decode back
      final decoded = jsonDecode(jsonString);
      expect(decoded, isA<Map<String, dynamic>>());
    });

    test('handles Nostr EVENT message structure', () {
      final eventMessage = [
        'EVENT',
        {
          'id': 'test123',
          'pubkey': 'pubkey123',
          'created_at': 1234567890,
          'kind': 0,
          'tags': [['h', 'vine'], ['expiration', '1234567890']],
          'content': '{"name":"test"}',
          'sig': 'signature123'
        }
      ];
      
      final sanitized = relay.testSanitizeForJson(eventMessage);
      expect(() => jsonEncode(sanitized), returnsNormally);
      
      final jsonString = jsonEncode(sanitized);
      final decoded = jsonDecode(jsonString);
      
      expect(decoded[0], equals('EVENT'));
      expect(decoded[1]['id'], equals('test123'));
      expect(decoded[1]['tags'], isA<List>());
      expect(decoded[1]['tags'][0], equals(['h', 'vine']));
    });
  });
}

// Mock classes for testing
class MockEventWithToJson {
  Map<String, dynamic> toJson() {
    return {'id': 'test', 'data': 'mock'};
  }
}

class MockObjectWithoutToJson {
  final String value = 'test';
}