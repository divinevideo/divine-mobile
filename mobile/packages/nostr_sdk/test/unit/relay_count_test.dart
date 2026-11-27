// ABOUTME: Unit tests for NIP-45 COUNT query tracking in Relay class.
// ABOUTME: Tests the COUNT query registration, completion, and failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

// Test implementation of Relay for unit testing
class TestRelay extends Relay {
  TestRelay(String url) : super(url, RelayStatus(url));

  @override
  Future<bool> doConnect() async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async => true;
}

void main() {
  group('Relay COUNT query tracking', () {
    late TestRelay relay;

    setUp(() {
      relay = TestRelay('wss://test.relay');
    });

    test('registerCountQuery returns a future', () {
      final future = relay.registerCountQuery('sub1');

      expect(future, isA<Future<CountResponse>>());
    });

    test('hasCountQuery returns true after registration', () {
      relay.registerCountQuery('sub1');

      expect(relay.hasCountQuery('sub1'), isTrue);
      expect(relay.hasCountQuery('sub2'), isFalse);
    });

    test('completeCountQuery completes the future with response', () async {
      final future = relay.registerCountQuery('sub1');
      const response = CountResponse(count: 42, isComplete: true);

      relay.completeCountQuery('sub1', response);

      final result = await future;
      expect(result.count, equals(42));
      expect(result.approximate, isFalse);
    });

    test('completeCountQuery removes the query', () {
      relay.registerCountQuery('sub1');
      expect(relay.hasCountQuery('sub1'), isTrue);

      relay.completeCountQuery(
        'sub1',
        const CountResponse(count: 10, isComplete: true),
      );

      expect(relay.hasCountQuery('sub1'), isFalse);
    });

    test('failCountQuery completes the future with error', () async {
      final future = relay.registerCountQuery('sub1');

      relay.failCountQuery('sub1', 'NIP-45 not supported');

      await expectLater(future, throwsA(isA<CountNotSupportedException>()));
    });

    test('failCountQuery removes the query', () async {
      final future = relay.registerCountQuery('sub1');
      expect(relay.hasCountQuery('sub1'), isTrue);

      relay.failCountQuery('sub1', 'error');

      expect(relay.hasCountQuery('sub1'), isFalse);

      // Consume the error to prevent unhandled exception
      try {
        await future;
      } on CountNotSupportedException {
        // Expected
      }
    });

    test('multiple COUNT queries can be tracked independently', () async {
      final future1 = relay.registerCountQuery('sub1');
      final future2 = relay.registerCountQuery('sub2');

      expect(relay.hasCountQuery('sub1'), isTrue);
      expect(relay.hasCountQuery('sub2'), isTrue);

      relay.completeCountQuery(
        'sub1',
        const CountResponse(count: 10, isComplete: true),
      );

      expect(relay.hasCountQuery('sub1'), isFalse);
      expect(relay.hasCountQuery('sub2'), isTrue);

      final result1 = await future1;
      expect(result1.count, equals(10));

      relay.completeCountQuery(
        'sub2',
        const CountResponse(count: 20, approximate: true, isComplete: true),
      );

      final result2 = await future2;
      expect(result2.count, equals(20));
      expect(result2.approximate, isTrue);
    });

    test('completing non-existent query does nothing', () {
      // Should not throw
      relay.completeCountQuery(
        'nonexistent',
        const CountResponse(count: 0, isComplete: true),
      );
    });

    test('failing non-existent query does nothing', () {
      // Should not throw
      relay.failCountQuery('nonexistent', 'error');
    });
  });
}
