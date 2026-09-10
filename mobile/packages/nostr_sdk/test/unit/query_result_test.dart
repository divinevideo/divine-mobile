// ABOUTME: Unit tests for QueryResult, PagedQueryResult, and QueryEnd.
// ABOUTME: Pins isComplete semantics and the documented field defaults.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

Event _buildEvent(String content) {
  return Event('a'.padRight(64, 'a'), EventKind.textNote, const [], content);
}

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

      test('possiblyCapped and confirmedExhaustive can be set explicitly', () {
        final result = QueryResult(
          events: const [],
          endedBy: QueryEnd.complete,
          possiblyCapped: true,
          confirmedExhaustive: true,
        );

        expect(result.possiblyCapped, isTrue);
        expect(result.confirmedExhaustive, isTrue);
      });
    });

    group('events', () {
      test('retains events collected before an early end', () {
        final event = _buildEvent('collected-before-deadline');
        final result = QueryResult(events: [event], endedBy: QueryEnd.deadline);

        expect(result.events, [event]);
      });
    });
  });

  group(PagedQueryResult, () {
    test('carries events, isComplete, pages, and stoppedBy', () {
      final event = _buildEvent('page-one-event');
      final result = PagedQueryResult(
        events: [event],
        isComplete: false,
        pages: 3,
        stoppedBy: QueryEnd.settledEarly,
      );

      expect(result.events, [event]);
      expect(result.isComplete, isFalse);
      expect(result.pages, 3);
      expect(result.stoppedBy, QueryEnd.settledEarly);
    });

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
