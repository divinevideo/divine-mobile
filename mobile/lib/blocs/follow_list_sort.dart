// ABOUTME: Presentation sorting for the signed-in user's follow lists.
// ABOUTME: Smart uses a frozen local ranking; dated sorts use repository order.

import 'package:follow_repository/follow_repository.dart';

/// Presentation order for an owned follow list.
enum FollowListSort {
  smart,
  newestFirst,
  oldestFirst;

  /// Repository ordering, or null for the local ranking snapshot.
  FollowSortOrder? get followSortOrder => switch (this) {
    smart => null,
    newestFirst => FollowSortOrder.newestFirst,
    oldestFirst => FollowSortOrder.oldestFirst,
  };
}
