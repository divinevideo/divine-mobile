// ABOUTME: Unit tests for NIP-45 CountResponse model.
// ABOUTME: Tests the count response data class and exception.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('CountResponse', () {
    test('creates with required count parameter', () {
      const response = CountResponse(count: 42, isComplete: true);

      expect(response.count, equals(42));
      expect(response.approximate, isFalse);
    });

    test('creates with approximate flag', () {
      const response = CountResponse(
        count: 1000,
        approximate: true,
        isComplete: true,
      );

      expect(response.count, equals(1000));
      expect(response.approximate, isTrue);
    });

    test('creates with approximate defaulting to false', () {
      const response = CountResponse(count: 5, isComplete: true);

      expect(response.approximate, isFalse);
    });

    test('toString returns readable format', () {
      const response = CountResponse(
        count: 42,
        approximate: true,
        isComplete: true,
      );

      expect(
        response.toString(),
        equals('CountResponse(count: 42, approximate: true, isComplete: true)'),
      );
    });

    test('equality works correctly', () {
      const response1 = CountResponse(count: 42, isComplete: true);
      const response2 = CountResponse(count: 42, isComplete: true);
      const response3 = CountResponse(
        count: 42,
        approximate: true,
        isComplete: true,
      );
      const response4 = CountResponse(count: 100, isComplete: true);
      const response5 = CountResponse(count: 42, isComplete: false);

      expect(response1, equals(response2));
      expect(response1, isNot(equals(response3)));
      expect(response1, isNot(equals(response4)));
      expect(response1, isNot(equals(response5)));
    });

    test('hashCode is consistent with equality', () {
      const response1 = CountResponse(count: 42, isComplete: true);
      const response2 = CountResponse(count: 42, isComplete: true);

      expect(response1.hashCode, equals(response2.hashCode));
    });
  });

  group('CountNotSupportedException', () {
    test('stores reason', () {
      final exception = CountNotSupportedException(
        'Relay does not support NIP-45',
      );

      expect(exception.reason, equals('Relay does not support NIP-45'));
    });

    test('toString returns readable format', () {
      final exception = CountNotSupportedException('Timeout');

      expect(
        exception.toString(),
        equals('CountNotSupportedException: Timeout'),
      );
    });

    test('can be caught as Exception', () {
      expect(
        () => throw CountNotSupportedException('test'),
        throwsA(isA<Exception>()),
      );
    });

    test('can be caught specifically', () {
      expect(
        () => throw CountNotSupportedException('test'),
        throwsA(isA<CountNotSupportedException>()),
      );
    });
  });
}
