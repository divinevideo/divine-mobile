// ABOUTME: Tests the auto-advance coordinator — which completed play advances
// ABOUTME: the feed, which queues a pagination advance, and which is suppressed.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/feed_auto_advance_coordinator.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';

void main() {
  group('handleFeedAutoAdvanceCompleted', () {
    late FeedAutoAdvanceCubit cubit;
    late List<int> advancedTo;
    late int loadMoreCalls;

    setUp(() {
      cubit = FeedAutoAdvanceCubit();
      addTearDown(cubit.close);
      advancedTo = <int>[];
      loadMoreCalls = 0;
    });

    void completePlay({
      required int currentIndex,
      required int itemCount,
      bool hasMore = false,
      bool isLoadingMore = false,
    }) {
      handleFeedAutoAdvanceCompleted(
        cubit: cubit,
        snapshot: FeedAutoAdvanceSnapshot(
          currentIndex: currentIndex,
          itemCount: itemCount,
          hasMore: hasMore,
          isLoadingMore: isLoadingMore,
        ),
        animateToPage: advancedTo.add,
        requestLoadMore: () => loadMoreCalls++,
      );
    }

    test('does nothing while Auto is off', () {
      completePlay(currentIndex: 0, itemCount: 3);

      expect(advancedTo, isEmpty);
      expect(loadMoreCalls, isZero);
    });

    test('advances to the next video while Auto is active', () {
      cubit.setEnabled(enabled: true);

      completePlay(currentIndex: 0, itemCount: 3);

      expect(advancedTo, equals([1]));
    });

    test('does not advance while Auto is suppressed', () {
      cubit
        ..setEnabled(enabled: true)
        ..suppressForInteraction();
      expect(
        cubit.state.enabled,
        isTrue,
        reason: 'suppression must not be mistaken for Auto being off',
      );

      completePlay(currentIndex: 0, itemCount: 3);

      expect(advancedTo, isEmpty);
      expect(loadMoreCalls, isZero);
    });

    test('queues a pagination advance on the last item when more remain', () {
      cubit.setEnabled(enabled: true);

      completePlay(currentIndex: 2, itemCount: 3, hasMore: true);

      expect(advancedTo, isEmpty);
      expect(loadMoreCalls, equals(1));
      expect(cubit.state.pendingPaginationAdvance, isTrue);
    });

    test('waits without re-requesting while a page is already loading', () {
      cubit.setEnabled(enabled: true);

      completePlay(
        currentIndex: 2,
        itemCount: 3,
        hasMore: true,
        isLoadingMore: true,
      );

      expect(advancedTo, isEmpty);
      expect(loadMoreCalls, isZero);
      expect(cubit.state.pendingPaginationAdvance, isFalse);
    });

    test('wraps to the start on the last item of an exhausted feed', () {
      cubit.setEnabled(enabled: true);

      completePlay(currentIndex: 2, itemCount: 3);

      expect(advancedTo, equals([0]));
    });

    test('does nothing on an empty feed', () {
      cubit.setEnabled(enabled: true);

      completePlay(currentIndex: 0, itemCount: 0);

      expect(advancedTo, isEmpty);
      expect(loadMoreCalls, isZero);
    });

    // The reported failure in #9315: a viewer pauses, turns Auto on from the
    // settings popover, then taps to play. The video loops forever and the
    // feed never moves on. Suppression — not the Auto toggle — is what stops
    // it, which is why the control still reads "on" the whole time, and why
    // manually swiping once (resumeAfterSwipe) made every later video advance
    // again and hid the cause.
    group('the reported pause / enable Auto / play sequence', () {
      test('a resume that suppresses instead of lifting stalls the feed', () {
        // Tapping pause before Auto is on changes nothing: suppression only
        // applies once Auto is enabled.
        cubit.suppressForInteraction();
        expect(cubit.state, const FeedAutoAdvanceState());

        cubit.toggle();
        expect(
          cubit.state.isEffectivelyActive,
          isTrue,
          reason: 'enabling Auto clears suppression',
        );

        // The tap to play. Suppressing here is the defect; the feed then
        // loops the current video forever.
        cubit.suppressForInteraction();

        expect(cubit.state.enabled, isTrue, reason: 'the control reads "on"');
        expect(cubit.state.isEffectivelyActive, isFalse);
        completePlay(currentIndex: 0, itemCount: 3);
        expect(advancedTo, isEmpty, reason: 'the reported stall');

        // Lifting suppression instead — what a tap to play should do — leaves
        // the feed able to move on.
        cubit.resumeAfterSwipe();

        completePlay(currentIndex: 0, itemCount: 3);
        expect(advancedTo, equals([1]));
      });
    });
  });

  group('continueFeedAutoAdvanceAfterPagination', () {
    late FeedAutoAdvanceCubit cubit;
    late List<int> advancedTo;

    setUp(() {
      cubit = FeedAutoAdvanceCubit();
      addTearDown(cubit.close);
      advancedTo = <int>[];
    });

    void pageSettled({
      required int currentIndex,
      required int itemCount,
      bool hasMore = false,
      bool isLoadingMore = false,
    }) {
      continueFeedAutoAdvanceAfterPagination(
        cubit: cubit,
        snapshot: FeedAutoAdvanceSnapshot(
          currentIndex: currentIndex,
          itemCount: itemCount,
          hasMore: hasMore,
          isLoadingMore: isLoadingMore,
        ),
        animateToPage: advancedTo.add,
      );
    }

    test('does nothing when no advance is queued', () {
      cubit.setEnabled(enabled: true);

      pageSettled(currentIndex: 2, itemCount: 5);

      expect(advancedTo, isEmpty);
    });

    test('advances into the newly loaded page and clears the queue', () {
      cubit
        ..setEnabled(enabled: true)
        ..markPendingPaginationAdvance();

      pageSettled(currentIndex: 2, itemCount: 5);

      expect(advancedTo, equals([3]));
      expect(cubit.state.pendingPaginationAdvance, isFalse);
    });

    test('keeps waiting while the page is still loading', () {
      cubit
        ..setEnabled(enabled: true)
        ..markPendingPaginationAdvance();

      pageSettled(currentIndex: 2, itemCount: 5, isLoadingMore: true);

      expect(advancedTo, isEmpty);
      expect(
        cubit.state.pendingPaginationAdvance,
        isTrue,
        reason: 'the queued advance must survive until the page settles',
      );
    });

    test('wraps to the start once the feed is exhausted', () {
      cubit
        ..setEnabled(enabled: true)
        ..markPendingPaginationAdvance();

      pageSettled(currentIndex: 2, itemCount: 3);

      expect(advancedTo, equals([0]));
      expect(cubit.state.pendingPaginationAdvance, isFalse);
    });

    test(
      'holds the queued advance when more pages remain but none arrived',
      () {
        cubit
          ..setEnabled(enabled: true)
          ..markPendingPaginationAdvance();

        pageSettled(currentIndex: 2, itemCount: 3, hasMore: true);

        expect(advancedTo, isEmpty);
        expect(cubit.state.pendingPaginationAdvance, isTrue);
      },
    );
  });
}
