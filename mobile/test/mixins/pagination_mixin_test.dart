// ABOUTME: Tests for PaginationMixin to verify throttling and pagination behavior
// ABOUTME: Ensures loadMore calls are throttled correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/mixins/pagination_mixin.dart';

void main() {
  group('PaginationMixin', () {
    late int loadMoreCallCount;
    late List<int> loadMoreCallIndices;

    setUp(() {
      loadMoreCallCount = 0;
      loadMoreCallIndices = [];
    });

    void onLoadMore(int index) {
      loadMoreCallCount++;
      loadMoreCallIndices.add(index);
    }

    testWidgets('calls onLoadMore when within threshold of end', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestPaginationWidget(onLoadMore: onLoadMore, threshold: 3),
      );

      final state = tester.state<_TestPaginationWidgetState>(
        find.byType(_TestPaginationWidget),
      );

      // Total items: 10, threshold: 3
      // Should trigger at index 7 or higher (10 - 3 = 7)

      // Index 6: Should NOT trigger
      state.checkForPagination(
        currentIndex: 6,
        totalItems: 10,
        onLoadMore: () => onLoadMore(6),
      );
      await tester.pump();
      expect(loadMoreCallCount, 0);

      // Index 7: Should trigger (at threshold)
      state.checkForPagination(
        currentIndex: 7,
        totalItems: 10,
        onLoadMore: () => onLoadMore(7),
      );
      await tester.pump();
      expect(loadMoreCallCount, 1);
      expect(loadMoreCallIndices, [7]);

      // Index 9: Should trigger (past threshold)
      state.resetPagination();
      state.checkForPagination(
        currentIndex: 9,
        totalItems: 10,
        onLoadMore: () => onLoadMore(9),
      );
      await tester.pump();
      expect(loadMoreCallCount, 2);
      expect(loadMoreCallIndices, [7, 9]);
    });

    testWidgets('throttles duplicate calls immediately', (tester) async {
      await tester.pumpWidget(
        _TestPaginationWidget(onLoadMore: onLoadMore, throttleSeconds: 5),
      );

      final state = tester.state<_TestPaginationWidgetState>(
        find.byType(_TestPaginationWidget),
      );

      // First call: Should succeed
      state.checkForPagination(
        currentIndex: 8,
        totalItems: 10,
        onLoadMore: () => onLoadMore(8),
        throttleSeconds: 5,
      );
      await tester.pump();
      expect(loadMoreCallCount, 1);

      // Second call immediately: Should be throttled
      state.checkForPagination(
        currentIndex: 9,
        totalItems: 10,
        onLoadMore: () => onLoadMore(9),
        throttleSeconds: 5,
      );
      await tester.pump();
      expect(loadMoreCallCount, 1); // Still 1, throttled
      expect(loadMoreCallIndices, [8]); // Only first call went through
    });

    testWidgets('resetPagination clears throttle', (tester) async {
      await tester.pumpWidget(
        _TestPaginationWidget(onLoadMore: onLoadMore, throttleSeconds: 5),
      );

      final state = tester.state<_TestPaginationWidgetState>(
        find.byType(_TestPaginationWidget),
      );

      // First call
      state.checkForPagination(
        currentIndex: 8,
        totalItems: 10,
        onLoadMore: () => onLoadMore(8),
      );
      await tester.pump();
      expect(loadMoreCallCount, 1);

      // Reset pagination (clears throttle)
      state.resetPagination();

      // Second call immediately after reset: Should succeed
      state.checkForPagination(
        currentIndex: 9,
        totalItems: 10,
        onLoadMore: () => onLoadMore(9),
      );
      await tester.pump();
      expect(loadMoreCallCount, 2);
      expect(loadMoreCallIndices, [8, 9]);
    });

    testWidgets('respects custom threshold', (tester) async {
      await tester.pumpWidget(
        _TestPaginationWidget(
          onLoadMore: onLoadMore,
          threshold: 5, // Custom threshold
        ),
      );

      final state = tester.state<_TestPaginationWidgetState>(
        find.byType(_TestPaginationWidget),
      );

      // Total: 20, threshold: 5
      // Should trigger at index 15 or higher (20 - 5 = 15)

      // Index 14: Should NOT trigger
      state.checkForPagination(
        currentIndex: 14,
        totalItems: 20,
        onLoadMore: () => onLoadMore(14),
        threshold: 5, // ← Must pass the threshold parameter!
      );
      await tester.pump();
      expect(loadMoreCallCount, 0);

      // Index 15: Should trigger
      state.checkForPagination(
        currentIndex: 15,
        totalItems: 20,
        onLoadMore: () => onLoadMore(15),
        threshold: 5, // ← Must pass the threshold parameter!
      );
      await tester.pump();
      expect(loadMoreCallCount, 1);
      expect(loadMoreCallIndices, [15]);
    });
  });
}

/// Test widget that uses PaginationMixin
class _TestPaginationWidget extends StatefulWidget {
  const _TestPaginationWidget({
    required this.onLoadMore,
    this.threshold = 3,
    this.throttleSeconds = 5,
  });

  final void Function(int) onLoadMore;
  final int threshold;
  final int throttleSeconds;

  @override
  State<_TestPaginationWidget> createState() => _TestPaginationWidgetState();
}

class _TestPaginationWidgetState extends State<_TestPaginationWidget>
    with PaginationMixin {
  @override
  Widget build(BuildContext context) {
    return Container(); // Dummy widget
  }
}
