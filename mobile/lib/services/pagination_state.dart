// ABOUTME: Tracks cursor and result-count state for paginated feed queries.
// ABOUTME: Determines when a subscription has exhausted its historical events.

import 'package:unified_logger/unified_logger.dart';

class PaginationState {
  PaginationState({
    this.oldestTimestamp,
    this.isLoading = false,
    this.hasMore = true,
    Set<String>? seenEventIds,
    this.eventsReceivedInCurrentQuery = 0,
  }) : seenEventIds = seenEventIds ?? <String>{};

  int? oldestTimestamp;
  bool isLoading;
  bool hasMore;
  Set<String> seenEventIds;
  int eventsReceivedInCurrentQuery;

  void updateOldestTimestamp(int timestamp) {
    if (oldestTimestamp == null || timestamp < oldestTimestamp!) {
      oldestTimestamp = timestamp;
    }
  }

  void markEventSeen(String eventId) {
    seenEventIds.add(eventId.toLowerCase());
  }

  void startQuery() {
    eventsReceivedInCurrentQuery = 0;
    hasMore = true;
    isLoading = true;
  }

  void incrementEventCount() {
    eventsReceivedInCurrentQuery++;
  }

  /// Records a per-query tally the caller counted for itself.
  ///
  /// [incrementEventCount] only fires for events flagged `isHistorical`. An
  /// initial subscription delivers its stored backlog through the real-time
  /// handler, so its tally stays at zero without this externally observed count.
  void recordReceivedCount(int count) {
    if (count > eventsReceivedInCurrentQuery) {
      eventsReceivedInCurrentQuery = count;
    }
  }

  void completeQuery(int requestedLimit) {
    isLoading = false;
    if (eventsReceivedInCurrentQuery < requestedLimit) {
      hasMore = false;
      Log.info(
        'PaginationState: No more content available - received '
        '$eventsReceivedInCurrentQuery < $requestedLimit requested',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }
  }

  void reset() {
    oldestTimestamp = null;
    isLoading = false;
    hasMore = true;
    seenEventIds.clear();
    eventsReceivedInCurrentQuery = 0;
  }
}
