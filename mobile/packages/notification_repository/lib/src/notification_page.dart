// ABOUTME: Paginated result wrapper returned by NotificationRepository.
// ABOUTME: Contains enriched, grouped NotificationItems plus cursor metadata.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// A page of enriched, grouped notifications returned by the repository.
class NotificationPage extends Equatable {
  /// Creates a notification page.
  const NotificationPage({
    required this.items,
    required this.unreadCount,
    this.nextCursor,
    this.nextCursorId,
    this.hasMore = false,
    this.lastRefreshError = false,
  });

  /// Empty page used as a default / error fallback.
  static const empty = NotificationPage(items: [], unreadCount: 0);

  /// The enriched, grouped notification items for this page.
  final List<NotificationItem> items;

  /// Unread notifications: the server's total on a social page, or the
  /// unread [items] once client-side rows (announcements, room mentions) are
  /// merged in.
  final int unreadCount;

  /// Cursor for fetching the next page, if available.
  final String? nextCursor;

  /// Cursor tiebreaker for fetching the next page, if available.
  final String? nextCursorId;

  /// Whether more pages are available.
  final bool hasMore;

  /// Whether the most recent first-page refresh failed after exhausting
  /// retries.
  ///
  /// The repository sets this `true` when `getNotifications(cursor: null)`
  /// gives up on a transient `5xx`/timeout, and clears it on the next
  /// successful refresh. UI uses it to render an inline "couldn't refresh"
  /// banner when cached items are still rendered, or the full failure
  /// screen when the snapshot is also empty.
  final bool lastRefreshError;

  /// Returns a copy of this page with the given fields replaced.
  NotificationPage copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    String? nextCursor,
    String? nextCursorId,
    bool? hasMore,
    bool? lastRefreshError,
  }) {
    return NotificationPage(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      nextCursor: nextCursor ?? this.nextCursor,
      nextCursorId: nextCursorId ?? this.nextCursorId,
      hasMore: hasMore ?? this.hasMore,
      lastRefreshError: lastRefreshError ?? this.lastRefreshError,
    );
  }

  @override
  List<Object?> get props => [
    items,
    unreadCount,
    nextCursor,
    nextCursorId,
    hasMore,
    lastRefreshError,
  ];
}
