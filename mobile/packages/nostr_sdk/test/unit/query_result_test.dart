// ABOUTME: Unit tests for QueryResult, PagedQueryResult, and QueryEnd.
// ABOUTME: Pins isComplete semantics and the documented field defaults.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group(QueryResult, () {
    group('isComplete', () {
      test('is true when endedBy is QueryEnd.complete', () {
        final result = QueryResult(
          events: const [],
          endedBy: QueryEnd.complete,
        );

        expect(result.isComplete, isTrue);
      });

      test('is false for every QueryEnd value other than complete', () {
        for (final endedBy in QueryEnd.values) {
          if (endedBy == QueryEnd.complete) continue;
          final result = QueryResult(events: const [], endedBy: endedBy);

          expect(
            result.isComplete,
            isFalse,
            reason: 'QueryEnd.$endedBy must not report isComplete',
          );
        }
      });
    });

    group('field defaults', () {
      test('possiblyCapped and confirmedExhaustive default to false', () {
        final result = QueryResult(
          events: const [],
          endedBy: QueryEnd.complete,
        );

        expect(result.possiblyCapped, isFalse);
        expect(result.confirmedExhaustive, isFalse);
      });

      test('possiblyCapped and confirmedExhaustive are set independently '
          '(possiblyCapped true, confirmedExhaustive false)', () {
        final result = QueryResult(
          events: const [],
          endedBy: QueryEnd.complete,
          possiblyCapped: true,
          confirmedExhaustive: false,
        );

        expect(result.possiblyCapped, isTrue);
        expect(result.confirmedExhaustive, isFalse);
      });

      test('possiblyCapped and confirmedExhaustive are set independently '
          '(possiblyCapped false, confirmedExhaustive true)', () {
        final result = QueryResult(
          events: const [],
          endedBy: QueryEnd.complete,
          possiblyCapped: false,
          confirmedExhaustive: true,
        );

        expect(result.possiblyCapped, isFalse);
        expect(result.confirmedExhaustive, isTrue);
      });
    });
  });

  group(PagedQueryResult, () {
    test('stoppedBy defaults to null when the walk completed', () {
      final result = PagedQueryResult(
        events: const [],
        isComplete: true,
        pages: 2,
      );

      expect(result.stoppedBy, isNull);
    });
  });
}
