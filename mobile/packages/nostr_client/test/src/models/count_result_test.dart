// ABOUTME: Unit tests for CountResult model in nostr_client.
// ABOUTME: Tests the high-level count result data class.

import 'package:nostr_client/nostr_client.dart';
import 'package:test/test.dart';

void main() {
  group('CountResult', () {
    test('creates with required count parameter', () {
      const result = CountResult(count: 42);

      expect(result.count, equals(42));
      expect(result.approximate, isFalse);
      expect(result.source, equals(CountSource.websocket));
    });

    test('creates with all parameters', () {
      const result = CountResult(
        count: 100,
        approximate: true,
        source: CountSource.cache,
      );

      expect(result.count, equals(100));
      expect(result.approximate, isTrue);
      expect(result.source, equals(CountSource.cache));
    });

    test('copyWith creates new instance with updated values', () {
      const original = CountResult(
        count: 50,
      );

      final copied = original.copyWith(count: 100);

      expect(copied.count, equals(100));
      expect(copied.approximate, isFalse);
      expect(copied.source, equals(CountSource.websocket));
      expect(original.count, equals(50)); // Original unchanged
    });

    test('copyWith can update all fields', () {
      const original = CountResult(
        count: 50,
      );

      final copied = original.copyWith(
        count: 200,
        approximate: true,
        source: CountSource.cache,
      );

      expect(copied.count, equals(200));
      expect(copied.approximate, isTrue);
      expect(copied.source, equals(CountSource.cache));
    });

    test('equality works correctly', () {
      const result1 = CountResult(count: 42);
      const result2 = CountResult(count: 42);
      const result3 = CountResult(count: 42, source: CountSource.gateway);
      const result4 = CountResult(count: 100);

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
      expect(result1, isNot(equals(result4)));
    });
  });
}
