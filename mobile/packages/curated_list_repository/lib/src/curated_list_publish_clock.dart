// ABOUTME: Allocates strictly increasing timestamps per owned list coordinate.
// ABOUTME: Orders retries after attempted sends, including queued events.

import 'package:clock/clock.dart';
import 'package:models/models.dart';

/// Publication revisions belong to an owner and d-tag, never to a form visit.
///
/// Observe stored and received source revisions before allocating a write.
/// Reserving before signing also orders a retry after an unconfirmed queued
/// send. The service persists the signed timestamp separately from local edits.
class CuratedListPublishClock {
  /// Client-side limit; deployed relays can enforce a stricter policy.
  CuratedListPublishClock({this.maxFutureDrift = const Duration(seconds: 60)});

  /// Maximum offset allocated beyond this client's current wall clock.
  final Duration maxFutureDrift;
  final Map<String, int> _seconds = {};
  final Map<String, int> _retryAfter = {};

  /// Remembers a source without letting an older echo lower its revision.
  void observe(CuratedList list) {
    final owner = list.pubkey;
    if (owner == null ||
        (list.nostrEventId == null && !list.pendingRepublish)) {
      return;
    }
    final key = '$owner:${list.id}';
    final source = list.updatedAt.millisecondsSinceEpoch ~/ 1000;
    if (source > (_seconds[key] ?? 0)) {
      _seconds[key] = source;
    }
  }

  /// Defers another attempt when a relay explicitly rejects a future timestamp.
  void rejectedFuture({
    required String ownerPubkey,
    required String listId,
    required int createdAt,
  }) {
    _retryAfter['$ownerPubkey:$listId'] = createdAt + 1;
  }

  /// Reserves a revision later than any known source or attempted send.
  int next({required String ownerPubkey, required String listId}) {
    final key = '$ownerPubkey:$listId';
    final now = clock.now().millisecondsSinceEpoch ~/ 1000;
    if (now < (_retryAfter[key] ?? 0)) {
      throw const CuratedListClockException();
    }
    final previous = _seconds[key];
    final result = previous != null && previous >= now ? previous + 1 : now;
    // A client policy, not an assumption about a deployed relay's tolerance.
    // Exhaustion preserves the pending edit for an explicit later retry.
    if (result > now + maxFutureDrift.inSeconds) {
      throw const CuratedListClockException();
    }
    _seconds[key] = result;
    return result;
  }
}

/// A monotonic revision cannot currently fit the client clock policy.
class CuratedListClockException implements Exception {
  /// Retrying after clock advancement keeps the source revision intact.
  const CuratedListClockException();
}
